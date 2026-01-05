import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/backend/job_log_controller.dart';

class PrepareSavesPage extends ConsumerStatefulWidget {
  const PrepareSavesPage({super.key});

  @override
  ConsumerState<PrepareSavesPage> createState() => _PrepareSavesPageState();
}

class _PrepareSavesPageState extends ConsumerState<PrepareSavesPage> {
  final TextEditingController _outputController = TextEditingController();
  List<String> _missing = [];
  List<String> _installed = [];

  @override
  void dispose() {
    _outputController.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    final runner = ref.read(jobRunnerProvider);
    final log = ref.read(jobLogProvider.notifier);
    final result = await runner.runJob('saves_deps', args: {}, onLog: log.addLine);
    final payload = result.result as Map<String, dynamic>?;
    if (payload == null) return;
    setState(() {
      _missing = (payload['missing'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList();
      _installed = (payload['installed'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList();
    });
  }

  Future<void> _validateOutput() async {
    final path = _outputController.text.trim();
    if (path.isEmpty) return;
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final isEmpty = dir.listSync().isEmpty;
    if (!isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Output folder is not empty.')),
      );
    }
  }

  Future<void> _copyMissing() async {
    if (_missing.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _missing.join('\n')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Prepare Saves')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _outputController,
                        decoration: const InputDecoration(
                          labelText: 'Output folder',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: _validateOutput,
                      child: const Text('Validate Output'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _analyze,
                      child: const Text('Analyze'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _copyMissing,
                      child: const Text('Copy Missing'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _listPanel('Missing Dependencies', _missing),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _listPanel('Installed', _installed),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _listPanel(String title, List<String> items) {
    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Text(title),
                const Spacer(),
                Text('${items.length} items'),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) => ListTile(
                title: Text(items[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
