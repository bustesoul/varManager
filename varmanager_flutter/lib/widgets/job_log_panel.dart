import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/backend/job_log_controller.dart';
import '../l10n/l10n.dart';

class JobLogPanel extends ConsumerStatefulWidget {
  const JobLogPanel({super.key});

  @override
  ConsumerState<JobLogPanel> createState() => _JobLogPanelState();
}

class _JobLogPanelState extends ConsumerState<JobLogPanel> {
  final ScrollController _scrollController = ScrollController();
  static const double _expandedHeight = 160;
  static const double _collapsedHeight = 36;
  bool _isExpanded = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  IconButton _buildToggleButton() {
    final l10n = context.l10n;
    return IconButton(
      onPressed: _toggleExpanded,
      icon: Icon(_isExpanded ? Icons.expand_more : Icons.expand_less),
      tooltip: _isExpanded
          ? l10n.jobLogCollapseTooltip
          : l10n.jobLogExpandTooltip,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      visualDensity: VisualDensity.compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final logs = ref.watch(jobLogProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final latestLine = logs.isNotEmpty ? logs.last.format() : '';
    final buttonStyle = TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    // 当日志更新时自动滚动到底部
    if (_isExpanded && logs.isNotEmpty) {
      _scrollToBottom();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      height: _isExpanded ? _expandedHeight : _collapsedHeight,
      margin: const EdgeInsets.all(12),
      padding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: _isExpanded ? 12 : 6,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: _isExpanded
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      l10n.jobLogsTitle,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    _buildToggleButton(),
                    const SizedBox(width: 4),
                    TextButton(
                      onPressed: () =>
                          ref.read(jobLogProvider.notifier).clear(),
                      style: buttonStyle,
                      child: Text(l10n.commonClear),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Scrollbar(
                    controller: _scrollController,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: SelectableText(
                        logs.map((entry) => entry.format()).join('\n'),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Text(
                  l10n.jobLogsTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    latestLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withValues(alpha: 0.75),
                    ),
                  ),
                ),
                _buildToggleButton(),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: () => ref.read(jobLogProvider.notifier).clear(),
                  style: buttonStyle,
                  child: Text(l10n.commonClear),
                ),
              ],
            ),
    );
  }
}
