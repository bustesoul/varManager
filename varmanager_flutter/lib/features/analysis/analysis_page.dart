import 'package:flutter/material.dart';
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

  bool _loadingAtoms = false;
  List<AtomTreeNode> _atoms = [];
  List<String> _personAtoms = [];
  String? _selectedPerson;
  final Set<String> _selectedAtomPaths = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadAtoms);
  }

  Future<void> _runJob(String kind, Map<String, dynamic> args) async {
    final runner = ref.read(jobRunnerProvider);
    final log = ref.read(jobLogProvider.notifier);
    await runner.runJob(kind, args: args, onLog: log.addEntry);
  }

  Future<void> _loadAtoms() async {
    if (_loadingAtoms) return;
    setState(() {
      _loadingAtoms = true;
    });
    try {
      final client = ref.read(backendClientProvider);
      final varName = widget.payload['var_name']?.toString() ?? '';
      final entryName = widget.payload['entry_name']?.toString() ?? '';
      final response = await client.listAnalysisAtoms(varName, entryName);
      if (!mounted) return;
      setState(() {
        _atoms = response.atoms;
        _personAtoms = response.personAtoms;
        _selectedPerson =
            _personAtoms.isNotEmpty ? _personAtoms.first : _selectedPerson;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingAtoms = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final varName = widget.payload['var_name']?.toString() ?? '';
    final entryName = widget.payload['entry_name']?.toString() ?? '';
    final gender = widget.payload['character_gender']?.toString() ?? 'unknown';
    return Scaffold(
      appBar: AppBar(title: const Text('Scene Analysis')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: ListTile(
                title: Text(varName),
                subtitle: Text('Entry: $entryName | Gender: $gender'),
                trailing: TextButton(
                  onPressed: _loadingAtoms ? null : _loadAtoms,
                  child: const Text('Refresh'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: 320,
                    child: ListView(
                      children: [
                        _section(
                          title: 'Person List',
                          child: _buildPersonList(),
                        ),
                        const SizedBox(height: 12),
                        _section(
                          title: 'Look Options',
                          child: _buildLookOptions(),
                        ),
                        const SizedBox(height: 12),
                        _section(
                          title: 'Single Atom Actions',
                          child: _buildSingleAtomActions(varName, entryName),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _section(
                      title: 'Atom Paths',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_loadingAtoms)
                            const LinearProgressIndicator(minHeight: 2),
                          const SizedBox(height: 8),
                          Text('Selected ${_selectedAtomPaths.length} items'),
                          const SizedBox(height: 8),
                          Expanded(
                            child: _atoms.isEmpty
                                ? const Center(child: Text('No atoms loaded'))
                                : ListView(
                                    children: _atoms
                                        .map((node) => _buildAtomNode(node))
                                        .toList(),
                                  ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton(
                                onPressed: _selectedAtomPaths.isEmpty
                                    ? null
                                    : () async {
                                        await _runJob('scene_preset_scene', {
                                          'var_name': varName,
                                          'entry_name': entryName,
                                          'atom_paths': _selectedAtomPaths.toList(),
                                          'ignore_gender': _ignoreGender,
                                          'person_order': _personOrder,
                                        });
                                      },
                                child: const Text('Load Scene'),
                              ),
                              FilledButton.tonal(
                                onPressed: _selectedAtomPaths.isEmpty
                                    ? null
                                    : () async {
                                        await _runJob('scene_add_atoms', {
                                          'var_name': varName,
                                          'entry_name': entryName,
                                          'atom_paths': _selectedAtomPaths.toList(),
                                          'ignore_gender': _ignoreGender,
                                          'person_order': _personOrder,
                                        });
                                      },
                                child: const Text('Add To Scene'),
                              ),
                              FilledButton.tonal(
                                onPressed: _selectedAtomPaths.isEmpty
                                    ? null
                                    : () async {
                                        await _runJob('scene_add_subscene', {
                                          'var_name': varName,
                                          'entry_name': entryName,
                                          'atom_paths': _selectedAtomPaths.toList(),
                                          'ignore_gender': _ignoreGender,
                                          'person_order': _personOrder,
                                        });
                                      },
                                child: const Text('Add as Subscene'),
                              ),
                              TextButton(
                                onPressed: _selectedAtomPaths.isEmpty
                                    ? null
                                    : () {
                                        setState(() {
                                          _selectedAtomPaths.clear();
                                        });
                                      },
                                child: const Text('Clear Selection'),
                              ),
                            ],
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

  Widget _buildPersonList() {
    if (_personAtoms.isEmpty) {
      return const Text('No person atoms found');
    }
    return RadioGroup<String>(
      groupValue: _selectedPerson,
      onChanged: (value) {
        if (value == null) return;
        setState(() {
          _selectedPerson = value;
        });
      },
      child: Column(
        children: _personAtoms
            .map(
              (person) => RadioListTile<String>(
                value: person,
                title: Text(person),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildLookOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: [
            FilterChip(
              label: const Text('Morphs'),
              selected: _morphs,
              onSelected: (value) {
                setState(() {
                  _morphs = value;
                });
              },
            ),
            FilterChip(
              label: const Text('Hair'),
              selected: _hair,
              onSelected: (value) {
                setState(() {
                  _hair = value;
                });
              },
            ),
            FilterChip(
              label: const Text('Clothing'),
              selected: _clothing,
              onSelected: (value) {
                setState(() {
                  _clothing = value;
                });
              },
            ),
            FilterChip(
              label: const Text('Skin'),
              selected: _skin,
              onSelected: (value) {
                setState(() {
                  _skin = value;
                });
              },
            ),
            FilterChip(
              label: const Text('Breast'),
              selected: _breast,
              onSelected: (value) {
                setState(() {
                  _breast = value;
                });
              },
            ),
            FilterChip(
              label: const Text('Glute'),
              selected: _glute,
              onSelected: (value) {
                setState(() {
                  _glute = value;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButton<int>(
                value: _personOrder,
                items: [1, 2, 3, 4, 5, 6, 7, 8]
                    .map((value) => DropdownMenuItem(
                          value: value,
                          child: Text('Person $value'),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _personOrder = value;
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            FilterChip(
              label: const Text('Ignore Gender'),
              selected: _ignoreGender,
              onSelected: (value) {
                setState(() {
                  _ignoreGender = value;
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSingleAtomActions(String varName, String entryName) {
    final atomName = _selectedPerson;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton(
          onPressed: atomName == null
              ? null
              : () async {
                  await _runJob('scene_preset_look', {
                    'var_name': varName,
                    'entry_name': entryName,
                    'atom_name': atomName,
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
          onPressed: atomName == null
              ? null
              : () async {
                  await _runJob('scene_preset_pose', {
                    'var_name': varName,
                    'entry_name': entryName,
                    'atom_name': atomName,
                    'ignore_gender': _ignoreGender,
                    'person_order': _personOrder,
                  });
                },
          child: const Text('Load Pose'),
        ),
        FilledButton.tonal(
          onPressed: atomName == null
              ? null
              : () async {
                  await _runJob('scene_preset_animation', {
                    'var_name': varName,
                    'entry_name': entryName,
                    'atom_name': atomName,
                    'ignore_gender': _ignoreGender,
                    'person_order': _personOrder,
                  });
                },
          child: const Text('Load Animation'),
        ),
        FilledButton.tonal(
          onPressed: atomName == null
              ? null
              : () async {
                  await _runJob('scene_preset_plugin', {
                    'var_name': varName,
                    'entry_name': entryName,
                    'atom_name': atomName,
                    'ignore_gender': _ignoreGender,
                    'person_order': _personOrder,
                  });
                },
          child: const Text('Load Plugin'),
        ),
      ],
    );
  }

  Widget _buildAtomNode(AtomTreeNode node) {
    final state = _nodeState(node);
    final hasChildren = node.children.isNotEmpty;
    final title = Row(
      children: [
        Checkbox(
          tristate: true,
          value: state,
          onChanged: (value) => _toggleNode(node, value),
        ),
        Expanded(child: Text(node.name)),
      ],
    );
    if (!hasChildren) {
      return Padding(
        padding: const EdgeInsets.only(left: 8),
        child: title,
      );
    }
    return ExpansionTile(
      title: title,
      children: node.children.map(_buildAtomNode).toList(),
    );
  }

  bool? _nodeState(AtomTreeNode node) {
    if (node.children.isEmpty) {
      if (node.path == null || node.path!.isEmpty) return false;
      return _selectedAtomPaths.contains(node.path) ? true : false;
    }
    final states = node.children.map(_nodeState).toList();
    if (states.every((state) => state == true)) {
      return true;
    }
    if (states.every((state) => state == false)) {
      return false;
    }
    return null;
  }

  void _toggleNode(AtomTreeNode node, bool? selected) {
    final select = selected ?? false;
    final paths = _collectPaths(node);
    setState(() {
      if (select) {
        _selectedAtomPaths.addAll(paths);
      } else {
        _selectedAtomPaths.removeAll(paths);
      }
    });
  }

  List<String> _collectPaths(AtomTreeNode node) {
    final paths = <String>[];
    if (node.path != null && node.path!.isNotEmpty) {
      paths.add(node.path!);
    }
    for (final child in node.children) {
      paths.addAll(_collectPaths(child));
    }
    return paths;
  }

  Widget _section({required String title, required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

