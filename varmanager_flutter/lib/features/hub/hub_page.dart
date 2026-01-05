import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/backend/job_log_controller.dart';

class HubPage extends ConsumerStatefulWidget {
  const HubPage({super.key});

  @override
  ConsumerState<HubPage> createState() => _HubPageState();
}

class _HubPageState extends ConsumerState<HubPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _creatorController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  final TextEditingController _payTypeController = TextEditingController();
  final TextEditingController _hostedController = TextEditingController();
  int _page = 1;
  int _perPage = 20;
  List<Map<String, dynamic>> _resources = [];
  int _totalFound = 0;
  final List<String> _downloadList = [];

  @override
  void dispose() {
    _searchController.dispose();
    _categoryController.dispose();
    _creatorController.dispose();
    _tagsController.dispose();
    _payTypeController.dispose();
    _hostedController.dispose();
    super.dispose();
  }

  Future<void> _runJob(String kind, Map<String, dynamic> args) async {
    final runner = ref.read(jobRunnerProvider);
    final log = ref.read(jobLogProvider.notifier);
    await runner.runJob(kind, args: args, onLog: log.addLine);
  }

  Future<void> _refreshResources() async {
    final runner = ref.read(jobRunnerProvider);
    final log = ref.read(jobLogProvider.notifier);
    final result = await runner.runJob(
      'hub_resources',
      args: {
        'perpage': _perPage,
        'location': _hostedController.text.trim(),
        'paytype': _payTypeController.text.trim(),
        'category': _categoryController.text.trim(),
        'username': _creatorController.text.trim(),
        'tags': _tagsController.text.trim(),
        'search': _searchController.text.trim(),
        'sort': 'updated',
        'page': _page,
      },
      onLog: log.addLine,
    );
    final payload = result.result as Map<String, dynamic>?;
    if (payload == null) return;
    final resources = (payload['resources'] as List<dynamic>? ?? [])
        .map((item) => (item as Map).cast<String, dynamic>())
        .toList();
    final pagination = payload['pagination'] as Map<String, dynamic>? ?? {};
    final total = int.tryParse(pagination['total_found']?.toString() ?? '') ??
        resources.length;
    if (!mounted) return;
    setState(() {
      _resources = resources;
      _totalFound = total;
    });
  }

  Future<void> _scanMissing() async {
    final runner = ref.read(jobRunnerProvider);
    final log = ref.read(jobLogProvider.notifier);
    final result = await runner.runJob('hub_missing_scan', args: {}, onLog: log.addLine);
    final payload = result.result as Map<String, dynamic>?;
    if (payload == null) return;
    _mergeDownloads(payload);
  }

  Future<void> _scanUpdates() async {
    final runner = ref.read(jobRunnerProvider);
    final log = ref.read(jobLogProvider.notifier);
    final result = await runner.runJob('hub_updates_scan', args: {}, onLog: log.addLine);
    final payload = result.result as Map<String, dynamic>?;
    if (payload == null) return;
    _mergeDownloads(payload);
  }

  void _mergeDownloads(Map<String, dynamic> payload) {
    final direct = payload['download_urls'] as Map<String, dynamic>? ?? {};
    final noVersion = payload['download_urls_no_version'] as Map<String, dynamic>? ?? {};
    final urls = <String>[];
    for (final entry in direct.entries) {
      final value = entry.value?.toString() ?? '';
      if (value.isNotEmpty) urls.add(value);
    }
    for (final entry in noVersion.entries) {
      final value = entry.value?.toString() ?? '';
      if (value.isNotEmpty) urls.add(value);
    }
    setState(() {
      _downloadList.addAll(urls);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          SizedBox(
            width: 320,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ListView(
                  children: [
                    const Text('Filters & Actions',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    _field(_searchController, 'Search'),
                    _field(_categoryController, 'Category'),
                    _field(_creatorController, 'Creator'),
                    _field(_tagsController, 'Tags'),
                    _field(_payTypeController, 'PayType'),
                    _field(_hostedController, 'Hosted'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButton<int>(
                            value: _perPage,
                            items: const [20, 48]
                                .map((value) => DropdownMenuItem(
                                      value: value,
                                      child: Text('Per page $value'),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _perPage = value;
                              });
                            },
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              if (_page > 1) _page -= 1;
                            });
                            _refreshResources();
                          },
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Text('$_page'),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _page += 1;
                            });
                            _refreshResources();
                          },
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _refreshResources,
                      child: const Text('Refresh'),
                    ),
                    OutlinedButton(
                      onPressed: _scanMissing,
                      child: const Text('Scan Missing'),
                    ),
                    OutlinedButton(
                      onPressed: _scanUpdates,
                      child: const Text('Scan Updates'),
                    ),
                    const Divider(height: 24),
                    const Text('Download List',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text('Total ${_downloadList.length} links'),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _downloadList.isEmpty
                          ? null
                          : () async {
                              await _runJob('hub_download_all',
                                  {'urls': _downloadList});
                            },
                      child: const Text('Download All'),
                    ),
                    OutlinedButton(
                      onPressed: _downloadList.isEmpty
                          ? null
                          : () async {
                              await Clipboard.setData(
                                ClipboardData(text: _downloadList.join('\n')),
                              );
                            },
                      child: const Text('Copy Links'),
                    ),
                    OutlinedButton(
                      onPressed: _downloadList.isEmpty
                          ? null
                          : () {
                              setState(() {
                                _downloadList.clear();
                              });
                            },
                      child: const Text('Clear List'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Card(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Text('Resources ($_totalFound)'),
                        const Spacer(),
                        TextButton(
                          onPressed: _refreshResources,
                          child: const Text('Refresh'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      itemCount: _resources.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final resource = _resources[index];
                        final title = resource['title']?.toString() ?? 'Untitled';
                        final username =
                            resource['username']?.toString() ?? 'unknown';
                        final type = resource['type']?.toString() ?? '-';
                        final resourceId =
                            resource['resource_id']?.toString() ??
                                resource['id']?.toString() ??
                                '';
                        return ListTile(
                          title: Text(title),
                          subtitle: Text('$username - $type'),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              TextButton(
                                onPressed: resourceId.isEmpty
                                    ? null
                                    : () async {
                                        final runner = ref.read(jobRunnerProvider);
                                        final log =
                                            ref.read(jobLogProvider.notifier);
                                        final result = await runner.runJob(
                                          'hub_resource_detail',
                                          args: {'resource_id': resourceId},
                                          onLog: log.addLine,
                                        );
                                        final payload =
                                            result.result as Map<String, dynamic>?;
                                        if (payload == null) return;
                                        _mergeDownloads(payload);
                                      },
                                child: const Text('Add Downloads'),
                              ),
                              TextButton(
                                onPressed: resourceId.isEmpty
                                    ? null
                                    : () async {
                                        await _runJob('open_url', {
                                          'url':
                                              'https://hub.virtamate.com/resources/$resourceId/',
                                        });
                                      },
                                child: const Text('Open Page'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
