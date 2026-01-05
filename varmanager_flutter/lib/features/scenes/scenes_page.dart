import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../app/providers.dart';
import '../../core/backend/job_log_controller.dart';
import '../../core/backend/query_params.dart';
import '../../core/models/scene_models.dart';
import '../analysis/analysis_page.dart';

final scenesQueryProvider = StateProvider<ScenesQueryParams>((ref) {
  return ScenesQueryParams();
});

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

class _ScenesPageState extends ConsumerState<ScenesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _merge = false;
  bool _ignoreGender = false;
  bool _forMale = false;
  int _personOrder = 1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(scenesQueryProvider.notifier).update(
            (state) => state.copyWith(hideFav: 'hide'),
          );
    });
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final hideFav = switch (_tabController.index) {
          0 => 'hide',
          1 => 'normal',
          _ => 'fav',
        };
        ref.read(scenesQueryProvider.notifier).update(
              (state) => state.copyWith(hideFav: hideFav),
            );
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _runJob(String kind, Map<String, dynamic> args) async {
    final runner = ref.read(jobRunnerProvider);
    final log = ref.read(jobLogProvider.notifier);
    await runner.runJob(kind, args: args, onLog: log.addLine);
  }

  @override
  Widget build(BuildContext context) {
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
                children: [
                  DropdownButton<String>(
                    value: query.category,
                    items: const [
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
                              child: Text(item),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      ref.read(scenesQueryProvider.notifier).update(
                            (state) => state.copyWith(category: value),
                          );
                    },
                  ),
                  SizedBox(
                    width: 220,
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Name filter',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        ref.read(scenesQueryProvider.notifier).update(
                              (state) => state.copyWith(search: value),
                            );
                      },
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Creator',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        ref.read(scenesQueryProvider.notifier).update(
                              (state) => state.copyWith(creator: value),
                            );
                      },
                    ),
                  ),
                  DropdownButton<String>(
                    value: query.sort,
                    items: const [
                      DropdownMenuItem(value: 'var_date', child: Text('New to Old')),
                      DropdownMenuItem(value: 'meta_date', child: Text('Meta Date')),
                      DropdownMenuItem(value: 'var_name', child: Text('VarName')),
                      DropdownMenuItem(value: 'scene_name', child: Text('SceneName')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      ref.read(scenesQueryProvider.notifier).update(
                            (state) => state.copyWith(sort: value),
                          );
                    },
                  ),
                  FilterChip(
                    label: const Text('Merge'),
                    selected: _merge,
                    onSelected: (value) {
                      setState(() {
                        _merge = value;
                      });
                    },
                  ),
                  FilterChip(
                    label: const Text('Ignore Gender'),
                    selected: _ignoreGender,
                    onSelected: (value) {
                      setState(() {
                        _ignoreGender = value;
                      });
                    },
                  ),
                  FilterChip(
                    label: const Text('For Male'),
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
                              child: Text('Person $value'),
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
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Hide'),
              Tab(text: 'Normal'),
              Tab(text: 'Fav'),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: scenesAsync.when(
              data: (data) => _buildList(context, data.items),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Load failed: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, List<SceneListItem> items) {
    final client = ref.read(backendClientProvider);
    return Card(
      child: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = items[index];
          final previewPath = item.previewPic == null || item.previewPic!.isEmpty
              ? null
              : '___PreviewPics___/${item.atomType}/${item.varName}/${item.previewPic}';
          final title = p.basenameWithoutExtension(item.scenePath);
          return ListTile(
            leading: previewPath == null
                ? const Icon(Icons.image_not_supported)
                : ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      client.previewUrl(root: 'varspath', path: previewPath),
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 56,
                        height: 56,
                        color: Colors.grey.shade200,
                        alignment: Alignment.center,
                        child: const Icon(Icons.broken_image),
                      ),
                    ),
                  ),
            title: Text('$title (${item.atomType})'),
            subtitle: Text(item.varName),
            trailing: Wrap(
              spacing: 6,
              children: [
                TextButton(
                  onPressed: () async {
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
                  },
                  child: const Text('Load'),
                ),
                TextButton(
                  onPressed: () async {
                    final runner = ref.read(jobRunnerProvider);
                    final log = ref.read(jobLogProvider.notifier);
                    final result = await runner.runJob('scene_analyze',
                        args: {
                          'save_name':
                              '${item.varName}:/${item.scenePath.replaceAll('\\', '/')}',
                          'character_gender': _forMale ? 'male' : 'female',
                        },
                        onLog: log.addLine);
                    final payload = result.result as Map<String, dynamic>?;
                    if (payload == null || !context.mounted) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AnalysisPage(payload: payload),
                      ),
                    );
                  },
                  child: const Text('Analyze'),
                ),
                TextButton(
                  onPressed: () async {
                    await _runJob('vars_locate', {'var_name': item.varName});
                  },
                  child: const Text('Locate'),
                ),
                TextButton(
                  onPressed: () async {
                    await _runJob('cache_clear', {
                      'var_name': item.varName,
                      'entry_name': item.scenePath,
                    });
                  },
                  child: const Text('Clear cache'),
                ),
                TextButton(
                  onPressed: () async {
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
                  },
                  child: Text(item.hide ? 'Unhide' : 'Hide'),
                ),
                TextButton(
                  onPressed: () async {
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
                  },
                  child: Text(item.fav ? 'Unfav' : 'Fav'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
