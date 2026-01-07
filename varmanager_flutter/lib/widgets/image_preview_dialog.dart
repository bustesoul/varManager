import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';

import 'preview_placeholder.dart';

class ImagePreviewItem {
  const ImagePreviewItem({
    required this.title,
    this.subtitle = '',
    this.footer = '',
    this.imageUrl,
    this.headers,
  });

  final String title;
  final String subtitle;
  final String footer;
  final String? imageUrl;
  final Map<String, String>? headers;
}

class ImagePreviewDialog extends StatefulWidget {
  const ImagePreviewDialog({
    super.key,
    required this.items,
    required this.initialIndex,
    required this.onIndexChanged,
    this.showHeaderText = true,
    this.showFooter = true,
    this.wrapNavigation = false,
  });

  final List<ImagePreviewItem> items;
  final int initialIndex;
  final ValueChanged<int> onIndexChanged;
  final bool showHeaderText;
  final bool showFooter;
  final bool wrapNavigation;

  @override
  State<ImagePreviewDialog> createState() => _ImagePreviewDialogState();
}

class _ImagePreviewDialogState extends State<ImagePreviewDialog> {
  static const double _minScale = 0.5;
  static const double _maxScale = 4.0;

  late int currentIndex;
  late TransformationController transformationController;
  double currentZoom = 1.0;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex.clamp(0, widget.items.length - 1);
    transformationController = TransformationController();
    transformationController.addListener(_onTransformChanged);
  }

  @override
  void dispose() {
    transformationController.removeListener(_onTransformChanged);
    transformationController.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    final newZoom = transformationController.value.getMaxScaleOnAxis();
    if ((newZoom - currentZoom).abs() > 0.001) {
      setState(() {
        currentZoom = newZoom;
      });
    }
  }

  void _handlePointerSignal(
    BuildContext context,
    PointerSignalEvent event,
  ) {
    if (event is! PointerScrollEvent) {
      return;
    }
    if (event.scrollDelta.dy == 0) {
      return;
    }
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) {
      return;
    }
    final localFocal = renderBox.globalToLocal(event.position);
    final currentScale = transformationController.value.getMaxScaleOnAxis();
    final delta = -event.scrollDelta.dy * 0.001;
    final targetScale = (currentScale * (1 + delta)).clamp(_minScale, _maxScale);
    if (targetScale == currentScale) {
      return;
    }
    final scaleFactor = targetScale / currentScale;
    final next = transformationController.value.clone()
      ..translate(localFocal.dx, localFocal.dy)
      ..scale(scaleFactor)
      ..translate(-localFocal.dx, -localFocal.dy);
    transformationController.value = next;
  }

  void _setIndex(int next) {
    final clamped = next.clamp(0, widget.items.length - 1);
    if (clamped == currentIndex) return;
    setState(() {
      currentIndex = clamped;
      transformationController.value = Matrix4.identity();
    });
    widget.onIndexChanged(clamped);
  }

  void _stepIndex(int delta) {
    final count = widget.items.length;
    if (count <= 1) return;
    var next = currentIndex + delta;
    if (widget.wrapNavigation) {
      next %= count;
      if (next < 0) {
        next += count;
      }
    } else if (next < 0 || next >= count) {
      return;
    }
    _setIndex(next);
  }

  String _titleText(ImagePreviewItem item) {
    if (item.subtitle.isEmpty) {
      return item.title;
    }
    if (item.title.isEmpty) {
      return item.subtitle;
    }
    return '${item.title} (${item.subtitle})';
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.items[currentIndex];
    final imageUrl = item.imageUrl;
    final size = MediaQuery.of(context).size;
    final dialogWidth = size.width * 0.95;
    final dialogHeight = size.height * 0.95;
    final canNavigate = widget.items.length > 1;
    final showSideNavigation = !widget.showFooter && canNavigate;
    final canGoPrev = widget.wrapNavigation || currentIndex > 0;
    final canGoNext = widget.wrapNavigation || currentIndex < widget.items.length - 1;

    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.escape): const _DismissIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowLeft):
            const _PreviousImageIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowRight):
            const _NextImageIntent(),
      },
      child: Actions(
        actions: {
          _DismissIntent: CallbackAction<_DismissIntent>(
            onInvoke: (_) {
              Navigator.of(context).pop();
              return null;
            },
          ),
          _PreviousImageIntent: CallbackAction<_PreviousImageIntent>(
            onInvoke: (_) {
              _stepIndex(-1);
              return null;
            },
          ),
          _NextImageIntent: CallbackAction<_NextImageIntent>(
            onInvoke: (_) {
              _stepIndex(1);
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Dialog(
            insetPadding: const EdgeInsets.all(16),
            child: SizedBox(
              width: dialogWidth,
              height: dialogHeight,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: widget.showHeaderText
                              ? Text(
                                  _titleText(item),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: Container(
                      color: Colors.black,
                      child: Row(
                        children: [
                          Expanded(
                            child: imageUrl == null || imageUrl.isEmpty
                                ? const PreviewPlaceholder()
                                : LayoutBuilder(
                                    builder: (viewerContext, constraints) {
                                      final boundary = EdgeInsets.all(
                                        constraints.biggest.longestSide *
                                            (1 / _minScale - 1) /
                                            2,
                                      );
                                      return Listener(
                                        onPointerSignal: (event) =>
                                            _handlePointerSignal(
                                          viewerContext,
                                          event,
                                        ),
                                        child: InteractiveViewer(
                                          transformationController:
                                              transformationController,
                                          minScale: _minScale,
                                          maxScale: _maxScale,
                                          boundaryMargin: boundary,
                                          child: Image.network(
                                            imageUrl,
                                            headers: item.headers,
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, _, _) =>
                                                const PreviewPlaceholder(
                                              icon: Icons.broken_image,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white24,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (showSideNavigation)
                                  IconButton(
                                    onPressed: canGoPrev
                                        ? () => _stepIndex(-1)
                                        : null,
                                    icon: const Icon(
                                      Icons.keyboard_arrow_up,
                                      color: Colors.white70,
                                    ),
                                    tooltip: 'Previous',
                                  ),
                                const Icon(
                                  Icons.zoom_in,
                                  color: Colors.white70,
                                  size: 20,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${currentZoom.toStringAsFixed(2)}x',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Scroll',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 10,
                                  ),
                                ),
                                if (showSideNavigation)
                                  IconButton(
                                    onPressed: canGoNext
                                        ? () => _stepIndex(1)
                                        : null,
                                    icon: const Icon(
                                      Icons.keyboard_arrow_down,
                                      color: Colors.white70,
                                    ),
                                    tooltip: 'Next',
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                      ),
                    ),
                  ),
                  if (widget.showFooter) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed:
                                currentIndex > 0 ? () => _setIndex(0) : null,
                            icon: const Icon(Icons.first_page),
                          ),
                          IconButton(
                            onPressed: currentIndex > 0
                                ? () => _setIndex(currentIndex - 1)
                                : null,
                            icon: const Icon(Icons.chevron_left),
                          ),
                          Text(
                            '${currentIndex + 1}/${widget.items.length}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          IconButton(
                            onPressed: currentIndex < widget.items.length - 1
                                ? () => _setIndex(currentIndex + 1)
                                : null,
                            icon: const Icon(Icons.chevron_right),
                          ),
                          IconButton(
                            onPressed: currentIndex < widget.items.length - 1
                                ? () =>
                                    _setIndex(widget.items.length - 1)
                                : null,
                            icon: const Icon(Icons.last_page),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item.footer,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DismissIntent extends Intent {
  const _DismissIntent();
}

class _PreviousImageIntent extends Intent {
  const _PreviousImageIntent();
}

class _NextImageIntent extends Intent {
  const _NextImageIntent();
}
