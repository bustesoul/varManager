import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/backend/backend_client.dart';
import '../core/backend/backend_process_manager.dart';
import '../core/backend/job_log_controller.dart';
import '../core/backend/job_runner.dart';
import '../l10n/locale_config.dart';
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

class InitialLocaleConfig {
  const InitialLocaleConfig({
    required this.tag,
    required this.persistOnStart,
  });

  final String tag;
  final bool persistOnStart;
}

final initialLocaleConfigProvider = Provider<InitialLocaleConfig>((ref) {
  return const InitialLocaleConfig(tag: kFallbackLocaleTag, persistOnStart: false);
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

class LocaleNotifier extends Notifier<Locale> {
  bool _persistOnStart = false;
  String _languageTag = kFallbackLocaleTag;

  @override
  Locale build() {
    final initial = ref.read(initialLocaleConfigProvider);
    _persistOnStart = initial.persistOnStart;
    _languageTag = initial.tag;
    return localeFromTag(initial.tag);
  }

  Future<void> loadFromConfig() async {
    try {
      final client = ref.read(backendClientProvider);
      final config = await client.getConfig();
      final tag = normalizeLocaleTag(config.uiLanguage);
      if (tag == null) {
        return;
      }
      _persistOnStart = false;
      _languageTag = tag;
      state = localeFromTag(tag);
    } catch (_) {
      // Ignore errors, keep current locale
    }
  }

  Future<void> persistInitialIfNeeded() async {
    if (!_persistOnStart) return;
    _persistOnStart = false;
    await _saveLanguageTag(_languageTag);
  }

  Future<void> setLocale(Locale locale) async {
    _persistOnStart = false;
    final tag = localeTagFromLocale(locale);
    _languageTag = tag;
    state = localeFromTag(tag);
    await _saveLanguageTag(tag);
  }

  Future<void> _saveLanguageTag(String tag) async {
    try {
      final client = ref.read(backendClientProvider);
      await client.updateConfig({'ui_language': tag});
    } catch (_) {
      // Ignore save errors
    }
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
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
