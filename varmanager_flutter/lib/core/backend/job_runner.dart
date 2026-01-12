import 'dart:async';

import '../models/job_models.dart';
import 'backend_client.dart';

class JobRunner {
  JobRunner({required this.client, this.onJobFailed});

  final BackendClient client;
  final void Function(JobView job)? onJobFailed;

  Duration _pollDelay(int idleTicks) {
    if (idleTicks < 2) {
      return const Duration(milliseconds: 350);
    }
    if (idleTicks < 5) {
      return const Duration(milliseconds: 650);
    }
    return const Duration(milliseconds: 1000);
  }

  Future<JobResult<dynamic>> runJob(
    String kind, {
    Map<String, dynamic>? args,
    void Function(JobLogEntry entry)? onLog,
  }) async {
    final start = await client.startJob(kind, args);
    int logOffset = 0;
    int lastLogOffset = 0;
    int lastLogCount = 0;
    int lastProgress = -1;
    String lastStatus = '';
    int idleTicks = 0;
    JobView job;
    while (true) {
      job = await client.getJob(start.id);
      final hasLogChanges =
          onLog != null &&
          (job.logOffset != lastLogOffset || job.logCount != lastLogCount);
      if (hasLogChanges) {
        final logs = await client.getJobLogs(start.id, from: logOffset);
        logOffset = logs.next;
        for (final entry in logs.entries) {
          onLog(entry);
        }
      }
      lastLogOffset = job.logOffset;
      lastLogCount = job.logCount;
      if (job.isDone) {
        break;
      }
      final stateChanged =
          hasLogChanges ||
          job.progress != lastProgress ||
          job.status != lastStatus;
      if (stateChanged) {
        idleTicks = 0;
      } else {
        idleTicks += 1;
      }
      lastProgress = job.progress;
      lastStatus = job.status;
      await Future.delayed(_pollDelay(idleTicks));
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
