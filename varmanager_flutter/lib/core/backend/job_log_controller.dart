import 'package:flutter_riverpod/flutter_riverpod.dart';

class JobLogController extends Notifier<List<String>> {
  @override
  List<String> build() => const [];

  void addLine(String line) {
    final next = [...state, line];
    if (next.length > 1000) {
      state = next.sublist(next.length - 1000);
    } else {
      state = next;
    }
  }

  void addLines(Iterable<String> lines) {
    if (lines.isEmpty) {
      return;
    }
    final next = [...state, ...lines];
    if (next.length > 1000) {
      state = next.sublist(next.length - 1000);
    } else {
      state = next;
    }
  }

  void clear() {
    state = const [];
  }
}

final jobLogProvider = NotifierProvider<JobLogController, List<String>>(
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
