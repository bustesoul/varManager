class StartJobResponse {
  StartJobResponse({required this.id, required this.status});

  final int id;
  final String status;

  factory StartJobResponse.fromJson(Map<String, dynamic> json) {
    return StartJobResponse(
      id: (json['id'] as num).toInt(),
      status: json['status'] as String? ?? 'queued',
    );
  }
}

class JobView {
  JobView({
    required this.id,
    required this.kind,
    required this.status,
    required this.progress,
    required this.message,
    required this.error,
    required this.logOffset,
    required this.logCount,
    required this.resultAvailable,
  });

  final int id;
  final String kind;
  final String status;
  final int progress;
  final String message;
  final String? error;
  final int logOffset;
  final int logCount;
  final bool resultAvailable;

  factory JobView.fromJson(Map<String, dynamic> json) {
    return JobView(
      id: (json['id'] as num).toInt(),
      kind: json['kind'] as String? ?? '',
      status: json['status'] as String? ?? 'queued',
      progress: (json['progress'] as num?)?.toInt() ?? 0,
      message: json['message'] as String? ?? '',
      error: json['error'] as String?,
      logOffset: (json['log_offset'] as num?)?.toInt() ?? 0,
      logCount: (json['log_count'] as num?)?.toInt() ?? 0,
      resultAvailable: json['result_available'] as bool? ?? false,
    );
  }

  bool get isDone => status == 'succeeded' || status == 'failed';
  bool get isFailed => status == 'failed';
}

class JobLogsResponse {
  JobLogsResponse({
    required this.id,
    required this.from,
    required this.next,
    required this.dropped,
    required this.lines,
  });

  final int id;
  final int from;
  final int next;
  final bool dropped;
  final List<String> lines;

  factory JobLogsResponse.fromJson(Map<String, dynamic> json) {
    return JobLogsResponse(
      id: (json['id'] as num).toInt(),
      from: (json['from'] as num?)?.toInt() ?? 0,
      next: (json['next'] as num?)?.toInt() ?? 0,
      dropped: json['dropped'] as bool? ?? false,
      lines: (json['lines'] as List<dynamic>? ?? [])
          .map((line) => line.toString())
          .toList(),
    );
  }
}

class JobResult<T> {
  JobResult({
    required this.job,
    required this.result,
  });

  final JobView job;
  final T? result;
}
