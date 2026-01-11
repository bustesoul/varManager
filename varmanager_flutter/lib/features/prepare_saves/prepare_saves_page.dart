import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/backend/job_log_controller.dart';
import '../../core/models/extra_models.dart';
import '../../l10n/l10n.dart';

class PrepareSavesPage extends ConsumerStatefulWidget {
  const PrepareSavesPage({super.key});

  @override
  ConsumerState<PrepareSavesPage> createState() => _PrepareSavesPageState();
}

class _PrepareSavesPageState extends ConsumerState<PrepareSavesPage> {
  final TextEditingController _outputController = TextEditingController();
  List<String> _missing = [];
  List<String> _installed = [];
  List<SavesTreeGroup> _groups = [];
  final Set<String> _selectedPaths = {};
  bool _loadingTree = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadTree);
  }

  @override
  void dispose() {
    _outputController.dispose();
    super.dispose();
  }

  Future<void> _loadTree() async {
    if (_loadingTree) return;
    setState(() {
      _loadingTree = true;
    });
    try {
      final client = ref.read(backendClientProvider);
      final response = await client.getSavesTree();
      if (!mounted) return;
      final paths = <String>{};
      for (final group in response.groups) {
        for (final item in group.items) {
          paths.add(item.path);
        }
      }
      setState(() {
        _groups = response.groups;
        _selectedPaths
          ..clear()
          ..addAll(paths);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingTree = false;
        });
      }
    }
  }

  Future<void> _analyze() async {
    final runner = ref.read(jobRunnerProvider);
    final log = ref.read(jobLogProvider.notifier);
    final result = await runner.runJob('saves_deps', args: {}, onLog: log.addEntry);
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
    final client = ref.read(backendClientProvider);
    final response = await client.validateOutputDir(path);
    if (!mounted) return;
    final l10n = context.l10n;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(response.ok
            ? l10n.outputFolderReady
            : response.reason ?? l10n.outputFolderValidationFailed),
      ),
    );
  }

  Future<void> _copyMissing() async {
    if (_missing.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _missing.join('\n')));
  }

  Future<void> _pickOutputDir() async {
    final path = await getDirectoryPath();
    if (path == null) return;
    setState(() {
      _outputController.text = path;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.prepareSavesTitle)),
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
                        decoration: InputDecoration(
                          labelText: l10n.outputFolderLabel,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _pickOutputDir,
                      child: Text(l10n.commonBrowse),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _validateOutput,
                      child: Text(l10n.validateOutputLabel),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _analyze,
                      child: Text(l10n.commonAnalyze),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _copyMissing,
                      child: Text(l10n.copyMissingLabel),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: 360,
                    child: _buildTreePanel(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _listPanel(l10n.missingDependenciesTitle, _missing),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _listPanel(l10n.statusInstalled, _installed),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTreePanel() {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.savesTreeTitle,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (_loadingTree) const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 8),
            Expanded(
              child: _groups.isEmpty
                  ? Center(child: Text(l10n.noSavesFound))
                  : ListView(
                      children: _groups.map(_buildGroupNode).toList(),
                    ),
            ),
            const SizedBox(height: 8),
            Text(l10n.selectedFilesCount(_selectedPaths.length)),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupNode(SavesTreeGroup group) {
    final state = _groupState(group);
    return ExpansionTile(
      title: Row(
        children: [
          Checkbox(
            tristate: true,
            value: state,
            onChanged: (value) => _toggleGroup(group, value),
          ),
          Expanded(child: Text(group.title)),
        ],
      ),
      children: group.items
          .map(
            (item) => CheckboxListTile(
              value: _selectedPaths.contains(item.path),
              onChanged: (value) => _toggleItem(item.path, value ?? false),
              title: Text(item.name),
              subtitle: Text(item.path, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
    );
  }

  bool? _groupState(SavesTreeGroup group) {
    if (group.items.isEmpty) return false;
    final selected = group.items.where((item) => _selectedPaths.contains(item.path));
    if (selected.length == group.items.length) return true;
    if (selected.isEmpty) return false;
    return null;
  }

  void _toggleGroup(SavesTreeGroup group, bool? value) {
    final selected = value ?? false;
    setState(() {
      for (final item in group.items) {
        if (selected) {
          _selectedPaths.add(item.path);
        } else {
          _selectedPaths.remove(item.path);
        }
      }
    });
  }

  void _toggleItem(String path, bool selected) {
    setState(() {
      if (selected) {
        _selectedPaths.add(path);
      } else {
        _selectedPaths.remove(path);
      }
    });
  }

  Widget _listPanel(String title, List<String> items) {
    final l10n = context.l10n;
    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Text(title),
                const Spacer(),
                Text(l10n.itemsCount(items.length)),
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
