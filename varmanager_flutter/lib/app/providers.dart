import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/backend/backend_client.dart';
import '../core/backend/backend_process_manager.dart';
import '../core/backend/job_runner.dart';

final baseUrlProvider = Provider<String>((ref) {
  return 'http://127.0.0.1:57123';
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
