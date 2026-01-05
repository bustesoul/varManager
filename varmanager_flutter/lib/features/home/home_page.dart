import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/backend/job_log_controller.dart';
import '../../core/backend/job_runner.dart';
import '../../core/backend/query_params.dart';
import '../../core/models/job_models.dart';
import '../../core/models/var_models.dart';
import '../../core/utils/debounce.dart';
import '../missing_vars/missing_vars_page.dart';
import '../packswitch/packswitch_page.dart';
import '../prepare_saves/prepare_saves_page.dart';
import '../uninstall_vars/uninstall_vars_page.dart';
import '../var_detail/var_detail_page.dart';

final varsQueryProvider = StateProvider<VarsQueryParams>((ref) {
  return VarsQueryParams();
});

final varsListProvider = FutureProvider<VarsListResponse>((ref) async {
  final client = ref.watch(backendClientProvider);
  final query = ref.watch(varsQueryProvider);
  return client.listVars(query);
});

final creatorsProvider = FutureProvider<List<String>>((ref) async {
  final client = ref.watch(backendClientProvider);
  return client.listCreators();
});

final selectedVarsProvider = StateProvider<Set<String>>((ref) {
  return <String>{};
});

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _searchDebounce = Debouncer(const Duration(milliseconds: 250));

  @override
  void dispose() {
    _searchDebounce.dispose();
    super.dispose();
  }

  Future<JobResult<dynamic>> _runJob(String kind,
      {Map<String, dynamic>? args}) async {
    final runner = ref.read(jobRunnerProvider);
    final log = ref.read(jobLogProvider.notifier);
    return runner.runJob(kind, args: args, onLog: log.addLine);
  }

  void _updateQuery(VarsQueryParams Function(VarsQueryParams) updater) {
    ref.read(varsQueryProvider.notifier).update((state) => updater(state));
  }

  @override
  Widget build(BuildContext context) {
    final varsAsync = ref.watch(varsListProvider);
    final selected = ref.watch(selectedVarsProvider);
    final creatorsAsync = ref.watch(creatorsProvider);
    final query = ref.watch(varsQueryProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildToolbar(context, varsAsync),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 240,
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Search var/package',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        _searchDebounce.run(() {
                          _updateQuery((state) => state.copyWith(search: value));
                        });
                      },
                    ),
                  ),
                  creatorsAsync.when(
                    data: (creators) {
                      final options = ['ALL', ...creators];
                      return DropdownButton<String>(
                        value: options.contains(query.creator)
                            ? query.creator
                            : 'ALL',
                        items: options
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(item == 'ALL' ? 'All creators' : item),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          _updateQuery((state) => state.copyWith(creator: value));
                        },
                      );
                    },
                    loading: () => const SizedBox(
                      width: 120,
                      child: LinearProgressIndicator(),
                    ),
                    error: (_, __) => const Text('Creators load failed'),
                  ),
                  DropdownButton<String>(
                    value: query.installed,
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All status')),
                      DropdownMenuItem(value: 'true', child: Text('Installed')),
                      DropdownMenuItem(value: 'false', child: Text('Not installed')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      _updateQuery((state) => state.copyWith(installed: value));
                    },
                  ),
                  Text('Selected ${selected.length}'),
                  TextButton(
                    onPressed: selected.isEmpty
                        ? null
                        : () {
                            ref.read(selectedVarsProvider.notifier).state = {};
                          },
                    child: const Text('Clear selection'),
                  ),
                  TextButton(
                    onPressed: () {
                      ref.read(varsQueryProvider.notifier).state = VarsQueryParams();
                    },
                    child: const Text('Reset filters'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: varsAsync.when(
              data: (data) => _buildList(context, data, selected),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text('Load failed: $err'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context, AsyncValue<VarsListResponse> vars) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          onPressed: () async {
            await _runJob('update_db');
            ref.invalidate(varsListProvider);
          },
          icon: const Icon(Icons.sync),
          label: const Text('Update DB'),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            await _runJob('vam_start');
          },
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start VaM'),
        ),
        OutlinedButton(
          onPressed: () async {
            final result = await _runJob('missing_deps', args: {
              'scope': 'installed',
            });
            _openMissingVars(result);
          },
          child: const Text('Missing deps (installed)'),
        ),
        OutlinedButton(
          onPressed: () async {
            final result = await _runJob('missing_deps', args: {
              'scope': 'all',
            });
            _openMissingVars(result);
          },
          child: const Text('Missing deps (all)'),
        ),
        OutlinedButton(
          onPressed: () async {
            final data = vars.valueOrNull;
            if (data == null) return;
            final names = data.items.map((e) => e.varName).toList();
            final result = await _runJob('missing_deps', args: {
              'scope': 'filtered',
              'var_names': names,
            });
            _openMissingVars(result);
          },
          child: const Text('Missing deps (filtered)'),
        ),
        OutlinedButton(
          onPressed: () async {
            await _runJob('rebuild_links', args: {'include_missing': true});
          },
          child: const Text('Rebuild links'),
        ),
        OutlinedButton(
          onPressed: () async {
            await _runJob('saves_deps');
          },
          child: const Text('Analyze Saves'),
        ),
        OutlinedButton(
          onPressed: () async {
            await _runJob('log_deps');
          },
          child: const Text('Analyze Log'),
        ),
        OutlinedButton(
          onPressed: () async {
            await _runJob('stale_vars');
          },
          child: const Text('Stale Vars'),
        ),
        OutlinedButton(
          onPressed: () async {
            await _runJob('old_version_vars');
          },
          child: const Text('Old Versions'),
        ),
        OutlinedButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PrepareSavesPage()),
            );
          },
          child: const Text('Prepare Saves'),
        ),
        OutlinedButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PackSwitchPage()),
            );
          },
          child: const Text('PackSwitch'),
        ),
      ],
    );
  }

  Widget _buildList(
      BuildContext context, VarsListResponse data, Set<String> selected) {
    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Text('Total ${data.total} items'),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    _updateQuery((state) => state.copyWith(page: 1));
                  },
                  child: const Text('Refresh'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: data.items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = data.items[index];
                final isSelected = selected.contains(item.varName);
                return ListTile(
                  leading: Checkbox(
                    value: isSelected,
                    onChanged: (value) {
                      final next = {...selected};
                      if (value == true) {
                        next.add(item.varName);
                      } else {
                        next.remove(item.varName);
                      }
                      ref.read(selectedVarsProvider.notifier).state = next;
                    },
                  ),
                  title: Text(item.varName),
                  subtitle: Text(
                    '${item.creatorName ?? '-'} - ${item.packageName ?? '-'} - v${item.version ?? '-'}',
                  ),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      Chip(
                        label: Text(item.installed ? 'Installed' : 'Not installed'),
                        backgroundColor: item.installed
                            ? Colors.green.shade100
                            : Colors.grey.shade200,
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => VarDetailPage(varName: item.varName),
                            ),
                          );
                        },
                        child: const Text('Details'),
                      ),
                    ],
                  ),
                  onTap: () {
                    final next = {...selected};
                    if (isSelected) {
                      next.remove(item.varName);
                    } else {
                      next.add(item.varName);
                    }
                    ref.read(selectedVarsProvider.notifier).state = next;
                  },
                );
              },
            ),
          ),
          if (selected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: () async {
                      await _runJob('install_vars', args: {
                        'var_names': selected.toList(),
                        'include_dependencies': true,
                      });
                      ref.invalidate(varsListProvider);
                    },
                    child: const Text('Install Selected'),
                  ),
                  FilledButton.tonal(
                    onPressed: () async {
                      final preview = await _runJob('preview_uninstall', args: {
                        'var_names': selected.toList(),
                        'include_implicated': true,
                      });
                      if (!context.mounted) return;
                      final result = preview.result as Map<String, dynamic>?;
                      if (result == null) return;
                      final confirmed = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => UninstallVarsPage(payload: result),
                        ),
                      );
                      if (confirmed == true) {
                        await _runJob('uninstall_vars', args: {
                          'var_names': selected.toList(),
                          'include_implicated': true,
                        });
                        ref.invalidate(varsListProvider);
                      }
                    },
                    child: const Text('Uninstall Selected'),
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      await _runJob('delete_vars', args: {
                        'var_names': selected.toList(),
                        'include_implicated': true,
                      });
                      ref.invalidate(varsListProvider);
                    },
                    child: const Text('Delete Selected'),
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      final target = await _askText(context, 'Target dir');
                      if (target == null || target.trim().isEmpty) return;
                      await _runJob('links_move', args: {
                        'var_names': selected.toList(),
                        'target_dir': target.trim(),
                      });
                    },
                    child: const Text('Move Links'),
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      final path = await _askText(context, 'Export path',
                          hint: 'installed_vars.txt');
                      if (path == null || path.trim().isEmpty) return;
                      await _runJob('vars_export_installed', args: {
                        'path': path.trim(),
                      });
                    },
                    child: const Text('Export Installed'),
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      final path = await _askText(context, 'Install list path',
                          hint: 'install_list.txt');
                      if (path == null || path.trim().isEmpty) return;
                      await _runJob('vars_install_batch', args: {
                        'path': path.trim(),
                      });
                      ref.invalidate(varsListProvider);
                    },
                    child: const Text('Install from List'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openMissingVars(JobResult<dynamic> result) async {
    final payload = result.result as Map<String, dynamic>?;
    if (payload == null) {
      return;
    }
    final missing = (payload['missing'] as List<dynamic>? ?? [])
        .map((item) => item.toString())
        .toList();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MissingVarsPage(missing: missing),
      ),
    );
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
