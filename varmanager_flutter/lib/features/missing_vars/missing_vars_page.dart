import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/backend/job_log_controller.dart';
import '../../core/backend/query_params.dart';
import '../../core/models/extra_models.dart';
import '../home/providers.dart';
import '../../widgets/lazy_dropdown_field.dart';

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
  bool _includeLinked = true;

  List<MissingEntry> _missingEntries = [];
  List<MissingEntry> _entries = [];
  int _selectedIndex = -1;
  String? _selectedVar;

  Map<String, String> _existingLinkMap = {};
  Map<String, String> _linkAliasMap = {};
  Map<String, String> _draftLinkMap = {};
  Set<String> _brokenLinks = {};
  Set<String> _brokenAliasSet = {};
  Set<String> _missingKeySet = {};
  List<String> _linkedNames = [];
  bool _loadingLinks = false;
  bool _linkFilterSamePackage = true;
  String _pickerValue = '';
  Map<String, String> _downloadUrls = {};
  Map<String, String> _downloadUrlsNoVersion = {};
  Map<String, String> _resolved = {};

  List<String> _dependents = [];
  List<String> _dependentSaves = [];
  bool _loadingDependents = false;

  @override
  void initState() {
    super.initState();
    _missingEntries = widget.missing.map(_parseEntry).toList();
    _missingKeySet =
        _missingEntries.map((entry) => _nameKey(entry.displayName)).toSet();
    _entries = List.of(_missingEntries);
    Future.microtask(() async {
      await _loadExistingLinks();
      await _refreshResolved();
    });
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

  String _nameKey(String name) {
    return name.trim().toLowerCase();
  }

  List<MissingEntry> get _viewEntries {
    if (!_includeLinked) {
      return _entries
          .where((entry) =>
              _missingKeySet.contains(_nameKey(entry.displayName)) &&
              !_hasAppliedLink(entry.displayName))
          .toList();
    }
    return _entries;
  }

  List<MissingEntry> get _filteredEntries {
    final search = _searchController.text.trim().toLowerCase();
    return _viewEntries.where((entry) {
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

  void _rebuildEntries() {
    final linkedKeys = <String>{..._existingLinkMap.keys, ..._brokenLinks};
    final linkedNames = _linkedNames.toSet();
    final aliasTargets = <String>{};
    final aliasMap = <String, String>{};
    final brokenAliases = <String>{};
    for (final entry in _missingEntries) {
      final name = entry.displayName;
      if (!name.endsWith('.latest')) continue;
      final base = name.substring(0, name.lastIndexOf('.'));
      final matchKey = _findLatestLinkMatch(_nameKey(base), linkedKeys);
      if (matchKey == null) continue;
      aliasTargets.add(matchKey);
      final dest = _existingLinkMap[matchKey];
      if (dest != null && dest.trim().isNotEmpty) {
        aliasMap[_nameKey(name)] = dest;
      }
      if (_brokenLinks.contains(matchKey)) {
        brokenAliases.add(_nameKey(name));
      }
    }
    final linkedEntries = <MissingEntry>[];
    for (final name in linkedNames) {
      final key = _nameKey(name);
      if (_missingKeySet.contains(key)) continue;
      if (aliasTargets.contains(key)) continue;
      linkedEntries.add(_parseEntry(name));
    }
    linkedEntries.sort((a, b) => a.displayName.compareTo(b.displayName));
    _linkAliasMap = aliasMap;
    _brokenAliasSet = brokenAliases;
    _entries = [..._missingEntries, ...linkedEntries];
  }

  String? _findLatestLinkMatch(String baseKey, Iterable<String> keys) {
    final exactLatest = '$baseKey.latest';
    if (keys.contains(exactLatest)) {
      return exactLatest;
    }
    final prefix = '$baseKey.';
    String? best;
    int? bestVer;
    for (final key in keys) {
      if (!key.startsWith(prefix)) continue;
      final version = key.substring(prefix.length);
      final parsed = int.tryParse(version);
      if (parsed != null) {
        if (bestVer == null || parsed > bestVer) {
          bestVer = parsed;
          best = key;
        }
      } else {
        best ??= key;
      }
    }
    return best;
  }

  Future<void> _loadExistingLinks() async {
    setState(() {
      _loadingLinks = true;
    });
    final client = ref.read(backendClientProvider);
    MissingMapResponse response;
    try {
      response = await client.listMissingLinks();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingLinks = false;
      });
      return;
    }
    if (!mounted) return;
    final existing = <String, String>{};
    final broken = <String>{};
    final linkedNames = <String>{};
    for (final link in response.links) {
      final missing = link.missingVar.trim();
      final dest = link.destVar.trim();
      if (missing.isEmpty) continue;
      linkedNames.add(missing);
      final key = _nameKey(missing);
      if (dest.isEmpty) {
        broken.add(key);
      } else {
        existing[key] = dest;
      }
    }
    setState(() {
      _existingLinkMap = existing;
      _brokenLinks = broken;
      _linkedNames = linkedNames.toList();
      _draftLinkMap = {};
      _loadingLinks = false;
      _rebuildEntries();
      if (_selectedVar != null) {
        _linkController.text = _effectiveLink(_selectedVar!);
        _pickerValue = _linkController.text;
      }
    });
    _ensureSelection();
  }

  String _effectiveLink(String name) {
    if (_draftLinkMap.containsKey(name)) {
      return _draftLinkMap[name]?.trim() ?? '';
    }
    final key = _nameKey(name);
    final alias = _linkAliasMap[key];
    if (alias != null) {
      return alias.trim();
    }
    return _existingLinkMap[key]?.trim() ?? '';
  }

  String _appliedLink(String name) {
    final key = _nameKey(name);
    return _linkAliasMap[key]?.trim() ?? _existingLinkMap[key]?.trim() ?? '';
  }

  String _draftLink(String name) {
    return _draftLinkMap[name]?.trim() ?? '';
  }

  bool _hasDraft(String name) {
    return _draftLinkMap.containsKey(name);
  }

  bool _hasAppliedLink(String name) {
    return _appliedLink(name).isNotEmpty;
  }

  bool _isBroken(String name) {
    final key = _nameKey(name);
    return _brokenLinks.contains(key) || _brokenAliasSet.contains(key);
  }

  bool _isPendingChange(String name) {
    if (!_draftLinkMap.containsKey(name)) {
      return false;
    }
    final desired = _draftLink(name);
    final existing = _appliedLink(name);
    if (_isBroken(name)) {
      return true;
    }
    return desired != existing;
  }

  String _linkStatusLabel(String name) {
    final applied = _appliedLink(name);
    final draft = _draftLink(name);
    final hasDraft = _hasDraft(name);
    final broken = _isBroken(name);
    if (broken && !hasDraft) {
      return 'Broken link';
    }
    if (hasDraft) {
      if (draft.isEmpty && applied.isNotEmpty) return 'Remove link';
      if (draft.isEmpty && applied.isEmpty) return 'Clear link';
      if (applied.isEmpty) return 'New link';
      if (draft == applied) return 'Linked';
      return 'Link changed';
    }
    if (applied.isNotEmpty) return 'Linked';
    return 'Not linked';
  }

  Color _linkStatusColor(String name) {
    final applied = _appliedLink(name);
    final draft = _draftLink(name);
    final hasDraft = _hasDraft(name);
    final broken = _isBroken(name);
    if (broken && !hasDraft) {
      return Colors.orange;
    }
    if (hasDraft) {
      if (draft.isEmpty && applied.isNotEmpty) return Colors.red;
      if (draft.isEmpty && applied.isEmpty) return Colors.grey;
      if (applied.isEmpty) return Colors.blue;
      if (draft == applied) return Colors.green;
      return Colors.blue;
    }
    if (applied.isNotEmpty) return Colors.green;
    return Colors.grey;
  }

  String? _suggestedLink(String name) {
    final resolved = _resolved[name];
    if (resolved == null || resolved == 'missing') return null;
    if (resolved.endsWith(r'$')) {
      return resolved.substring(0, resolved.length - 1);
    }
    return resolved;
  }

  bool _suggestedIsClosest(String name) {
    final resolved = _resolved[name];
    if (resolved == null || resolved == 'missing') return false;
    return resolved.endsWith(r'$');
  }

  String? _packageKey(String name) {
    final parts = name.split('.');
    if (parts.length < 2) return null;
    return '${parts[0]}.${parts[1]}';
  }

  Future<List<String>> _loadLinkOptions(
      String queryText, int offset, int limit) async {
    final client = ref.read(backendClientProvider);
    final selected = _selectedVar;
    var creator = '';
    var package = '';
    if (_linkFilterSamePackage && selected != null) {
      final parts = selected.split('.');
      if (parts.length >= 2) {
        creator = parts[0];
        package = parts[1];
      }
    }
    final page = (offset ~/ limit) + 1;
    final params = VarsQueryParams(
      page: page,
      perPage: limit,
      search: queryText,
      creator: creator,
      package: package,
    );
    final response = await client.listVars(params);
    return response.items.map((item) => item.varName).toList();
  }

  Future<void> _runJob(String kind, Map<String, dynamic> args) async {
    final runner = ref.read(jobRunnerProvider);
    final log = ref.read(jobLogProvider.notifier);
    await runner.runJob(kind, args: args, onLog: log.addEntry);
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
        _pickerValue = '';
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
      _linkController.text = _effectiveLink(entry.displayName);
      _pickerValue = _linkController.text;
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
    final packages =
        _missingEntries.map((entry) => entry.displayName).toSet().toList();
    if (packages.isEmpty) return;
    final runner = ref.read(jobRunnerProvider);
    final log = ref.read(jobLogProvider.notifier);
    final result = await runner.runJob(
      'hub_find_packages',
      args: {
        'packages': packages,
      },
      onLog: log.addEntry,
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

  void _setDraftLink(String name, String value) {
    setState(() {
      _draftLinkMap[name] = value.trim();
    });
  }

  void _clearDraftLink(String name) {
    setState(() {
      _draftLinkMap[name] = '';
    });
  }

  void _revertDraft(String name) {
    setState(() {
      _draftLinkMap.remove(name);
      _linkController.text = _effectiveLink(name);
      _pickerValue = _linkController.text;
    });
  }

  void _applySuggestedForSelected() {
    final name = _selectedVar;
    if (name == null) return;
    final suggested = _suggestedLink(name);
    if (suggested == null || suggested.isEmpty) return;
    setState(() {
      _linkController.text = suggested;
      _pickerValue = suggested;
      _draftLinkMap[name] = suggested;
    });
  }

  void _applyDraftToPackage() {
    final name = _selectedVar;
    if (name == null) return;
    final dest = _linkController.text.trim();
    if (dest.isEmpty) return;
    final key = _packageKey(name);
    if (key == null) return;
    setState(() {
      for (final entry in _entries) {
        if (_packageKey(entry.displayName) == key) {
          _draftLinkMap[entry.displayName] = dest;
        }
      }
    });
  }

  void _autoFillResolved() {
    setState(() {
      for (final entry in _entries) {
        final name = entry.displayName;
        if (_draftLinkMap.containsKey(name)) continue;
        if (_existingLinkMap.containsKey(name)) continue;
        final suggested = _suggestedLink(name);
        if (suggested == null || suggested.isEmpty) continue;
        _draftLinkMap[name] = suggested;
      }
      if (_selectedVar != null) {
        _linkController.text = _effectiveLink(_selectedVar!);
        _pickerValue = _linkController.text;
      }
    });
  }

  void _discardDrafts() {
    setState(() {
      _draftLinkMap = {};
      if (_selectedVar != null) {
        _linkController.text = _effectiveLink(_selectedVar!);
        _pickerValue = _linkController.text;
      }
    });
  }

  Map<String, String> _buildEffectiveMap() {
    final map = <String, String>{};
    for (final entry in _entries) {
      final name = entry.displayName;
      final link = _effectiveLink(name).trim();
      if (link.isEmpty) continue;
      map[name] = link;
    }
    return map;
  }

  List<Map<String, String>> _buildLinkChanges() {
    final changes = <Map<String, String>>[];
    for (final entry in _entries) {
      final name = entry.displayName;
      if (!_draftLinkMap.containsKey(name)) continue;
      final desired = _draftLink(name);
      final existing = _appliedLink(name);
      if (!_isBroken(name) && desired == existing) {
        continue;
      }
      changes.add({'missing_var': name, 'dest_var': desired});
    }
    return changes;
  }

  Future<void> _applyLinkChanges() async {
    final changes = _buildLinkChanges();
    if (changes.isEmpty) return;
    final runner = ref.read(jobRunnerProvider);
    final log = ref.read(jobLogProvider.notifier);
    final result = await runner.runJob(
      'links_missing_create',
      args: {'links': changes},
      onLog: log.addEntry,
    );
    if (!mounted) return;
    await _loadExistingLinks();
    if (!mounted) return;
    final payload = result.result as Map<String, dynamic>? ?? {};
    final total = payload['total'] ?? changes.length;
    final created = payload['created'] ?? 0;
    final skipped = payload['skipped'] ?? 0;
    final failed = payload['failed'] ?? 0;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Link changes applied: $total total, $created created, $skipped skipped, $failed failed.',
        ),
      ),
    );
  }

  Future<void> _saveMap() async {
    final location = await getSaveLocation(suggestedName: 'missing_map.txt');
    if (location == null) return;
    final path = location.path;
    final effective = _buildEffectiveMap();
    final links = effective.entries
        .map((entry) => MissingMapItem(
              missingVar: entry.key,
              destVar: entry.value,
            ))
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
      final allowed = _entries.map((entry) => entry.displayName).toSet();
      _draftLinkMap = {
        for (final link in response.links)
          if (allowed.contains(link.missingVar) && link.destVar.trim().isNotEmpty)
            link.missingVar: link.destVar.trim(),
      };
      if (_selectedVar != null) {
        _linkController.text = _effectiveLink(_selectedVar!);
        _pickerValue = _linkController.text;
      }
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
    final creators = _viewEntries
        .map((entry) => entry.displayName.split('.').first)
        .toSet()
        .toList()
      ..sort();
    final appliedCount =
        _entries.where((entry) => _appliedLink(entry.displayName).isNotEmpty).length;
    final pendingCount =
        _entries.where((entry) => _isPendingChange(entry.displayName)).length;
    final brokenCount =
        _entries.where((entry) => _isBroken(entry.displayName)).length;
    final selectedVar = _selectedVar;
    final appliedLink = selectedVar == null ? '' : _appliedLink(selectedVar);
    final draftLink = selectedVar == null ? '' : _draftLink(selectedVar);
    final hasDraft = selectedVar != null && _hasDraft(selectedVar);
    final isBroken = selectedVar != null && _isBroken(selectedVar);
    final suggestion = selectedVar == null ? null : _suggestedLink(selectedVar);
    final suggestionLabel = suggestion == null
        ? '-'
        : '$suggestion${_suggestedIsClosest(selectedVar!) ? ' (closest)' : ''}';
    final linkStatusLabel =
        selectedVar == null ? '-' : _linkStatusLabel(selectedVar);
    final linkStatusColor =
        selectedVar == null ? Colors.grey : _linkStatusColor(selectedVar);
    final hasPendingChanges = pendingCount > 0;
    final hasDrafts = _draftLinkMap.isNotEmpty;

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
                          SizedBox(
                            width: 220,
                            child: LazyDropdownField(
                              label: 'Creator',
                              value: _creatorFilter.isEmpty ? 'ALL' : _creatorFilter,
                              allValue: 'ALL',
                              allLabel: 'All creators',
                              optionsLoader: (queryText, offset, limit) async {
                                final needle = queryText.trim().toLowerCase();
                                final matches = creators
                                    .where((item) =>
                                        item.toLowerCase().contains(needle))
                                    .toList();
                                matches.sort((a, b) {
                                  final aLower = a.toLowerCase();
                                  final bLower = b.toLowerCase();
                                  if (needle.isNotEmpty) {
                                    final aPrefix = aLower.startsWith(needle);
                                    final bPrefix = bLower.startsWith(needle);
                                    if (aPrefix != bPrefix) {
                                      return aPrefix ? -1 : 1;
                                    }
                                  }
                                  return aLower.compareTo(bLower);
                                });
                                final start = offset.clamp(0, matches.length);
                                final end = (start + limit).clamp(0, matches.length);
                                return matches.sublist(start, end);
                              },
                              onChanged: (value) {
                                setState(() {
                                  _creatorFilter = value;
                                });
                                _ensureSelection();
                              },
                            ),
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
                          const SizedBox(width: 12),
                          Tooltip(
                            message: 'Show entries that already have link substitutions.',
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Checkbox(
                                  value: _includeLinked,
                                  onChanged: (value) {
                                    setState(() {
                                      _includeLinked = value ?? true;
                                    });
                                    _ensureSelection();
                                  },
                                ),
                                const Text('Include Linked'),
                              ],
                            ),
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
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Row(
                        children: [
                          Text('Applied $appliedCount'),
                          const SizedBox(width: 12),
                          Text('Draft $pendingCount'),
                          const SizedBox(width: 12),
                          Text('Broken $brokenCount'),
                          if (_loadingLinks) ...[
                            const SizedBox(width: 12),
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ],
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
                          Expanded(flex: 3, child: Text('Substitute', style: TextStyle(fontWeight: FontWeight.w600))),
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
                          final link = _effectiveLink(entry.displayName);
                          final pending = _isPendingChange(entry.displayName);
                          final broken = _isBroken(entry.displayName);
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
                                    child: Row(
                                      children: [
                                        Expanded(child: Text(link.isEmpty ? '-' : link)),
                                        if (pending)
                                          const Padding(
                                            padding: EdgeInsets.only(left: 6),
                                            child: Icon(Icons.edit, size: 14, color: Colors.blueGrey),
                                          ),
                                        if (broken && !pending)
                                          const Padding(
                                            padding: EdgeInsets.only(left: 6),
                                            child: Icon(Icons.link_off, size: 14, color: Colors.orange),
                                          ),
                                      ],
                                    ),
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
                          Text('Selected: ${selectedVar ?? '-'}'),
                          const SizedBox(height: 4),
                          Text('Resolved: ${selectedVar == null ? '-' : _resolvedDisplay(selectedVar)}'),
                          const SizedBox(height: 4),
                          Text('Download: ${selectedVar == null ? '-' : _downloadStatus(selectedVar)}'),
                          const SizedBox(height: 4),
                          Text('Link status: $linkStatusLabel',
                              style: TextStyle(color: linkStatusColor)),
                          if (_loadingLinks)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: LinearProgressIndicator(minHeight: 2),
                            ),
                          const Divider(height: 16),
                          const Text('Link Substitution',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Text(
                            'Links create symlinks in ___MissingVarLink___ to substitute missing dependencies.',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Applied: ${selectedVar == null ? '-' : (isBroken ? 'broken link' : (appliedLink.isEmpty ? '-' : appliedLink))}',
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Draft: ${selectedVar == null ? '-' : (hasDraft ? (draftLink.isEmpty ? '(clear)' : draftLink) : '-')}',
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(child: Text('Suggestion: $suggestionLabel')),
                              Tooltip(
                                message: 'Use suggested resolved var as draft link.',
                                child: TextButton(
                                  onPressed: suggestion == null ? null : _applySuggestedForSelected,
                                  child: const Text('Use'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LazyDropdownField(
                            label: 'Find target',
                            value: _pickerValue,
                            allValue: '',
                            allLabel: 'Pick target',
                            pageSize: 15,
                            minQueryLength: 2,
                            optionsLoader: _loadLinkOptions,
                            onChanged: (value) {
                              setState(() {
                                _pickerValue = value;
                                _linkController.text = value;
                              });
                            },
                          ),
                          Row(
                            children: [
                              Tooltip(
                                message: 'Limit picker to same creator/package as missing var.',
                                child: Checkbox(
                                  value: _linkFilterSamePackage,
                                  onChanged: (value) {
                                    setState(() {
                                      _linkFilterSamePackage = value ?? true;
                                    });
                                  },
                                ),
                              ),
                              const Expanded(
                                child: Text('Limit to same creator/package'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _linkController,
                            decoration: const InputDecoration(
                              labelText: 'Target Var',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Tooltip(
                                  message: 'Save draft link for selected missing var.',
                                  child: FilledButton(
                                    onPressed: selectedVar == null
                                        ? null
                                        : () {
                                            _setDraftLink(selectedVar, _linkController.text);
                                            setState(() {
                                              _pickerValue = _linkController.text.trim();
                                            });
                                          },
                                    child: const Text('Set Draft'),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Tooltip(
                                  message: 'Clear draft link for selected var (will remove).',
                                  child: OutlinedButton(
                                    onPressed: selectedVar == null
                                        ? null
                                        : () {
                                            _clearDraftLink(selectedVar);
                                            setState(() {
                                              _linkController.text = '';
                                              _pickerValue = '';
                                            });
                                          },
                                    child: const Text('Clear Draft'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Tooltip(
                                  message: 'Revert draft to currently applied link.',
                                  child: OutlinedButton(
                                    onPressed: selectedVar == null || !hasDraft
                                        ? null
                                        : () => _revertDraft(selectedVar),
                                    child: const Text('Revert Draft'),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Tooltip(
                                  message: 'Apply draft target to all missing vars in same package.',
                                  child: OutlinedButton(
                                    onPressed: selectedVar == null ||
                                            _linkController.text.trim().isEmpty
                                        ? null
                                        : _applyDraftToPackage,
                                    child: const Text('Apply to Package'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Tooltip(
                                  message: 'Fill drafts using best resolved matches.',
                                  child: OutlinedButton(
                                    onPressed: _autoFillResolved,
                                    child: const Text('Auto-fill Resolved'),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Tooltip(
                                  message: 'Create/update/remove symlinks from draft changes.',
                                  child: FilledButton(
                                    onPressed:
                                        hasPendingChanges ? _applyLinkChanges : null,
                                    child: const Text('Apply Link Changes'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Tooltip(
                                  message: 'Save current effective map to a text file.',
                                  child: OutlinedButton(
                                    onPressed: _saveMap,
                                    child: const Text('Save Map'),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Tooltip(
                                  message: 'Load a map file as drafts for this list.',
                                  child: OutlinedButton(
                                    onPressed: _loadMap,
                                    child: const Text('Load Map'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Tooltip(
                            message: 'Discard all draft changes.',
                            child: OutlinedButton(
                              onPressed: hasDrafts ? _discardDrafts : null,
                              child: const Text('Discard Drafts'),
                            ),
                          ),
                          const Divider(height: 16),
                          Tooltip(
                            message: 'Search the missing var on the web.',
                            child: OutlinedButton(
                              onPressed: selectedVar == null
                                  ? null
                                  : () async {
                                      final search =
                                          selectedVar.replaceAll('.latest', '.1');
                                      await _runJob('open_url', {
                                        'url':
                                            'https://www.google.com/search?q=$search var',
                                      });
                                    },
                              child: const Text('Google Search'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Tooltip(
                            message: 'Query hub for download links for missing vars.',
                            child: OutlinedButton(
                              onPressed: _fetchDownload,
                              child: const Text('Fetch Hub Links'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Tooltip(
                            message: 'Download link for selected missing var if available.',
                            child: OutlinedButton(
                              onPressed: _downloadSelected,
                              child: const Text('Download Selected'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Tooltip(
                            message: 'Queue downloads for all missing vars with links.',
                            child: OutlinedButton(
                              onPressed: _downloadAll,
                              child: const Text('Download All'),
                            ),
                          ),
                          const Divider(height: 16),
                          Tooltip(
                            message: 'Export installed vars to a text file.',
                            child: OutlinedButton(
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

