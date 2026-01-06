import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/backend/job_log_controller.dart';
import '../../core/models/extra_models.dart';
import '../home/home_page.dart';

class MissingEntry {
  MissingEntry({
    required this.rawName,
    required this.displayName,
    required this.versionMismatch,
  });

  final String rawName;
  final String displayName;
  final bool versionMismatch;
}

class MissingVarsPage extends ConsumerStatefulWidget {
  const MissingVarsPage({super.key, required this.missing});

  final List<String> missing;

  @override
  ConsumerState<MissingVarsPage> createState() => _MissingVarsPageState();
}

class _MissingVarsPageState extends ConsumerState<MissingVarsPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();
  String _creatorFilter = 'ALL';
  String _versionFilter = 'ignore';

  List<MissingEntry> _entries = [];
  int _selectedIndex = -1;
  String? _selectedVar;

  Map<String, String> _linkMap = {};
  Map<String, String> _downloadUrls = {};
  Map<String, String> _downloadUrlsNoVersion = {};
  Map<String, String> _resolved = {};

  List<String> _dependents = [];
  List<String> _dependentSaves = [];
  bool _loadingDependents = false;

  @override
  void initState() {
    super.initState();
    _entries = widget.missing.map(_parseEntry).toList();
    Future.microtask(_refreshResolved);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  MissingEntry _parseEntry(String raw) {
    var name = raw.trim();
    var mismatch = false;
    if (name.endsWith(r'$')) {
      mismatch = true;
      name = name.substring(0, name.length - 1);
    }
    final slashIndex = name.lastIndexOf('/');
    if (slashIndex >= 0 && slashIndex + 1 < name.length) {
      name = name.substring(slashIndex + 1);
    }
    return MissingEntry(rawName: raw, displayName: name, versionMismatch: mismatch);
  }

  List<MissingEntry> get _filteredEntries {
    final search = _searchController.text.trim().toLowerCase();
    return _entries.where((entry) {
      if (_versionFilter == 'ignore' && entry.versionMismatch) {
        return false;
      }
      if (_creatorFilter != 'ALL' && !entry.displayName.startsWith('$_creatorFilter.')) {
        return false;
      }
      if (search.isEmpty) return true;
      return entry.displayName.toLowerCase().contains(search);
    }).toList();
  }

  Future<void> _runJob(String kind, Map<String, dynamic> args) async {
    final runner = ref.read(jobRunnerProvider);
    final log = ref.read(jobLogProvider.notifier);
    await runner.runJob(kind, args: args, onLog: log.addLine);
  }

  Future<void> _refreshResolved() async {
    final names = _entries.map((entry) => entry.displayName).toSet().toList();
    if (names.isEmpty) return;
    final client = ref.read(backendClientProvider);
    final response = await client.resolveVars(names);
    if (!mounted) return;
    setState(() {
      _resolved = response.resolved;
    });
    _ensureSelection();
  }

  void _ensureSelection() {
    final filtered = _filteredEntries;
    if (filtered.isEmpty) {
      setState(() {
        _selectedIndex = -1;
        _selectedVar = null;
        _linkController.text = '';
        _dependents = [];
        _dependentSaves = [];
      });
      return;
    }
    var nextIndex = _selectedIndex;
    if (nextIndex < 0 || nextIndex >= filtered.length) {
      nextIndex = 0;
    }
    _selectIndex(nextIndex, filtered);
  }

  void _selectIndex(int index, List<MissingEntry> list) {
    final entry = list[index];
    setState(() {
      _selectedIndex = index;
      _selectedVar = entry.displayName;
      _linkController.text = _linkMap[entry.displayName] ?? '';
    });
    _loadDependents(entry.displayName);
  }

  Future<void> _loadDependents(String name) async {
    setState(() {
      _loadingDependents = true;
    });
    final client = ref.read(backendClientProvider);
    final response = await client.getDependents(name);
    if (!mounted) return;
    setState(() {
      _dependents = response.dependents;
      _dependentSaves = response.dependentSaves;
      _loadingDependents = false;
    });
  }

  String _noVersionKey(String name) {
    final index = name.lastIndexOf('.');
    if (index <= 0) return name;
    return name.substring(0, index);
  }

  String _downloadStatus(String name) {
    if (_downloadUrls.containsKey(name)) return 'Direct';
    if (_downloadUrlsNoVersion.containsKey(_noVersionKey(name))) return 'No Version';
    return 'None';
  }

  IconData _downloadIcon(String name) {
    final status = _downloadStatus(name);
    switch (status) {
      case 'Direct':
        return Icons.cloud_done;
      case 'No Version':
        return Icons.cloud_download;
      default:
        return Icons.block;
    }
  }

  Color _downloadColor(String name) {
    final status = _downloadStatus(name);
    switch (status) {
      case 'Direct':
        return Colors.green;
      case 'No Version':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _resolvedDisplay(String name) {
    final resolved = _resolved[name];
    if (resolved == null || resolved == 'missing') return 'missing';
    if (resolved.endsWith(r'$')) {
      return '${resolved.substring(0, resolved.length - 1)} (closest)';
    }
    return resolved;
  }

  Future<void> _fetchDownload() async {
    final packages = _entries.map((entry) => entry.displayName).toSet().toList();
    if (packages.isEmpty) return;
    final runner = ref.read(jobRunnerProvider);
    final log = ref.read(jobLogProvider.notifier);
    final result = await runner.runJob(
      'hub_find_packages',
      args: {
        'packages': packages,
      },
      onLog: log.addLine,
    );
    final payload = result.result as Map<String, dynamic>?;
    if (payload == null) return;
    final direct = payload['download_urls'] as Map<String, dynamic>? ?? {};
    final noVersion =
        payload['download_urls_no_version'] as Map<String, dynamic>? ?? {};
    final urls = <String, String>{};
    final urlsNoVersion = <String, String>{};
    for (final entry in direct.entries) {
      final value = entry.value?.toString() ?? '';
      if (value.isNotEmpty) {
        urls[entry.key] = value;
      }
    }
    for (final entry in noVersion.entries) {
      final value = entry.value?.toString() ?? '';
      if (value.isNotEmpty) {
        urlsNoVersion[entry.key] = value;
      }
    }
    if (!mounted) return;
    setState(() {
      _downloadUrls = urls;
      _downloadUrlsNoVersion = urlsNoVersion;
    });
  }

  Future<void> _downloadSelected() async {
    final name = _selectedVar;
    if (name == null) return;
    final url = _downloadUrls[name] ?? _downloadUrlsNoVersion[_noVersionKey(name)];
    if (url == null || url.isEmpty) return;
    await _runJob('hub_download_all', {'urls': [url]});
  }

  Future<void> _downloadAll() async {
    final urls = <String>{};
    urls.addAll(_downloadUrls.values);
    urls.addAll(_downloadUrlsNoVersion.values);
    if (urls.isEmpty) return;
    await _runJob('hub_download_all', {'urls': urls.toList()});
  }

  Future<void> _saveMap() async {
    final location = await getSaveLocation(suggestedName: 'missing_map.txt');
    if (location == null) return;
    final path = location.path;
    final links = _linkMap.entries
        .where((entry) => entry.value.trim().isNotEmpty)
        .map(
          (entry) => MissingMapItem(
            missingVar: entry.key,
            destVar: entry.value.trim(),
          ),
        )
        .toList();
    final client = ref.read(backendClientProvider);
    await client.saveMissingMap(path, links);
  }

  Future<void> _loadMap() async {
    final file = await openFile(acceptedTypeGroups: [
      const XTypeGroup(label: 'Text', extensions: ['txt'])
    ]);
    if (file == null) return;
    final client = ref.read(backendClientProvider);
    final response = await client.loadMissingMap(file.path);
    if (!mounted) return;
    setState(() {
      _linkMap = {
        for (final link in response.links) link.missingVar: link.destVar,
      };
      if (_selectedVar != null) {
        _linkController.text = _linkMap[_selectedVar!] ?? '';
      }
    });
  }

  Future<void> _createLinks() async {
    final links = _linkMap.entries
        .where((entry) => entry.value.trim().isNotEmpty)
        .map((entry) => {
              'missing_var': entry.key,
              'dest_var': entry.value.trim(),
            })
        .toList();
    if (links.isEmpty) return;
    await _runJob('links_missing_create', {
      'links': links,
    });
  }

  Future<String?> _askText(BuildContext context, String title, {String hint = ''}) {
    final controller = TextEditingController(text: hint);
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredEntries;
    final creators = _entries
        .map((entry) => entry.displayName.split('.').first)
        .toSet()
        .toList()
      ..sort();

    return Scaffold(
      appBar: AppBar(title: const Text('Missing Dependencies')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Card(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: const InputDecoration(
                                labelText: 'Filter',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) => _ensureSelection(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          DropdownButton<String>(
                            value: _creatorFilter,
                            items: ['ALL', ...creators]
                                .map(
                                  (item) => DropdownMenuItem(
                                    value: item,
                                    child: Text(item == 'ALL' ? 'All creators' : item),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _creatorFilter = value;
                              });
                              _ensureSelection();
                            },
                          ),
                          const SizedBox(width: 12),
                          DropdownButton<String>(
                            value: _versionFilter,
                            items: const [
                              DropdownMenuItem(
                                  value: 'ignore', child: Text('Ignore version mismatch')),
                              DropdownMenuItem(value: 'all', child: Text('All missing vars')),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _versionFilter = value;
                              });
                              _ensureSelection();
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          Text('Row ${filtered.isEmpty ? 0 : _selectedIndex + 1} / ${filtered.length}'),
                          const Spacer(),
                          IconButton(
                            onPressed: filtered.isEmpty || _selectedIndex <= 0
                                ? null
                                : () => _selectIndex(0, filtered),
                            icon: const Icon(Icons.first_page),
                          ),
                          IconButton(
                            onPressed: filtered.isEmpty || _selectedIndex <= 0
                                ? null
                                : () => _selectIndex(_selectedIndex - 1, filtered),
                            icon: const Icon(Icons.chevron_left),
                          ),
                          IconButton(
                            onPressed: filtered.isEmpty || _selectedIndex >= filtered.length - 1
                                ? null
                                : () => _selectIndex(_selectedIndex + 1, filtered),
                            icon: const Icon(Icons.chevron_right),
                          ),
                          IconButton(
                            onPressed: filtered.isEmpty || _selectedIndex >= filtered.length - 1
                                ? null
                                : () => _selectIndex(filtered.length - 1, filtered),
                            icon: const Icon(Icons.last_page),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Container(
                      color: Colors.grey.shade100,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Row(
                        children: const [
                          Expanded(flex: 3, child: Text('Missing Var', style: TextStyle(fontWeight: FontWeight.w600))),
                          Expanded(flex: 3, child: Text('Link To', style: TextStyle(fontWeight: FontWeight.w600))),
                          SizedBox(width: 32, child: Text('DL', style: TextStyle(fontWeight: FontWeight.w600))),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final entry = filtered[index];
                          final link = _linkMap[entry.displayName] ?? '';
                          final selected = index == _selectedIndex;
                          return InkWell(
                            onTap: () => _selectIndex(index, filtered),
                            child: Container(
                              color: selected ? Colors.blue.shade50 : null,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Row(
                                      children: [
                                        Expanded(child: Text(entry.displayName)),
                                        if (entry.versionMismatch)
                                          const Padding(
                                            padding: EdgeInsets.only(left: 6),
                                            child: Icon(Icons.warning_amber, size: 16, color: Colors.orange),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(link.isEmpty ? '-' : link),
                                  ),
                                  SizedBox(
                                    width: 32,
                                    child: Icon(_downloadIcon(entry.displayName),
                                        color: _downloadColor(entry.displayName), size: 18),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 360,
              child: ListView(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Details', style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Text('Selected: ${_selectedVar ?? '-'}'),
                          const SizedBox(height: 4),
                          Text('Resolved: ${_selectedVar == null ? '-' : _resolvedDisplay(_selectedVar!)}'),
                          const SizedBox(height: 4),
                          Text('Download: ${_selectedVar == null ? '-' : _downloadStatus(_selectedVar!)}'),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _linkController,
                            decoration: const InputDecoration(
                              labelText: 'Link To',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton(
                                  onPressed: _selectedVar == null
                                      ? null
                                      : () {
                                          setState(() {
                                            _linkMap[_selectedVar!] = _linkController.text.trim();
                                          });
                                        },
                                  child: const Text('Set Link'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _selectedVar == null
                                      ? null
                                      : () {
                                          setState(() {
                                            _linkMap.remove(_selectedVar!);
                                            _linkController.text = '';
                                          });
                                        },
                                  child: const Text('Clear Link'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: _selectedVar == null
                                ? null
                                : () async {
                                    final search = _selectedVar!.replaceAll('.latest', '.1');
                                    await _runJob('open_url', {
                                      'url': 'https://www.google.com/search?q=$search var',
                                    });
                                  },
                            child: const Text('Google Search'),
                          ),
                          OutlinedButton(
                            onPressed: _downloadSelected,
                            child: const Text('Download Selected'),
                          ),
                          OutlinedButton(
                            onPressed: _fetchDownload,
                            child: const Text('Fetch Downloads'),
                          ),
                          OutlinedButton(
                            onPressed: _downloadAll,
                            child: const Text('Download All'),
                          ),
                          OutlinedButton(
                            onPressed: _createLinks,
                            child: const Text('Create Links'),
                          ),
                          const Divider(height: 16),
                          OutlinedButton(
                            onPressed: _saveMap,
                            child: const Text('Save Map'),
                          ),
                          OutlinedButton(
                            onPressed: _loadMap,
                            child: const Text('Load Map'),
                          ),
                          const Divider(height: 16),
                          OutlinedButton(
                            onPressed: () async {
                              final path = await _askText(context, 'Export path',
                                  hint: 'installed_vars.txt');
                              if (path == null || path.trim().isEmpty) return;
                              await _runJob('vars_export_installed', {
                                'path': path.trim(),
                              });
                            },
                            child: const Text('Export Installed'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Dependents', style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          if (_loadingDependents) const LinearProgressIndicator(minHeight: 2),
                          ..._dependents.map(
                            (name) => ListTile(
                              dense: true,
                              title: Text(name),
                              trailing: TextButton(
                                onPressed: () {
                                  ref.read(varsQueryProvider.notifier).update(
                                        (state) => state.copyWith(page: 1, search: name),
                                      );
                                  ref
                                      .read(navIndexProvider.notifier)
                                      .setIndex(0);
                                },
                                child: const Text('Select'),
                              ),
                            ),
                          ),
                          if (_dependents.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text('No dependents'),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Dependent Saves',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          ..._dependentSaves.map(
                            (path) => ListTile(
                              dense: true,
                              title: Text(path),
                              trailing: TextButton(
                                onPressed: () {
                                  final normalized = path.startsWith('\\')
                                      ? path.substring(1)
                                      : path;
                                  _runJob('vars_locate', {
                                    'path': normalized.replaceAll('/', '\\'),
                                  });
                                },
                                child: const Text('Locate'),
                              ),
                            ),
                          ),
                          if (_dependentSaves.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text('No dependent saves'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
