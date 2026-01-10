import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../app/providers.dart';
import '../../core/backend/backend_client.dart';
import '../../core/backend/job_log_controller.dart';
import '../../core/models/var_models.dart';
import '../../widgets/image_preview_dialog.dart';
import '../../widgets/preview_placeholder.dart';
import '../missing_vars/missing_vars_page.dart';
import '../home/providers.dart';

final varDetailProvider = FutureProvider.family<VarDetailResponse, String>((ref, name) async {
  final client = ref.watch(backendClientProvider);
  return client.getVarDetail(name);
});

class VarDetailPage extends ConsumerWidget {
  const VarDetailPage({super.key, required this.varName});

  final String varName;

  Future<void> _runLocate(WidgetRef ref) async {
    final runner = ref.read(jobRunnerProvider);
    final log = ref.read(jobLogProvider.notifier);
    await runner.runJob('vars_locate',
        args: {'var_name': varName}, onLog: log.addEntry);
  }

  Future<void> _runJob(WidgetRef ref, String kind, Map<String, dynamic> args) async {
    final runner = ref.read(jobRunnerProvider);
    final log = ref.read(jobLogProvider.notifier);
    await runner.runJob(kind, args: args, onLog: log.addEntry);
  }

  Future<void> _runMissingDeps(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final runner = ref.read(jobRunnerProvider);
    final log = ref.read(jobLogProvider.notifier);
    final result = await runner.runJob(
      'missing_deps',
      args: {
        'scope': 'filtered',
        'var_names': [varName],
      },
      onLog: log.addEntry,
    );
    final payload = result.result as Map<String, dynamic>?;
    if (payload == null) {
      return;
    }
    final missing = (payload['missing'] as List<dynamic>? ?? [])
        .map((item) => item.toString())
        .toList();
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MissingVarsPage(missing: missing),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(varDetailProvider(varName));
    return Scaffold(
      appBar: AppBar(title: Text('Details: $varName')),
      body: detailAsync.when(
        data: (detail) => _buildDetail(context, ref, detail),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Load failed: $err')),
      ),
    );
  }

  Widget _buildDetail(
      BuildContext context, WidgetRef ref, VarDetailResponse detail) {
    final client = ref.read(backendClientProvider);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: ListTile(
              title: Text(detail.varInfo.varName),
              subtitle: Text(
                '${detail.varInfo.creatorName ?? '-'} - ${detail.varInfo.packageName ?? '-'} - v${detail.varInfo.version ?? '-'}',
              ),
              trailing: Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: () => _runLocate(ref),
                    child: const Text('Locate'),
                  ),
                  TextButton(
                    onPressed: () {
                      final creator = detail.varInfo.creatorName;
                      if (creator == null || creator.isEmpty) return;
                      ref
                          .read(varsQueryProvider.notifier)
                          .update((state) => state.copyWith(creator: creator));
                      Navigator.pop(context);
                    },
                    child: const Text('Filter by Creator'),
                  ),
                  TextButton(
                    onPressed: () => _runMissingDeps(context, ref),
                    child: const Text('Missing Deps'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              children: [
                _buildSection(
                  title: 'Dependencies',
                  child: Column(
                    children: detail.dependencies
                        .map((dep) {
                      final resolved = dep.resolved;
                      return ListTile(
                        title: Text(dep.name),
                        subtitle: Text(resolved),
                        tileColor: dep.missing
                            ? Colors.red.shade50
                            : dep.closest
                                ? Colors.orange.shade50
                                : null,
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            if (dep.missing)
                              TextButton(
                                onPressed: () {
                                  final search = dep.name.replaceAll('.latest', '.1');
                                  _runJob(ref, 'open_url', {
                                    'url':
                                        'https://www.google.com/search?q=$search var',
                                  });
                                },
                                child: const Text('Search'),
                              )
                            else
                              TextButton(
                                onPressed: () {
                                  ref.read(varsQueryProvider.notifier).update(
                                        (state) => state.copyWith(
                                          page: 1,
                                          search: resolved,
                                        ),
                                      );
                                  Navigator.pop(context);
                                },
                                child: const Text('Select'),
                              ),
                          ],
                        ),
                      );
                    })
                        .toList(),
                  ),
                ),
                const SizedBox(height: 12),
                _buildSection(
                  title: 'Dependents',
                  child: Column(
                    children: detail.dependents
                        .map(
                          (name) => ListTile(
                            title: Text(name),
                            trailing: TextButton(
                              onPressed: () {
                                ref.read(varsQueryProvider.notifier).update(
                                      (state) => state.copyWith(
                                        page: 1,
                                        search: name,
                                      ),
                                    );
                                Navigator.pop(context);
                              },
                              child: const Text('Select'),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 12),
                _buildSection(
                  title: 'Save Dependencies',
                  child: Column(
                    children: detail.dependentSaves
                        .map(
                          (name) => ListTile(
                            title: Text(name),
                            trailing: TextButton(
                              onPressed: () {
                                final path = name.startsWith('\\')
                                    ? name.substring(1)
                                    : name;
                                _runJob(ref, 'vars_locate', {
                                  'path': path.replaceAll('/', '\\'),
                                });
                              },
                              child: const Text('Locate'),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 12),
                _buildSection(
                  title: 'Previews',
                  child: _VarPreviewGrid(
                    client: client,
                    varName: detail.varInfo.varName,
                    scenes: detail.scenes,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
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

class _VarPreviewGrid extends StatefulWidget {
  const _VarPreviewGrid({
    required this.client,
    required this.varName,
    required this.scenes,
  });

  final BackendClient client;
  final String varName;
  final List<ScenePreviewItem> scenes;

  @override
  State<_VarPreviewGrid> createState() => _VarPreviewGridState();
}

class _VarPreviewGridState extends State<_VarPreviewGrid> {
  static const int _perPage = 60;
  int _page = 1;

  @override
  void didUpdateWidget(covariant _VarPreviewGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scenes != widget.scenes) {
      _page = 1;
    }
  }

  String? _previewPath(ScenePreviewItem scene) {
    final pic = scene.previewPic;
    if (pic == null || pic.isEmpty) return null;
    return '___PreviewPics___/${scene.atomType}/${widget.varName}/$pic';
  }

  String _sceneTitle(ScenePreviewItem item) {
    final title = p.basenameWithoutExtension(item.scenePath);
    if (title.isEmpty) {
      return '${item.atomType}_${widget.varName}';
    }
    return title;
  }

  Future<void> _openPreviewDialog(
    BuildContext context,
    List<ScenePreviewItem> items,
    int initialIndex,
  ) async {
    if (items.isEmpty) return;
    final clampedIndex = initialIndex.clamp(0, items.length - 1);
    final previewItems = items.map((item) {
      final previewPath = _previewPath(item);
      final imageUrl = previewPath == null
          ? null
          : widget.client.previewUrl(root: 'varspath', path: previewPath);
      return ImagePreviewItem(
        title: _sceneTitle(item),
        subtitle: item.atomType,
        footer: widget.varName,
        imageUrl: imageUrl,
      );
    }).toList();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return ImagePreviewDialog(
          items: previewItems,
          initialIndex: clampedIndex,
          onIndexChanged: (_) {},
          showFooter: false,
          wrapNavigation: true,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.scenes
        .where((scene) => scene.previewPic != null && scene.previewPic!.isNotEmpty)
        .toList();
    if (items.isEmpty) {
      return const Text('No previews');
    }
    final totalPages = (items.length + _perPage - 1) ~/ _perPage;
    final currentPage = _page.clamp(1, totalPages);
    if (currentPage != _page) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _page = currentPage;
        });
      });
    }
    final startIndex = (currentPage - 1) * _perPage;
    final pageItems = items.skip(startIndex).take(_perPage).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Total ${items.length}'),
            const Spacer(),
            Text('Page $currentPage/$totalPages'),
            IconButton(
              onPressed: currentPage > 1
                  ? () {
                      setState(() {
                        _page = 1;
                      });
                    }
                  : null,
              icon: const Icon(Icons.first_page),
            ),
            IconButton(
              onPressed: currentPage > 1
                  ? () {
                      setState(() {
                        _page -= 1;
                      });
                    }
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              onPressed: currentPage < totalPages
                  ? () {
                      setState(() {
                        _page += 1;
                      });
                    }
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
            IconButton(
              onPressed: currentPage < totalPages
                  ? () {
                      setState(() {
                        _page = totalPages;
                      });
                    }
                  : null,
              icon: const Icon(Icons.last_page),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount =
                (constraints.maxWidth / 140).floor().clamp(2, 6).toInt();
            const spacing = 8.0;
            final tileSize = (constraints.maxWidth -
                    (crossAxisCount - 1) * spacing) /
                crossAxisCount;
            final cacheSize =
                (tileSize * MediaQuery.of(context).devicePixelRatio).round();
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: spacing,
                mainAxisSpacing: spacing,
                childAspectRatio: 1,
              ),
              itemCount: pageItems.length,
              itemBuilder: (context, index) {
                final scene = pageItems[index];
                final previewPath = _previewPath(scene);
                final canPreview = previewPath != null;
                final previewImage = ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: previewPath == null
                      ? const PreviewPlaceholder()
                      : Image.network(
                          widget.client
                              .previewUrl(root: 'varspath', path: previewPath),
                          fit: BoxFit.cover,
                          cacheWidth: cacheSize,
                          cacheHeight: cacheSize,
                          errorBuilder: (_, _, _) => const PreviewPlaceholder(
                            icon: Icons.broken_image,
                          ),
                        ),
                );
                return GestureDetector(
                  onDoubleTap: canPreview
                      ? () => _openPreviewDialog(
                            context,
                            items,
                            startIndex + index,
                          )
                      : null,
                  child: previewImage,
                );
              },
            );
          },
        ),
      ],
    );
  }
}

