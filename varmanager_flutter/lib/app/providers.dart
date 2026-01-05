import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/backend/backend_client.dart';
import '../core/backend/backend_process_manager.dart';
import '../core/backend/job_runner.dart';

final baseUrlProvider = StateProvider<String>((ref) {
  return 'http://127.0.0.1:57123';
});

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
  return JobRunner(client: client);
});
