import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/backend/job_log_controller.dart';
import '../../core/backend/query_params.dart';
import '../../core/models/job_models.dart';
import '../../core/models/extra_models.dart';
import '../home/providers.dart';
import '../../widgets/lazy_dropdown_field.dart';
import '../../l10n/l10n.dart';

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

enum _DownloadStatus { direct, noVersion, torrent, none }

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
  Map<String, String> _downloadSources = {};
  Map<String, String> _downloadSourcesNoVersion = {};
  Map<String, List<String>> _torrentHits = {};
  Map<String, List<String>> _torrentHitsNoVersion = {};
  Map<String, String> _resolved = {};

  // External source options
  bool _enableExternal = true;
  bool _enablePixeldrain = true;
  bool _enableMediafire = true;
  bool _pixeldrainBypass = false;
  bool _enableTorrents = true;
  bool _fetchingDownloads = false;

  List<String> _dependents = [];
  List<String> _dependentSaves = [];
  bool _loadingDependents = false;

  @override
  void initState() {
    super.initState();
    _missingEntries = widget.missing.map(_parseEntry).toList();
    _missingKeySet = _missingEntries
        .map((entry) => _nameKey(entry.displayName))
        .toSet();
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
    return MissingEntry(
      rawName: raw,
      displayName: name,
      versionMismatch: mismatch,
    );
  }

  String _nameKey(String name) {
    return name.trim().toLowerCase();
  }

  List<MissingEntry> get _viewEntries {
    if (!_includeLinked) {
      return _entries
          .where(
            (entry) =>
                _missingKeySet.contains(_nameKey(entry.displayName)) &&
                !_hasAppliedLink(entry.displayName),
          )
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
      if (_creatorFilter != 'ALL' &&
          !entry.displayName.startsWith('$_creatorFilter.')) {
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
    final l10n = context.l10n;
    final applied = _appliedLink(name);
    final draft = _draftLink(name);
    final hasDraft = _hasDraft(name);
    final broken = _isBroken(name);
    if (broken && !hasDraft) {
      return l10n.linkStatusBroken;
    }
    if (hasDraft) {
      if (draft.isEmpty && applied.isNotEmpty) return l10n.linkStatusRemove;
      if (draft.isEmpty && applied.isEmpty) return l10n.linkStatusClear;
      if (applied.isEmpty) return l10n.linkStatusNew;
      if (draft == applied) return l10n.linkStatusLinked;
      return l10n.linkStatusChanged;
    }
    if (applied.isNotEmpty) return l10n.linkStatusLinked;
    return l10n.linkStatusNotLinked;
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
    String queryText,
    int offset,
    int limit,
  ) async {
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

  Future<JobResult<dynamic>> _runJob(
    String kind,
    Map<String, dynamic> args, {
    void Function(JobLogEntry entry)? onLog,
  }) async {
    final runner = ref.read(jobRunnerProvider);
    final log = ref.read(jobLogProvider.notifier);
    return runner.runJob(
      kind,
      args: args,
      onLog: onLog ?? log.addEntry,
    );
  }

  Future<void> _openTorrentInExternalClient(String torrentFileName) async {
    final trimmed = torrentFileName.trim();
    if (trimmed.isEmpty) return;
    try {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      final torrentPath = '$exeDir\\data\\links\\torrents\\$trimmed';
      final file = File(torrentPath);
      if (!file.existsSync()) {
        _showSnackBar('Torrent file not found: $trimmed');
        return;
      }
      if (Platform.isWindows) {
        await Process.start('explorer.exe', [torrentPath]);
        return;
      }
      if (Platform.isMacOS) {
        await Process.start('open', [torrentPath]);
        return;
      }
      await Process.start('xdg-open', [torrentPath]);
    } catch (e) {
      _showSnackBar('Failed to open torrent: $e');
    }
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

  _DownloadStatus _downloadStatus(String name) {
    if (_downloadUrls.containsKey(name)) return _DownloadStatus.direct;
    if (_downloadUrlsNoVersion.containsKey(_noVersionKey(name))) {
      return _DownloadStatus.noVersion;
    }
    if (_hasTorrentHit(name)) return _DownloadStatus.torrent;
    return _DownloadStatus.none;
  }

  String _downloadStatusLabel(_DownloadStatus status) {
    final l10n = context.l10n;
    switch (status) {
      case _DownloadStatus.direct:
        return l10n.downloadStatusDirect;
      case _DownloadStatus.noVersion:
        return l10n.downloadStatusNoVersion;
      case _DownloadStatus.torrent:
        return 'Torrent';
      case _DownloadStatus.none:
        return l10n.downloadStatusNone;
    }
  }

  IconData _downloadIcon(String name) {
    final status = _downloadStatus(name);
    switch (status) {
      case _DownloadStatus.direct:
        return Icons.cloud_done;
      case _DownloadStatus.noVersion:
        return Icons.cloud_download;
      case _DownloadStatus.torrent:
        return Icons.folder_zip;
      default:
        return Icons.block;
    }
  }

  Color _downloadColor(String name) {
    final status = _downloadStatus(name);
    switch (status) {
      case _DownloadStatus.direct:
        return Colors.green;
      case _DownloadStatus.noVersion:
        return Colors.orange;
      case _DownloadStatus.torrent:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _downloadSource(String name) {
    return _downloadSources[name] ??
        _downloadSourcesNoVersion[_noVersionKey(name)] ??
        'none';
  }

  bool _hasTorrentHit(String name) {
    return (_torrentHits[name]?.isNotEmpty ?? false) ||
        (_torrentHitsNoVersion[_noVersionKey(name)]?.isNotEmpty ?? false);
  }

  List<String> _torrentFilesFor(String name) {
    final hits = <String>{};
    hits.addAll(_torrentHits[name] ?? const []);
    hits.addAll(_torrentHitsNoVersion[_noVersionKey(name)] ?? const []);
    final list = hits.toList();
    list.sort();
    return list;
  }

  Future<void> _downloadTorrents(Map<String, List<String>> items) async {
    setState(() {
      _fetchingDownloads = true;
    });
    if (items.isEmpty) {
      _showSnackBar('No torrent files available.');
      setState(() {
        _fetchingDownloads = false;
      });
      return;
    }
    final log = ref.read(jobLogProvider.notifier);
    final payload = <Map<String, dynamic>>[];
    for (final entry in items.entries) {
      final name = entry.key.trim();
      if (name.isEmpty) continue;
      final torrents = entry.value
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList();
      if (torrents.isEmpty) continue;
      payload.add({'var_name': name, 'torrents': torrents});
    }
    if (payload.isEmpty) {
      _showSnackBar('No torrent files available.');
      setState(() {
        _fetchingDownloads = false;
      });
      return;
    }
    final result = await _runJob(
      'torrent_download',
      {'items': payload},
      onLog: log.addEntry,
    );
    final resMap = result.result as Map<String, dynamic>? ?? {};
    final downloaded = resMap['downloaded'] ?? 0;
    final skipped = resMap['skipped'] ?? 0;
    final failed = (resMap['failed'] as List?)?.length ?? 0;
    final missing = (resMap['missing'] as List?)?.length ?? 0;
    setState(() {
      _fetchingDownloads = false;
    });
    _showSnackBar(
      'Torrent job: downloaded $downloaded, skipped $skipped, failed $failed, missing $missing',
    );
  }

  String _downloadTooltip(String name) {
    final status = _downloadStatus(name);
    final source = _downloadSource(name);
    final hasTorrent = _hasTorrentHit(name);

    String statusText = _downloadStatusLabel(status);
    String sourceText = source != 'none' ? ' ($source)' : '';
    String torrentText =
        hasTorrent && status != _DownloadStatus.torrent
            ? '\nTorrent available'
            : '';

    return '$statusText$sourceText$torrentText';
  }

  Widget _torrentBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Text(
        'TOR',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: Colors.blue.shade700,
        ),
      ),
    );
  }

  String _resolvedDisplay(String name) {
    final l10n = context.l10n;
    final resolved = _resolved[name];
    if (resolved == null || resolved == 'missing') return l10n.missingStatus;
    if (resolved.endsWith(r'$')) {
      return l10n.closestMatch(resolved.substring(0, resolved.length - 1));
    }
    return resolved;
  }

  Future<void> _fetchDownload() async {
    setState(() {
      _fetchingDownloads = true;
    });
    final packages = _missingEntries
        .map((entry) => entry.displayName)
        .toSet()
        .toList();
    if (packages.isEmpty) return;

    final runner = ref.read(jobRunnerProvider);
    final log = ref.read(jobLogProvider.notifier);

    // Build external sources list
    final externalSources = <String>[];
    if (_enablePixeldrain) externalSources.add('pixeldrain');
    if (_enableMediafire) externalSources.add('mediafire');

    final result = await runner.runJob(
      'hub_find_packages',
      args: {
        'packages': packages,
        'include_external': _enableExternal,
        'external_sources': externalSources,
        'pixeldrain_bypass': _pixeldrainBypass,
        'include_torrents': _enableTorrents,
      },
      onLog: log.addEntry,
    );

    final payload = result.result as Map<String, dynamic>? ?? {};
    setState(() {
      _fetchingDownloads = false;
    });
    if (payload.isEmpty) return;

    final direct = payload['download_urls'] as Map<String, dynamic>? ?? {};
    final noVersion =
        payload['download_urls_no_version'] as Map<String, dynamic>? ?? {};
    final sources = payload['download_sources'] as Map<String, dynamic>? ?? {};
    final sourcesNoVersion =
        payload['download_sources_no_version'] as Map<String, dynamic>? ?? {};
    final torrents = payload['torrent_hits'] as Map<String, dynamic>? ?? {};
    final torrentsNoVersion =
        payload['torrent_hits_no_version'] as Map<String, dynamic>? ?? {};

    // Parse into typed maps
    final urls = <String, String>{};
    final urlsNoVersion = <String, String>{};
    final downloadSources = <String, String>{};
    final downloadSourcesNoVersion = <String, String>{};
    final torrentHitsMap = <String, List<String>>{};
    final torrentHitsNoVersionMap = <String, List<String>>{};

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
    for (final entry in sources.entries) {
      final value = entry.value?.toString() ?? '';
      if (value.isNotEmpty) {
        downloadSources[entry.key] = value;
      }
    }
    for (final entry in sourcesNoVersion.entries) {
      final value = entry.value?.toString() ?? '';
      if (value.isNotEmpty) {
        downloadSourcesNoVersion[entry.key] = value;
      }
    }
    for (final entry in torrents.entries) {
      if (entry.value is List) {
        torrentHitsMap[entry.key] = (entry.value as List)
            .map((e) => e.toString())
            .toList();
      }
    }
    for (final entry in torrentsNoVersion.entries) {
      if (entry.value is List) {
        torrentHitsNoVersionMap[entry.key] = (entry.value as List)
            .map((e) => e.toString())
            .toList();
      }
    }

    if (!mounted) return;
    setState(() {
      _downloadUrls = urls;
      _downloadUrlsNoVersion = urlsNoVersion;
      _downloadSources = downloadSources;
      _downloadSourcesNoVersion = downloadSourcesNoVersion;
      _torrentHits = torrentHitsMap;
      _torrentHitsNoVersion = torrentHitsNoVersionMap;
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _downloadSelected() async {
    final l10n = context.l10n;
    final name = _selectedVar;
    if (name == null) {
      _showSnackBar(l10n.missingSelectFirst);
      return;
    }
    final url =
        _downloadUrls[name] ?? _downloadUrlsNoVersion[_noVersionKey(name)];
    if (url == null || url.isEmpty) {
      final torrents = _torrentFilesFor(name);
      if (torrents.isEmpty) {
        _showSnackBar(l10n.missingNoDownloadUrlForSelected);
        return;
      }
      await _downloadTorrents({name: torrents});
      return;
    }
    await _runJob('hub_download_all', {
      'items': [
        {'url': url, 'name': name},
      ],
    });
    _showSnackBar(l10n.missingAddedDownload);
  }

  Future<void> _downloadAll() async {
    final l10n = context.l10n;
    final items = <Map<String, String>>[];
    final seen = <String>{};
    for (final entry in _downloadUrls.entries) {
      final url = entry.value;
      if (url.isEmpty || seen.contains(url)) continue;
      seen.add(url);
      items.add({'url': url, 'name': entry.key});
    }
    for (final entry in _downloadUrlsNoVersion.entries) {
      final url = entry.value;
      if (url.isEmpty || seen.contains(url)) continue;
      seen.add(url);
      items.add({'url': url, 'name': entry.key});
    }
    final torrentItems = <String, List<String>>{};
    for (final entry in _viewEntries) {
      final name = entry.displayName;
      final hasUrl = _downloadUrls.containsKey(name) ||
          _downloadUrlsNoVersion.containsKey(_noVersionKey(name));
      if (hasUrl) continue;
      final torrents = _torrentFilesFor(name);
      if (torrents.isNotEmpty) {
        torrentItems[name] = torrents;
      }
    }

    if (items.isEmpty && torrentItems.isEmpty) {
      _showSnackBar(l10n.missingNoDownloadUrlsAvailable);
      return;
    }
    if (items.isNotEmpty) {
      await _runJob('hub_download_all', {'items': items});
      _showSnackBar(l10n.missingAddedDownloads(items.length));
    }
    if (torrentItems.isNotEmpty) {
      await _downloadTorrents(torrentItems);
    }
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
          context.l10n.linkChangesApplied(total, created, skipped, failed),
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
        .map(
          (entry) =>
              MissingMapItem(missingVar: entry.key, destVar: entry.value),
        )
        .toList();
    final client = ref.read(backendClientProvider);
    await client.saveMissingMap(path, links);
  }

  Future<void> _loadMap() async {
    final l10n = context.l10n;
    final file = await openFile(
      acceptedTypeGroups: [
        XTypeGroup(label: l10n.textFileTypeLabel, extensions: const ['txt']),
      ],
    );
    if (file == null) return;
    final client = ref.read(backendClientProvider);
    final response = await client.loadMissingMap(file.path);
    if (!mounted) return;
    setState(() {
      final allowed = _entries.map((entry) => entry.displayName).toSet();
      _draftLinkMap = {
        for (final link in response.links)
          if (allowed.contains(link.missingVar) &&
              link.destVar.trim().isNotEmpty)
            link.missingVar: link.destVar.trim(),
      };
      if (_selectedVar != null) {
        _linkController.text = _effectiveLink(_selectedVar!);
        _pickerValue = _linkController.text;
      }
    });
  }

  Future<void> _exportMissing() async {
    final l10n = context.l10n;
    final path = await _askText(
      context,
      l10n.exportPathTitle,
      hint: 'missing_vars.txt',
    );
    if (path == null || path.trim().isEmpty) return;
    final file = File(path.trim());
    final parent = file.parent;
    if (parent.path.isNotEmpty && !await parent.exists()) {
      await parent.create(recursive: true);
    }
    final seen = <String>{};
    final lines = <String>[];
    for (final entry in _missingEntries) {
      final name = entry.displayName.trim();
      if (name.isEmpty) continue;
      if (seen.add(name)) {
        lines.add(name);
      }
    }
    await file.writeAsString(lines.join('\n'));
  }

  Future<String?> _askText(
    BuildContext context,
    String title, {
    String hint = '',
  }) {
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
              child: Text(context.l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: Text(context.l10n.commonOk),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final filtered = _filteredEntries;
    final creators =
        _viewEntries
            .map((entry) => entry.displayName.split('.').first)
            .toSet()
            .toList()
          ..sort();
    final appliedCount = _entries
        .where((entry) => _appliedLink(entry.displayName).isNotEmpty)
        .length;
    final pendingCount = _entries
        .where((entry) => _isPendingChange(entry.displayName))
        .length;
    final brokenCount = _entries
        .where((entry) => _isBroken(entry.displayName))
        .length;
    final selectedVar = _selectedVar;
    final appliedLink = selectedVar == null ? '' : _appliedLink(selectedVar);
    final draftLink = selectedVar == null ? '' : _draftLink(selectedVar);
    final hasDraft = selectedVar != null && _hasDraft(selectedVar);
    final isBroken = selectedVar != null && _isBroken(selectedVar);
    final suggestion = selectedVar == null ? null : _suggestedLink(selectedVar);
    final suggestionLabel = suggestion == null
        ? '-'
        : _suggestedIsClosest(selectedVar!)
        ? l10n.closestMatch(suggestion)
        : suggestion;
    final linkStatusLabel = selectedVar == null
        ? '-'
        : _linkStatusLabel(selectedVar);
    final linkStatusColor = selectedVar == null
        ? Colors.grey
        : _linkStatusColor(selectedVar);
    final hasPendingChanges = pendingCount > 0;
    final hasDrafts = _draftLinkMap.isNotEmpty;
    final appliedDisplay = selectedVar == null
        ? '-'
        : isBroken
        ? l10n.linkStatusBroken
        : (appliedLink.isEmpty ? '-' : appliedLink);
    final draftDisplay = selectedVar == null
        ? '-'
        : hasDraft
        ? (draftLink.isEmpty ? l10n.draftClearLabel : draftLink)
        : '-';
    final selectedTorrentFiles =
        selectedVar == null ? const <String>[] : _torrentFilesFor(selectedVar);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.missingDependenciesTitle)),
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
                              decoration: InputDecoration(
                                labelText: l10n.commonFilter,
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (_) => _ensureSelection(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 220,
                            child: LazyDropdownField(
                              label: l10n.creatorLabel,
                              value: _creatorFilter.isEmpty
                                  ? 'ALL'
                                  : _creatorFilter,
                              allValue: 'ALL',
                              allLabel: l10n.allCreators,
                              optionsLoader: (queryText, offset, limit) async {
                                final needle = queryText.trim().toLowerCase();
                                final matches = creators
                                    .where(
                                      (item) =>
                                          item.toLowerCase().contains(needle),
                                    )
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
                                final end = (start + limit).clamp(
                                  0,
                                  matches.length,
                                );
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
                            items: [
                              DropdownMenuItem(
                                value: 'ignore',
                                child: Text(l10n.ignoreVersionMismatch),
                              ),
                              DropdownMenuItem(
                                value: 'all',
                                child: Text(l10n.allMissingVars),
                              ),
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
                            message: l10n.includeLinkedTooltip,
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
                                Text(l10n.includeLinkedLabel),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Text(
                            l10n.rowPosition(
                              filtered.isEmpty ? 0 : _selectedIndex + 1,
                              filtered.length,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: filtered.isEmpty || _selectedIndex <= 0
                                ? null
                                : () => _selectIndex(0, filtered),
                            icon: const Icon(Icons.first_page),
                            tooltip: l10n.paginationFirstPageTooltip,
                          ),
                          IconButton(
                            onPressed: filtered.isEmpty || _selectedIndex <= 0
                                ? null
                                : () => _selectIndex(
                                    _selectedIndex - 1,
                                    filtered,
                                  ),
                            icon: const Icon(Icons.chevron_left),
                            tooltip: l10n.paginationPreviousPageTooltip,
                          ),
                          IconButton(
                            onPressed:
                                filtered.isEmpty ||
                                    _selectedIndex >= filtered.length - 1
                                ? null
                                : () => _selectIndex(
                                    _selectedIndex + 1,
                                    filtered,
                                  ),
                            icon: const Icon(Icons.chevron_right),
                            tooltip: l10n.paginationNextPageTooltip,
                          ),
                          IconButton(
                            onPressed:
                                filtered.isEmpty ||
                                    _selectedIndex >= filtered.length - 1
                                ? null
                                : () => _selectIndex(
                                    filtered.length - 1,
                                    filtered,
                                  ),
                            icon: const Icon(Icons.last_page),
                            tooltip: l10n.paginationLastPageTooltip,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          Text(l10n.appliedCount(appliedCount)),
                          const SizedBox(width: 12),
                          Text(l10n.draftCount(pendingCount)),
                          const SizedBox(width: 12),
                          Text(l10n.brokenCount(brokenCount)),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              l10n.missingVarHeader,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              l10n.substituteHeader,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            child: Row(
                              children: [
                                Text(
                                  l10n.downloadHeaderShort,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (_fetchingDownloads)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 4),
                                    child: SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
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
                          return Tooltip(
                            message: l10n.selectMissingVarTooltip,
                            child: InkWell(
                              onTap: () => _selectIndex(index, filtered),
                              child: Container(
                                color: selected ? Colors.blue.shade50 : null,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(entry.displayName),
                                          ),
                                          if (entry.versionMismatch)
                                            const Padding(
                                              padding: EdgeInsets.only(left: 6),
                                              child: Icon(
                                                Icons.warning_amber,
                                                size: 16,
                                                color: Colors.orange,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              link.isEmpty ? '-' : link,
                                            ),
                                          ),
                                          if (pending)
                                            const Padding(
                                              padding: EdgeInsets.only(left: 6),
                                              child: Icon(
                                                Icons.edit,
                                                size: 14,
                                                color: Colors.blueGrey,
                                              ),
                                            ),
                                          if (broken && !pending)
                                            const Padding(
                                              padding: EdgeInsets.only(left: 6),
                                              child: Icon(
                                                Icons.link_off,
                                                size: 14,
                                                color: Colors.orange,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(
                                      width: 72,
                                      child: Tooltip(
                                        message: _downloadTooltip(
                                          entry.displayName,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _downloadIcon(entry.displayName),
                                              color: _downloadColor(
                                                entry.displayName,
                                              ),
                                              size: 18,
                                            ),
                                            if (_hasTorrentHit(
                                              entry.displayName,
                                            ))
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  left: 4,
                                                ),
                                                child: _torrentBadge(),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
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
                          Text(
                            l10n.detailsTitle,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Text(l10n.selectedLabel(selectedVar ?? '-')),
                          const SizedBox(height: 4),
                          Text(
                            l10n.resolvedLabel(
                              selectedVar == null
                                  ? '-'
                                  : _resolvedDisplay(selectedVar),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.downloadLabel(
                              selectedVar == null
                                  ? '-'
                                  : _downloadStatusLabel(
                                      _downloadStatus(selectedVar),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.linkStatusLabel(linkStatusLabel),
                            style: TextStyle(color: linkStatusColor),
                          ),
                          if (_loadingLinks)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: LinearProgressIndicator(minHeight: 2),
                            ),
                          const Divider(height: 16),
                          Text(
                            l10n.linkSubstitutionTitle,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.linkSubstitutionDescription,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(l10n.appliedLinkLabel(appliedDisplay)),
                          const SizedBox(height: 4),
                          Text(l10n.draftLinkLabel(draftDisplay)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  l10n.suggestionLabel(suggestionLabel),
                                ),
                              ),
                              Tooltip(
                                message: l10n.useSuggestionTooltip,
                                child: TextButton(
                                  onPressed: suggestion == null
                                      ? null
                                      : _applySuggestedForSelected,
                                  child: Text(l10n.commonUse),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LazyDropdownField(
                            label: l10n.findTargetLabel,
                            value: _pickerValue,
                            allValue: '',
                            allLabel: l10n.pickTargetLabel,
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
                                message: l10n.limitSamePackageTooltip,
                                child: Checkbox(
                                  value: _linkFilterSamePackage,
                                  onChanged: (value) {
                                    setState(() {
                                      _linkFilterSamePackage = value ?? true;
                                    });
                                  },
                                ),
                              ),
                              Expanded(child: Text(l10n.limitSamePackageLabel)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _linkController,
                            decoration: InputDecoration(
                              labelText: l10n.targetVarLabel,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Tooltip(
                                  message: l10n.setDraftTooltip,
                                  child: FilledButton(
                                    onPressed: selectedVar == null
                                        ? null
                                        : () {
                                            _setDraftLink(
                                              selectedVar,
                                              _linkController.text,
                                            );
                                            setState(() {
                                              _pickerValue = _linkController
                                                  .text
                                                  .trim();
                                            });
                                          },
                                    child: Text(l10n.setDraftLabel),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Tooltip(
                                  message: l10n.clearDraftTooltip,
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
                                    child: Text(l10n.clearDraftLabel),
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
                                  message: l10n.revertDraftTooltip,
                                  child: OutlinedButton(
                                    onPressed: selectedVar == null || !hasDraft
                                        ? null
                                        : () => _revertDraft(selectedVar),
                                    child: Text(l10n.revertDraftLabel),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Tooltip(
                                  message: l10n.applyToPackageTooltip,
                                  child: OutlinedButton(
                                    onPressed:
                                        selectedVar == null ||
                                            _linkController.text.trim().isEmpty
                                        ? null
                                        : _applyDraftToPackage,
                                    child: Text(l10n.applyToPackageLabel),
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
                                  message: l10n.autoFillResolvedTooltip,
                                  child: OutlinedButton(
                                    onPressed: _autoFillResolved,
                                    child: Text(l10n.autoFillResolvedLabel),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Tooltip(
                                  message: l10n.applyLinkChangesTooltip,
                                  child: FilledButton(
                                    onPressed: hasPendingChanges
                                        ? _applyLinkChanges
                                        : null,
                                    child: Text(l10n.applyLinkChangesLabel),
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
                                  message: l10n.saveMapTooltip,
                                  child: OutlinedButton(
                                    onPressed: _saveMap,
                                    child: Text(l10n.saveMapLabel),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Tooltip(
                                  message: l10n.loadMapTooltip,
                                  child: OutlinedButton(
                                    onPressed: _loadMap,
                                    child: Text(l10n.loadMapLabel),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Tooltip(
                            message: l10n.discardDraftsTooltip,
                            child: OutlinedButton(
                              onPressed: hasDrafts ? _discardDrafts : null,
                              child: Text(l10n.discardDraftsLabel),
                            ),
                          ),
                          const Divider(height: 16),
                          Tooltip(
                            message: l10n.googleSearchTooltip,
                            child: OutlinedButton(
                              onPressed: selectedVar == null
                                  ? null
                                  : () async {
                                      final search = selectedVar.replaceAll(
                                        '.latest',
                                        '.1',
                                      );
                                      await _runJob('open_url', {
                                        'url':
                                            'https://www.google.com/search?q=$search var',
                                      });
                                    },
                              child: Text(l10n.googleSearchLabel),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Tooltip(
                            message: 'Search for this var on F95Zone forum',
                            child: OutlinedButton(
                              onPressed: selectedVar == null
                                  ? null
                                  : () async {
                                      final search = selectedVar.replaceAll(
                                        '.latest',
                                        '.1',
                                      );
                                      final encodedSearch = Uri.encodeComponent(
                                        search,
                                      );
                                      await _runJob('open_url', {
                                        'url':
                                            'https://f95zone.to/search/?q=$encodedSearch&t=post&c[nodes][0]=72&o=date&c[child_nodes]=1',
                                      });
                                    },
                              child: const Text('Search in F95'),
                            ),
                          ),
                          const Divider(height: 16),
                          const Text(
                            'External Sources',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Checkbox(
                                value: _enableExternal,
                                onChanged: (value) {
                                  setState(() {
                                    _enableExternal = value ?? false;
                                  });
                                },
                              ),
                              const Expanded(
                                child: Text('Enable External Sources'),
                              ),
                            ],
                          ),
                          if (_enableExternal) ...[
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.only(left: 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Checkbox(
                                        value: _enablePixeldrain,
                                        onChanged: (value) {
                                          setState(() {
                                            _enablePixeldrain = value ?? false;
                                          });
                                        },
                                      ),
                                      const Expanded(child: Text('Pixeldrain')),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Checkbox(
                                        value: _enableMediafire,
                                        onChanged: (value) {
                                          setState(() {
                                            _enableMediafire = value ?? false;
                                          });
                                        },
                                      ),
                                      const Expanded(child: Text('Mediafire')),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Checkbox(
                                        value: _pixeldrainBypass,
                                        onChanged: (value) {
                                          setState(() {
                                            _pixeldrainBypass = value ?? false;
                                          });
                                        },
                                      ),
                                      const Expanded(
                                        child: Text('Pixeldrain Bypass'),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Checkbox(
                                        value: _enableTorrents,
                                        onChanged: (value) {
                                          setState(() {
                                            _enableTorrents = value ?? false;
                                          });
                                        },
                                      ),
                                      const Expanded(
                                        child: Text('Local Torrents'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const Divider(height: 16),
                          Tooltip(
                            message: _enableExternal
                                ? 'Fetch download links from Hub with external fallback'
                                : l10n.fetchHubLinksTooltip,
                            child: OutlinedButton(
                              onPressed: _fetchDownload,
                              child: Text(
                                _enableExternal
                                    ? 'Fetch Links (Hub + External)'
                                    : l10n.fetchHubLinksLabel,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Tooltip(
                            message: l10n.downloadSelectedTooltip,
                            child: OutlinedButton(
                              onPressed: _downloadSelected,
                              child: Text(l10n.downloadSelectedLabel),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Tooltip(
                            message: l10n.downloadAllTooltip,
                            child: OutlinedButton(
                              onPressed: _downloadAll,
                              child: Text(l10n.downloadAllLabel),
                            ),
                          ),
                          const Divider(height: 16),
                          Tooltip(
                            message: l10n.exportInstalledTooltip,
                            child: OutlinedButton(
                              onPressed: () async {
                                final path = await _askText(
                                  context,
                                  l10n.exportPathTitle,
                                  hint: 'installed_vars.txt',
                                );
                                if (path == null || path.trim().isEmpty) return;
                                await _runJob('vars_export_installed', {
                                  'path': path.trim(),
                                });
                              },
                              child: Text(l10n.exportInstalledLabel),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Tooltip(
                            message: l10n.exportMissingTooltip,
                            child: OutlinedButton(
                              onPressed: _exportMissing,
                              child: Text(l10n.exportMissingLabel),
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
                          const Text(
                            'Torrents',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          if (selectedVar == null)
                            const Text('Select a missing var to view torrents.')
                          else if (selectedTorrentFiles.isEmpty)
                            const Text('No torrents found for this var.')
                          else ...[
                            Row(
                              children: [
                                Text(
                                  'Found ${selectedTorrentFiles.length} torrent(s).',
                                ),
                                const Spacer(),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...selectedTorrentFiles.map(
                              (name) => Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Open in external client',
                                    onPressed: () =>
                                        _openTorrentInExternalClient(name),
                                    icon: const Icon(Icons.open_in_new),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
                          Text(
                            l10n.dependentsTitle,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          if (_loadingDependents)
                            const LinearProgressIndicator(minHeight: 2),
                          ..._dependents.map(
                            (name) => ListTile(
                              dense: true,
                              title: Text(name),
                              trailing: TextButton(
                                onPressed: () {
                                  ref
                                      .read(varsQueryProvider.notifier)
                                      .update(
                                        (state) => state.copyWith(
                                          page: 1,
                                          search: name,
                                        ),
                                      );
                                  ref
                                      .read(navIndexProvider.notifier)
                                      .setIndex(0);
                                },
                                child: Text(l10n.commonSelect),
                              ),
                            ),
                          ),
                          if (_dependents.isEmpty)
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text(l10n.noDependents),
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
                          Text(
                            l10n.dependentSavesTitle,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
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
                                child: Text(l10n.commonLocate),
                              ),
                            ),
                          ),
                          if (_dependentSaves.isEmpty)
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text(l10n.noDependentSaves),
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
