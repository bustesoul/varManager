import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/job_models.dart';

class JobLogController extends Notifier<List<JobLogEntry>> {
  static const int _maxLines = 1000;

  @override
  List<JobLogEntry> build() => const [];

  void addEntry(JobLogEntry entry) {
    final next = [...state, entry];
    if (next.length > _maxLines) {
      state = next.sublist(next.length - _maxLines);
    } else {
      state = next;
    }
  }

  void addEntries(Iterable<JobLogEntry> entries) {
    if (entries.isEmpty) {
      return;
    }
    final next = [...state, ...entries];
    if (next.length > _maxLines) {
      state = next.sublist(next.length - _maxLines);
    } else {
      state = next;
    }
  }

  void clear() {
    state = const [];
  }
}

final jobLogProvider = NotifierProvider<JobLogController, List<JobLogEntry>>(
  JobLogController.new,
);

class JobErrorNotice {
  JobErrorNotice({
    required this.jobId,
    required this.kind,
    required this.message,
  });

  final int jobId;
  final String kind;
  final String message;
}

class JobErrorController extends Notifier<JobErrorNotice?> {
  @override
  JobErrorNotice? build() => null;

  void report(JobErrorNotice notice) {
    state = notice;
  }
}

final jobErrorProvider = NotifierProvider<JobErrorController, JobErrorNotice?>(
  JobErrorController.new,
);

/// Tracks whether a job is currently running
class JobBusyController extends Notifier<bool> {
  @override
  bool build() => false;

  void setBusy(bool value) {
    state = value;
  }
}

final jobBusyProvider = NotifierProvider<JobBusyController, bool>(
  JobBusyController.new,
);
