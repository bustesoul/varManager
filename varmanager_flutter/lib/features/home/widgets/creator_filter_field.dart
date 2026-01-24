import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class CreatorFilterField extends StatefulWidget {
  const CreatorFilterField({
    super.key,
    required this.label,
    required this.hintText,
    required this.selections,
    required this.onChanged,
    this.onListPressed,
    this.listTooltip,
  });

  final String label;
  final String hintText;
  final List<String> selections;
  final ValueChanged<List<String>> onChanged;
  final VoidCallback? onListPressed;
  final String? listTooltip;

  @override
  State<CreatorFilterField> createState() => _CreatorFilterFieldState();
}

class _CreatorFilterFieldState extends State<CreatorFilterField> {
  final TextEditingController _controller = TextEditingController();
  bool _suppressChange = false;
  static const double _chipAreaHeight = 28;
  static const double _chipMaxWidthRatio = 0.5;

  @override
  void didUpdateWidget(covariant CreatorFilterField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.selections, widget.selections) &&
        widget.selections.isEmpty) {
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleInputChanged(String value) {
    if (_suppressChange) return;
    if (!value.contains(',')) return;
    final parts = value.split(',');
    if (parts.length <= 1) return;
    for (var i = 0; i < parts.length - 1; i += 1) {
      _commitEntry(parts[i]);
    }
    final tail = parts.last.trimLeft();
    _suppressChange = true;
    _controller.text = tail;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: tail.length),
    );
    _suppressChange = false;
  }

  void _commitEntry(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return;
    final next = List<String>.from(widget.selections);
    if (_containsIgnoreCase(next, trimmed)) return;
    next.add(trimmed);
    widget.onChanged(next);
  }

  void _commitAndClear() {
    _commitEntry(_controller.text);
    _controller.clear();
  }

  bool _containsIgnoreCase(List<String> values, String target) {
    final needle = target.toLowerCase();
    for (final value in values) {
      if (value.toLowerCase() == needle) {
        return true;
      }
    }
    return false;
  }

  void _removeCreator(String name) {
    final next = widget.selections
        .where((value) => value.toLowerCase() != name.toLowerCase())
        .toList();
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final hasSelections = widget.selections.isNotEmpty;
        final maxChipWidth = (constraints.maxWidth * _chipMaxWidthRatio)
            .clamp(0.0, 140.0)
            .toDouble();
        return TextField(
          controller: _controller,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hintText,
            border: const OutlineInputBorder(),
            prefixIcon: hasSelections
                ? Padding(
                    padding: const EdgeInsets.only(left: 8, right: 6),
                    child: SizedBox(
                      width: maxChipWidth,
                      height: _chipAreaHeight,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final creator in widget.selections)
                                Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Chip(
                                    label: Text(
                                      creator,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    onDeleted: () => _removeCreator(creator),
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    labelPadding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                    ),
                                    padding: EdgeInsets.zero,
                                    deleteIcon: const Icon(Icons.close, size: 14),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : null,
            prefixIconConstraints: hasSelections
                ? BoxConstraints(
                    minWidth: 0,
                    maxWidth: maxChipWidth + 14,
                    minHeight: 0,
                    maxHeight: _chipAreaHeight,
                  )
                : null,
            suffixIcon: widget.onListPressed == null
                ? null
                : IconButton(
                    onPressed: widget.onListPressed,
                    icon: const Icon(Icons.arrow_drop_down),
                    tooltip: widget.listTooltip,
                  ),
          ),
          onChanged: _handleInputChanged,
          onSubmitted: (_) => _commitAndClear(),
        );
      },
    );
  }
}
