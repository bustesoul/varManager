import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/models/extra_models.dart';
import '../../../core/utils/debounce.dart';
import '../../../l10n/l10n.dart';

class CreatorListDialog extends ConsumerStatefulWidget {
  const CreatorListDialog({super.key});

  @override
  ConsumerState<CreatorListDialog> createState() => _CreatorListDialogState();
}

class _CreatorListDialogState extends ConsumerState<CreatorListDialog> {
  static const int _pageSize = 200;
  static const double _scrollThreshold = 80;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Debouncer _debouncer = Debouncer(const Duration(milliseconds: 250));

  int _offset = 0;
  bool _loading = false;
  bool _hasMore = true;
  String _query = '';
  String? _prefix;
  String? _error;
  int _requestId = 0;
  List<String> _creators = [];
  final Map<String, CreatorStatsItem> _stats = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    Future.microtask(_loadFirstPage);
  }

  @override
  void dispose() {
    _debouncer.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients || !_hasMore || _loading) return;
    if (_scrollController.position.extentAfter <= _scrollThreshold) {
      _loadMore();
    }
  }

  void _onSearchChanged(String value) {
    _debouncer.run(() {
      _query = value.trim();
      _loadFirstPage();
    });
  }

  void _togglePrefix(String value) {
    setState(() {
      _prefix = _prefix == value ? null : value;
    });
    _loadFirstPage();
  }

  Future<void> _loadFirstPage() async {
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
      _offset = 0;
      _hasMore = true;
      _creators = [];
      _stats.clear();
    });
    await _loadPage(requestId: requestId, reset: true);
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    final requestId = _requestId;
    setState(() {
      _loading = true;
    });
    await _loadPage(requestId: requestId, reset: false);
  }

  Future<void> _loadPage({required int requestId, required bool reset}) async {
    final client = ref.read(backendClientProvider);
    try {
      final creators = await client.listCreators(
        query: _query.isEmpty ? null : _query,
        offset: _offset,
        limit: _pageSize,
        prefix: _prefix,
      );
      if (!mounted || requestId != _requestId) return;
      setState(() {
        if (reset) {
          _creators = creators;
        } else {
          _creators = [..._creators, ...creators];
        }
        _offset = _creators.length;
        _hasMore = creators.length >= _pageSize;
        _loading = false;
      });
      if (creators.isNotEmpty) {
        final stats = await client.listCreatorStats(names: creators);
        if (!mounted || requestId != _requestId) return;
        setState(() {
          for (final item in stats.items) {
            _stats[item.name] = item;
          }
        });
      }
    } catch (err) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _error = err.toString();
        _loading = false;
        _hasMore = false;
      });
    }
  }

  Widget _buildList() {
    final l10n = context.l10n;
    if (_error != null) {
      return Center(child: Text(l10n.loadFailed(_error!)));
    }
    if (_creators.isEmpty) {
      if (_loading) {
        return const Center(child: CircularProgressIndicator());
      }
      return Center(
        child: Text(_query.isEmpty ? l10n.creatorListEmpty : l10n.noMatches),
      );
    }
    final showLoadingRow = _loading && _creators.isNotEmpty;
    return ListView.builder(
      controller: _scrollController,
      itemCount: _creators.length + (showLoadingRow ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _creators.length) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final name = _creators[index];
        final stats = _stats[name];
        return ListTile(
          dense: true,
          title: Text(name),
          subtitle: stats == null
              ? null
              : Text(l10n.creatorStatsLabel(
                  stats.varCount,
                  stats.installedCount,
                )),
          onTap: () => Navigator.of(context).pop(name),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final letters = List<String>.generate(
      26,
      (index) => String.fromCharCode(65 + index),
    )..add('#');

    return AlertDialog(
      title: Text(l10n.creatorListTitle),
      content: SizedBox(
        width: 560,
        height: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: l10n.creatorListSearchLabel,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(''),
                  child: Text(l10n.creatorListClearLabel),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final letter in letters)
                  ChoiceChip(
                    label: Text(letter),
                    selected: _prefix == letter,
                    onSelected: (_) => _togglePrefix(letter),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildList()),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonClose),
        ),
      ],
    );
  }
}
