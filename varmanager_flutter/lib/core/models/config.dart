class AppConfig {
  AppConfig({
    required this.listenHost,
    required this.listenPort,
    required this.logLevel,
    required this.jobConcurrency,
    this.varspath,
    this.vampath,
    this.vamExec,
    this.downloaderSavePath,
    this.uiTheme,
  });

  final String listenHost;
  final int listenPort;
  final String logLevel;
  final int jobConcurrency;
  final String? varspath;
  final String? vampath;
  final String? vamExec;
  final String? downloaderSavePath;
  final String? uiTheme;

  String get baseUrl => 'http://$listenHost:$listenPort';

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      listenHost: (json['listen_host'] as String?) ?? '127.0.0.1',
      listenPort: (json['listen_port'] as num?)?.toInt() ?? 57123,
      logLevel: (json['log_level'] as String?) ?? 'info',
      jobConcurrency: (json['job_concurrency'] as num?)?.toInt() ?? 10,
      varspath: json['varspath'] as String?,
      vampath: json['vampath'] as String?,
      vamExec: json['vam_exec'] as String?,
      downloaderSavePath: json['downloader_save_path'] as String?,
      uiTheme: json['ui_theme'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'listen_host': listenHost,
      'listen_port': listenPort,
      'log_level': logLevel,
      'job_concurrency': jobConcurrency,
      'varspath': varspath,
      'vampath': vampath,
      'vam_exec': vamExec,
      'downloader_save_path': downloaderSavePath,
      'ui_theme': uiTheme,
    };
  }

  AppConfig copyWith({
    String? listenHost,
    int? listenPort,
    String? logLevel,
    int? jobConcurrency,
    String? varspath,
    String? vampath,
    String? vamExec,
    String? downloaderSavePath,
    String? uiTheme,
  }) {
    return AppConfig(
      listenHost: listenHost ?? this.listenHost,
      listenPort: listenPort ?? this.listenPort,
      logLevel: logLevel ?? this.logLevel,
      jobConcurrency: jobConcurrency ?? this.jobConcurrency,
      varspath: varspath ?? this.varspath,
      vampath: vampath ?? this.vampath,
      vamExec: vamExec ?? this.vamExec,
      downloaderSavePath: downloaderSavePath ?? this.downloaderSavePath,
      uiTheme: uiTheme ?? this.uiTheme,
    );
  }
}
