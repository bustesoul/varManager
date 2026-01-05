import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/backend/job_log_controller.dart';
import '../../core/backend/job_runner.dart';
import '../../core/models/var_models.dart';
import '../home/home_page.dart';

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
        args: {'var_name': varName}, onLog: log.addLine);
  }

  Future<void> _runJob(WidgetRef ref, String kind, Map<String, dynamic> args) async {
    final runner = ref.read(jobRunnerProvider);
    final log = ref.read(jobLogProvider.notifier);
    await runner.runJob(kind, args: args, onLog: log.addLine);
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
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: detail.scenes
                        .where((scene) =>
                            scene.previewPic != null &&
                            scene.previewPic!.isNotEmpty)
                        .map((scene) {
                      final path =
                          '___PreviewPics___/${scene.atomType}/${detail.varInfo.varName}/${scene.previewPic}';
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          client.previewUrl(root: 'varspath', path: path),
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 120,
                            height: 120,
                            color: Colors.grey.shade200,
                            alignment: Alignment.center,
                            child: const Icon(Icons.broken_image),
                          ),
                        ),
                      );
                    }).toList(),
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
