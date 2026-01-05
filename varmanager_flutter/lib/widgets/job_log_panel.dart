import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/backend/job_log_controller.dart';

class JobLogPanel extends ConsumerWidget {
  const JobLogPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(jobLogProvider);
    return Container(
      height: 160,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08)),
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
              child: ListView.builder(
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
