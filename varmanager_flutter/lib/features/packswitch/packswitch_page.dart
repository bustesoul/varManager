import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/backend/job_log_controller.dart';
import '../../core/models/extra_models.dart';

class PackSwitchPage extends ConsumerStatefulWidget {
  const PackSwitchPage({super.key});

  @override
  ConsumerState<PackSwitchPage> createState() => _PackSwitchPageState();
}

class _PackSwitchPageState extends ConsumerState<PackSwitchPage> {
  final TextEditingController _addController = TextEditingController();
  final TextEditingController _renameController = TextEditingController();
  bool _loading = false;
  PackSwitchListResponse? _data;
  String? _selected;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadSwitches);
  }

  @override
  void dispose() {
    _addController.dispose();
    _renameController.dispose();
    super.dispose();
  }

  Future<void> _runJob(String kind, Map<String, dynamic> args) async {
    final runner = ref.read(jobRunnerProvider);
    final log = ref.read(jobLogProvider.notifier);
    await runner.runJob(kind, args: args, onLog: log.addLine);
  }

  Future<void> _loadSwitches() async {
    if (_loading) return;
    setState(() {
      _loading = true;
    });
    final client = ref.read(backendClientProvider);
    final response = await client.listPackSwitches();
    if (!mounted) return;
    setState(() {
      _data = response;
      _selected = response.switches.contains(_selected) ? _selected : response.current;
      _loading = false;
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  bool _exists(String name) {
    final switches = _data?.switches ?? [];
    return switches.any((item) => item.toLowerCase() == name.toLowerCase());
  }

  Future<void> _createSwitch() async {
    final name = _addController.text.trim();
    if (name.isEmpty) {
      _showMessage('Switch name is required.');
      return;
    }
    if (_exists(name)) {
      _showMessage('Switch already exists.');
      return;
    }
    await _runJob('packswitch_add', {'name': name});
    _addController.clear();
    await _loadSwitches();
  }

  Future<void> _renameSwitch() async {
    final oldName = _selected ?? '';
    final newName = _renameController.text.trim();
    if (oldName.isEmpty) {
      _showMessage('Select a switch to rename.');
      return;
    }
    if (newName.isEmpty) {
      _showMessage('New name is required.');
      return;
    }
    if (newName.toLowerCase() == oldName.toLowerCase()) {
      _showMessage('New name must be different.');
      return;
    }
    if (_exists(newName)) {
      _showMessage('Target name already exists.');
      return;
    }
    await _runJob('packswitch_rename', {
      'old_name': oldName,
      'new_name': newName,
    });
    _renameController.clear();
    await _loadSwitches();
  }

  Future<void> _deleteSwitch() async {
    final name = _selected ?? '';
    if (name.isEmpty) {
      _showMessage('Select a switch to delete.');
      return;
    }
    if (name.toLowerCase() == 'default') {
      _showMessage('Default switch cannot be deleted.');
      return;
    }
    if (_data != null && name == _data!.current) {
      _showMessage('Cannot delete the active switch.');
      return;
    }
    await _runJob('packswitch_delete', {'name': name});
    await _loadSwitches();
  }

  Future<void> _activateSwitch() async {
    final name = _selected ?? '';
    if (name.isEmpty) {
      _showMessage('Select a switch to activate.');
      return;
    }
    await _runJob('packswitch_set', {'name': name});
    await _loadSwitches();
  }

  @override
  Widget build(BuildContext context) {
    final switches = _data?.switches ?? [];
    final current = _data?.current ?? 'default';
    return Scaffold(
      appBar: AppBar(title: const Text('PackSwitch')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 320,
              child: Card(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Text('Switches', style: TextStyle(fontWeight: FontWeight.w600)),
                          const Spacer(),
                          if (_loading)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        itemCount: switches.length,
                        itemBuilder: (context, index) {
                          final name = switches[index];
                          return RadioListTile<String>(
                            value: name,
                            groupValue: _selected,
                            onChanged: (value) {
                              setState(() {
                                _selected = value;
                              });
                            },
                            title: Text(name),
                            secondary: name == current
                                ? const Chip(label: Text('Active'))
                                : null,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ListView(
                children: [
                  _section(
                    title: 'Current',
                    child: Text('Active switch: $current'),
                  ),
                  const SizedBox(height: 12),
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
                          onPressed: _createSwitch,
                          child: const Text('Create'),
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
                            controller: _renameController,
                            decoration: const InputDecoration(
                              labelText: 'New name',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonal(
                          onPressed: _renameSwitch,
                          child: const Text('Rename'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _section(
                    title: 'Actions',
                    child: Row(
                      children: [
                        FilledButton.tonal(
                          onPressed: _activateSwitch,
                          child: const Text('Activate Selected'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: _deleteSwitch,
                          child: const Text('Delete Selected'),
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
}
