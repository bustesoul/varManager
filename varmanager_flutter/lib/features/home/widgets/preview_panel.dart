import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:path/path.dart' as p;

import '../../../app/providers.dart';
import '../../../core/backend/backend_client.dart';
import '../../../core/backend/job_log_controller.dart';
import '../../../core/models/job_models.dart';
import '../models.dart';
import '../providers.dart';
import '../../uninstall_vars/uninstall_vars_page.dart';
import 'preview_dialog.dart';
import '../../../widgets/preview_placeholder.dart';

class PreviewPanel extends ConsumerStatefulWidget {
  const PreviewPanel({super.key});

  @override
  ConsumerState<PreviewPanel> createState() => _PreviewPanelState();
}

class _PreviewPanelState extends ConsumerState<PreviewPanel> {
  String _previewType = 'all';
  bool _previewLoadableOnly = true;
  int _previewPerPage = 24;
  int _previewPage = 1;
  int? _previewSelectedIndex;
  int _previewWheelLastMs = 0;
  static const int _previewWheelCooldownMs = 350;
  int _previewTapLastMs = 0;
  int? _previewTapLastIndex;
  static const int _previewTapDoubleMs = 300;

  @override
  void initState() {
    super.initState();
    ref.listen<String?>(focusedVarProvider, (previous, next) {
      if (!mounted) return;
      setState(() {
        _previewPage = 1;
        _previewSelectedIndex = next == null ? null : 0;
      });
    });
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

  Future<void> _openPreviewDialog(
    BuildContext context,
    BackendClient client,
    List<PreviewItem> items,
    int initialIndex,
  ) async {
    if (items.isEmpty) return;
    final clampedIndex = initialIndex.clamp(0, items.length - 1);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PreviewDialog(
          items: items,
          initialIndex: clampedIndex,
          client: client,
          onIndexChanged: (index) => _selectPreviewIndex(index, items.length),
        );
      },
    );
  }

  bool _handlePreviewScroll(
    ScrollNotification notification,
    int totalItems,
    int currentPage,
    int totalPages,
  ) {
    if (totalItems <= 0 || totalPages <= 1) {
      return false;
    }
    if (notification is! ScrollUpdateNotification) {
      return false;
    }
    final delta = notification.scrollDelta;
    if (delta == null || delta == 0) {
      return false;
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _previewWheelLastMs < _previewWheelCooldownMs) {
      return false;
    }
    const edgeThreshold = 18.0;
    if (delta > 0 && notification.metrics.extentAfter <= edgeThreshold) {
      setState(() {
        _previewWheelLastMs = nowMs;
      });
      _setPreviewPage(currentPage + 1, totalItems);
    } else if (delta < 0 &&
        notification.metrics.extentBefore <= edgeThreshold) {
      setState(() {
        _previewWheelLastMs = nowMs;
      });
      _setPreviewPage(currentPage - 1, totalItems);
    }
    return false;
  }

  void _handlePreviewTap(
    int index,
    int totalItems,
    void Function(int index) onOpenPreview,
  ) {
    if (totalItems <= 0) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final isDoubleTap = _previewTapLastIndex == index &&
        nowMs - _previewTapLastMs <= _previewTapDoubleMs;
    if (isDoubleTap) {
      _previewTapLastMs = 0;
      _previewTapLastIndex = null;
      onOpenPreview(index);
      return;
    }
    _previewTapLastMs = nowMs;
    _previewTapLastIndex = index;
    _selectPreviewIndex(index, totalItems);
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
    final focusedVar = ref.read(focusedVarProvider);
    if (focusedVar != null) {
      ref.invalidate(previewItemsProvider(focusedVar));
    }
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

  @override
  Widget build(BuildContext context) {
    final focusedVar = ref.watch(focusedVarProvider);
    if (focusedVar != null) {
      ref.listen<AsyncValue<List<PreviewItem>>>(
        previewItemsProvider(focusedVar),
        (previous, next) {
          next.whenData((items) {
            if (!mounted) return;
            setState(() {
              _previewPage = 1;
              _previewSelectedIndex = items.isEmpty ? null : 0;
            });
          });
        },
      );
    }
    final previewAsync = focusedVar == null
        ? AsyncValue.data(const <PreviewItem>[])
        : ref.watch(previewItemsProvider(focusedVar));
    final hasSelection = focusedVar != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: previewAsync.when(
          data: (items) {
            if (items.isEmpty) {
              final message = hasSelection
                  ? 'No preview entries for selected var'
                  : 'Click on a var to load previews';
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
            void openPreview(int index) {
              _openPreviewDialog(context, client, filtered, index);
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildControls(totalItems),
                const SizedBox(height: 8),
                _buildNavigation(selectedIndex, totalItems, currentPage, totalPages),
                const Divider(height: 16),
                Expanded(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) => _handlePreviewScroll(
                      notification,
                      totalItems,
                      currentPage,
                      totalPages,
                    ),
                    child: _buildPreviewGrid(
                      client: client,
                      items: pageItems,
                      startIndex: startIndex,
                      selectedIndex: selectedIndex,
                      totalItems: totalItems,
                      onOpenPreview: openPreview,
                    ),
                  ),
                ),
                const Divider(height: 16),
                SizedBox(
                  height: 280,
                  child: _buildPreviewDetail(
                    context,
                    client,
                    selectedItem,
                    onOpenPreview: selectedIndex == null
                        ? null
                        : () => openPreview(selectedIndex),
                  ),
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

  Widget _buildControls(int totalItems) {
    return Wrap(
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
            DropdownMenuItem(value: 'clothing', child: Text('Clothing')),
            DropdownMenuItem(value: 'hairstyle', child: Text('Hairstyle')),
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
    );
  }

  Widget _buildNavigation(int? selectedIndex, int totalItems, int currentPage, int totalPages) {
    return Row(
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
              : () => _selectPreviewIndex((selectedIndex ?? 0) - 1, totalItems),
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
              : () => _selectPreviewIndex((selectedIndex ?? 0) + 1, totalItems),
          icon: const Icon(Icons.chevron_right),
        ),
        IconButton(
          onPressed: totalItems == 0
              ? null
              : () => _selectPreviewIndex(totalItems - 1, totalItems),
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
    );
  }

  Widget _buildPreviewGrid({
    required BackendClient client,
    required List<PreviewItem> items,
    required int startIndex,
    required int? selectedIndex,
    required int totalItems,
    required void Function(int index) onOpenPreview,
  }) {
    if (items.isEmpty) {
      return const Center(child: Text('No previews after filters'));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount =
            (constraints.maxWidth / 140).floor().clamp(2, 6).toInt();
        final tileWidth = constraints.maxWidth / crossAxisCount;
        final cacheWidth =
            (tileWidth * MediaQuery.of(context).devicePixelRatio).round();
        return MasonryGridView.count(
          itemCount: items.length,
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          itemBuilder: (context, index) {
            final item = items[index];
            final globalIndex = startIndex + index;
            final isSelected = selectedIndex == globalIndex;
            final previewPath = _previewPath(item);
            return InkWell(
              onTap: () => _handlePreviewTap(
                globalIndex,
                totalItems,
                onOpenPreview,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SizedBox(
                      height: 110,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: previewPath == null
                            ? const PreviewPlaceholder()
                            : Image.network(
                                client.previewUrl(
                                  root: 'varspath',
                                  path: previewPath,
                                ),
                                fit: BoxFit.fitWidth,
                                cacheWidth: cacheWidth,
                                filterQuality: FilterQuality.low,
                                errorBuilder: (_, _, _) =>
                                    const PreviewPlaceholder(
                                  icon: Icons.broken_image,
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
    PreviewItem? item, {
    VoidCallback? onOpenPreview,
  }) {
    final isBusy = ref.watch(jobBusyProvider);
    if (item == null) {
      return const Center(child: Text('Select a preview'));
    }
    final detailCacheWidth =
        (360 * MediaQuery.of(context).devicePixelRatio).round();
    final previewPath = _previewPath(item);
    return Row(
      children: [
        SizedBox(
          width: 360,
          child: GestureDetector(
            onDoubleTap: onOpenPreview,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: previewPath == null
                  ? const PreviewPlaceholder()
                  : Image.network(
                      client.previewUrl(root: 'varspath', path: previewPath),
                      fit: BoxFit.contain,
                      cacheWidth: detailCacheWidth,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (_, _, _) =>
                          const PreviewPlaceholder(icon: Icons.broken_image),
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
                    onPressed: isBusy
                        ? null
                        : () => _togglePreviewInstall(context, item),
                    icon: Icon(
                      item.installed ? Icons.delete_outline : Icons.download,
                    ),
                    label: Text(item.installed ? 'Uninstall' : 'Install'),
                  ),
                  OutlinedButton(
                    onPressed: isBusy
                        ? null
                        : () async {
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
}
