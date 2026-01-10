import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'app/theme.dart';
import 'core/backend/backend_process_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _configureDesktopWindow();
  final workDir = Directory.current;
  final baseUrl = await BackendProcessManager.resolveBaseUrl(workDir);
  final themeName = await BackendProcessManager.resolveTheme(workDir);
  final initialTheme = themeName != null && themeName.isNotEmpty
      ? AppThemeType.values.firstWhere(
          (t) => t.name == themeName,
          orElse: () => AppThemeType.defaultTheme,
        )
      : AppThemeType.defaultTheme;
  runApp(
    ProviderScope(
      overrides: [
        baseUrlProvider.overrideWithValue(baseUrl),
        initialThemeProvider.overrideWithValue(initialTheme),
      ],
      child: const VarManagerApp(),
    ),
  );
}

Future<void> _configureDesktopWindow() async {
  if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    return;
  }

  await windowManager.ensureInitialized();

  final display = await screenRetriever.getPrimaryDisplay();
  final screenSize = display.size;
  final targetSize = Size(screenSize.width * 0.8, screenSize.height * 0.8);

  final windowOptions = WindowOptions(
    size: targetSize,
    center: true,
  );

  unawaited(
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    }),
  );
}
