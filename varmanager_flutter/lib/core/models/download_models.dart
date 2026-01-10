class DownloadItem {
  DownloadItem({
    required this.id,
    required this.url,
    required this.name,
    required this.status,
    required this.downloadedBytes,
    required this.totalBytes,
    required this.speedBytes,
    required this.error,
    required this.savePath,
    required this.tempPath,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String url;
  final String? name;
  final String status;
  final int downloadedBytes;
  final int? totalBytes;
  final int speedBytes;
  final String? error;
  final String? savePath;
  final String? tempPath;
  final int createdAt;
  final int updatedAt;

  factory DownloadItem.fromJson(Map<String, dynamic> json) {
    return DownloadItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      url: json['url']?.toString() ?? '',
      name: json['name']?.toString(),
      status: json['status']?.toString() ?? 'queued',
      downloadedBytes: (json['downloaded_bytes'] as num?)?.toInt() ?? 0,
      totalBytes: (json['total_bytes'] as num?)?.toInt(),
      speedBytes: (json['speed_bytes'] as num?)?.toInt() ?? 0,
      error: json['error']?.toString(),
      savePath: json['save_path']?.toString(),
      tempPath: json['temp_path']?.toString(),
      createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
      updatedAt: (json['updated_at'] as num?)?.toInt() ?? 0,
    );
  }
}

class DownloadSummary {
  DownloadSummary({
    required this.total,
    required this.queued,
    required this.downloading,
    required this.paused,
    required this.failed,
    required this.completed,
    required this.downloadedBytes,
    required this.totalBytes,
  });

  final int total;
  final int queued;
  final int downloading;
  final int paused;
  final int failed;
  final int completed;
  final int downloadedBytes;
  final int totalBytes;

  factory DownloadSummary.fromJson(Map<String, dynamic> json) {
    return DownloadSummary(
      total: (json['total'] as num?)?.toInt() ?? 0,
      queued: (json['queued'] as num?)?.toInt() ?? 0,
      downloading: (json['downloading'] as num?)?.toInt() ?? 0,
      paused: (json['paused'] as num?)?.toInt() ?? 0,
      failed: (json['failed'] as num?)?.toInt() ?? 0,
      completed: (json['completed'] as num?)?.toInt() ?? 0,
      downloadedBytes: (json['downloaded_bytes'] as num?)?.toInt() ?? 0,
      totalBytes: (json['total_bytes'] as num?)?.toInt() ?? 0,
    );
  }

  factory DownloadSummary.empty() {
    return DownloadSummary(
      total: 0,
      queued: 0,
      downloading: 0,
      paused: 0,
      failed: 0,
      completed: 0,
      downloadedBytes: 0,
      totalBytes: 0,
    );
  }
}

class DownloadListResponse {
  DownloadListResponse({
    required this.items,
    required this.summary,
  });

  final List<DownloadItem> items;
  final DownloadSummary summary;

  factory DownloadListResponse.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'] as List<dynamic>? ?? [];
    return DownloadListResponse(
      items: itemsRaw
          .whereType<Map>()
          .map((entry) => DownloadItem.fromJson(
                Map<String, dynamic>.from(entry),
              ))
          .toList(),
      summary: DownloadSummary.fromJson(
        Map<String, dynamic>.from(json['summary'] as Map? ?? {}),
      ),
    );
  }

  factory DownloadListResponse.empty() {
    return DownloadListResponse(
      items: const [],
      summary: DownloadSummary.empty(),
    );
  }
}
