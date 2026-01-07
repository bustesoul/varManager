import 'dart:async';

import 'package:flutter/material.dart';

class LazyDropdownField extends StatefulWidget {
  const LazyDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.optionsLoader,
    this.pageSize = 10,
    this.minQueryLength = 1,
    this.allValue = 'ALL',
    this.allLabel = 'All',
    this.debounce = const Duration(milliseconds: 250),
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final Future<List<String>> Function(String query, int offset, int limit)
      optionsLoader;
  final int pageSize;
  final int minQueryLength;
  final String allValue;
  final String allLabel;
  final Duration debounce;

  @override
  State<LazyDropdownField> createState() => _LazyDropdownFieldState();
}

class _LazyDropdownFieldState extends State<LazyDropdownField> {
  final LayerLink _layerLink = LayerLink();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  OverlayEntry? _overlayEntry;
  Timer? _debounceTimer;
  Timer? _blurTimer;

  List<String> _options = [];
  bool _loading = false;
  bool _hasMore = false;
  String _query = '';
  int _offset = 0;
  int _queryVersion = 0;
  bool _suspendTextChange = false;
  bool _skipCommitOnce = false;

  @override
  void initState() {
    super.initState();
    _controller.text = _displayText(widget.value);
    _focusNode.addListener(_handleFocusChanged);
    _scrollController.addListener(_handleScroll);
  }

  @override
  void didUpdateWidget(covariant LazyDropdownField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && !_focusNode.hasFocus) {
      _setControllerText(_displayText(widget.value));
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _blurTimer?.cancel();
    _closeOverlay();
    _scrollController.dispose();
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (!_focusNode.hasFocus) {
      if (_overlayEntry != null) {
        _blurTimer?.cancel();
        _blurTimer = Timer(const Duration(milliseconds: 120), () {
          if (!mounted || _focusNode.hasFocus) return;
          if (_skipCommitOnce) {
            _skipCommitOnce = false;
          } else {
            _commitText();
          }
          _closeOverlay();
        });
        return;
      }
      if (_skipCommitOnce) {
        _skipCommitOnce = false;
      } else {
        _commitText();
      }
      _closeOverlay();
      return;
    }
    if (widget.value == widget.allValue) {
      _setControllerText('');
    } else {
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    }
  }

  String _displayText(String value) {
    if (value == widget.allValue) {
      return widget.allLabel;
    }
    return value;
  }

  void _setControllerText(String value) {
    _suspendTextChange = true;
    _controller.text = value;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: _controller.text.length),
    );
    _suspendTextChange = false;
  }

  void _commitText() {
    final text = _controller.text.trim();
    if (text.isEmpty || text == widget.allLabel) {
      _applySelection(widget.allValue);
      return;
    }
    _applySelection(text);
  }

  void _applySelection(String value) {
    widget.onChanged(value);
    _setControllerText(_displayText(value));
  }

  void _onTextChanged(String value) {
    if (_suspendTextChange) return;
    _debounceTimer?.cancel();
    final text = value.trim();
    if (text.length < widget.minQueryLength) {
      _query = '';
      _options = [];
      _hasMore = false;
      _loading = false;
      _closeOverlay();
      setState(() {});
      return;
    }
    _debounceTimer = Timer(widget.debounce, () {
      _query = text;
      _loadFirstPage();
    });
  }

  Future<void> _loadFirstPage() async {
    _queryVersion += 1;
    final requestId = _queryVersion;
    setState(() {
      _loading = true;
      _options = [];
      _hasMore = false;
      _offset = 0;
    });
    _openOverlay();
    final items =
        await widget.optionsLoader(_query, _offset, widget.pageSize);
    if (!mounted || requestId != _queryVersion) return;
    setState(() {
      _options = items;
      _offset = items.length;
      _hasMore = items.length >= widget.pageSize;
      _loading = false;
    });
    _overlayEntry?.markNeedsBuild();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    _loading = true;
    _overlayEntry?.markNeedsBuild();
    final requestId = _queryVersion;
    final items =
        await widget.optionsLoader(_query, _offset, widget.pageSize);
    if (!mounted || requestId != _queryVersion) return;
    setState(() {
      _options = [..._options, ...items];
      _offset += items.length;
      _hasMore = items.length >= widget.pageSize;
      _loading = false;
    });
    _overlayEntry?.markNeedsBuild();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients || !_hasMore || _loading) return;
    final position = _scrollController.position;
    if (position.extentAfter < 60) {
      _loadMore();
    }
  }

  void _openOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry?.markNeedsBuild();
      return;
    }
    final overlay = Overlay.of(context);
    _overlayEntry = _buildOverlayEntry();
    overlay.insert(_overlayEntry!);
  }

  void _closeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _buildOverlayEntry() {
    final renderBox = context.findRenderObject() as RenderBox?;
    final size = renderBox?.size ?? const Size(240, 40);
    return OverlayEntry(
      builder: (context) {
        return Positioned(
          width: size.width,
          child: CompositedTransformFollower(
            link: _layerLink,
            offset: Offset(0, size.height + 4),
            showWhenUnlinked: false,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: _buildOptionsList(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionsList() {
    final items = _options;
    final showEmpty = !_loading && items.isEmpty;
    final displayItems = <String>[];
    if (!items.contains(widget.allValue)) {
      displayItems.add(widget.allValue);
    }
    displayItems.addAll(items);
    final itemCount = displayItems.length +
        (showEmpty ? 1 : 0) +
        (_loading ? 1 : 0);
    return ListView.builder(
      controller: _scrollController,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index < displayItems.length) {
          final value = displayItems[index];
          final label = value == widget.allValue ? widget.allLabel : value;
          return ListTile(
            dense: true,
            title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () {
              _skipCommitOnce = true;
              _applySelection(value);
              _closeOverlay();
              _focusNode.unfocus();
            },
          );
        }
        if (showEmpty && index == displayItems.length) {
          return const ListTile(
            dense: true,
            title: Text('No matches'),
          );
        }
        return const Padding(
          padding: EdgeInsets.all(12),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        decoration: InputDecoration(
          labelText: widget.label,
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            icon: const Icon(Icons.clear),
            tooltip: widget.allLabel,
            onPressed: () {
              _applySelection(widget.allValue);
              _closeOverlay();
              _focusNode.unfocus();
            },
          ),
        ),
        onChanged: _onTextChanged,
        onSubmitted: (_) {
          _commitText();
          _closeOverlay();
        },
      ),
    );
  }
}
