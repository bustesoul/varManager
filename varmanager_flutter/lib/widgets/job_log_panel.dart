import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/backend/job_log_controller.dart';

class JobLogPanel extends ConsumerStatefulWidget {
  const JobLogPanel({super.key});

  @override
  ConsumerState<JobLogPanel> createState() => _JobLogPanelState();
}

class _JobLogPanelState extends ConsumerState<JobLogPanel> {
  final ScrollController _scrollController = ScrollController();

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

  @override
  Widget build(BuildContext context) {
    final logs = ref.watch(jobLogProvider);

    // 当日志更新时自动滚动到底部
    if (logs.isNotEmpty) {
      _scrollToBottom();
    }

    if (logs.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 160,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Job Logs', style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              TextButton(
                onPressed: () => ref.read(jobLogProvider.notifier).clear(),
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Scrollbar(
              controller: _scrollController,
              child: ListView.builder(
                controller: _scrollController,
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  return Text(
                    logs[index],
                    style: const TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
