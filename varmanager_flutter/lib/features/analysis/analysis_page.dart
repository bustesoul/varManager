import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/backend/job_log_controller.dart';
import '../../core/models/extra_models.dart';

class AnalysisPage extends ConsumerStatefulWidget {
  const AnalysisPage({super.key, required this.payload});

  final Map<String, dynamic> payload;

  @override
  ConsumerState<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends ConsumerState<AnalysisPage> {
  bool _morphs = true;
  bool _hair = true;
  bool _clothing = true;
  bool _skin = true;
  bool _breast = false;
  bool _glute = false;
  bool _ignoreGender = false;
  int _personOrder = 1;
  bool _includeBaseAtoms = true;

  AnalysisSummaryResponse? _summary;
  bool _loading = false;
  String? _error;

  final Set<String> _selectedAtomPaths = {};
  final Map<String, Set<String>> _nodeLeaves = {};
  final Map<String, String> _leafPathByName = {};
  final Map<String, List<String>> _parentLinks = {};
  final Map<String, Set<String>> _typeToPaths = {};
  final Set<String> _baseAtomPaths = {};
  Set<String> _allAtomPaths = {};

  String? _selectedPersonName;

  final TextEditingController _atomSearchController = TextEditingController();
  final TextEditingController _dependencySearchController =
      TextEditingController();
  String _atomQuery = '';
  String _dependencyQuery = '';
  String _dependencyFilter = 'all';

  @override
  void initState() {
    super.initState();
    _atomSearchController.addListener(() {
      setState(() {
        _atomQuery = _atomSearchController.text.trim().toLowerCase();
      });
    });
    _dependencySearchController.addListener(() {
      setState(() {
        _dependencyQuery = _dependencySearchController.text.trim().toLowerCase();
      });
    });
    Future.microtask(_loadSummary);
  }

  @override
  void dispose() {
    _atomSearchController.dispose();
    _dependencySearchController.dispose();
    super.dispose();
  }

  Future<void> _runJob(String kind, Map<String, dynamic> args) async {
    final runner = ref.read(jobRunnerProvider);
    final log = ref.read(jobLogProvider.notifier);
    await runner.runJob(kind, args: args, onLog: log.addEntry);
  }

  Future<void> _loadSummary() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = ref.read(backendClientProvider);
      final varName = widget.payload['var_name']?.toString() ?? '';
      final entryName = widget.payload['entry_name']?.toString() ?? '';
      final summary = await client.getAnalysisSummary(varName, entryName);
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _loading = false;
        _error = null;
        _rebuildIndexes();
        _syncSelections();
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = err.toString();
      });
    }
  }

  Future<void> _clearCache() async {
    final varName = _summary?.varName ?? widget.payload['var_name']?.toString() ?? '';
    final entryName =
        _summary?.entryName ?? widget.payload['entry_name']?.toString() ?? '';
    await _runJob('cache_clear', {
      'var_name': varName,
      'entry_name': entryName,
    });
    await _loadSummary();
  }

  void _rebuildIndexes() {
    _nodeLeaves.clear();
    _leafPathByName.clear();
    _parentLinks.clear();
    _typeToPaths.clear();
    _baseAtomPaths.clear();
    _allAtomPaths = {};

    final summary = _summary;
    if (summary == null) return;

    for (final link in summary.parentLinks) {
      _parentLinks[link.parent] = link.children;
    }

    for (final node in summary.atoms) {
      _indexNode(node, '');
    }

    _allAtomPaths = _leafPathByName.values.toSet();
  }

  Set<String> _indexNode(AtomTreeNode node, String parentKey) {
    final key = parentKey.isEmpty ? node.name : '$parentKey/${node.name}';
    if (node.path != null && node.path!.isNotEmpty) {
      final path = node.path!;
      final fileName = _basename(path);
      _leafPathByName[fileName] = path;

      final type = _typeFromPath(path);
      _typeToPaths.putIfAbsent(type, () => <String>{}).add(path);
      if (type.startsWith('(base)')) {
        _baseAtomPaths.add(path);
      }

      final leaves = <String>{path};
      _nodeLeaves[key] = leaves;
      return leaves;
    }

    final leaves = <String>{};
    for (final child in node.children) {
      leaves.addAll(_indexNode(child, key));
    }
    _nodeLeaves[key] = leaves;
    return leaves;
  }

  void _syncSelections() {
    _selectedAtomPaths.removeWhere((path) => !_allAtomPaths.contains(path));
    final people = _summary?.personAtoms ?? [];
    if (people.isEmpty) {
      _selectedPersonName = null;
      return;
    }
    final exists = people.any((person) => person.name == _selectedPersonName);
    _selectedPersonName ??= people.first.name;
    if (!exists) {
      _selectedPersonName = people.first.name;
    }
    _syncGenderOptions();
  }

  void _syncGenderOptions() {
    final person = _selectedPerson;
    if (person == null) return;
    if (!_allowBreast(person.gender)) {
      _breast = false;
    }
    if (!_allowGlute(person.gender)) {
      _glute = false;
    }
  }

  String _basename(String path) => path.split('/').last;

  String _typeFromPath(String path) {
    final parts = path.split('/');
    if (parts.length < 2) return 'unknown';
    return parts[parts.length - 2];
  }

  bool _allowBreast(String gender) {
    final lower = gender.toLowerCase();
    return lower == 'female' || lower == 'futa';
  }

  bool _allowGlute(String gender) {
    final lower = gender.toLowerCase();
    return lower == 'female' || lower == 'futa';
  }

  AnalysisPersonInfo? get _selectedPerson {
    final summary = _summary;
    if (summary == null) return null;
    for (final person in summary.personAtoms) {
      if (person.name == _selectedPersonName) {
        return person;
      }
    }
    return null;
  }

  bool get _hasLookSelection {
    final person = _selectedPerson;
    final allowBreast = person == null ? false : _allowBreast(person.gender);
    final allowGlute = person == null ? false : _allowGlute(person.gender);
    return _morphs ||
        _hair ||
        _clothing ||
        _skin ||
        (_breast && allowBreast) ||
        (_glute && allowGlute);
  }

  bool get _hasSceneSelection {
    if (_selectedAtomPaths.isNotEmpty) return true;
    return _includeBaseAtoms && _baseAtomPaths.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scene Analysis'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadSummary,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading && summary == null
          ? const Center(child: CircularProgressIndicator())
          : summary == null
              ? _buildErrorState()
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildHeader(summary),
                    ),
                    Expanded(child: _buildTabs(summary)),
                  ],
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Failed to load analysis summary'),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ],
          const SizedBox(height: 12),
          FilledButton(onPressed: _loadSummary, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildHeader(AnalysisSummaryResponse summary) {
    final personCount = summary.personAtoms.length;
    final atomCount = _allAtomPaths.length;
    final missingCount = summary.dependencies
        .where((dep) => dep.status == 'missing')
        .length;
    final mismatchCount = summary.dependencies
        .where((dep) => dep.status == 'version_mismatch')
        .length;
    final depsCount = summary.dependencies.length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.varName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text('Entry: ${summary.entryName}'),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _loading ? null : _clearCache,
                  child: const Text('Clear cache'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip('Gender', summary.characterGender),
                _chip('Persons', personCount.toString()),
                _chip('Atoms', atomCount.toString()),
                _chip('Deps', depsCount.toString()),
                if (missingCount > 0)
                  _chip('Missing', missingCount.toString(),
                      color: Colors.redAccent),
                if (mismatchCount > 0)
                  _chip('Mismatch', mismatchCount.toString(),
                      color: Colors.orangeAccent),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, String value, {Color? color}) {
    final bg = color == null
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : color.withValues(alpha: 0.2);
    final fg = color ?? Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.2)),
      ),
      child: Text('$label: $value', style: TextStyle(color: fg)),
    );
  }

  Widget _buildTabs(AnalysisSummaryResponse summary) {
    final tabs = <Tab>[const Tab(text: 'People')];
    final views = <Widget>[_buildPeopleTab(summary)];
    if (summary.isScene || summary.atoms.isNotEmpty) {
      tabs.add(const Tab(text: 'Atoms'));
      views.add(_buildAtomsTab(summary));
    }
    if (summary.dependencies.isNotEmpty) {
      tabs.add(const Tab(text: 'Dependencies'));
      views.add(_buildDependenciesTab(summary));
    }
    return DefaultTabController(
      length: tabs.length,
      child: Column(
        children: [
          TabBar(tabs: tabs),
          Expanded(
            child: TabBarView(children: views),
          ),
        ],
      ),
    );
  }

  Widget _buildPeopleTab(AnalysisSummaryResponse summary) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 900;
          final personList = _buildPersonList(summary);
          final actions = _buildPersonActions(summary);
          if (isNarrow) {
            return ListView(
              children: [
                personList,
                const SizedBox(height: 12),
                actions,
              ],
            );
          }
          return Row(
            children: [
              SizedBox(width: 320, child: personList),
              const SizedBox(width: 12),
              Expanded(child: actions),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPersonList(AnalysisSummaryResponse summary) {
    if (summary.personAtoms.isEmpty) {
      return _section(
        title: 'People',
        child: const Text('No person atoms found'),
      );
    }
    return _section(
      title: 'People',
      child: SizedBox(
        height: 420,
        child: ListView.separated(
          itemCount: summary.personAtoms.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final person = summary.personAtoms[index];
            final selected = person.name == _selectedPersonName;
            return ListTile(
              title: Text(person.name),
              subtitle: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _tag(person.gender),
                  if (person.hasPose) _tag('Pose'),
                  if (person.hasAnimation) _tag('Animation'),
                  if (person.hasPlugin) _tag('Plugin'),
                ],
              ),
              trailing:
                  selected ? const Icon(Icons.check_circle, size: 20) : null,
              selected: selected,
              onTap: () {
                setState(() {
                  _selectedPersonName = person.name;
                  _syncGenderOptions();
                });
              },
            );
          },
        ),
      ),
    );
  }

  Widget _tag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _buildPersonActions(AnalysisSummaryResponse summary) {
    final person = _selectedPerson;
    final allowBreast = person == null ? false : _allowBreast(person.gender);
    final allowGlute = person == null ? false : _allowGlute(person.gender);
    return _section(
      title: 'Presets & Actions',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTargetOptions(),
          const SizedBox(height: 12),
          Text('Look Options', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _optionChip('Morphs', _morphs, (value) {
                setState(() => _morphs = value);
              }),
              _optionChip('Hair', _hair, (value) {
                setState(() => _hair = value);
              }),
              _optionChip('Clothing', _clothing, (value) {
                setState(() => _clothing = value);
              }),
              _optionChip('Skin', _skin, (value) {
                setState(() => _skin = value);
              }),
              _optionChip(
                'Breast',
                _breast,
                allowBreast
                    ? (value) {
                        setState(() => _breast = value);
                      }
                    : null,
              ),
              _optionChip(
                'Glute',
                _glute,
                allowGlute
                    ? (value) {
                        setState(() => _glute = value);
                      }
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Actions', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: person == null || !_hasLookSelection
                    ? null
                    : () async {
                        await _runJob('scene_preset_look', {
                          'var_name': summary.varName,
                          'entry_name': summary.entryName,
                          'atom_name': person.name,
                          'morphs': _morphs,
                          'hair': _hair,
                          'clothing': _clothing,
                          'skin': _skin,
                          'breast': _breast,
                          'glute': _glute,
                          'ignore_gender': _ignoreGender,
                          'person_order': _personOrder,
                        });
                      },
                child: const Text('Load Look'),
              ),
              FilledButton.tonal(
                onPressed: person == null || !person.hasPose
                    ? null
                    : () async {
                        await _runJob('scene_preset_pose', {
                          'var_name': summary.varName,
                          'entry_name': summary.entryName,
                          'atom_name': person.name,
                          'ignore_gender': _ignoreGender,
                          'person_order': _personOrder,
                        });
                      },
                child: const Text('Load Pose'),
              ),
              FilledButton.tonal(
                onPressed: person == null || !person.hasAnimation
                    ? null
                    : () async {
                        await _runJob('scene_preset_animation', {
                          'var_name': summary.varName,
                          'entry_name': summary.entryName,
                          'atom_name': person.name,
                          'ignore_gender': _ignoreGender,
                          'person_order': _personOrder,
                        });
                      },
                child: const Text('Load Animation'),
              ),
              FilledButton.tonal(
                onPressed: person == null || !person.hasPlugin
                    ? null
                    : () async {
                        await _runJob('scene_preset_plugin', {
                          'var_name': summary.varName,
                          'entry_name': summary.entryName,
                          'atom_name': person.name,
                          'ignore_gender': _ignoreGender,
                          'person_order': _personOrder,
                        });
                      },
                child: const Text('Load Plugin'),
              ),
            ],
          ),
          if (person != null && !person.hasPose) ...[
            const SizedBox(height: 8),
            const Text('Pose presets require .json scene entries.'),
          ],
        ],
      ),
    );
  }

  Widget _optionChip(String label, bool value, ValueChanged<bool>? onChanged) {
    return FilterChip(
      label: Text(label),
      selected: value,
      onSelected: onChanged == null ? null : (next) => onChanged(next),
    );
  }

  Widget _buildAtomsTab(AnalysisSummaryResponse summary) {
    final types = _typeToPaths.keys.toList()..sort();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _section(
            title: 'Atom Search',
            child: TextField(
              controller: _atomSearchController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Filter atoms by name',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _section(
            title: 'Selection',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Selected ${_selectedAtomPaths.length} atoms'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: _baseAtomPaths.isEmpty
                          ? null
                          : () => _selectPaths(_baseAtomPaths),
                      child: const Text('Select Base'),
                    ),
                    OutlinedButton(
                      onPressed: _allAtomPaths.isEmpty
                          ? null
                          : () => _selectPaths(_allAtomPaths, replace: true),
                      child: const Text('Select All'),
                    ),
                    OutlinedButton(
                      onPressed: _selectedAtomPaths.isEmpty
                          ? null
                          : () {
                              setState(() => _selectedAtomPaths.clear());
                            },
                      child: const Text('Clear'),
                    ),
                    if (_typeToPaths.isNotEmpty)
                      PopupMenuButton<String>(
                        onSelected: (value) =>
                            _selectPaths(_typeToPaths[value] ?? {}),
                        itemBuilder: (context) {
                          return types
                              .map(
                                (type) => PopupMenuItem(
                                  value: type,
                                  child: Text(
                                      'Select $type (${_typeToPaths[type]!.length})'),
                                ),
                              )
                              .toList();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          child: const Text('Select Type'),
                        ),
                      ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: _includeBaseAtoms,
                          onChanged: (value) {
                            setState(() => _includeBaseAtoms = value);
                          },
                        ),
                        const Text('Include base atoms'),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _section(
              title: 'Atom Tree',
              expandChild: true,
              child: summary.atoms.isEmpty
                  ? const Center(child: Text('No atoms available'))
                  : ListView(
                      children: _buildAtomNodes(summary.atoms, '', _atomQuery),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          _section(
            title: 'Scene Actions',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: _hasSceneSelection
                      ? () async {
                          final paths = <String>{};
                          paths.addAll(_selectedAtomPaths);
                          if (_includeBaseAtoms) {
                            paths.addAll(_baseAtomPaths);
                          }
                          await _runJob('scene_preset_scene', {
                            'var_name': summary.varName,
                            'entry_name': summary.entryName,
                            'atom_paths': paths.toList(),
                          });
                        }
                      : null,
                  child: const Text('Load Scene'),
                ),
                FilledButton.tonal(
                  onPressed: _selectedAtomPaths.isNotEmpty
                      ? () async {
                          await _runJob('scene_add_atoms', {
                            'var_name': summary.varName,
                            'entry_name': summary.entryName,
                            'atom_paths': _selectedAtomPaths.toList(),
                          });
                        }
                      : null,
                  child: const Text('Add To Scene'),
                ),
                FilledButton.tonal(
                  onPressed: _selectedAtomPaths.isNotEmpty
                      ? () async {
                          await _runJob('scene_add_subscene', {
                            'var_name': summary.varName,
                            'entry_name': summary.entryName,
                            'atom_paths': _selectedAtomPaths.toList(),
                          });
                        }
                      : null,
                  child: const Text('Add as Subscene'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildAtomNodes(
    List<AtomTreeNode> nodes,
    String parentKey,
    String query,
  ) {
    final widgets = <Widget>[];
    for (final node in nodes) {
      final key = parentKey.isEmpty ? node.name : '$parentKey/${node.name}';
      final nodeMatches = _nodeMatches(node, query);
      final childQuery = nodeMatches ? '' : query;
      final childWidgets = _buildAtomNodes(node.children, key, childQuery);
      if (!nodeMatches && childWidgets.isEmpty) {
        continue;
      }
      widgets.add(_buildAtomNode(node, key, childWidgets));
    }
    return widgets;
  }

  bool _nodeMatches(AtomTreeNode node, String query) {
    if (query.isEmpty) return true;
    if (node.name.toLowerCase().contains(query)) return true;
    if (node.path != null && node.path!.toLowerCase().contains(query)) {
      return true;
    }
    for (final child in node.children) {
      if (_nodeMatches(child, query)) return true;
    }
    return false;
  }

  Widget _buildAtomNode(
    AtomTreeNode node,
    String key,
    List<Widget> children,
  ) {
    final state = _nodeState(key);
    final hasChildren = node.children.isNotEmpty;
    final title = Row(
      children: [
        Checkbox(
          tristate: true,
          value: state,
          onChanged: (value) => _toggleNode(key, node, value),
        ),
        Expanded(child: Text(node.name)),
      ],
    );
    if (!hasChildren) {
      return Padding(
        padding: const EdgeInsets.only(left: 16),
        child: title,
      );
    }
    return ExpansionTile(
      key: PageStorageKey<String>(key),
      title: title,
      childrenPadding: const EdgeInsets.only(left: 16),
      children: children,
    );
  }

  bool? _nodeState(String key) {
    final leaves = _nodeLeaves[key];
    if (leaves == null || leaves.isEmpty) {
      return false;
    }
    final selectedCount =
        leaves.where((path) => _selectedAtomPaths.contains(path)).length;
    if (selectedCount == 0) {
      return false;
    }
    if (selectedCount == leaves.length) {
      return true;
    }
    return null;
  }

  void _toggleNode(String key, AtomTreeNode node, bool? selected) {
    final select = selected ?? false;
    final leaves = _nodeLeaves[key] ?? {};
    final next = Set<String>.from(_selectedAtomPaths);
    if (select) {
      next.addAll(leaves);
    } else {
      next.removeAll(leaves);
    }

    if (select && node.path != null) {
      final fileName = _basename(node.path!);
      final children = _parentLinks[fileName] ?? const [];
      for (final child in children) {
        final childPath = _leafPathByName[child];
        if (childPath != null) {
          next.add(childPath);
        }
      }
    }

    setState(() {
      _selectedAtomPaths
        ..clear()
        ..addAll(next);
    });
  }

  void _selectPaths(Iterable<String> paths, {bool replace = false}) {
    setState(() {
      if (replace) {
        _selectedAtomPaths
          ..clear()
          ..addAll(paths);
        return;
      }
      _selectedAtomPaths.addAll(paths);
    });
  }

  Widget _buildDependenciesTab(AnalysisSummaryResponse summary) {
    final filtered = summary.dependencies.where((dep) {
      if (_dependencyFilter != 'all' && dep.status != _dependencyFilter) {
        return false;
      }
      if (_dependencyQuery.isEmpty) return true;
      return dep.name.toLowerCase().contains(_dependencyQuery) ||
          dep.resolved.toLowerCase().contains(_dependencyQuery);
    }).toList();

    final missing = summary.dependencies
        .where((dep) => dep.status == 'missing')
        .map((dep) => dep.name)
        .toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _section(
            title: 'Dependency Search',
            child: TextField(
              controller: _dependencySearchController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Filter dependencies',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _section(
            title: 'Filters',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _filterChip('all', 'All'),
                _filterChip('missing', 'Missing'),
                _filterChip('version_mismatch', 'Mismatch'),
                _filterChip('resolved', 'Resolved'),
                _filterChip('ok', 'Installed'),
                TextButton(
                  onPressed: missing.isEmpty
                      ? null
                      : () async {
                          await Clipboard.setData(
                            ClipboardData(text: missing.join('\n')),
                          );
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Missing deps copied')),
                          );
                        },
                  child: const Text('Copy Missing'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _section(
              title: 'Dependencies (${filtered.length})',
              expandChild: true,
              child: filtered.isEmpty
                  ? const Center(child: Text('No dependencies match'))
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final dep = filtered[index];
                        final color = _dependencyColor(dep.status);
                        final resolved =
                            dep.resolved.isNotEmpty && dep.resolved != dep.name;
                        return ListTile(
                          title: Text(dep.name),
                          subtitle: resolved
                              ? Text('Resolved: ${dep.resolved}')
                              : Text(dep.status.replaceAll('_', ' ')),
                          trailing: Icon(Icons.circle, color: color, size: 12),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Color _dependencyColor(String status) {
    switch (status) {
      case 'missing':
        return Colors.redAccent;
      case 'version_mismatch':
        return Colors.orangeAccent;
      case 'resolved':
        return Colors.blueAccent;
      case 'ok':
        return Colors.green;
      default:
        return Theme.of(context).colorScheme.outline;
    }
  }

  Widget _filterChip(String value, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _dependencyFilter == value,
      onSelected: (_) {
        setState(() {
          _dependencyFilter = value;
        });
      },
    );
  }

  Widget _buildTargetOptions() {
    return _section(
      title: 'Preset Target',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButton<int>(
                  value: _personOrder,
                  isExpanded: true,
                  items: List.generate(
                    8,
                    (index) => DropdownMenuItem(
                      value: index + 1,
                      child: Text('Person ${index + 1}'),
                    ),
                  ),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _personOrder = value);
                  },
                ),
              ),
              const SizedBox(width: 12),
              FilterChip(
                label: const Text('Ignore Gender'),
                selected: _ignoreGender,
                onSelected: (value) {
                  setState(() => _ignoreGender = value);
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Applies to person presets only. Atom actions ignore this.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required Widget child,
    bool expandChild = false,
  }) {
    final content = expandChild ? Expanded(child: child) : child;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            content,
          ],
        ),
      ),
    );
  }
}
