import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/backend/job_log_controller.dart';

class MissingVarsPage extends ConsumerStatefulWidget {
  const MissingVarsPage({super.key, required this.missing});

  final List<String> missing;

  @override
  ConsumerState<MissingVarsPage> createState() => _MissingVarsPageState();
}

class _MissingVarsPageState extends ConsumerState<MissingVarsPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();
  String? _selectedVar;
  String _creatorFilter = 'ALL';
  Map<String, String> _linkMap = {};
  Map<String, String> _downloadUrls = {};

  List<String> get _filtered {
    final search = _searchController.text.trim().toLowerCase();
    return widget.missing.where((varName) {
      if (_creatorFilter != 'ALL' && !varName.startsWith('$_creatorFilter.')) {
        return false;
      }
      if (search.isEmpty) {
        return true;
      }
      return varName.toLowerCase().contains(search);
    }).toList();
  }

  Future<void> _runJob(String kind, Map<String, dynamic> args) async {
    final runner = ref.read(jobRunnerProvider);
    final log = ref.read(jobLogProvider.notifier);
    await runner.runJob(kind, args: args, onLog: log.addLine);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final creators = widget.missing
        .map((e) => e.split('.').first)
        .toSet()
        .toList()
      ..sort();
    final filtered = _filtered;

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
                              onChanged: (_) => setState(() {}),
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
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final name = filtered[index];
                          final link = _linkMap[name];
                          final downloadable = _downloadUrls.containsKey(name);
                          return ListTile(
                            title: Text(name),
                            subtitle: Text(link == null ? 'No link set' : 'Link to: $link'),
                            trailing: downloadable
                                ? const Icon(Icons.cloud_download,
                                    color: Colors.green)
                                : const Icon(Icons.block, color: Colors.grey),
                            selected: _selectedVar == name,
                            onTap: () {
                              setState(() {
                                _selectedVar = name;
                                _linkController.text = link ?? '';
                              });
                            },
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
              width: 320,
              child: Column(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Actions', style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _linkController,
                            decoration: const InputDecoration(
                              labelText: 'Link To',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: _selectedVar == null
                                ? null
                                : () {
                                    setState(() {
                                      _linkMap[_selectedVar!] =
                                          _linkController.text.trim();
                                    });
                                  },
                            child: const Text('Set Link'),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: () async {
                              await _fetchDownload();
                            },
                            child: const Text('Fetch Downloads'),
                          ),
                          OutlinedButton(
                            onPressed: () async {
                              final urls = _downloadUrls.values.toSet().toList();
                              if (urls.isEmpty) return;
                              await _runJob('hub_download_all', {'urls': urls});
                            },
                            child: const Text('Download All'),
                          ),
                          OutlinedButton(
                            onPressed: () async {
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
                            },
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchDownload() async {
    final runner = ref.read(jobRunnerProvider);
    final log = ref.read(jobLogProvider.notifier);
    final result = await runner.runJob(
      'hub_find_packages',
      args: {
        'packages': widget.missing,
      },
      onLog: log.addLine,
    );
    final payload = result.result as Map<String, dynamic>?;
    if (payload == null) return;
    final urls = <String, String>{};
    final direct = payload['download_urls'] as Map<String, dynamic>? ?? {};
    final noVersion =
        payload['download_urls_no_version'] as Map<String, dynamic>? ?? {};
    for (final entry in direct.entries) {
      final value = entry.value?.toString() ?? '';
      if (value.isNotEmpty) {
        urls[entry.key] = value;
      }
    }
    for (final entry in noVersion.entries) {
      if (!urls.containsKey(entry.key)) {
        final value = entry.value?.toString() ?? '';
        if (value.isNotEmpty) {
          urls[entry.key] = value;
        }
      }
    }
    setState(() {
      _downloadUrls = urls;
    });
  }

  Future<void> _saveMap() async {
    final file = File('missing_link_map.json');
    await file.writeAsString(jsonEncode(_linkMap));
  }

  Future<void> _loadMap() async {
    final file = File('missing_link_map.json');
    if (!await file.exists()) return;
    final raw = await file.readAsString();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    setState(() {
      _linkMap = json.map((key, value) => MapEntry(key, value.toString()));
    });
  }

  Future<String?> _askText(BuildContext context, String title,
      {String hint = ''}) {
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
}
