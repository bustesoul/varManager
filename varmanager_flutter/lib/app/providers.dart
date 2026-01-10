import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/backend/backend_client.dart';
import '../core/backend/backend_process_manager.dart';
import '../core/backend/job_log_controller.dart';
import '../core/backend/job_runner.dart';
import 'theme.dart';

/// Base URL provider - value is set via overrideWithValue in main.dart
final baseUrlProvider = Provider<String>((ref) {
  // Default value; overridden in main.dart with resolved URL from config
  return 'http://127.0.0.1:57123';
});

/// Initial theme provider - value is set via overrideWithValue in main.dart
final initialThemeProvider = Provider<AppThemeType>((ref) {
  return AppThemeType.defaultTheme;
});

class NavIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int value) {
    state = value;
  }
}

final navIndexProvider = NotifierProvider<NavIndexNotifier, int>(
  NavIndexNotifier.new,
);

/// Theme provider for managing app theme with persistence
class ThemeNotifier extends Notifier<AppThemeType> {
  @override
  AppThemeType build() => ref.read(initialThemeProvider);

  /// Load theme from backend config (called after backend starts)
  Future<void> loadFromConfig() async {
    try {
      final client = ref.read(backendClientProvider);
      final config = await client.getConfig();
      final themeName = config.uiTheme;
      if (themeName != null && themeName.isNotEmpty) {
        final theme = AppThemeType.values.firstWhere(
          (t) => t.name == themeName,
          orElse: () => AppThemeType.defaultTheme,
        );
        state = theme;
      }
    } catch (_) {
      // Ignore errors, keep current theme
    }
  }

  /// Set theme and persist to backend config
  Future<void> setTheme(AppThemeType theme) async {
    state = theme;
    try {
      final client = ref.read(backendClientProvider);
      await client.updateConfig({'ui_theme': theme.name});
    } catch (_) {
      // Ignore save errors
    }
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, AppThemeType>(
  ThemeNotifier.new,
);

final backendClientProvider = Provider<BackendClient>((ref) {
  final baseUrl = ref.watch(baseUrlProvider);
  return BackendClient(baseUrl: baseUrl);
});

final backendProcessManagerProvider = Provider<BackendProcessManager>((ref) {
  final client = ref.watch(backendClientProvider);
  final manager = BackendProcessManager(client: client, workDir: Directory.current);
  ref.onDispose(manager.shutdown);
  return manager;
});

final jobRunnerProvider = Provider<JobRunner>((ref) {
  final client = ref.watch(backendClientProvider);
  final errors = ref.read(jobErrorProvider.notifier);
  return JobRunner(
    client: client,
    onJobFailed: (job) {
      final message = (job.error == null || job.error!.isEmpty)
          ? 'Unknown error'
          : job.error!;
      errors.report(JobErrorNotice(
        jobId: job.id,
        kind: job.kind,
        message: message,
      ));
    },
  );
});
