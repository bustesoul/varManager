class ProxyConfig {
  const ProxyConfig({
    required this.host,
    required this.port,
    this.username,
    this.password,
  });

  static const ProxyConfig empty = ProxyConfig(
    host: '',
    port: 0,
    username: null,
    password: null,
  );

  final String host;
  final int port;
  final String? username;
  final String? password;

  bool get enabled => host.trim().isNotEmpty && port > 0;

  factory ProxyConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return ProxyConfig.empty;
    return ProxyConfig(
      host: (json['host'] as String?) ?? '',
      port: (json['port'] as num?)?.toInt() ?? 0,
      username: json['username'] as String?,
      password: json['password'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'host': host,
      'port': port,
      'username': username,
      'password': password,
    };
  }
}

enum ProxyMode {
  system,
  manual;

  static ProxyMode fromJson(String? value) {
    return value == 'manual' ? ProxyMode.manual : ProxyMode.system;
  }
}

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
    required this.proxyMode,
    required this.proxy,
    this.uiTheme,
    this.uiLanguage,
  });

  final String listenHost;
  final int listenPort;
  final String logLevel;
  final int jobConcurrency;
  final String? varspath;
  final String? vampath;
  final String? vamExec;
  final String? downloaderSavePath;
  final ProxyMode proxyMode;
  final ProxyConfig proxy;
  final String? uiTheme;
  final String? uiLanguage;

  String get baseUrl => 'http://$listenHost:$listenPort';

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    final proxyJson = json['proxy'];
    return AppConfig(
      listenHost: (json['listen_host'] as String?) ?? '127.0.0.1',
      listenPort: (json['listen_port'] as num?)?.toInt() ?? 57123,
      logLevel: (json['log_level'] as String?) ?? 'info',
      jobConcurrency: (json['job_concurrency'] as num?)?.toInt() ?? 10,
      varspath: json['varspath'] as String?,
      vampath: json['vampath'] as String?,
      vamExec: json['vam_exec'] as String?,
      downloaderSavePath: json['downloader_save_path'] as String?,
      proxyMode: ProxyMode.fromJson(json['proxy_mode'] as String?),
      proxy: proxyJson is Map<String, dynamic>
          ? ProxyConfig.fromJson(proxyJson)
          : ProxyConfig.empty,
      uiTheme: json['ui_theme'] as String?,
      uiLanguage: json['ui_language'] as String?,
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
      'proxy_mode': proxyMode.name,
      'proxy': proxy.toJson(),
      'ui_theme': uiTheme,
      'ui_language': uiLanguage,
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
    ProxyMode? proxyMode,
    ProxyConfig? proxy,
    String? uiTheme,
    String? uiLanguage,
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
      proxyMode: proxyMode ?? this.proxyMode,
      proxy: proxy ?? this.proxy,
      uiTheme: uiTheme ?? this.uiTheme,
      uiLanguage: uiLanguage ?? this.uiLanguage,
    );
  }
}
