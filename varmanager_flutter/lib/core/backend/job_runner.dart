import 'dart:async';

import '../models/job_models.dart';
import 'backend_client.dart';

class JobRunner {
  JobRunner({required this.client, this.onJobFailed});

  final BackendClient client;
  final void Function(JobView job)? onJobFailed;

  Future<JobResult<dynamic>> runJob(
    String kind, {
    Map<String, dynamic>? args,
    void Function(String line)? onLog,
  }) async {
    final start = await client.startJob(kind, args);
    int logOffset = 0;
    JobView job;
    while (true) {
      job = await client.getJob(start.id);
      if (onLog != null) {
        final logs = await client.getJobLogs(start.id, from: logOffset);
        logOffset = logs.next;
        for (final line in logs.lines) {
          onLog(line);
        }
      }
      if (job.isDone) {
        break;
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }
    dynamic result;
    if (job.resultAvailable) {
      result = await client.getJobResult(start.id);
    }
    if (job.isFailed) {
      onJobFailed?.call(job);
    }
    return JobResult(job: job, result: result);
  }
}
