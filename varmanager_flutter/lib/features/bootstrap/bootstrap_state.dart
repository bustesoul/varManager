enum BootstrapStep {
  welcome,
  features,
  config,
  checks,
  tourHome,
  tourScenes,
  tourHubTags,
  tourHubDownloads,
  tourSettings,
  finish,
}

enum BootstrapCheckStatus {
  pending,
  pass,
  warn,
  fail,
}

class BootstrapConfig {
  const BootstrapConfig({
    required this.varspath,
    required this.vampath,
    required this.vamExec,
    required this.downloaderSavePath,
    required this.proxyHost,
    required this.proxyPort,
    required this.proxyUsername,
    required this.proxyPassword,
  });

  final String varspath;
  final String vampath;
  final String vamExec;
  final String downloaderSavePath;
  final String proxyHost;
  final String proxyPort;
  final String proxyUsername;
  final String proxyPassword;

  BootstrapConfig copyWith({
    String? varspath,
    String? vampath,
    String? vamExec,
    String? downloaderSavePath,
    String? proxyHost,
    String? proxyPort,
    String? proxyUsername,
    String? proxyPassword,
  }) {
    return BootstrapConfig(
      varspath: varspath ?? this.varspath,
      vampath: vampath ?? this.vampath,
      vamExec: vamExec ?? this.vamExec,
      downloaderSavePath: downloaderSavePath ?? this.downloaderSavePath,
      proxyHost: proxyHost ?? this.proxyHost,
      proxyPort: proxyPort ?? this.proxyPort,
      proxyUsername: proxyUsername ?? this.proxyUsername,
      proxyPassword: proxyPassword ?? this.proxyPassword,
    );
  }
}

class BootstrapCheckItem {
  const BootstrapCheckItem({
    required this.id,
    required this.label,
    required this.status,
    required this.message,
    required this.hints,
  });

  final String id;
  final String label;
  final BootstrapCheckStatus status;
  final String message;
  final List<String> hints;

  BootstrapCheckItem copyWith({
    BootstrapCheckStatus? status,
    String? message,
    List<String>? hints,
  }) {
    return BootstrapCheckItem(
      id: id,
      label: label,
      status: status ?? this.status,
      message: message ?? this.message,
      hints: hints ?? this.hints,
    );
  }
}

class BootstrapState {
  const BootstrapState({
    required this.active,
    required this.step,
    required this.config,
    required this.checks,
    required this.checksRunning,
    required this.checksRan,
    required this.savingConfig,
    required this.installMarkerPath,
    required this.errorMessage,
  });

  final bool active;
  final BootstrapStep step;
  final BootstrapConfig config;
  final List<BootstrapCheckItem> checks;
  final bool checksRunning;
  final bool checksRan;
  final bool savingConfig;
  final String? installMarkerPath;
  final String? errorMessage;

  BootstrapState copyWith({
    bool? active,
    BootstrapStep? step,
    BootstrapConfig? config,
    List<BootstrapCheckItem>? checks,
    bool? checksRunning,
    bool? checksRan,
    bool? savingConfig,
    String? installMarkerPath,
    String? errorMessage,
  }) {
    return BootstrapState(
      active: active ?? this.active,
      step: step ?? this.step,
      config: config ?? this.config,
      checks: checks ?? this.checks,
      checksRunning: checksRunning ?? this.checksRunning,
      checksRan: checksRan ?? this.checksRan,
      savingConfig: savingConfig ?? this.savingConfig,
      installMarkerPath: installMarkerPath ?? this.installMarkerPath,
      errorMessage: errorMessage,
    );
  }

  bool get isTourStep {
    switch (step) {
      case BootstrapStep.tourHome:
      case BootstrapStep.tourScenes:
      case BootstrapStep.tourHubTags:
      case BootstrapStep.tourHubDownloads:
      case BootstrapStep.tourSettings:
        return true;
      case BootstrapStep.welcome:
      case BootstrapStep.features:
      case BootstrapStep.config:
      case BootstrapStep.checks:
      case BootstrapStep.finish:
        return false;
    }
  }

  static BootstrapState inactive() {
    return BootstrapState(
      active: false,
      step: BootstrapStep.welcome,
      config: const BootstrapConfig(
        varspath: '',
        vampath: '',
        vamExec: '',
        downloaderSavePath: '',
        proxyHost: '',
        proxyPort: '',
        proxyUsername: '',
        proxyPassword: '',
      ),
      checks: const [],
      checksRunning: false,
      checksRan: false,
      savingConfig: false,
      installMarkerPath: null,
      errorMessage: null,
    );
  }
}
