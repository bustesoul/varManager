import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/backend/job_log_controller.dart';
import '../../core/backend/query_params.dart';
import '../../core/models/extra_models.dart';
import '../../core/models/job_models.dart';
import '../../core/models/var_models.dart';
import '../../core/utils/debounce.dart';
import '../../widgets/lazy_dropdown_field.dart';
import '../missing_vars/missing_vars_page.dart';
import '../prepare_saves/prepare_saves_page.dart';
import '../uninstall_vars/uninstall_vars_page.dart';
import '../var_detail/var_detail_page.dart';
import 'providers.dart';
import 'widgets/preview_panel.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

enum _ActionGroup { core, maintenance }

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
  _ActionGroup _actionGroup = _ActionGroup.core;
  String _missingDepsScope = 'installed';

  static const Duration _tooltipDelay = Duration(seconds: 1);

  // PackSwitch state
  PackSwitchListResponse? _packSwitchData;
  String? _selectedSwitch;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadPackSwitches);
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
    final busy = ref.read(jobBusyProvider.notifier);
    busy.setBusy(true);
    try {
      return await runner.runJob(kind, args: args, onLog: log.addLine);
    } finally {
      busy.setBusy(false);
    }
  }

  Widget _withTooltip(String message, Widget child) {
    return Tooltip(
      message: message,
      waitDuration: _tooltipDelay,
      showDuration: const Duration(seconds: 6),
      child: child,
    );
  }

  Future<void> _runMissingDeps(VarsQueryParams query) async {
    JobResult<dynamic>? result;
    switch (_missingDepsScope) {
      case 'installed':
        result = await _runJob('missing_deps', args: {'scope': 'installed'});
        break;
      case 'all':
        result = await _runJob('missing_deps', args: {'scope': 'all'});
        break;
      case 'filtered':
        final names = await _fetchFilteredVarNames(query);
        if (names.isEmpty) return;
        result = await _runJob('missing_deps', args: {
          'scope': 'filtered',
          'var_names': names,
        });
        break;
      case 'saves':
        result = await _runJob('saves_deps');
        break;
      case 'log':
        result = await _runJob('log_deps');
        break;
    }
    if (result != null) {
      await _openMissingVars(result);
    }
  }

  void _updateQuery(VarsQueryParams Function(VarsQueryParams) updater) {
    ref.read(varsQueryProvider.notifier).update((state) => updater(state));
  }

  Future<void> _loadPackSwitches() async {
    final client = ref.read(backendClientProvider);
    try {
      final response = await client.listPackSwitches();
      if (!mounted) return;
      setState(() {
        _packSwitchData = response;
        _selectedSwitch = response.switches.contains(_selectedSwitch)
            ? _selectedSwitch
            : response.current;
      });
    } catch (e) {
      // Ignore errors during load
    }
  }

  @override
  Widget build(BuildContext context) {
    final varsAsync = ref.watch(varsListProvider);
    final selected = ref.watch(selectedVarsProvider);
    final focusedVar = ref.watch(focusedVarProvider);
    final query = ref.watch(varsQueryProvider);
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
          _buildToolbar(context, varsAsync, query),
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
                  SizedBox(
                    width: 220,
                    child: LazyDropdownField(
                      label: 'Creator',
                      value: query.creator.isEmpty ? 'ALL' : query.creator,
                      allValue: 'ALL',
                      allLabel: 'All creators',
                      optionsLoader: (queryText, offset, limit) async {
                        final client = ref.read(backendClientProvider);
                        return client.listCreators(
                          query: queryText,
                          offset: offset,
                          limit: limit,
                        );
                      },
                      onChanged: (value) {
                        _updateQuery(
                          (state) => state.copyWith(page: 1, creator: value),
                        );
                      },
                    ),
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
                  _withTooltip(
                    'Select all items on the current page.',
                    TextButton(
                      onPressed: () {
                        final items = varsAsync.asData?.value.items ?? [];
                        if (items.isEmpty) return;
                        final pageNames = items.map((e) => e.varName).toSet();
                        final next = <String>{...selected, ...pageNames};
                        ref.read(selectedVarsProvider.notifier).setSelection(next);
                      },
                      child: const Text('Select page'),
                    ),
                  ),
                  _withTooltip(
                    'Invert selection on the current page.',
                    TextButton(
                      onPressed: () {
                        final items = varsAsync.asData?.value.items ?? [];
                        if (items.isEmpty) return;
                        final pageNames = items.map((e) => e.varName).toSet();
                        final next = <String>{};
                        // Add items not on this page
                        for (final name in selected) {
                          if (!pageNames.contains(name)) {
                            next.add(name);
                          }
                        }
                        // Add unselected items from this page
                        for (final name in pageNames) {
                          if (!selected.contains(name)) {
                            next.add(name);
                          }
                        }
                        ref
                            .read(selectedVarsProvider.notifier)
                            .setSelection(next);
                      },
                      child: const Text('Invert page'),
                    ),
                  ),
                  _withTooltip(
                    'Clear all selected items.',
                    TextButton(
                      onPressed: selected.isEmpty
                          ? null
                          : () {
                              ref.read(selectedVarsProvider.notifier).clear();
                            },
                      child: const Text('Clear all'),
                    ),
                  ),
                  _withTooltip(
                    'Reset all filters to defaults.',
                    TextButton(
                      onPressed: () {
                        ref.read(varsQueryProvider.notifier).reset();
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
                  ),
                  _withTooltip(
                    _showAdvancedFilters
                        ? 'Hide advanced filters.'
                        : 'Show advanced filters.',
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _showAdvancedFilters = !_showAdvancedFilters;
                        });
                      },
                      child: Text(
                        _showAdvancedFilters
                            ? 'Hide advanced'
                            : 'Advanced filters',
                      ),
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
                    final wide = constraints.maxWidth >= 1200;
                    final list = _buildList(context, data, selected, query, focusedVar);
                    const preview = PreviewPanel();
                    final packSwitch = _buildPackSwitchPanel(context);
                    if (wide) {
                      return Row(
                        children: [
                          SizedBox(width: 180, child: packSwitch),
                          const SizedBox(width: 12),
                          Expanded(flex: 2, child: list),
                          const SizedBox(width: 12),
                          Expanded(flex: 3, child: preview),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        Expanded(child: list),
                        const SizedBox(height: 12),
                        SizedBox(height: 440, child: preview),
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

  Widget _buildToolbar(
    BuildContext context,
    AsyncValue<VarsListResponse> _,
    VarsQueryParams query,
  ) {
    final isBusy = ref.watch(jobBusyProvider);
    final compactPadding =
        const EdgeInsets.symmetric(horizontal: 12, vertical: 8);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 520;
                final title = Text(
                  'Actions',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                );
                final switcher = SegmentedButton<_ActionGroup>(
                  segments: const [
                    ButtonSegment(
                      value: _ActionGroup.core,
                      label: Text('Core'),
                      tooltip: 'Core actions and dependency checks.',
                    ),
                    ButtonSegment(
                      value: _ActionGroup.maintenance,
                      label: Text('Maintenance'),
                      tooltip: 'Cleanup and maintenance jobs.',
                    ),
                  ],
                  selected: {_actionGroup},
                  onSelectionChanged: (value) {
                    setState(() {
                      _actionGroup = value.first;
                    });
                  },
                );
                if (wide) {
                  return Row(
                    children: [
                      title,
                      const Spacer(),
                      if (isBusy)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      const SizedBox(width: 8),
                      switcher,
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        title,
                        const Spacer(),
                        if (isBusy)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    switcher,
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _buildActionGroupContent(
                context,
                query,
                isBusy,
                compactPadding,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionGroupContent(
    BuildContext context,
    VarsQueryParams query,
    bool isBusy,
    EdgeInsets compactPadding,
  ) {
    switch (_actionGroup) {
      case _ActionGroup.core:
        return Wrap(
          key: const ValueKey('core-actions'),
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _withTooltip(
              'Scan vars, extract previews, and update the database.',
              FilledButton.icon(
                onPressed: isBusy
                    ? null
                    : () async {
                        await _runJob('update_db');
                        ref.invalidate(varsListProvider);
                      },
                icon: const Icon(Icons.sync),
                label: const Text('Update DB'),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: compactPadding,
                ),
              ),
            ),
            _withTooltip(
              'Launch the VaM application.',
              OutlinedButton.icon(
                onPressed: isBusy
                    ? null
                    : () async {
                        await _runJob('vam_start');
                      },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start VaM'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: compactPadding,
                ),
              ),
            ),
            _withTooltip(
              'Open the saves preparation and dependency tools.',
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PrepareSavesPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.build_circle),
                label: const Text('Prepare Saves'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: compactPadding,
                ),
              ),
            ),
            SizedBox(
              width: 230,
              child: _withTooltip(
                'Choose the source used to detect missing dependencies.',
                DropdownButtonFormField<String>(
                  initialValue: _missingDepsScope,
                  decoration: const InputDecoration(
                    labelText: 'Missing deps source',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'installed',
                      child: Text('Installed packages'),
                    ),
                    DropdownMenuItem(
                      value: 'all',
                      child: Text('All packages'),
                    ),
                    DropdownMenuItem(
                      value: 'filtered',
                      child: Text('Filtered list'),
                    ),
                    DropdownMenuItem(
                      value: 'saves',
                      child: Text('Saves folder'),
                    ),
                    DropdownMenuItem(
                      value: 'log',
                      child: Text('Log (output_log.txt)'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _missingDepsScope = value;
                    });
                  },
                ),
              ),
            ),
            _withTooltip(
              'Analyze missing dependencies and open the results.',
              FilledButton.icon(
                onPressed: isBusy ? null : () => _runMissingDeps(query),
                icon: const Icon(Icons.search),
                label: const Text('Run Missing Deps'),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: compactPadding,
                ),
              ),
            ),
          ],
        );
      case _ActionGroup.maintenance:
        return Wrap(
          key: const ValueKey('maintenance-actions'),
          spacing: 8,
          runSpacing: 8,
          children: [
            _withTooltip(
              'Rebuild symlinks after changing the Vars source directory.',
              OutlinedButton.icon(
                onPressed: isBusy
                    ? null
                    : () async {
                        await _runJob('rebuild_links',
                            args: {'include_missing': true});
                      },
                icon: const Icon(Icons.link),
                label: const Text('Rebuild Links'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: compactPadding,
                ),
              ),
            ),
            _withTooltip(
              'Re-extract missing preview images.',
              OutlinedButton.icon(
                onPressed: isBusy
                    ? null
                    : () async {
                        await _runJob('fix_previews');
                      },
                icon: const Icon(Icons.image_search),
                label: const Text('Fix Preview'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: compactPadding,
                ),
              ),
            ),
            _withTooltip(
              'Move old versions not referenced by dependencies.',
              OutlinedButton.icon(
                onPressed: isBusy
                    ? null
                    : () async {
                        await _runJob('stale_vars');
                      },
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Stale Vars'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: compactPadding,
                ),
              ),
            ),
            _withTooltip(
              'Find or manage old package versions.',
              OutlinedButton.icon(
                onPressed: isBusy
                    ? null
                    : () async {
                        await _runJob('old_version_vars');
                      },
                icon: const Icon(Icons.layers_clear),
                label: const Text('Old Versions'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: compactPadding,
                ),
              ),
            ),
          ],
        );
    }
  }

  Widget _buildList(
      BuildContext context,
      VarsListResponse data,
      Set<String> selected,
      VarsQueryParams query,
      String? focusedVar) {
    final isBusy = ref.watch(jobBusyProvider);
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
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = data.items[index];
                final isChecked = selected.contains(item.varName);
                final isFocused = focusedVar == item.varName;
                return Container(
                  color: isFocused ? Colors.blue.shade50 : null,
                  child: ListTile(
                    leading: Checkbox(
                      value: isChecked,
                      onChanged: (value) {
                        final next = {...selected};
                        if (value == true) {
                          next.add(item.varName);
                        } else {
                          next.remove(item.varName);
                        }
                        ref.read(selectedVarsProvider.notifier).setSelection(next);
                      },
                    ),
                    onTap: () {
                      ref.read(focusedVarProvider.notifier).setFocused(item.varName);
                    },
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
                  ),
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
                  _withTooltip(
                    'Install selected vars and dependencies.',
                    FilledButton(
                      onPressed: isBusy
                          ? null
                          : () async {
                              await _runJob('install_vars', args: {
                                'var_names': selected.toList(),
                                'include_dependencies': true,
                              });
                              ref.invalidate(varsListProvider);
                            },
                      child: const Text('Install Selected'),
                    ),
                  ),
                  _withTooltip(
                    'Uninstall selected vars and affected items.',
                    FilledButton.tonal(
                      onPressed: isBusy
                          ? null
                          : () async {
                              final preview =
                                  await _runJob('preview_uninstall', args: {
                                'var_names': selected.toList(),
                                'include_implicated': true,
                              });
                              if (!context.mounted) return;
                              final result =
                                  preview.result as Map<String, dynamic>?;
                              if (result == null) return;
                              final confirmed =
                                  await Navigator.of(context).push<bool>(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      UninstallVarsPage(payload: result),
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
                  ),
                  _withTooltip(
                    'Delete selected vars and affected items.',
                    OutlinedButton(
                      onPressed: isBusy
                          ? null
                          : () async {
                              await _runJob('delete_vars', args: {
                                'var_names': selected.toList(),
                                'include_implicated': true,
                              });
                              ref.invalidate(varsListProvider);
                            },
                      child: const Text('Delete Selected'),
                    ),
                  ),
                  _withTooltip(
                    'Move selected symlink entries to a target folder.',
                    OutlinedButton(
                      onPressed: isBusy
                          ? null
                          : () async {
                              final target =
                                  await _askText(context, 'Target dir');
                              if (target == null || target.trim().isEmpty) {
                                return;
                              }
                              await _runJob('links_move', args: {
                                'var_names': selected.toList(),
                                'target_dir': target.trim(),
                              });
                            },
                      child: const Text('Move Links'),
                    ),
                  ),
                  _withTooltip(
                    'Export installed vars to a text file.',
                    OutlinedButton(
                      onPressed: isBusy
                          ? null
                          : () async {
                              final path = await _askText(
                                context,
                                'Export path',
                                hint: 'installed_vars.txt',
                              );
                              if (path == null || path.trim().isEmpty) return;
                              await _runJob('vars_export_installed', args: {
                                'path': path.trim(),
                              });
                            },
                      child: const Text('Export Installed'),
                    ),
                  ),
                  _withTooltip(
                    'Install vars from a text list.',
                    OutlinedButton(
                      onPressed: isBusy
                          ? null
                          : () async {
                              final path = await _askText(
                                context,
                                'Install list path',
                                hint: 'install_list.txt',
                              );
                              if (path == null || path.trim().isEmpty) return;
                              await _runJob('vars_install_batch', args: {
                                'path': path.trim(),
                              });
                              ref.invalidate(varsListProvider);
                            },
                      child: const Text('Install from List'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
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

  Widget _buildPackSwitchPanel(BuildContext context) {
    final switches = _packSwitchData?.switches ?? [];
    final current = _packSwitchData?.current ?? 'default';
    final selectedSwitch = switches.contains(_selectedSwitch)
        ? _selectedSwitch
        : (switches.isNotEmpty ? switches.first : null);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Pack Switch',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 12),
            if (switches.isNotEmpty)
              DropdownButton<String>(
                value: selectedSwitch,
                isExpanded: true,
                items: switches
                    .map((name) => DropdownMenuItem(
                          value: name,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (name == current)
                                Container(
                                  margin: const EdgeInsets.only(left: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Active',
                                    style: TextStyle(fontSize: 10),
                                  ),
                                ),
                            ],
                          ),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedSwitch = value;
                    });
                  }
                },
              )
            else
              const Text('No switches available', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _addPackSwitch(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: selectedSwitch != null
                  ? () => _activatePackSwitch(selectedSwitch)
                  : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline, size: 18),
                  SizedBox(width: 8),
                  Text('Activate'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: selectedSwitch != null
                  ? () => _renamePackSwitch(context, selectedSwitch)
                  : null,
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('Rename'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: selectedSwitch != null &&
                      selectedSwitch != current &&
                      selectedSwitch.toLowerCase() != 'default'
                  ? () => _deletePackSwitch(selectedSwitch)
                  : null,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Delete'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
                foregroundColor: Colors.red.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addPackSwitch(BuildContext context) async {
    final name = await _askText(context, 'New Switch Name', hint: '');
    if (name == null || name.trim().isEmpty) return;
    final trimmed = name.trim();
    final switches = _packSwitchData?.switches ?? [];
    if (switches.any((s) => s.toLowerCase() == trimmed.toLowerCase())) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Switch already exists')),
      );
      return;
    }
    await _runJob('packswitch_add', args: {'name': trimmed});
    await _loadPackSwitches();
  }

  Future<void> _renamePackSwitch(BuildContext context, String oldName) async {
    final newName = await _askText(context, 'Rename Switch', hint: oldName);
    if (newName == null || newName.trim().isEmpty) return;
    final trimmed = newName.trim();
    if (trimmed.toLowerCase() == oldName.toLowerCase()) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New name must be different')),
      );
      return;
    }
    final switches = _packSwitchData?.switches ?? [];
    if (switches.any((s) => s.toLowerCase() == trimmed.toLowerCase())) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Target name already exists')),
      );
      return;
    }
    await _runJob('packswitch_rename', args: {
      'old_name': oldName,
      'new_name': trimmed,
    });
    await _loadPackSwitches();
  }

  Future<void> _deletePackSwitch(String name) async {
    final confirmed = await _confirmAction(
      context,
      'Delete Switch',
      'Delete switch "$name"?',
    );
    if (!confirmed) return;
    await _runJob('packswitch_delete', args: {'name': name});
    await _loadPackSwitches();
  }

  Future<void> _activatePackSwitch(String name) async {
    // Optimistic update: immediately reflect the change in UI
    setState(() {
      if (_packSwitchData != null) {
        _packSwitchData = PackSwitchListResponse(
          current: name,
          switches: _packSwitchData!.switches,
        );
      }
    });
    await _runJob('packswitch_set', args: {'name': name});
    await _loadPackSwitches();
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        DropdownButton<String>(
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
        ),
      ],
    );
  }
}
