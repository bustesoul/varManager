import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/backend/job_log_controller.dart';

class PackSwitchPage extends ConsumerStatefulWidget {
  const PackSwitchPage({super.key});

  @override
  ConsumerState<PackSwitchPage> createState() => _PackSwitchPageState();
}

class _PackSwitchPageState extends ConsumerState<PackSwitchPage> {
  final TextEditingController _addController = TextEditingController();
  final TextEditingController _deleteController = TextEditingController();
  final TextEditingController _renameOldController = TextEditingController();
  final TextEditingController _renameNewController = TextEditingController();
  final TextEditingController _setController = TextEditingController();

  @override
  void dispose() {
    _addController.dispose();
    _deleteController.dispose();
    _renameOldController.dispose();
    _renameNewController.dispose();
    _setController.dispose();
    super.dispose();
  }

  Future<void> _runJob(String kind, Map<String, dynamic> args) async {
    final runner = ref.read(jobRunnerProvider);
    final log = ref.read(jobLogProvider.notifier);
    await runner.runJob(kind, args: args, onLog: log.addLine);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PackSwitch')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _section(
              title: 'Add',
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _addController,
                      decoration: const InputDecoration(
                        labelText: 'New switch name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () async {
                      await _runJob('packswitch_add', {
                        'name': _addController.text.trim(),
                      });
                    },
                    child: const Text('Create'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _section(
              title: 'Delete',
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _deleteController,
                      decoration: const InputDecoration(
                        labelText: 'Switch name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: () async {
                      await _runJob('packswitch_delete', {
                        'name': _deleteController.text.trim(),
                      });
                    },
                    child: const Text('Delete'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _section(
              title: 'Rename',
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _renameOldController,
                      decoration: const InputDecoration(
                        labelText: 'Old name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _renameNewController,
                      decoration: const InputDecoration(
                        labelText: 'New name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: () async {
                      await _runJob('packswitch_rename', {
                        'old_name': _renameOldController.text.trim(),
                        'new_name': _renameNewController.text.trim(),
                      });
                    },
                    child: const Text('Rename'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _section(
              title: 'Activate',
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _setController,
                      decoration: const InputDecoration(
                        labelText: 'Switch name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: () async {
                      await _runJob('packswitch_set', {
                        'name': _setController.text.trim(),
                      });
                    },
                    child: const Text('Set'),
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
}
