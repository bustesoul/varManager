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

enum JobLogLevel {
  info,
  warn,
  error,
  debug,
  unknown,
}

JobLogLevel _parseJobLogLevel(String? raw) {
  switch (raw?.toLowerCase()) {
    case 'info':
      return JobLogLevel.info;
    case 'warn':
    case 'warning':
      return JobLogLevel.warn;
    case 'error':
      return JobLogLevel.error;
    case 'debug':
      return JobLogLevel.debug;
    default:
      return JobLogLevel.unknown;
  }
}

String _jobLogLevelLabel(JobLogLevel level) {
  switch (level) {
    case JobLogLevel.info:
      return 'INFO';
    case JobLogLevel.warn:
      return 'WARN';
    case JobLogLevel.error:
      return 'ERROR';
    case JobLogLevel.debug:
      return 'DEBUG';
    case JobLogLevel.unknown:
      return 'INFO';
  }
}

class JobLogEntry {
  JobLogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
  });

  final DateTime timestamp;
  final JobLogLevel level;
  final String message;

  factory JobLogEntry.fromJson(Map<String, dynamic> json) {
    final rawTimestamp = json['timestamp'] as String?;
    DateTime timestamp;
    if (rawTimestamp == null || rawTimestamp.isEmpty) {
      timestamp = DateTime.now();
    } else {
      try {
        timestamp = DateTime.parse(rawTimestamp);
      } catch (_) {
        timestamp = DateTime.now();
      }
    }
    return JobLogEntry(
      timestamp: timestamp,
      level: _parseJobLogLevel(json['level']?.toString()),
      message: json['message']?.toString() ?? '',
    );
  }

  factory JobLogEntry.fromLine(String line) {
    return JobLogEntry(
      timestamp: DateTime.now(),
      level: JobLogLevel.info,
      message: line,
    );
  }

  String format() {
    final local = timestamp.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final second = local.second.toString().padLeft(2, '0');
    final levelLabel = _jobLogLevelLabel(level);
    return '$year-$month-$day $hour:$minute:$second [$levelLabel] $message';
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
    required this.entries,
  });

  final int id;
  final int from;
  final int next;
  final bool dropped;
  final List<JobLogEntry> entries;

  factory JobLogsResponse.fromJson(Map<String, dynamic> json) {
    final entriesRaw = json['entries'] as List<dynamic>?;
    final linesRaw = json['lines'] as List<dynamic>?;
    final entries = entriesRaw != null
        ? entriesRaw
            .whereType<Map>()
            .map((entry) => JobLogEntry.fromJson(
                  Map<String, dynamic>.from(entry),
                ))
            .toList()
        : (linesRaw ?? []).map((line) => JobLogEntry.fromLine('$line')).toList();
    return JobLogsResponse(
      id: (json['id'] as num).toInt(),
      from: (json['from'] as num?)?.toInt() ?? 0,
      next: (json['next'] as num?)?.toInt() ?? 0,
      dropped: json['dropped'] as bool? ?? false,
      entries: entries,
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
