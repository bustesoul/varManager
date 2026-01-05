import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/backend/job_log_controller.dart';
import '../home/home_page.dart';

class HubInfo {
  HubInfo({
    required this.locations,
    required this.payTypes,
    required this.categories,
    required this.tags,
    required this.creators,
    required this.sorts,
  });

  final List<String> locations;
  final List<String> payTypes;
  final List<String> categories;
  final List<String> tags;
  final List<String> creators;
  final List<String> sorts;

  factory HubInfo.fromPayload(Map<String, dynamic> payload) {
    List<String> listFromArray(dynamic value) {
      if (value is List) {
        return value.map((item) => item.toString()).toList();
      }
      return [];
    }

    List<String> listFromKeys(dynamic value) {
      if (value is Map) {
        return value.keys.map((item) => item.toString()).toList();
      }
      return [];
    }

    return HubInfo(
      locations: listFromArray(payload['location']),
      payTypes: listFromArray(payload['category']),
      categories: listFromArray(payload['type']),
      tags: listFromKeys(payload['tags']),
      creators: listFromKeys(payload['users']),
      sorts: listFromArray(payload['sort']),
    );
  }
}

class HubPackageInfo {
  HubPackageInfo({
    required this.packageKey,
    required this.hubVersion,
    required this.displayVarName,
  });

  final String packageKey;
  final int hubVersion;
  final String displayVarName;
}

class HubPage extends ConsumerStatefulWidget {
  const HubPage({super.key});

  @override
  ConsumerState<HubPage> createState() => _HubPageState();
}

class _HubPageState extends ConsumerState<HubPage> {
  final TextEditingController _searchController = TextEditingController();
  HubInfo? _info;
  bool _loadingInfo = false;
  bool _loadingResources = false;

  int _page = 1;
  int _perPage = 48;
  int _totalPages = 1;
  int _totalFound = 0;

  String _location = 'All';
  String _payType = 'All';
  String _category = 'All';
  String _creator = 'All';
  String _tags = 'All';
  String _sortPrimary = '';
  String _sortSecondary = '';

  List<Map<String, dynamic>> _resources = [];
  final Map<String, String> _repoStatusById = {};
  final Map<String, String> _repoPackageById = {};
  final Map<String, String> _downloadUrlById = {};

  final Map<String, String> _downloadByVar = {};
  final Map<String, String> _downloadByUrl = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadInfo);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _runJob(String kind, Map<String, dynamic> args) async {
    final runner = ref.read(jobRunnerProvider);
    final log = ref.read(jobLogProvider.notifier);
    await runner.runJob(kind, args: args, onLog: log.addLine);
  }

  Future<void> _loadInfo() async {
    if (_loadingInfo) return;
    setState(() {
      _loadingInfo = true;
    });
    try {
      final runner = ref.read(jobRunnerProvider);
      final log = ref.read(jobLogProvider.notifier);
      final result = await runner.runJob('hub_info', args: {}, onLog: log.addLine);
      final payload = result.result as Map<String, dynamic>?;
      if (payload == null) return;
      final info = HubInfo.fromPayload(payload);
      if (!mounted) return;
      setState(() {
        _info = info;
        _location = 'All';
        _payType = info.payTypes.contains('Free') ? 'Free' : 'All';
        _category = 'All';
        _creator = 'All';
        _tags = 'All';
        _sortPrimary = info.sorts.isNotEmpty ? info.sorts.first : '';
        _sortSecondary = '';
      });
      await _refreshResources(force: true);
    } finally {
      if (!mounted) return;
      setState(() {
        _loadingInfo = false;
      });
    }
  }

  Future<void> _refreshResources({bool force = false}) async {
    if (_loadingResources && !force) return;
    setState(() {
      _loadingResources = true;
    });
    final runner = ref.read(jobRunnerProvider);
    final log = ref.read(jobLogProvider.notifier);
    final sort = _sortSecondary.trim().isEmpty
        ? _sortPrimary.trim()
        : '${_sortPrimary.trim()},${_sortSecondary.trim()}';
    final result = await runner.runJob(
      'hub_resources',
      args: {
        'perpage': _perPage,
        'location': _location,
        'paytype': _payType,
        'category': _category,
        'username': _creator,
        'tags': _tags,
        'search': _searchController.text.trim(),
        'sort': sort,
        'page': _page,
      },
      onLog: log.addLine,
    );
    final payload = result.result as Map<String, dynamic>?;
    if (payload == null) {
      if (!mounted) return;
      setState(() {
        _loadingResources = false;
      });
      return;
    }
    final resources = (payload['resources'] as List<dynamic>? ?? [])
        .map((item) => (item as Map).cast<String, dynamic>())
        .toList();
    final pagination = payload['pagination'] as Map<String, dynamic>? ?? {};
    final total = int.tryParse(pagination['total_found']?.toString() ?? '') ??
        resources.length;
    final totalPages =
        int.tryParse(pagination['total_pages']?.toString() ?? '') ?? 1;
    final currentPage =
        int.tryParse(pagination['page']?.toString() ?? '') ?? _page;
    if (!mounted) return;
    setState(() {
      _resources = resources;
      _totalFound = total;
      _totalPages = totalPages == 0 ? 1 : totalPages;
      _page = currentPage;
      _repoStatusById.clear();
      _repoPackageById.clear();
      _downloadUrlById.clear();
    });
    await _updateRepositoryStatus();
    if (!mounted) return;
    setState(() {
      _loadingResources = false;
    });
  }

  Future<void> _updateRepositoryStatus() async {
    final packageByResource = <String, HubPackageInfo>{};
    final latestRequests = <String>{};
    for (final resource in _resources) {
      final resourceId = _resourceId(resource);
      if (resourceId.isEmpty) continue;
      final hubFiles = resource['hubFiles'];
      if (hubFiles is List) {
        HubPackageInfo? info;
        for (final entry in hubFiles) {
          if (entry is! Map) continue;
          final filename = entry['filename']?.toString() ?? '';
          if (!filename.toLowerCase().endsWith('.var')) continue;
          final baseName = filename.substring(0, filename.length - 4);
          final parts = baseName.split('.');
          if (parts.length < 3) continue;
          final packageKey = '${parts[0]}.${parts[1]}';
          final hubVersion = int.tryParse(parts[2]) ?? 1;
          if (info == null || hubVersion > info.hubVersion) {
            info = HubPackageInfo(
              packageKey: packageKey,
              hubVersion: hubVersion,
              displayVarName: baseName,
            );
          }
        }
        if (info != null) {
          packageByResource[resourceId] = info;
          latestRequests.add('${info.packageKey}.latest');
        }
      } else {
        final downloadUrl = resource['download_url']?.toString() ?? '';
        if (downloadUrl.isNotEmpty && downloadUrl != 'null') {
          _downloadUrlById[resourceId] = downloadUrl;
          _repoStatusById[resourceId] = 'Go To Download';
        }
      }
    }

    if (latestRequests.isEmpty) {
      setState(() {});
      return;
    }
    final client = ref.read(backendClientProvider);
    final resolved = await client.resolveVars(latestRequests.toList());
    final nextStatus = <String, String>{};
    final nextPackage = <String, String>{};

    for (final entry in packageByResource.entries) {
      final resourceId = entry.key;
      final info = entry.value;
      final resolvedName = resolved.resolved['${info.packageKey}.latest'] ?? 'missing';
      if (resolvedName == 'missing') {
        nextStatus[resourceId] = 'Generate Download List';
        nextPackage[resourceId] = info.displayVarName;
        continue;
      }
      final resolvedClean = resolvedName.endsWith(r'$')
          ? resolvedName.substring(0, resolvedName.length - 1)
          : resolvedName;
      final parts = resolvedClean.split('.');
      final installedVersion =
          parts.isNotEmpty ? int.tryParse(parts.last) ?? 0 : 0;
      if (installedVersion >= info.hubVersion) {
        nextStatus[resourceId] = 'In Repository';
      } else {
        nextStatus[resourceId] = '$installedVersion Upgrade to ${info.hubVersion}';
      }
      nextPackage[resourceId] = info.displayVarName;
    }

    if (!mounted) return;
    setState(() {
      _repoStatusById.addAll(nextStatus);
      _repoPackageById.addAll(nextPackage);
    });
  }

  Future<void> _scanMissing() async {
    final runner = ref.read(jobRunnerProvider);
    final log = ref.read(jobLogProvider.notifier);
    final result = await runner.runJob('hub_missing_scan', args: {}, onLog: log.addLine);
    final payload = result.result as Map<String, dynamic>?;
    if (payload == null) return;
    _mergeDownloads(payload);
  }

  Future<void> _scanUpdates() async {
    final runner = ref.read(jobRunnerProvider);
    final log = ref.read(jobLogProvider.notifier);
    final result = await runner.runJob('hub_updates_scan', args: {}, onLog: log.addLine);
    final payload = result.result as Map<String, dynamic>?;
    if (payload == null) return;
    _mergeDownloads(payload);
  }

  void _mergeDownloads(Map<String, dynamic> payload) {
    final direct = payload['download_urls'] as Map<String, dynamic>? ?? {};
    final noVersion = payload['download_urls_no_version'] as Map<String, dynamic>? ?? {};
    for (final entry in direct.entries) {
      _addDownloadUrl(entry.key.toString(), entry.value?.toString() ?? '');
    }
    for (final entry in noVersion.entries) {
      _addDownloadUrl(entry.key.toString(), entry.value?.toString() ?? '');
    }
    if (!mounted) return;
    setState(() {});
  }

  void _addDownloadUrl(String varName, String url) {
    final cleanVar = varName.trim();
    final cleanUrl = url.trim();
    if (cleanVar.isEmpty || cleanUrl.isEmpty || cleanUrl == 'null') return;
    final existingUrl = _downloadByVar[cleanVar];
    if (existingUrl != null && existingUrl.toLowerCase() != cleanUrl.toLowerCase()) {
      _downloadByUrl.remove(existingUrl);
    }
    final existingName = _downloadByUrl[cleanUrl];
    if (existingName != null && existingName.toLowerCase() != cleanVar.toLowerCase()) {
      final existingVersioned = _isVersionedName(existingName);
      final newVersioned = _isVersionedName(cleanVar);
      if (newVersioned && !existingVersioned) {
        _downloadByVar.remove(existingName);
        _downloadByVar[cleanVar] = cleanUrl;
        _downloadByUrl[cleanUrl] = cleanVar;
      }
      return;
    }
    _downloadByVar[cleanVar] = cleanUrl;
    _downloadByUrl[cleanUrl] = cleanVar;
  }

  bool _isVersionedName(String name) {
    final parts = name.split('.');
    if (parts.length < 3) return false;
    return int.tryParse(parts.last) != null;
  }

  String _resourceId(Map<String, dynamic> resource) {
    return resource['resource_id']?.toString() ?? resource['id']?.toString() ?? '';
  }

  List<String> _optionsWithAll(List<String> values) {
    final options = <String>['All', ...values];
    return options;
  }

  Future<void> _addResourceDownloads(String resourceId) async {
    if (resourceId.isEmpty) return;
    final runner = ref.read(jobRunnerProvider);
    final log = ref.read(jobLogProvider.notifier);
    final result = await runner.runJob(
      'hub_resource_detail',
      args: {'resource_id': resourceId},
      onLog: log.addLine,
    );
    final payload = result.result as Map<String, dynamic>?;
    if (payload == null) return;
    _mergeDownloads(payload);
  }

  Future<void> _handleRepositoryAction(Map<String, dynamic> resource) async {
    final resourceId = _resourceId(resource);
    if (resourceId.isEmpty) return;
    final status = _repoStatusById[resourceId] ?? 'Unknown Status';
    if (status == 'In Repository') {
      final name = _repoPackageById[resourceId];
      if (name == null || name.isEmpty) return;
      ref.read(varsQueryProvider.notifier).update(
            (state) => state.copyWith(page: 1, search: name),
          );
      ref.read(navIndexProvider.notifier).state = 0;
      return;
    }
    if (status.contains('Generate Download List') || status.contains('Upgrade to')) {
      await _addResourceDownloads(resourceId);
      return;
    }
    if (status == 'Go To Download') {
      final url = _downloadUrlById[resourceId];
      if (url == null || url.isEmpty) return;
      await _runJob('open_url', {'url': url});
    }
  }

  void _applyQuickFilter({String? payType, String? category, String? creator}) {
    setState(() {
      if (payType != null && payType.isNotEmpty) {
        _payType = payType;
      }
      if (category != null && category.isNotEmpty) {
        _category = category;
      }
      if (creator != null && creator.isNotEmpty) {
        _creator = creator;
      }
      _page = 1;
    });
    _refreshResources();
  }

  void _updateAndRefresh(VoidCallback update) {
    setState(update);
    _refreshResources();
  }

  String _formatDate(dynamic unixSeconds) {
    if (unixSeconds == null) return '-';
    final raw = int.tryParse(unixSeconds.toString());
    if (raw == null) return '-';
    final date = DateTime.fromMillisecondsSinceEpoch(raw * 1000, isUtc: true).toLocal();
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final options = _info;
    final downloadUrls = _downloadByUrl.keys.toList();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          SizedBox(
            width: 340,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ListView(
                  children: [
                    const Text('Filters & Actions',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        labelText: 'Search',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _refreshResources(),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _location,
                      items: _optionsWithAll(options?.locations ?? [])
                          .map((value) => DropdownMenuItem(
                                value: value,
                                child: Text(value == 'All' ? 'All locations' : value),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        _updateAndRefresh(() {
                          _location = value;
                          _page = 1;
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'Location',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _payType,
                      items: _optionsWithAll(options?.payTypes ?? [])
                          .map((value) => DropdownMenuItem(
                                value: value,
                                child: Text(value == 'All' ? 'All pay types' : value),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        _updateAndRefresh(() {
                          _payType = value;
                          _page = 1;
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'Pay Type',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _category,
                      items: _optionsWithAll(options?.categories ?? [])
                          .map((value) => DropdownMenuItem(
                                value: value,
                                child: Text(value == 'All' ? 'All types' : value),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        _updateAndRefresh(() {
                          _category = value;
                          _page = 1;
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _creator,
                      items: _optionsWithAll(options?.creators ?? [])
                          .map((value) => DropdownMenuItem(
                                value: value,
                                child: Text(value == 'All' ? 'All creators' : value),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        _updateAndRefresh(() {
                          _creator = value;
                          _page = 1;
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'Creator',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _tags,
                      items: _optionsWithAll(options?.tags ?? [])
                          .map((value) => DropdownMenuItem(
                                value: value,
                                child: Text(value == 'All' ? 'All tags' : value),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        _updateAndRefresh(() {
                          _tags = value;
                          _page = 1;
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'Tag',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: options == null || options.sorts.isEmpty
                          ? null
                          : (_sortPrimary.isEmpty
                              ? options.sorts.first
                              : _sortPrimary),
                      items: (options?.sorts ?? [])
                          .map((value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        _updateAndRefresh(() {
                          _sortPrimary = value;
                          _page = 1;
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'Primary Sort',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _sortSecondary,
                      items: ['']
                          .followedBy(options?.sorts ?? [])
                          .map((value) => DropdownMenuItem(
                                value: value,
                                child: Text(value.isEmpty ? 'No secondary sort' : value),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        _updateAndRefresh(() {
                          _sortSecondary = value;
                          _page = 1;
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'Secondary Sort',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButton<int>(
                            value: _perPage,
                            items: const [20, 48]
                                .map((value) => DropdownMenuItem(
                                      value: value,
                                      child: Text('Per page $value'),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              _updateAndRefresh(() {
                                _perPage = value;
                                _page = 1;
                              });
                            },
                          ),
                        ),
                        Text('$_page / $_totalPages'),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: _page <= 1
                              ? null
                              : () {
                                  setState(() {
                                    _page = 1;
                                  });
                                  _refreshResources();
                                },
                          icon: const Icon(Icons.first_page),
                        ),
                        IconButton(
                          onPressed: _page <= 1
                              ? null
                              : () {
                                  setState(() {
                                    _page -= 1;
                                  });
                                  _refreshResources();
                                },
                          icon: const Icon(Icons.chevron_left),
                        ),
                        IconButton(
                          onPressed: _page >= _totalPages
                              ? null
                              : () {
                                  setState(() {
                                    _page += 1;
                                  });
                                  _refreshResources();
                                },
                          icon: const Icon(Icons.chevron_right),
                        ),
                        IconButton(
                          onPressed: _page >= _totalPages
                              ? null
                              : () {
                                  setState(() {
                                    _page = _totalPages;
                                  });
                                  _refreshResources();
                                },
                          icon: const Icon(Icons.last_page),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _loadingResources ? null : _refreshResources,
                      child: const Text('Refresh'),
                    ),
                    OutlinedButton(
                      onPressed: _scanMissing,
                      child: const Text('Scan Missing'),
                    ),
                    OutlinedButton(
                      onPressed: _scanUpdates,
                      child: const Text('Scan Updates'),
                    ),
                    const Divider(height: 24),
                    const Text('Download List',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text('Total ${downloadUrls.length} links'),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: downloadUrls.isEmpty
                          ? null
                          : () async {
                              await _runJob('hub_download_all', {'urls': downloadUrls});
                            },
                      child: const Text('Download All'),
                    ),
                    OutlinedButton(
                      onPressed: downloadUrls.isEmpty
                          ? null
                          : () async {
                              await Clipboard.setData(
                                ClipboardData(text: downloadUrls.join('\n')),
                              );
                            },
                      child: const Text('Copy Links'),
                    ),
                    OutlinedButton(
                      onPressed: downloadUrls.isEmpty
                          ? null
                          : () {
                              setState(() {
                                _downloadByVar.clear();
                                _downloadByUrl.clear();
                              });
                            },
                      child: const Text('Clear List'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Card(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Text('Resources ($_totalFound)'),
                        const Spacer(),
                        if (_loadingResources)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: _refreshResources,
                          child: const Text('Refresh'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final columns = width > 1400
                            ? 3
                            : width > 900
                                ? 2
                                : 1;
                        return GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.6,
                          ),
                          itemCount: _resources.length,
                          itemBuilder: (context, index) {
                            final resource = _resources[index];
                            return _buildResourceCard(resource);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResourceCard(Map<String, dynamic> resource) {
    final resourceId = _resourceId(resource);
    final title = resource['title']?.toString() ?? 'Untitled';
    final username = resource['username']?.toString() ?? 'unknown';
    final type = resource['type']?.toString() ?? '-';
    final payType = resource['category']?.toString() ?? '-';
    final tagLine = resource['tag_line']?.toString() ?? '';
    final imageUrl = resource['image_url']?.toString();
    final ratingAvg = double.tryParse(resource['rating_avg']?.toString() ?? '') ?? 0;
    final ratingCount = int.tryParse(resource['rating_count']?.toString() ?? '') ?? 0;
    final downloads = int.tryParse(resource['download_count']?.toString() ?? '') ?? 0;
    final lastUpdated = _formatDate(resource['last_update']);
    final repoStatus = _repoStatusById[resourceId] ?? 'Unknown Status';

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: imageUrl == null || imageUrl.isEmpty
                      ? Container(
                          width: 96,
                          height: 96,
                          color: Colors.grey.shade200,
                          alignment: Alignment.center,
                          child: const Icon(Icons.image_not_supported),
                        )
                      : Image.network(
                          imageUrl,
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 96,
                            height: 96,
                            color: Colors.grey.shade200,
                            alignment: Alignment.center,
                            child: const Icon(Icons.broken_image),
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (tagLine.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          tagLine,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text('Rating $ratingAvg ($ratingCount) | $downloads downloads'),
                      Text('Updated $lastUpdated'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ActionChip(
                  label: Text(payType),
                  onPressed: payType == '-' ? null : () => _applyQuickFilter(payType: payType),
                ),
                ActionChip(
                  label: Text(type),
                  onPressed: type == '-' ? null : () => _applyQuickFilter(category: type),
                ),
                ActionChip(
                  label: Text(username),
                  onPressed: () => _applyQuickFilter(creator: username),
                ),
              ],
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: repoStatus == 'Unknown Status' ? null : () => _handleRepositoryAction(resource),
                    child: Text(repoStatus, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: resourceId.isEmpty ? null : () => _addResourceDownloads(resourceId),
                  child: const Text('Add Downloads'),
                ),
                TextButton(
                  onPressed: resourceId.isEmpty
                      ? null
                      : () async {
                          await _runJob('open_url', {
                            'url': 'https://hub.virtamate.com/resources/$resourceId/',
                          });
                        },
                  child: const Text('Open Page'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
