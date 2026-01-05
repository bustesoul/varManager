import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/config.dart';
import 'backend_client.dart';

class BackendProcessManager {
  BackendProcessManager({required this.client, required this.workDir});

  final BackendClient client;
  final Directory workDir;
  Process? _process;
  bool _starting = false;

  static const String defaultHost = '127.0.0.1';
  static const int defaultPort = 57123;
  static const String parentPidEnvKey = 'VARMANAGER_PARENT_PID';

  static Future<String> resolveBaseUrl(Directory workDir) async {
    final configFile = File(p.join(workDir.path, 'config.json'));
    if (!await configFile.exists()) {
      return 'http://$defaultHost:$defaultPort';
    }
    try {
      final raw = await configFile.readAsString();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final config = AppConfig.fromJson(json);
      return config.baseUrl;
    } catch (_) {
      return 'http://$defaultHost:$defaultPort';
    }
  }

  Future<void> start() async {
    if (_starting) {
      return;
    }
    _starting = true;
    try {
      if (await _isHealthy()) {
        await _shutdownExisting();
      }
      final exePath = _resolveBackendExe();
      if (exePath == null) {
        throw Exception('backend exe not found');
      }
      _process = await Process.start(
        exePath,
        [],
        workingDirectory: workDir.path,
        environment: {parentPidEnvKey: pid.toString()},
      );
      await _waitForHealth();
    } finally {
      _starting = false;
    }
  }

  Future<void> shutdown() async {
    try {
      await client.shutdown();
    } catch (_) {}
    if (_process != null) {
      final process = _process!;
      await Future.delayed(const Duration(seconds: 2));
      process.kill(ProcessSignal.sigkill);
      _process = null;
    }
  }

  Future<void> _shutdownExisting() async {
    try {
      await client.shutdown();
    } catch (_) {}
    await _waitForShutdown();
  }

  Future<bool> _isHealthy() async {
    try {
      final resp = await HttpClient()
          .getUrl(Uri.parse('${client.baseUrl}/health'))
          .then((req) => req.close())
          .timeout(const Duration(milliseconds: 800));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<void> _waitForHealth() async {
    final deadline = DateTime.now().add(const Duration(seconds: 12));
    while (DateTime.now().isBefore(deadline)) {
      if (await _isHealthy()) {
        return;
      }
      await Future.delayed(const Duration(milliseconds: 350));
    }
    throw Exception('backend health check timeout');
  }

  Future<void> _waitForShutdown() async {
    final deadline = DateTime.now().add(const Duration(seconds: 8));
    while (DateTime.now().isBefore(deadline)) {
      if (!await _isHealthy()) {
        return;
      }
      await Future.delayed(const Duration(milliseconds: 300));
    }
    if (await _isHealthy()) {
      throw Exception('backend shutdown timeout');
    }
  }

  String? _resolveBackendExe() {
    final name = Platform.isWindows ? 'varManager_backend.exe' : 'varManager_backend';
    final candidate = File(p.join(workDir.path, name));
    if (candidate.existsSync()) {
      return candidate.path;
    }
    return null;
  }
}
