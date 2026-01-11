import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:varmanager_flutter/l10n/app_localizations.dart';
import 'package:path/path.dart' as p;

import '../../app/providers.dart';
import '../../core/backend/backend_client.dart';
import '../../core/backend/job_log_controller.dart';
import '../../core/backend/query_params.dart';
import '../../core/models/scene_models.dart';
import '../../core/utils/debounce.dart';
import '../../widgets/image_preview_dialog.dart';
import '../../widgets/preview_placeholder.dart';
import '../../widgets/lazy_dropdown_field.dart';
import '../../l10n/l10n.dart';
import '../bootstrap/bootstrap_keys.dart';
import '../analysis/analysis_page.dart';
import '../var_detail/var_detail_page.dart';

class ScenesQueryNotifier extends Notifier<ScenesQueryParams> {
  @override
  ScenesQueryParams build() =>
      ScenesQueryParams(location: 'installed,not_installed,save');

  void update(ScenesQueryParams Function(ScenesQueryParams) updater) {
    state = updater(state);
  }
}

final scenesQueryProvider =
    NotifierProvider<ScenesQueryNotifier, ScenesQueryParams>(
  ScenesQueryNotifier.new,
);

final scenesListProvider = FutureProvider<ScenesListResponse>((ref) async {
  final client = ref.watch(backendClientProvider);
  final query = ref.watch(scenesQueryProvider);
  return client.listScenes(query);
});

class ScenesPage extends ConsumerStatefulWidget {
  const ScenesPage({super.key});

  @override
  ConsumerState<ScenesPage> createState() => _ScenesPageState();
}

class _ScenesPageState extends ConsumerState<ScenesPage> {
  final _searchDebounce = Debouncer(const Duration(milliseconds: 300));
  bool _merge = false;
  bool _ignoreGender = false;
  bool _forMale = false;
  int _personOrder = 1;
  final Set<String> _locationFilter = {
    'installed',
    'not_installed',
    'save',
  };
  final Set<int> _hideFavFilter = {-1, 0, 1};

  @override
  void dispose() {
    _searchDebounce.dispose();
    super.dispose();
  }

  Future<void> _runJob(String kind, Map<String, dynamic> args) async {
    final runner = ref.read(jobRunnerProvider);
    final log = ref.read(jobLogProvider.notifier);
    await runner.runJob(kind, args: args, onLog: log.addEntry);
  }

  void _updateQuery(ScenesQueryParams Function(ScenesQueryParams) updater) {
    ref.read(scenesQueryProvider.notifier).update((state) => updater(state));
  }

  String _locationQueryValue() {
    return _locationFilter.join(',');
  }

  String _hideFavQueryValue() {
    if (_hideFavFilter.length == 3) {
      return 'all';
    }
    final parts = <String>[];
    if (_hideFavFilter.contains(-1)) parts.add('hide');
    if (_hideFavFilter.contains(0)) parts.add('normal');
    if (_hideFavFilter.contains(1)) parts.add('fav');
    return parts.join(',');
  }

  void _toggleLocation(String value, bool selected) {
    setState(() {
      if (selected) {
        _locationFilter.add(value);
      } else {
        _locationFilter.remove(value);
      }
    });
    _updateQuery(
      (state) => state.copyWith(page: 1, location: _locationQueryValue()),
    );
  }

  void _toggleHideFav(int value, bool selected) {
    setState(() {
      if (selected) {
        _hideFavFilter.add(value);
      } else {
        _hideFavFilter.remove(value);
      }
    });
    _updateQuery(
      (state) => state.copyWith(page: 1, hideFav: _hideFavQueryValue()),
    );
  }

  void _resetFilters() {
    setState(() {
      _locationFilter
        ..clear()
        ..addAll(['installed', 'not_installed', 'save']);
      _hideFavFilter
        ..clear()
        ..addAll([-1, 0, 1]);
    });
    _updateQuery(
      (state) => ScenesQueryParams(location: _locationQueryValue()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scenesAsync = ref.watch(scenesListProvider);
    final query = ref.watch(scenesQueryProvider);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  DropdownButton<String>(
                    value: query.category,
                    items: [
                      'scenes',
                      'looks',
                      'clothing',
                      'hairstyle',
                      'assets',
                      'morphs',
                      'pose',
                      'skin',
                    ]
                        .map((item) => DropdownMenuItem(
                              value: item,
                              child: Text(_categoryLabel(l10n, item)),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      _updateQuery(
                        (state) => state.copyWith(page: 1, category: value),
                      );
                    },
                  ),
                  SizedBox(
                    width: 220,
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: l10n.nameFilterLabel,
                        border: const OutlineInputBorder(),
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
                      label: l10n.creatorLabel,
                      value: query.creator.isEmpty ? 'ALL' : query.creator,
                      allValue: 'ALL',
                      allLabel: l10n.allCreators,
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
                    value: query.sort,
                    items: [
                      DropdownMenuItem(
                          value: 'var_date', child: Text(l10n.sortNewToOld)),
                      DropdownMenuItem(
                          value: 'meta_date', child: Text(l10n.sortMetaDate)),
                      DropdownMenuItem(
                          value: 'var_name', child: Text(l10n.sortVarName)),
                      DropdownMenuItem(
                          value: 'scene_name', child: Text(l10n.sortSceneName)),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      _updateQuery(
                        (state) => state.copyWith(page: 1, sort: value),
                      );
                    },
                  ),
                  DropdownButton<int>(
                    value: query.perPage,
                    items: const [24, 48, 96, 200]
                        .map((value) => DropdownMenuItem(
                              value: value,
                              child: Text(l10n.perPageLabel(value)),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      _updateQuery(
                        (state) => state.copyWith(page: 1, perPage: value),
                      );
                    },
                  ),
                  TextButton(
                    onPressed: _resetFilters,
                    child: Text(l10n.resetFiltersLabel),
                  ),
                  const SizedBox(width: 8),
                  Text(l10n.locationLabel),
                  FilterChip(
                    label: Text(l10n.locationInstalled),
                    selected: _locationFilter.contains('installed'),
                    onSelected: (value) => _toggleLocation('installed', value),
                  ),
                  FilterChip(
                    label: Text(l10n.locationNotInstalled),
                    selected: _locationFilter.contains('not_installed'),
                    onSelected: (value) => _toggleLocation('not_installed', value),
                  ),
                  FilterChip(
                    label: Text(l10n.locationMissingLink),
                    selected: _locationFilter.contains('missinglink'),
                    onSelected: (value) => _toggleLocation('missinglink', value),
                  ),
                  FilterChip(
                    label: Text(l10n.locationSave),
                    selected: _locationFilter.contains('save'),
                    onSelected: (value) => _toggleLocation('save', value),
                  ),
                  const SizedBox(width: 8),
                  Text(l10n.columnsLabel),
                  FilterChip(
                    label: Text(l10n.columnHide),
                    selected: _hideFavFilter.contains(-1),
                    onSelected: (value) => _toggleHideFav(-1, value),
                  ),
                  FilterChip(
                    label: Text(l10n.columnNormal),
                    selected: _hideFavFilter.contains(0),
                    onSelected: (value) => _toggleHideFav(0, value),
                  ),
                  FilterChip(
                    label: Text(l10n.columnFav),
                    selected: _hideFavFilter.contains(1),
                    onSelected: (value) => _toggleHideFav(1, value),
                  ),
                  const SizedBox(width: 12),
                  FilterChip(
                    label: Text(l10n.mergeLabel),
                    selected: _merge,
                    onSelected: (value) {
                      setState(() {
                        _merge = value;
                      });
                    },
                  ),
                  FilterChip(
                    label: Text(l10n.ignoreGenderLabel),
                    selected: _ignoreGender,
                    onSelected: (value) {
                      setState(() {
                        _ignoreGender = value;
                      });
                    },
                  ),
                  FilterChip(
                    label: Text(l10n.forMaleLabel),
                    selected: _forMale,
                    onSelected: (value) {
                      setState(() {
                        _forMale = value;
                      });
                    },
                  ),
                  DropdownButton<int>(
                    value: _personOrder,
                    items: [1, 2, 3, 4, 5, 6, 7, 8]
                        .map((value) => DropdownMenuItem(
                              value: value,
                              child: Text(l10n.personLabel(value)),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _personOrder = value;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: scenesAsync.when(
              data: (data) => _buildColumns(context, data, query),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) =>
                  Center(child: Text(l10n.loadFailed(err.toString()))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumns(
      BuildContext context, ScenesListResponse data, ScenesQueryParams query) {
    final l10n = context.l10n;
    final totalPages = data.total == 0
        ? 1
        : (data.total + query.perPage - 1) ~/ query.perPage;
    final hideItems = data.items.where((item) => item.hideFav == -1).toList();
    final normalItems = data.items.where((item) => item.hideFav == 0).toList();
    final favItems = data.items.where((item) => item.hideFav == 1).toList();
    final columns = <Widget>[
      if (_hideFavFilter.contains(-1))
        Expanded(
          child: _sceneColumn(
            context,
            title: l10n.columnHide,
            items: hideItems,
            targetHideFav: -1,
          ),
        ),
      if (_hideFavFilter.contains(0))
        Expanded(
          child: _sceneColumn(
            context,
            title: l10n.columnNormal,
            items: normalItems,
            targetHideFav: 0,
          ),
        ),
      if (_hideFavFilter.contains(1))
        Expanded(
          child: _sceneColumn(
            context,
            title: l10n.columnFav,
            items: favItems,
            targetHideFav: 1,
          ),
        ),
    ];
    return Column(
      children: [
        Row(
          children: [
            Text(l10n.totalItems(data.total)),
            const Spacer(),
            Text(l10n.pageOf(data.page, totalPages)),
            IconButton(
              onPressed: data.page > 1
                  ? () => _updateQuery((state) => state.copyWith(page: 1))
                  : null,
              icon: const Icon(Icons.first_page),
            ),
            IconButton(
              onPressed: data.page > 1
                  ? () => _updateQuery(
                        (state) => state.copyWith(page: data.page - 1),
                      )
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              onPressed: data.page < totalPages
                  ? () => _updateQuery(
                        (state) => state.copyWith(page: data.page + 1),
                      )
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
            IconButton(
              onPressed: data.page < totalPages
                  ? () => _updateQuery(
                        (state) => state.copyWith(page: totalPages),
                      )
                  : null,
              icon: const Icon(Icons.last_page),
            ),
            TextButton(
              onPressed: () => ref.invalidate(scenesListProvider),
              child: Text(l10n.commonRefresh),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: columns.length == 1
              ? columns.first
              : Row(
                  children: [
                    for (var i = 0; i < columns.length; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      columns[i],
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _sceneColumn(
    BuildContext context, {
    required String title,
    required List<SceneListItem> items,
    required int targetHideFav,
  }) {
    return DragTarget<SceneListItem>(
      onAcceptWithDetails: (details) => _moveScene(details.data, targetHideFav),
        builder: (context, candidate, rejected) {
          final l10n = context.l10n;
          final titleWidget = Text(l10n.columnTitleWithCount(title, items.length));
          final headerTitle = targetHideFav == 0
              ? KeyedSubtree(key: BootstrapKeys.scenesColumnHeader, child: titleWidget)
              : titleWidget;
          return Card(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      headerTitle,
                      if (candidate.isNotEmpty) ...[
                        const Spacer(),
                        const Icon(Icons.arrow_downward, size: 18),
                      ],
                    ],
                  ),
                ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _sceneCard(context, item);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sceneCard(BuildContext context, SceneListItem item) {
    final feedbackHeader = _buildSceneHeader(context, item);
    final feedback = _sceneCardContent(context, item, feedbackHeader);
    final dragHandleIcon = _buildSceneDragHandleIcon(context);
    final draggableHandle = Draggable<SceneListItem>(
      data: item,
      feedback: Material(
        elevation: 6,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: feedback,
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.4,
        child: MouseRegion(
          cursor: SystemMouseCursors.move,
          child: dragHandleIcon,
        ),
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.move,
        child: dragHandleIcon,
      ),
    );
    final header = _buildSceneHeader(
      context,
      item,
      dragHandle: draggableHandle,
    );
    return _sceneCardContent(context, item, header);
  }

  Widget _buildSceneHeader(
    BuildContext context,
    SceneListItem item, {
    Widget? dragHandle,
  }) {
    final l10n = context.l10n;
    final client = ref.read(backendClientProvider);
    final previewUrl = _previewUrl(client, item);
    final canPreview = previewUrl != null && previewUrl.isNotEmpty;
    final title = p.basenameWithoutExtension(item.scenePath);
    final cacheSize =
        (72 * MediaQuery.of(context).devicePixelRatio).round();
    final previewImage = ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: previewUrl == null
          ? const PreviewPlaceholder(width: 72, height: 72)
          : Image.network(
              previewUrl,
              width: 72,
              height: 72,
              fit: BoxFit.cover,
              cacheWidth: cacheSize,
              cacheHeight: cacheSize,
              errorBuilder: (_, _, _) => const PreviewPlaceholder(
                width: 72,
                height: 72,
                icon: Icons.broken_image,
              ),
            ),
    );
    return Row(
      children: [
        GestureDetector(
          onDoubleTap:
              canPreview ? () => _openScenePreview(context, item) : null,
          child: previewImage,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$title (${item.atomType})',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                item.varName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                children: [
                  Chip(
                    label: Text(_locationLabel(l10n, item.location)),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
        ),
        dragHandle ?? _buildSceneDragHandleIcon(context),
      ],
    );
  }

  Widget _buildSceneDragHandleIcon(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: Center(
        child: Icon(
          Icons.drag_indicator,
          size: 18,
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
    );
  }

  String _sceneTitle(SceneListItem item) {
    final title = p.basenameWithoutExtension(item.scenePath);
    if (title.isEmpty) {
      return '${item.atomType}_${item.varName}';
    }
    return title;
  }

  String _categoryLabel(AppLocalizations l10n, String value) {
    switch (value) {
      case 'scenes':
        return l10n.categoryScenes;
      case 'looks':
        return l10n.categoryLooks;
      case 'clothing':
        return l10n.categoryClothing;
      case 'hairstyle':
        return l10n.categoryHairstyle;
      case 'assets':
        return l10n.categoryAssets;
      case 'morphs':
        return l10n.categoryMorphs;
      case 'pose':
        return l10n.categoryPose;
      case 'skin':
        return l10n.categorySkin;
      default:
        return value;
    }
  }

  String _locationLabel(AppLocalizations l10n, String value) {
    switch (value) {
      case 'installed':
        return l10n.locationInstalled;
      case 'not_installed':
        return l10n.locationNotInstalled;
      case 'missinglink':
        return l10n.locationMissingLink;
      case 'save':
        return l10n.locationSave;
      default:
        return value;
    }
  }

  Widget _sceneCardContent(
      BuildContext context, SceneListItem item, Widget header) {
    final l10n = context.l10n;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                TextButton(
                  onPressed: () => _loadScene(item),
                  child: Text(l10n.commonLoad),
                ),
                if (item.atomType == 'scenes' || item.atomType == 'looks')
                  TextButton(
                    onPressed: () => _analyzeScene(context, item),
                    child: Text(l10n.commonAnalyze),
                  ),
                TextButton(
                  onPressed: () => _locateScene(item),
                  child: Text(l10n.commonLocate),
                ),
                TextButton(
                  onPressed: () => _clearCache(item),
                  child: Text(l10n.clearCacheLabel),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => VarDetailPage(varName: item.varName),
                      ),
                    );
                  },
                  child: Text(l10n.commonDetails),
                ),
                TextButton(
                  onPressed: () => _toggleHide(item),
                  child: Text(item.hide ? l10n.unhideLabel : l10n.hideLabel),
                ),
                TextButton(
                  onPressed: () => _toggleFav(item),
                  child: Text(item.fav ? l10n.unfavLabel : l10n.favLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String? _previewUrl(BackendClient client, SceneListItem item) {
    if (item.previewPic == null || item.previewPic!.isEmpty) {
      return null;
    }
    if (item.location == 'save') {
      return client.previewUrl(root: 'vampath', path: item.previewPic!);
    }
    final path =
        '___PreviewPics___/${item.atomType}/${item.varName}/${item.previewPic}';
    return client.previewUrl(root: 'varspath', path: path);
  }

  Future<void> _openScenePreview(
    BuildContext context,
    SceneListItem item,
  ) async {
    final client = ref.read(backendClientProvider);
    final imageUrl = _previewUrl(client, item);
    if (imageUrl == null || imageUrl.isEmpty) {
      return;
    }
    final previewItems = [
      ImagePreviewItem(
        title: _sceneTitle(item),
        subtitle: item.atomType,
        footer: item.varName,
        imageUrl: imageUrl,
      ),
    ];
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return ImagePreviewDialog(
          items: previewItems,
          initialIndex: 0,
          onIndexChanged: (_) {},
          showFooter: false,
          wrapNavigation: true,
        );
      },
    );
  }

  Future<void> _loadScene(SceneListItem item) async {
    await _runJob('scene_load', {
      'json': {
        'rescan': item.installed ? 'false' : 'true',
        'resources': [
          {
            'type': item.atomType,
            'saveName': '${item.varName}:/${item.scenePath.replaceAll('\\', '/')}',
          }
        ],
      },
      'merge': _merge,
      'ignore_gender': _ignoreGender,
      'character_gender': _forMale ? 'male' : 'female',
      'person_order': _personOrder,
    });
  }

  Future<void> _analyzeScene(BuildContext context, SceneListItem item) async {
    final runner = ref.read(jobRunnerProvider);
    final log = ref.read(jobLogProvider.notifier);
    final result = await runner.runJob('scene_analyze',
        args: {
          'save_name': '${item.varName}:/${item.scenePath.replaceAll('\\', '/')}',
          'character_gender': _forMale ? 'male' : 'female',
        },
        onLog: log.addEntry);
    final payload = result.result as Map<String, dynamic>?;
    if (payload == null || !context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AnalysisPage(payload: payload),
      ),
    );
  }

  Future<void> _locateScene(SceneListItem item) async {
    if (item.location == 'save') {
      await _runJob('vars_locate', {
        'path': item.scenePath.replaceAll('/', '\\'),
      });
      return;
    }
    await _runJob('vars_locate', {'var_name': item.varName});
  }

  Future<void> _clearCache(SceneListItem item) async {
    await _runJob('cache_clear', {
      'var_name': item.varName,
      'entry_name': item.scenePath,
    });
  }

  Future<void> _toggleHide(SceneListItem item) async {
    if (item.hide) {
      await _runJob('scene_unhide', {
        'var_name': item.varName,
        'scene_path': item.scenePath,
      });
    } else {
      await _runJob('scene_hide', {
        'var_name': item.varName,
        'scene_path': item.scenePath,
      });
    }
    ref.invalidate(scenesListProvider);
  }

  Future<void> _toggleFav(SceneListItem item) async {
    if (item.fav) {
      await _runJob('scene_unfav', {
        'var_name': item.varName,
        'scene_path': item.scenePath,
      });
    } else {
      await _runJob('scene_fav', {
        'var_name': item.varName,
        'scene_path': item.scenePath,
      });
    }
    ref.invalidate(scenesListProvider);
  }

  Future<void> _moveScene(SceneListItem item, int targetHideFav) async {
    if (item.hideFav == targetHideFav) {
      return;
    }
    final kind = switch (targetHideFav) {
      -1 => 'scene_hide',
      1 => 'scene_fav',
      _ => 'scene_unhide',
    };
    await _runJob(kind, {
      'var_name': item.varName,
      'scene_path': item.scenePath,
    });
    ref.invalidate(scenesListProvider);
  }
}

