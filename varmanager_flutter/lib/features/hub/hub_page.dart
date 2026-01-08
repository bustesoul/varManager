import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/backend/job_log_controller.dart';
import '../../core/utils/debounce.dart';
import '../../widgets/lazy_dropdown_field.dart';
import '../../widgets/preview_placeholder.dart';
import '../../widgets/image_preview_dialog.dart';
import '../home/providers.dart';

Map<String, String>? _hubImageHeaders(String? url) {
  if (url == null || url.isEmpty) {
    return null;
  }
  final lower = url.toLowerCase();
  if (lower.startsWith('https://hub.virtamate.com/attachments/') ||
      lower.startsWith('http://hub.virtamate.com/attachments/')) {
    return const {'Cookie': 'vamhubconsent=yes'};
  }
  return null;
}

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

class HubResourcesCacheEntry {
  HubResourcesCacheEntry({
    required this.resources,
    required this.totalFound,
    required this.totalPages,
    required this.page,
    required this.timestamp,
  });

  final List<Map<String, dynamic>> resources;
  final int totalFound;
  final int totalPages;
  final int page;
  final DateTime timestamp;
}

class HubPage extends ConsumerStatefulWidget {
  const HubPage({super.key});

  @override
  ConsumerState<HubPage> createState() => _HubPageState();
}

class _HubPageState extends ConsumerState<HubPage> {
  final TextEditingController _searchController = TextEditingController();
  final _searchDebounce = Debouncer(const Duration(milliseconds: 300));
  HubInfo? _info;
  bool _loadingInfo = false;
  bool _loadingResources = false;
  int _resourceRequestId = 0;
  bool _pendingRefresh = false;
  bool _pendingForce = false;

  int _page = 1;
  int _perPage = 12;
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
  final Map<String, HubResourcesCacheEntry> _resourcesCache = {};
  final Map<String, String> _repoStatusById = {};
  final Map<String, String> _repoPackageById = {};
  final Map<String, String> _downloadUrlById = {};

  final Map<String, String> _downloadByVar = {};
  final Map<String, String> _downloadByUrl = {};

  static const int _tagChipLimit = 4;
  static const Duration _resourcesCacheTtl = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadInfo);
  }

  @override
  void dispose() {
    _searchDebounce.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _runJob(String kind, Map<String, dynamic> args) async {
    final runner = ref.read(jobRunnerProvider);
    final log = ref.read(jobLogProvider.notifier);
    await runner.runJob(kind, args: args, onLog: log.addLine);
  }

  Future<void> _openImagePreview(
    BuildContext context,
    List<String> imageUrls,
    int initialIndex,
  ) async {
    if (imageUrls.isEmpty) {
      return;
    }
    final previewItems = imageUrls
        .map(
          (url) => ImagePreviewItem(
            title: '',
            imageUrl: url,
            headers: _hubImageHeaders(url),
          ),
        )
        .toList();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return ImagePreviewDialog(
          items: previewItems,
          initialIndex: initialIndex.clamp(0, previewItems.length - 1),
          onIndexChanged: (_) {},
          showHeaderText: false,
          showFooter: false,
          wrapNavigation: true,
        );
      },
    );
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
      if (mounted) {
        setState(() {
          _loadingInfo = false;
        });
      }
    }
  }

  Map<String, dynamic> _buildResourcesQuery() {
    final sort = _sortSecondary.trim().isEmpty
        ? _sortPrimary.trim()
        : '${_sortPrimary.trim()},${_sortSecondary.trim()}';
    return {
      'perpage': _perPage,
      'location': _location,
      'paytype': _payType,
      'category': _category,
      'username': _creator,
      'tags': _tags,
      'search': _searchController.text.trim(),
      'sort': sort,
      'page': _page,
    };
  }

  String _buildCacheKey(Map<String, dynamic> query) {
    final keys = query.keys.toList()..sort();
    return keys.map((key) => '$key=${query[key]}').join('|');
  }

  bool _isCacheExpired(HubResourcesCacheEntry entry) {
    return DateTime.now().difference(entry.timestamp) > _resourcesCacheTtl;
  }

  Future<void> _refreshResources({bool force = false}) async {
    final requestId = ++_resourceRequestId;
    if (_loadingResources) {
      _pendingRefresh = true;
      _pendingForce = _pendingForce || force;
      return;
    }
    setState(() {
      _loadingResources = true;
    });
    final runner = ref.read(jobRunnerProvider);
    final log = ref.read(jobLogProvider.notifier);
    final query = _buildResourcesQuery();
    final cacheKey = _buildCacheKey(query);
    bool isCurrent() => requestId == _resourceRequestId;
    try {
      if (!force) {
        final cached = _resourcesCache[cacheKey];
        if (cached != null && !_isCacheExpired(cached)) {
          if (mounted && isCurrent()) {
            setState(() {
              _resources = cached.resources;
              _totalFound = cached.totalFound;
              _totalPages = cached.totalPages;
              _page = cached.page;
              _repoStatusById.clear();
              _repoPackageById.clear();
              _downloadUrlById.clear();
            });
          }
          if (mounted && isCurrent()) {
            await _updateRepositoryStatus();
          }
          return;
        }
      }
      final result = await runner.runJob(
        'hub_resources',
        args: query,
        onLog: log.addLine,
      );
      final payload = result.result as Map<String, dynamic>?;
      if (payload == null || !mounted || !isCurrent()) {
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
      if (!mounted || !isCurrent()) return;
      setState(() {
        _resources = resources;
        _totalFound = total;
        _totalPages = totalPages == 0 ? 1 : totalPages;
        _page = currentPage;
        _repoStatusById.clear();
        _repoPackageById.clear();
        _downloadUrlById.clear();
      });
      _resourcesCache[cacheKey] = HubResourcesCacheEntry(
        resources: resources,
        totalFound: total,
        totalPages: totalPages == 0 ? 1 : totalPages,
        page: currentPage,
        timestamp: DateTime.now(),
      );
      await _updateRepositoryStatus();
    } finally {
      await _completeRefresh();
    }
  }

  Future<void> _completeRefresh() async {
    if (!mounted) return;
    setState(() {
      _loadingResources = false;
    });
    if (_pendingRefresh) {
      final pendingForce = _pendingForce;
      _pendingRefresh = false;
      _pendingForce = false;
      await _refreshResources(force: pendingForce);
    }
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

  List<String> _parseResourceTags(Map<String, dynamic> resource) {
    final raw = resource['tags'];
    if (raw is String) {
      return raw
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty && item != 'null')
          .toList();
    }
    if (raw is List) {
      return raw
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty && item != 'null')
          .toList();
    }
    if (raw is Map) {
      return raw.keys
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty && item != 'null')
          .toList();
    }
    return [];
  }

  Map<String, dynamic>? _selectLatestHubFile(Map<String, dynamic> resource) {
    final hubFiles = resource['hubFiles'];
    if (hubFiles is! List) return null;
    Map<String, dynamic>? best;
    int bestVersion = -1;
    for (final entry in hubFiles) {
      if (entry is! Map) continue;
      final entryMap = entry.cast<String, dynamic>();
      final filename = entryMap['filename']?.toString() ?? '';
      if (!filename.toLowerCase().endsWith('.var')) continue;
      final baseName = filename.substring(0, filename.length - 4);
      final parts = baseName.split('.');
      if (parts.length < 3) continue;
      final version = int.tryParse(parts[2]) ?? 0;
      if (best == null || version > bestVersion) {
        best = entryMap;
        bestVersion = version;
      }
    }
    return best;
  }

  String _formatBytes(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    double size = bytes.toDouble();
    int unitIndex = 0;
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex += 1;
    }
    final precision = size >= 10 || unitIndex == 0 ? 0 : 1;
    return '${size.toStringAsFixed(precision)} ${units[unitIndex]}';
  }

  Future<void> _openResourceDetails(Map<String, dynamic> resource) async {
    final resourceId = _resourceId(resource);
    final title = resource['title']?.toString() ?? 'Untitled';

    final details = <MapEntry<String, String>>[];
    void addDetail(String label, String? value) {
      final clean = value?.trim();
      if (clean == null || clean.isEmpty || clean == 'null') return;
      details.add(MapEntry(label, clean));
    }

    final version = resource['version_string']?.toString();
    addDetail('Version', version);

    final dependencyCount =
        int.tryParse(resource['dependency_count']?.toString() ?? '');
    if (dependencyCount != null) {
      addDetail('Dependencies', dependencyCount.toString());
    }

    final viewCount = int.tryParse(resource['view_count']?.toString() ?? '');
    if (viewCount != null) {
      addDetail('Views', viewCount.toString());
    }
    final reviewCount = int.tryParse(resource['review_count']?.toString() ?? '');
    if (reviewCount != null) {
      addDetail('Reviews', reviewCount.toString());
    }
    final ratingWeighted =
        double.tryParse(resource['rating_weighted']?.toString() ?? '');
    if (ratingWeighted != null) {
      addDetail('Rating (weighted)', ratingWeighted.toStringAsFixed(2));
    }

    final hubFile = _selectLatestHubFile(resource);
    if (hubFile != null) {
      addDetail('License', hubFile['licenseType']?.toString());
      final fileSize =
          int.tryParse(hubFile['file_size']?.toString() ?? '');
      if (fileSize != null) {
        addDetail('File Size', _formatBytes(fileSize));
      }
      addDetail('Program Version', hubFile['programVersion']?.toString());
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _EnhancedResourceDetailDialog(
          title: title,
          resourceId: resourceId,
          basicDetails: details,
          runner: ref.read(jobRunnerProvider),
          log: ref.read(jobLogProvider.notifier),
        );
      },
    );
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

  void _addResourceFiles(Map<String, dynamic> resource) {
    final hubFiles = resource['hubFiles'];
    if (hubFiles is! List) return;
    for (final entry in hubFiles) {
      if (entry is! Map) continue;
      final filename = entry['filename']?.toString() ?? '';
      final url = entry['urlHosted']?.toString() ?? '';
      if (filename.isEmpty || url.isEmpty || url == 'null') continue;
      if (!filename.toLowerCase().endsWith('.var')) continue;
      final baseName = filename.substring(0, filename.length - 4);
      _addDownloadUrl(baseName, url);
    }
    if (!mounted) return;
    setState(() {});
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
      ref.read(navIndexProvider.notifier).setIndex(0);
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

  void _resetFilters() {
    final info = _info;
    setState(() {
      _location = 'All';
      _payType = info != null && info.payTypes.contains('Free') ? 'Free' : 'All';
      _category = 'All';
      _creator = 'All';
      _tags = 'All';
      _sortPrimary = info != null && info.sorts.isNotEmpty ? info.sorts.first : '';
      _sortSecondary = '';
      _page = 1;
      _searchController.clear();
    });
    _refreshResources(force: true);
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
    final sortPrimaryValue = options == null || options.sorts.isEmpty
        ? null
        : (_sortPrimary.isEmpty ? options.sorts.first : _sortPrimary);
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

                    // Search - 始终显示
                    TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        labelText: 'Search',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) {
                        _searchDebounce.run(() {
                          if (!mounted) return;
                          setState(() {
                            _page = 1;
                          });
                          _refreshResources();
                        });
                      },
                      onSubmitted: (_) {
                        setState(() {
                          _page = 1;
                        });
                        _refreshResources();
                      },
                    ),
                    const SizedBox(height: 12),

                    // 基础筛选 - 可折叠
                    ExpansionTile(
                      title: const Text('Basic Filters'),
                      initiallyExpanded: true,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Column(
                            children: [
                              DropdownButtonFormField<String>(
                                key: ValueKey(_location),
                                initialValue: _location,
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
                                key: ValueKey(_payType),
                                initialValue: _payType,
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
                            ],
                          ),
                        ),
                      ],
                    ),

                    // 高级筛选 - 可折叠
                    ExpansionTile(
                      title: const Text('Advanced Filters'),
                      initiallyExpanded: false,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Column(
                            children: [
                              DropdownButtonFormField<String>(
                                key: ValueKey(_category),
                                initialValue: _category,
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
                              LazyDropdownField(
                                label: 'Creator',
                                value: _creator.isEmpty ? 'All' : _creator,
                                allValue: 'All',
                                allLabel: 'All creators',
                                optionsLoader: (queryText, offset, limit) async {
                                  final client = ref.read(backendClientProvider);
                                  return client.listHubOptions(
                                    kind: 'creator',
                                    query: queryText,
                                    offset: offset,
                                    limit: limit,
                                  );
                                },
                                onChanged: (value) {
                                  _updateAndRefresh(() {
                                    _creator = value;
                                    _page = 1;
                                  });
                                },
                              ),
                              const SizedBox(height: 8),
                              LazyDropdownField(
                                label: 'Tag',
                                value: _tags.isEmpty ? 'All' : _tags,
                                allValue: 'All',
                                allLabel: 'All tags',
                                optionsLoader: (queryText, offset, limit) async {
                                  final client = ref.read(backendClientProvider);
                                  return client.listHubOptions(
                                    kind: 'tag',
                                    query: queryText,
                                    offset: offset,
                                    limit: limit,
                                  );
                                },
                                onChanged: (value) {
                                  _updateAndRefresh(() {
                                    _tags = value;
                                    _page = 1;
                                  });
                                },
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // 排序选项 - 可折叠，修复空列表问题
                    ExpansionTile(
                      title: const Text('Sort Options'),
                      initiallyExpanded: false,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Column(
                            children: [
                              if (options?.sorts != null && options!.sorts.isNotEmpty)
                                DropdownButtonFormField<String>(
                                  key: ValueKey(sortPrimaryValue ?? ''),
                                  initialValue: sortPrimaryValue,
                                  items: options.sorts
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
                                )
                              else
                                const ListTile(
                                  title: Text('No sort options available'),
                                  subtitle: Text('Loading...'),
                                ),
                              const SizedBox(height: 8),
                              if (options?.sorts != null && options!.sorts.isNotEmpty)
                                DropdownButtonFormField<String>(
                                  key: ValueKey(_sortSecondary),
                                  initialValue: _sortSecondary,
                                  items: ['']
                                      .followedBy(options.sorts)
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
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _resetFilters,
                      child: const Text('Reset Filters'),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButton<int>(
                            value: _perPage,
                            items: const [12, 24, 48]
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
                      onPressed: _loadingResources
                          ? null
                          : () => _refreshResources(force: true),
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
                          onPressed: () => _refreshResources(force: true),
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
    final version = resource['version_string']?.toString() ?? '';
    final dependencyCount =
        int.tryParse(resource['dependency_count']?.toString() ?? '');
    final tags = _parseResourceTags(resource);
    final displayTags = tags.take(_tagChipLimit).toList();
    final extraTagCount =
        tags.length > _tagChipLimit ? tags.length - _tagChipLimit : 0;
    final hasHubFiles =
        resource['hubFiles'] is List && (resource['hubFiles'] as List).isNotEmpty;
    final repoStatus = _repoStatusById[resourceId] ?? 'Unknown Status';
    final cacheSize =
        (96 * MediaQuery.of(context).devicePixelRatio).round();

    final canPreview = imageUrl != null && imageUrl.isNotEmpty;
    final previewImage = ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: imageUrl == null || imageUrl.isEmpty
          ? const PreviewPlaceholder(width: 96, height: 96)
          : Image.network(
              imageUrl,
              headers: _hubImageHeaders(imageUrl),
              width: 96,
              height: 96,
              fit: BoxFit.cover,
              cacheWidth: cacheSize,
              cacheHeight: cacheSize,
              errorBuilder: (_, _, _) => const PreviewPlaceholder(
                width: 96,
                height: 96,
                icon: Icons.broken_image,
              ),
            ),
    );

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
                GestureDetector(
                  onDoubleTap: canPreview
                      ? () => _openImagePreview(context, [imageUrl], 0)
                      : null,
                  child: previewImage,
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
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          ActionChip(
                            label: Text(payType, style: const TextStyle(fontSize: 12)),
                            visualDensity: VisualDensity.compact,
                            onPressed: payType == '-' ? null : () => _applyQuickFilter(payType: payType),
                          ),
                          ActionChip(
                            label: Text(type, style: const TextStyle(fontSize: 12)),
                            visualDensity: VisualDensity.compact,
                            onPressed: type == '-' ? null : () => _applyQuickFilter(category: type),
                          ),
                          ActionChip(
                            label: Text(username, style: const TextStyle(fontSize: 12)),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _applyQuickFilter(creator: username),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('Rating $ratingAvg ($ratingCount) | $downloads downloads'),
                      Text('Updated $lastUpdated'),
                      if (version.isNotEmpty && version != 'null' ||
                          dependencyCount != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          [
                            if (version.isNotEmpty && version != 'null')
                              'Version $version',
                            if (dependencyCount != null)
                              'Deps $dependencyCount',
                          ].join(' | '),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (displayTags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final tag in displayTags)
                    ActionChip(
                      label: Text(tag),
                      onPressed: () {
                        _updateAndRefresh(() {
                          _tags = tag;
                          _page = 1;
                        });
                      },
                    ),
                  if (extraTagCount > 0) Chip(label: Text('+$extraTagCount')),
                ],
              ),
            ],
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
                  onPressed: () => _openResourceDetails(resource),
                  child: const Text('Detail'),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'files') {
                      _addResourceFiles(resource);
                    }
                    if (value == 'deps') {
                      _addResourceDownloads(resourceId);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'files',
                      enabled: hasHubFiles,
                      child: const Text('Add Files Only'),
                    ),
                    PopupMenuItem(
                      value: 'deps',
                      enabled: resourceId.isNotEmpty,
                      child: const Text('Add With Dependencies'),
                    ),
                  ],
                  child: const Text('Add'),
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

class _EnhancedResourceDetailDialog extends StatefulWidget {
  const _EnhancedResourceDetailDialog({
    required this.title,
    required this.resourceId,
    required this.basicDetails,
    required this.runner,
    required this.log,
  });

  final String title;
  final String resourceId;
  final List<MapEntry<String, String>> basicDetails;
  final dynamic runner;
  final dynamic log;

  @override
  State<_EnhancedResourceDetailDialog> createState() =>
      _EnhancedResourceDetailDialogState();
}

class _EnhancedResourceDetailDialogState
    extends State<_EnhancedResourceDetailDialog> {
  bool _loading = false;
  String _description = '';
  List<String> _images = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.resourceId.isNotEmpty) {
      _loadOverviewPanel();
    }
  }

  Future<void> _loadOverviewPanel() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await widget.runner.runJob(
        'hub_overview_panel',
        args: {'resource_id': widget.resourceId},
        onLog: widget.log.addLine,
      );

      final payload = result.result as Map<String, dynamic>?;
      if (payload != null && mounted) {
        setState(() {
          _description = payload['description']?.toString() ?? '';
          _images = (payload['images'] as List?)
                  ?.map((e) => e.toString())
                  .where((url) => url.isNotEmpty)
                  .toList() ??
              [];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _openImagePreview(
    BuildContext context,
    List<String> imageUrls,
    int initialIndex,
  ) async {
    if (imageUrls.isEmpty) {
      return;
    }
    final previewItems = imageUrls
        .map(
          (url) => ImagePreviewItem(
            title: '',
            imageUrl: url,
            headers: _hubImageHeaders(url),
          ),
        )
        .toList();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return ImagePreviewDialog(
          items: previewItems,
          initialIndex: initialIndex.clamp(0, previewItems.length - 1),
          onIndexChanged: (_) {},
          showHeaderText: false,
          showFooter: false,
          wrapNavigation: true,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 800,
          maxHeight: 600,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Scrollbar(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 基本信息
                      if (widget.basicDetails.isNotEmpty) ...[
                        const Text(
                          'Basic Information',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (final entry in widget.basicDetails)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 150,
                                  child: Text(
                                    entry.key,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Expanded(child: Text(entry.value)),
                              ],
                            ),
                          ),
                        const SizedBox(height: 24),
                      ],

                      // 加载状态
                      if (_loading) ...[
                        const Center(
                          child: Column(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 12),
                              Text('Loading detailed information...'),
                            ],
                          ),
                        ),
                      ],

                      // 错误信息
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.red.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Failed to load details: $_error',
                                  style: TextStyle(color: Colors.red.shade700),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // 描述
                      if (!_loading && _error == null && _description.isNotEmpty) ...[
                        const Text(
                          'Description',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
      child: SelectableText(
                            _description,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // 图片
                      if (!_loading && _error == null && _images.isNotEmpty) ...[
                        const Text(
                          'Images',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: _images.asMap().entries.map((entry) {
                            final index = entry.key;
                            final imageUrl = entry.value;
                            return GestureDetector(
                              onTap: () => _openImagePreview(context, _images, index),
                              child: Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    imageUrl,
                                    headers: _hubImageHeaders(imageUrl),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Container(
                                      color: Colors.grey.shade200,
                                      child: const Icon(
                                        Icons.broken_image,
                                        size: 48,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
