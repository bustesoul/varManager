import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'core/backend/backend_process_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final baseUrl = await BackendProcessManager.resolveBaseUrl(Directory.current);
  runApp(
    ProviderScope(
      overrides: [
        baseUrlProvider.overrideWithValue(baseUrl),
      ],
      child: const VarManagerApp(),
    ),
  );
}
