import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/models/extra_models.dart';

class UninstallVarsPage extends ConsumerStatefulWidget {
  const UninstallVarsPage({super.key, required this.payload});

  final Map<String, dynamic> payload;

  @override
  ConsumerState<UninstallVarsPage> createState() => _UninstallVarsPageState();
}

class _UninstallVarsPageState extends ConsumerState<UninstallVarsPage> {
  late final List<String> _varList;
  late final Set<String> _requested;
  late final Set<String> _implicated;

  final Set<String> _selectedVars = {};
  List<VarPreviewItem> _previews = [];
  List<VarDependencyItem> _dependencies = [];
  bool _loadingDetails = false;

  String _previewType = 'all';
  int _previewPage = 1;
  final int _previewPerPage = 60;

  @override
  void initState() {
    super.initState();
    _varList = (widget.payload['var_list'] as List<dynamic>? ?? [])
        .map((item) => item.toString())
        .toList();
    _requested = (widget.payload['requested'] as List<dynamic>? ?? [])
        .map((item) => item.toString())
        .toSet();
    _implicated = (widget.payload['implicated'] as List<dynamic>? ?? [])
        .map((item) => item.toString())
        .toSet();
    _selectedVars.addAll(_varList);
    Future.microtask(_loadDetails);
  }

  Future<void> _loadDetails() async {
    if (_selectedVars.isEmpty) {
      setState(() {
        _previews = [];
        _dependencies = [];
        _loadingDetails = false;
        _previewPage = 1;
      });
      return;
    }
    setState(() {
      _loadingDetails = true;
    });
    final client = ref.read(backendClientProvider);
    final names = _selectedVars.toList();
    final previews = await client.listVarPreviews(names);
    final deps = await client.listVarDependencies(names);
    if (!mounted) return;
    setState(() {
      _previews = previews.items;
      _dependencies = deps.items;
      _loadingDetails = false;
      _previewPage = 1;
    });
  }

  List<VarPreviewItem> get _filteredPreviews {
    if (_previewType == 'all') return _previews;
    return _previews.where((item) => item.atomType == _previewType).toList();
  }

  int get _previewTotalPages {
    final total = _filteredPreviews.length;
    return total == 0 ? 1 : (total + _previewPerPage - 1) ~/ _previewPerPage;
  }

  List<VarPreviewItem> get _pagedPreviews {
    final totalPages = _previewTotalPages;
    final page = _previewPage.clamp(1, totalPages);
    final start = (page - 1) * _previewPerPage;
    final end = start + _previewPerPage;
    return _filteredPreviews.sublist(
      start,
      end > _filteredPreviews.length ? _filteredPreviews.length : end,
    );
  }

  void _toggleVar(String name, bool selected) {
    setState(() {
      if (selected) {
        _selectedVars.add(name);
      } else {
        _selectedVars.remove(name);
      }
    });
    _loadDetails();
  }

  void _selectAll() {
    setState(() {
      _selectedVars
        ..clear()
        ..addAll(_varList);
    });
    _loadDetails();
  }

  void _clearSelection() {
    setState(() {
      _selectedVars.clear();
    });
    _loadDetails();
  }

  Future<void> _showPreview(VarPreviewItem item) async {
    final client = ref.read(backendClientProvider);
    final path =
        '___PreviewPics___/${item.atomType}/${item.varName}/${item.previewPic}';
    final url = client.previewUrl(root: 'varspath', path: path);
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(item.varName),
          content: Image.network(
            url,
            width: 480,
            height: 480,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const SizedBox(
              width: 240,
              height: 240,
              child: Center(child: Icon(Icons.broken_image)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dependencies = _dependencies
        .map((item) => item.dependency)
        .toSet()
        .toList()
      ..sort();

    return Scaffold(
      appBar: AppBar(title: const Text('Uninstall Preview')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: 320,
                    child: Card(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Will uninstall ${_varList.length} packages'),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    TextButton(
                                      onPressed: _selectAll,
                                      child: const Text('Select All'),
                                    ),
                                    TextButton(
                                      onPressed: _clearSelection,
                                      child: const Text('Clear'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          Expanded(
                            child: ListView.separated(
                              itemCount: _varList.length,
                              separatorBuilder: (_, _) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final name = _varList[index];
                                final tags = <String>[];
                                if (_requested.contains(name)) tags.add('Requested');
                                if (_implicated.contains(name)) tags.add('Implicated');
                                final selected = _selectedVars.contains(name);
                                return CheckboxListTile(
                                  value: selected,
                                  onChanged: (value) => _toggleVar(name, value ?? false),
                                  title: Text(name),
                                  subtitle: tags.isEmpty ? null : Text(tags.join(' - ')),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text('Previews (${_filteredPreviews.length})'),
                                      const Spacer(),
                                      if (_loadingDetails)
                                        const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
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
                                        ],
                                        onChanged: (value) {
                                          if (value == null) return;
                                          setState(() {
                                            _previewType = value;
                                            _previewPage = 1;
                                          });
                                        },
                                      ),
                                      const Spacer(),
                                      Text('Page $_previewPage / $_previewTotalPages'),
                                      IconButton(
                                        onPressed: _previewPage <= 1
                                            ? null
                                            : () {
                                                setState(() {
                                                  _previewPage = 1;
                                                });
                                              },
                                        icon: const Icon(Icons.first_page),
                                      ),
                                      IconButton(
                                        onPressed: _previewPage <= 1
                                            ? null
                                            : () {
                                                setState(() {
                                                  _previewPage -= 1;
                                                });
                                              },
                                        icon: const Icon(Icons.chevron_left),
                                      ),
                                      IconButton(
                                        onPressed: _previewPage >= _previewTotalPages
                                            ? null
                                            : () {
                                                setState(() {
                                                  _previewPage += 1;
                                                });
                                              },
                                        icon: const Icon(Icons.chevron_right),
                                      ),
                                      IconButton(
                                        onPressed: _previewPage >= _previewTotalPages
                                            ? null
                                            : () {
                                                setState(() {
                                                  _previewPage = _previewTotalPages;
                                                });
                                              },
                                        icon: const Icon(Icons.last_page),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    child: _pagedPreviews.isEmpty
                                        ? const Center(child: Text('No previews'))
                                        : LayoutBuilder(
                                            builder: (context, constraints) {
                                              final columns = constraints.maxWidth > 1200
                                                  ? 6
                                                  : constraints.maxWidth > 900
                                                      ? 5
                                                      : constraints.maxWidth > 700
                                                          ? 4
                                                          : 3;
                                              return GridView.builder(
                                                gridDelegate:
                                                    SliverGridDelegateWithFixedCrossAxisCount(
                                                  crossAxisCount: columns,
                                                  crossAxisSpacing: 8,
                                                  mainAxisSpacing: 8,
                                                  childAspectRatio: 1,
                                                ),
                                                itemCount: _pagedPreviews.length,
                                                itemBuilder: (context, index) {
                                                  final item = _pagedPreviews[index];
                                                  final client = ref.read(backendClientProvider);
                                                  final path =
                                                      '___PreviewPics___/${item.atomType}/${item.varName}/${item.previewPic}';
                                                  final url = client.previewUrl(
                                                      root: 'varspath', path: path);
                                                  return InkWell(
                                                    onTap: () => _showPreview(item),
                                                    child: ClipRRect(
                                                      borderRadius: BorderRadius.circular(8),
                                                      child: Image.network(
                                                        url,
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (_, _, _) => Container(
                                                          color: Colors.grey.shade200,
                                                          child: const Icon(Icons.broken_image),
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              );
                                            },
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Dependencies (${dependencies.length})'),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    child: dependencies.isEmpty
                                        ? const Center(child: Text('No dependencies'))
                                        : ListView.builder(
                                            itemCount: dependencies.length,
                                            itemBuilder: (context, index) {
                                              return ListTile(
                                                dense: true,
                                                title: Text(dependencies[index]),
                                              );
                                            },
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Confirm'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
