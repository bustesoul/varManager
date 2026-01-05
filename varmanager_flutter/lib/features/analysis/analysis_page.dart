import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/backend/job_log_controller.dart';

class AnalysisPage extends ConsumerStatefulWidget {
  const AnalysisPage({super.key, required this.payload});

  final Map<String, dynamic> payload;

  @override
  ConsumerState<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends ConsumerState<AnalysisPage> {
  final TextEditingController _atomNameController = TextEditingController();
  final TextEditingController _atomPathsController = TextEditingController();
  bool _morphs = true;
  bool _hair = true;
  bool _clothing = true;
  bool _skin = true;
  bool _breast = false;
  bool _glute = false;
  bool _ignoreGender = false;
  int _personOrder = 1;

  @override
  void dispose() {
    _atomNameController.dispose();
    _atomPathsController.dispose();
    super.dispose();
  }

  Future<void> _runJob(String kind, Map<String, dynamic> args) async {
    final runner = ref.read(jobRunnerProvider);
    final log = ref.read(jobLogProvider.notifier);
    await runner.runJob(kind, args: args, onLog: log.addLine);
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
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
                  _section(
                    title: 'Single Atom',
                    child: Column(
                      children: [
                        TextField(
                          controller: _atomNameController,
                          decoration: const InputDecoration(
                            labelText: 'Atom Name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
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
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton(
                              onPressed: () async {
                                await _runJob('scene_preset_look', {
                                  'var_name': varName,
                                  'entry_name': entryName,
                                  'atom_name': _atomNameController.text.trim(),
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
                              onPressed: () async {
                                await _runJob('scene_preset_pose', {
                                  'var_name': varName,
                                  'entry_name': entryName,
                                  'atom_name': _atomNameController.text.trim(),
                                  'ignore_gender': _ignoreGender,
                                  'person_order': _personOrder,
                                });
                              },
                              child: const Text('Load Pose'),
                            ),
                            FilledButton.tonal(
                              onPressed: () async {
                                await _runJob('scene_preset_animation', {
                                  'var_name': varName,
                                  'entry_name': entryName,
                                  'atom_name': _atomNameController.text.trim(),
                                  'ignore_gender': _ignoreGender,
                                  'person_order': _personOrder,
                                });
                              },
                              child: const Text('Load Animation'),
                            ),
                            FilledButton.tonal(
                              onPressed: () async {
                                await _runJob('scene_preset_plugin', {
                                  'var_name': varName,
                                  'entry_name': entryName,
                                  'atom_name': _atomNameController.text.trim(),
                                  'ignore_gender': _ignoreGender,
                                  'person_order': _personOrder,
                                });
                              },
                              child: const Text('Load Plugin'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _section(
                    title: 'Atom Paths',
                    child: Column(
                      children: [
                        TextField(
                          controller: _atomPathsController,
                          decoration: const InputDecoration(
                            labelText: 'Atom Paths (comma separated)',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            FilledButton(
                              onPressed: () async {
                                await _runJob('scene_preset_scene', {
                                  'var_name': varName,
                                  'entry_name': entryName,
                                  'atom_paths': _parsePaths(),
                                  'ignore_gender': _ignoreGender,
                                  'person_order': _personOrder,
                                });
                              },
                              child: const Text('Load Scene'),
                            ),
                            FilledButton.tonal(
                              onPressed: () async {
                                await _runJob('scene_add_atoms', {
                                  'var_name': varName,
                                  'entry_name': entryName,
                                  'atom_paths': _parsePaths(),
                                  'ignore_gender': _ignoreGender,
                                  'person_order': _personOrder,
                                });
                              },
                              child: const Text('Add To Scene'),
                            ),
                            FilledButton.tonal(
                              onPressed: () async {
                                await _runJob('scene_add_subscene', {
                                  'var_name': varName,
                                  'entry_name': entryName,
                                  'atom_paths': _parsePaths(),
                                  'ignore_gender': _ignoreGender,
                                  'person_order': _personOrder,
                                });
                              },
                              child: const Text('Add as Subscene'),
                            ),
                          ],
                        ),
                      ],
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

  List<String> _parsePaths() {
    return _atomPathsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
}
