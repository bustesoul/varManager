import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../app/providers.dart';
import '../../core/backend/backend_client.dart';
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

class PreviewItem {
  PreviewItem({
    required this.varName,
    required this.atomType,
    required this.previewPic,
    required this.scenePath,
    required this.isPreset,
    required this.isLoadable,
    required this.installed,
  });

  final String varName;
  final String atomType;
  final String? previewPic;
  final String scenePath;
  final bool isPreset;
  final bool isLoadable;
  final bool installed;
}

final previewItemsProvider = FutureProvider<List<PreviewItem>>((ref) async {
  final selected = ref.watch(selectedVarsProvider);
  if (selected.isEmpty) {
    return [];
  }
  final client = ref.watch(backendClientProvider);
  final futures = selected.map((name) async {
    try {
      final detail = await client.getVarDetail(name);
      final installed = detail.varInfo.installed;
      return detail.scenes
          .map((scene) => PreviewItem(
                varName: detail.varInfo.varName,
                atomType: scene.atomType,
                previewPic: scene.previewPic,
                scenePath: scene.scenePath,
                isPreset: scene.isPreset,
                isLoadable: scene.isLoadable,
                installed: installed,
              ))
          .toList();
    } catch (_) {
      return <PreviewItem>[];
    }
  }).toList();
  final results = await Future.wait(futures);
  return results.expand((items) => items).toList();
});

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _searchDebounce = Debouncer(const Duration(milliseconds: 250));
  final _filterDebounce = Debouncer(const Duration(milliseconds: 300));
  final TextEditingController _packageController = TextEditingController();
  final TextEditingController _versionController = TextEditingController();
  final TextEditingController _minSizeController = TextEditingController();
  final TextEditingController _maxSizeController = TextEditingController();
  final TextEditingController _minDepController = TextEditingController();
  final TextEditingController _maxDepController = TextEditingController();
  bool _showAdvancedFilters = false;
  String _previewType = 'all';
  bool _previewLoadableOnly = true;
  int _previewPerPage = 24;
  int _previewPage = 1;
  int? _previewSelectedIndex;

  @override
  void initState() {
    super.initState();
    ref.listen<AsyncValue<List<PreviewItem>>>(previewItemsProvider,
        (previous, next) {
      next.whenData((items) {
        if (!mounted) return;
        setState(() {
          _previewPage = 1;
          _previewSelectedIndex = items.isEmpty ? null : 0;
        });
      });
    });
  }

  @override
  void dispose() {
    _searchDebounce.dispose();
    _filterDebounce.dispose();
    _packageController.dispose();
    _versionController.dispose();
    _minSizeController.dispose();
    _maxSizeController.dispose();
    _minDepController.dispose();
    _maxDepController.dispose();
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
    final previewAsync = ref.watch(previewItemsProvider);
    _syncController(_packageController, query.package);
    _syncController(_versionController, query.version);
    _syncController(_minSizeController, _formatNumber(query.minSize));
    _syncController(_maxSizeController, _formatNumber(query.maxSize));
    _syncController(_minDepController, _formatInt(query.minDependency));
    _syncController(_maxDepController, _formatInt(query.maxDependency));

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
                          _updateQuery(
                            (state) => state.copyWith(page: 1, search: value),
                          );
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
                          _updateQuery(
                            (state) => state.copyWith(page: 1, creator: value),
                          );
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
                      _updateQuery(
                        (state) => state.copyWith(page: 1, installed: value),
                      );
                    },
                  ),
                  DropdownButton<String>(
                    value: query.sort,
                    items: const [
                      DropdownMenuItem(value: 'meta_date', child: Text('Meta date')),
                      DropdownMenuItem(value: 'var_date', child: Text('Var date')),
                      DropdownMenuItem(value: 'var_name', child: Text('Var name')),
                      DropdownMenuItem(value: 'creator', child: Text('Creator')),
                      DropdownMenuItem(value: 'package', child: Text('Package')),
                      DropdownMenuItem(value: 'size', child: Text('Size')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      _updateQuery(
                        (state) => state.copyWith(page: 1, sort: value),
                      );
                    },
                  ),
                  DropdownButton<String>(
                    value: query.order,
                    items: const [
                      DropdownMenuItem(value: 'desc', child: Text('Desc')),
                      DropdownMenuItem(value: 'asc', child: Text('Asc')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      _updateQuery(
                        (state) => state.copyWith(page: 1, order: value),
                      );
                    },
                  ),
                  DropdownButton<int>(
                    value: query.perPage,
                    items: const [25, 50, 100, 200]
                        .map((value) => DropdownMenuItem(
                              value: value,
                              child: Text('Per page $value'),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      _updateQuery(
                        (state) => state.copyWith(page: 1, perPage: value),
                      );
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
                      _packageController.clear();
                      _versionController.clear();
                      _minSizeController.clear();
                      _maxSizeController.clear();
                      _minDepController.clear();
                      _maxDepController.clear();
                      setState(() {
                        _showAdvancedFilters = false;
                      });
                    },
                    child: const Text('Reset filters'),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showAdvancedFilters = !_showAdvancedFilters;
                      });
                    },
                    child: Text(
                      _showAdvancedFilters ? 'Hide advanced' : 'Advanced filters',
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_showAdvancedFilters) ...[
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 220,
                      child: TextField(
                        controller: _packageController,
                        decoration: const InputDecoration(
                          labelText: 'Package filter',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          _filterDebounce.run(() {
                            _updateQuery(
                              (state) => state.copyWith(
                                page: 1,
                                package: value.trim(),
                              ),
                            );
                          });
                        },
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: TextField(
                        controller: _versionController,
                        decoration: const InputDecoration(
                          labelText: 'Version filter',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          _filterDebounce.run(() {
                            _updateQuery(
                              (state) => state.copyWith(
                                page: 1,
                                version: value.trim(),
                              ),
                            );
                          });
                        },
                      ),
                    ),
                    DropdownButton<String>(
                      value: query.disabled,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All enabled')),
                        DropdownMenuItem(value: 'false', child: Text('Enabled only')),
                        DropdownMenuItem(value: 'true', child: Text('Disabled only')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        _updateQuery(
                          (state) => state.copyWith(page: 1, disabled: value),
                        );
                      },
                    ),
                    SizedBox(
                      width: 140,
                      child: TextField(
                        controller: _minSizeController,
                        decoration: const InputDecoration(
                          labelText: 'Min size (MB)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          _filterDebounce.run(() {
                            _updateQuery(
                              (state) => state.copyWith(
                                page: 1,
                                minSize: _parseDouble(value),
                              ),
                            );
                          });
                        },
                      ),
                    ),
                    SizedBox(
                      width: 140,
                      child: TextField(
                        controller: _maxSizeController,
                        decoration: const InputDecoration(
                          labelText: 'Max size (MB)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          _filterDebounce.run(() {
                            _updateQuery(
                              (state) => state.copyWith(
                                page: 1,
                                maxSize: _parseDouble(value),
                              ),
                            );
                          });
                        },
                      ),
                    ),
                    SizedBox(
                      width: 140,
                      child: TextField(
                        controller: _minDepController,
                        decoration: const InputDecoration(
                          labelText: 'Min deps',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          _filterDebounce.run(() {
                            _updateQuery(
                              (state) => state.copyWith(
                                page: 1,
                                minDependency: _parseInt(value),
                              ),
                            );
                          });
                        },
                      ),
                    ),
                    SizedBox(
                      width: 140,
                      child: TextField(
                        controller: _maxDepController,
                        decoration: const InputDecoration(
                          labelText: 'Max deps',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          _filterDebounce.run(() {
                            _updateQuery(
                              (state) => state.copyWith(
                                page: 1,
                                maxDependency: _parseInt(value),
                              ),
                            );
                          });
                        },
                      ),
                    ),
                    _presenceFilter('Scenes', query.hasScene,
                        (value) => _updateQuery(
                            (state) => state.copyWith(page: 1, hasScene: value))),
                    _presenceFilter('Looks', query.hasLook,
                        (value) => _updateQuery(
                            (state) => state.copyWith(page: 1, hasLook: value))),
                    _presenceFilter('Clothing', query.hasCloth,
                        (value) => _updateQuery(
                            (state) => state.copyWith(page: 1, hasCloth: value))),
                    _presenceFilter('Hair', query.hasHair,
                        (value) => _updateQuery(
                            (state) => state.copyWith(page: 1, hasHair: value))),
                    _presenceFilter('Skin', query.hasSkin,
                        (value) => _updateQuery(
                            (state) => state.copyWith(page: 1, hasSkin: value))),
                    _presenceFilter('Pose', query.hasPose,
                        (value) => _updateQuery(
                            (state) => state.copyWith(page: 1, hasPose: value))),
                    _presenceFilter('Morphs', query.hasMorph,
                        (value) => _updateQuery(
                            (state) => state.copyWith(page: 1, hasMorph: value))),
                    _presenceFilter('Plugins', query.hasPlugin,
                        (value) => _updateQuery(
                            (state) => state.copyWith(page: 1, hasPlugin: value))),
                    _presenceFilter('Scripts', query.hasScript,
                        (value) => _updateQuery(
                            (state) => state.copyWith(page: 1, hasScript: value))),
                    _presenceFilter('Assets', query.hasAsset,
                        (value) => _updateQuery(
                            (state) => state.copyWith(page: 1, hasAsset: value))),
                    _presenceFilter('Textures', query.hasTexture,
                        (value) => _updateQuery(
                            (state) => state.copyWith(page: 1, hasTexture: value))),
                    _presenceFilter('SubScene', query.hasSubScene,
                        (value) => _updateQuery(
                            (state) => state.copyWith(page: 1, hasSubScene: value))),
                    _presenceFilter('Appearance', query.hasAppearance,
                        (value) => _updateQuery((state) =>
                            state.copyWith(page: 1, hasAppearance: value))),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: varsAsync.when(
              data: (data) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 1000;
                    final list = _buildList(context, data, selected, query);
                    final preview = _buildPreviewPanel(
                      context,
                      previewAsync,
                      selected.isNotEmpty,
                    );
                    if (wide) {
                      return Row(
                        children: [
                          Expanded(flex: 3, child: list),
                          const SizedBox(width: 12),
                          Expanded(flex: 2, child: preview),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        Expanded(child: list),
                        const SizedBox(height: 12),
                        SizedBox(height: 360, child: preview),
                      ],
                    );
                  },
                );
              },
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
            final query = ref.read(varsQueryProvider);
            final names = await _fetchFilteredVarNames(query);
            if (names.isEmpty) return;
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
          onPressed: () async {
            await _runJob('fix_previews');
          },
          child: const Text('Fix Preview'),
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
      BuildContext context,
      VarsListResponse data,
      Set<String> selected,
      VarsQueryParams query) {
    final totalPages =
        data.total == 0 ? 1 : (data.total + query.perPage - 1) ~/ query.perPage;
    if (data.total > 0 && data.page > totalPages) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateQuery((state) => state.copyWith(page: totalPages));
      });
    }
    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Text('Total ${data.total} items'),
                const Spacer(),
                Text('Page ${data.page}/$totalPages'),
                IconButton(
                  onPressed: data.page > 1
                      ? () {
                          _updateQuery((state) => state.copyWith(page: 1));
                        }
                      : null,
                  icon: const Icon(Icons.first_page),
                ),
                IconButton(
                  onPressed: data.page > 1
                      ? () {
                          _updateQuery(
                            (state) => state.copyWith(page: data.page - 1),
                          );
                        }
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton(
                  onPressed: data.page < totalPages
                      ? () {
                          _updateQuery(
                            (state) => state.copyWith(page: data.page + 1),
                          );
                        }
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
                IconButton(
                  onPressed: data.page < totalPages
                      ? () {
                          _updateQuery((state) => state.copyWith(page: totalPages));
                        }
                      : null,
                  icon: const Icon(Icons.last_page),
                ),
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

  Widget _buildPreviewPanel(
    BuildContext context,
    AsyncValue<List<PreviewItem>> previewAsync,
    bool hasSelection,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: previewAsync.when(
          data: (items) {
            if (items.isEmpty) {
              final message = hasSelection
                  ? 'No preview entries for selected vars'
                  : 'Select vars to load previews';
              return Center(child: Text(message));
            }
            final filtered = items.where((item) {
              if (_previewLoadableOnly &&
                  !(item.isPreset || item.atomType == 'scenes')) {
                return false;
              }
              if (_previewType != 'all' && item.atomType != _previewType) {
                return false;
              }
              return true;
            }).toList();
            final totalItems = filtered.length;
            final totalPages = totalItems == 0
                ? 1
                : (totalItems + _previewPerPage - 1) ~/ _previewPerPage;
            final currentPage = _previewPage.clamp(1, totalPages);
            final selectedIndex = totalItems == 0
                ? null
                : (_previewSelectedIndex != null &&
                        _previewSelectedIndex! < totalItems)
                    ? _previewSelectedIndex
                    : 0;
            if (_previewPage != currentPage) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                setState(() {
                  _previewPage = currentPage;
                });
              });
            }
            if (selectedIndex != _previewSelectedIndex) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                setState(() {
                  _previewSelectedIndex = selectedIndex;
                });
              });
            }
            final startIndex = (currentPage - 1) * _previewPerPage;
            final pageItems = filtered
                .skip(startIndex)
                .take(_previewPerPage)
                .toList();
            final selectedItem = (selectedIndex != null && totalItems > 0)
                ? filtered[selectedIndex]
                : null;
            final client = ref.read(backendClientProvider);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    DropdownButton<String>(
                      value: _previewType,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All types')),
                        DropdownMenuItem(value: 'scenes', child: Text('Scenes')),
                        DropdownMenuItem(value: 'looks', child: Text('Looks')),
                        DropdownMenuItem(
                            value: 'clothing', child: Text('Clothing')),
                        DropdownMenuItem(
                            value: 'hairstyle', child: Text('Hairstyle')),
                        DropdownMenuItem(value: 'assets', child: Text('Assets')),
                        DropdownMenuItem(value: 'morphs', child: Text('Morphs')),
                        DropdownMenuItem(value: 'pose', child: Text('Pose')),
                        DropdownMenuItem(value: 'skin', child: Text('Skin')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _previewType = value;
                          _previewPage = 1;
                          _previewSelectedIndex = 0;
                        });
                      },
                    ),
                    FilterChip(
                      label: const Text('Loadable'),
                      selected: _previewLoadableOnly,
                      onSelected: (value) {
                        setState(() {
                          _previewLoadableOnly = value;
                          _previewPage = 1;
                          _previewSelectedIndex = 0;
                        });
                      },
                    ),
                    DropdownButton<int>(
                      value: _previewPerPage,
                      items: const [12, 24, 36, 48]
                          .map((value) => DropdownMenuItem(
                                value: value,
                                child: Text('Per page $value'),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _previewPerPage = value;
                          _previewPage = 1;
                          _previewSelectedIndex = 0;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    Text('Items $totalItems'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton(
                      onPressed: totalItems == 0
                          ? null
                          : () => _selectPreviewIndex(0, totalItems),
                      icon: const Icon(Icons.first_page),
                    ),
                    IconButton(
                      onPressed: totalItems == 0
                          ? null
                          : () => _selectPreviewIndex(
                              (selectedIndex ?? 0) - 1, totalItems),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text(
                      selectedIndex == null
                          ? 'Item 0/0'
                          : 'Item ${selectedIndex + 1}/$totalItems',
                    ),
                    IconButton(
                      onPressed: totalItems == 0
                          ? null
                          : () => _selectPreviewIndex(
                              (selectedIndex ?? 0) + 1, totalItems),
                      icon: const Icon(Icons.chevron_right),
                    ),
                    IconButton(
                      onPressed: totalItems == 0
                          ? null
                          : () => _selectPreviewIndex(
                              totalItems - 1, totalItems),
                      icon: const Icon(Icons.last_page),
                    ),
                    const Spacer(),
                    Text('Page $currentPage/$totalPages'),
                    IconButton(
                      onPressed: currentPage > 1
                          ? () => _setPreviewPage(1, totalItems)
                          : null,
                      icon: const Icon(Icons.first_page),
                    ),
                    IconButton(
                      onPressed: currentPage > 1
                          ? () => _setPreviewPage(currentPage - 1, totalItems)
                          : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    IconButton(
                      onPressed: currentPage < totalPages
                          ? () => _setPreviewPage(currentPage + 1, totalItems)
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                    IconButton(
                      onPressed: currentPage < totalPages
                          ? () => _setPreviewPage(totalPages, totalItems)
                          : null,
                      icon: const Icon(Icons.last_page),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Expanded(
                  child: _buildPreviewGrid(
                    client: client,
                    items: pageItems,
                    startIndex: startIndex,
                    selectedIndex: selectedIndex,
                    totalItems: totalItems,
                  ),
                ),
                const Divider(height: 16),
                SizedBox(
                  height: 180,
                  child: _buildPreviewDetail(context, client, selectedItem),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Preview load failed: $err')),
        ),
      ),
    );
  }

  Widget _buildPreviewGrid({
    required BackendClient client,
    required List<PreviewItem> items,
    required int startIndex,
    required int? selectedIndex,
    required int totalItems,
  }) {
    if (items.isEmpty) {
      return const Center(child: Text('No preview items'));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount =
            (constraints.maxWidth / 140).floor().clamp(2, 6).toInt();
        return GridView.builder(
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.85,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            final globalIndex = startIndex + index;
            final isSelected = selectedIndex == globalIndex;
            final previewPath = _previewPath(item);
            return InkWell(
              onTap: () => _selectPreviewIndex(globalIndex, totalItems),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.shade300,
                          width: isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: previewPath == null
                            ? Container(
                                color: Colors.grey.shade200,
                                alignment: Alignment.center,
                                child: const Icon(Icons.image_not_supported),
                              )
                            : Image.network(
                                client.previewUrl(
                                  root: 'varspath',
                                  path: previewPath,
                                ),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.grey.shade200,
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.broken_image),
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _sceneTitle(item),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPreviewDetail(
    BuildContext context,
    BackendClient client,
    PreviewItem? item,
  ) {
    if (item == null) {
      return const Center(child: Text('Select a preview'));
    }
    final previewPath = _previewPath(item);
    return Row(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: previewPath == null
                ? Container(
                    color: Colors.grey.shade200,
                    alignment: Alignment.center,
                    child: const Icon(Icons.image_not_supported),
                  )
                : Image.network(
                    client.previewUrl(root: 'varspath', path: previewPath),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey.shade200,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image),
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.varName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text('${_sceneTitle(item)} (${item.atomType})'),
              const SizedBox(height: 4),
              Text(
                item.scenePath,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () => _togglePreviewInstall(context, item),
                    icon: Icon(
                      item.installed ? Icons.delete_outline : Icons.download,
                    ),
                    label: Text(item.installed ? 'Uninstall' : 'Install'),
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      final jobArgs = {'var_name': item.varName};
                      await _runJob('vars_locate', args: jobArgs);
                    },
                    child: const Text('Locate'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _selectPreviewIndex(int index, int totalItems) {
    if (totalItems <= 0) return;
    final next = index.clamp(0, totalItems - 1);
    setState(() {
      _previewSelectedIndex = next;
      _previewPage = (next ~/ _previewPerPage) + 1;
    });
  }

  void _setPreviewPage(int page, int totalItems) {
    if (totalItems <= 0) {
      setState(() {
        _previewPage = 1;
        _previewSelectedIndex = null;
      });
      return;
    }
    final totalPages = (totalItems + _previewPerPage - 1) ~/ _previewPerPage;
    final nextPage = page.clamp(1, totalPages);
    final nextIndex = ((nextPage - 1) * _previewPerPage).clamp(0, totalItems - 1);
    setState(() {
      _previewPage = nextPage;
      _previewSelectedIndex = nextIndex;
    });
  }

  void _syncController(TextEditingController controller, String value) {
    if (controller.text != value) {
      controller.text = value;
      controller.selection = TextSelection.fromPosition(
        TextPosition(offset: controller.text.length),
      );
    }
  }

  String _formatNumber(double? value) {
    if (value == null) return '';
    return value.toString();
  }

  String _formatInt(int? value) {
    if (value == null) return '';
    return value.toString();
  }

  double? _parseDouble(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed);
  }

  int? _parseInt(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return int.tryParse(trimmed);
  }

  Widget _presenceFilter(
      String label, String value, ValueChanged<String> onChanged) {
    return DropdownButton<String>(
      value: value,
      items: const [
        DropdownMenuItem(value: 'all', child: Text('All')),
        DropdownMenuItem(value: 'true', child: Text('Has')),
        DropdownMenuItem(value: 'false', child: Text('None')),
      ],
      onChanged: (next) {
        if (next == null) return;
        onChanged(next);
      },
      underline: const SizedBox.shrink(),
      hint: Text(label),
    );
  }

  String? _previewPath(PreviewItem item) {
    if (item.previewPic == null || item.previewPic!.isEmpty) {
      return null;
    }
    return '___PreviewPics___/${item.atomType}/${item.varName}/${item.previewPic}';
  }

  String _sceneTitle(PreviewItem item) {
    final title = p.basenameWithoutExtension(item.scenePath);
    if (title.isEmpty) {
      return '${item.atomType}_${item.varName}';
    }
    return title;
  }

  Future<void> _togglePreviewInstall(
      BuildContext context, PreviewItem item) async {
    if (item.installed) {
      final preview = await _runJob('preview_uninstall', args: {
        'var_names': [item.varName],
        'include_implicated': true,
      });
      if (!context.mounted) return;
      final payload = preview.result as Map<String, dynamic>?;
      if (payload == null) return;
      final confirmed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => UninstallVarsPage(payload: payload),
        ),
      );
      if (confirmed == true) {
        await _runJob('uninstall_vars', args: {
          'var_names': [item.varName],
          'include_implicated': true,
        });
      } else {
        return;
      }
    } else {
      final confirmed = await _confirmAction(
        context,
        'Install Var',
        '${item.varName} will be installed. Continue?',
      );
      if (!confirmed) return;
      await _runJob('vars_toggle_install', args: {
        'var_name': item.varName,
        'include_dependencies': true,
        'include_implicated': true,
      });
    }
    ref.invalidate(varsListProvider);
    ref.invalidate(previewItemsProvider);
  }

  Future<bool> _confirmAction(
      BuildContext context, String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  Future<List<String>> _fetchFilteredVarNames(VarsQueryParams query) async {
    final client = ref.read(backendClientProvider);
    const perPage = 200;
    final names = <String>[];
    final first =
        await client.listVars(query.copyWith(page: 1, perPage: perPage));
    names.addAll(first.items.map((e) => e.varName));
    final totalPages =
        first.total == 0 ? 1 : (first.total + perPage - 1) ~/ perPage;
    for (var page = 2; page <= totalPages; page += 1) {
      final resp =
          await client.listVars(query.copyWith(page: page, perPage: perPage));
      names.addAll(resp.items.map((e) => e.varName));
    }
    return names.toSet().toList();
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
