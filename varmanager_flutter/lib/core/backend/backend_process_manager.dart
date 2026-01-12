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

  /// Read config.json from exe directory or working directory
  static Future<AppConfig?> _readLocalConfig(Directory workDir) async {
    final exeDir = p.dirname(Platform.resolvedExecutable);
    final exeDirConfig = File(p.join(exeDir, 'config.json'));
    if (await exeDirConfig.exists()) {
      try {
        final raw = await exeDirConfig.readAsString();
        final json = jsonDecode(raw) as Map<String, dynamic>;
        return AppConfig.fromJson(json);
      } catch (_) {}
    }

    final configFile = File(p.join(workDir.path, 'config.json'));
    if (await configFile.exists()) {
      try {
        final raw = await configFile.readAsString();
        final json = jsonDecode(raw) as Map<String, dynamic>;
        return AppConfig.fromJson(json);
      } catch (_) {}
    }
    return null;
  }

  static Future<String> resolveBaseUrl(Directory workDir) async {
    final config = await _readLocalConfig(workDir);
    return config?.baseUrl ?? 'http://$defaultHost:$defaultPort';
  }

  /// Resolve theme from local config.json (before backend starts)
  static Future<String?> resolveTheme(Directory workDir) async {
    final config = await _readLocalConfig(workDir);
    return config?.uiTheme;
  }

  /// Resolve language from local config.json (before backend starts)
  static Future<String?> resolveLanguage(Directory workDir) async {
    final config = await _readLocalConfig(workDir);
    return config?.uiLanguage;
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
      final resolved = _resolveBackendExe();
      if (resolved == null) {
        throw Exception('backend exe not found');
      }
      final (exePath, backendWorkDir) = resolved;
      _process = await Process.start(
        exePath,
        [],
        workingDirectory: backendWorkDir,
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
    throw Exception(
      'backend health check timeout (if using a proxy, set NO_PROXY=127.0.0.1,localhost)',
    );
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

  (String exePath, String workingDir)? _resolveBackendExe() {
    final name = Platform.isWindows
        ? 'varManager_backend.exe'
        : 'varManager_backend';

    final exeDir = p.dirname(Platform.resolvedExecutable);

    // Priority 1: data/ subdirectory (new structure)
    final dataDir = p.join(exeDir, 'data');
    final dataDirCandidate = File(p.join(dataDir, name));
    if (dataDirCandidate.existsSync()) {
      return (dataDirCandidate.path, exeDir);
    }

    // Priority 2: exe directory (legacy/backward compatibility)
    final exeDirCandidate = File(p.join(exeDir, name));
    if (exeDirCandidate.existsSync()) {
      return (exeDirCandidate.path, exeDir);
    }

    // Priority 3: working directory
    final candidate = File(p.join(workDir.path, name));
    if (candidate.existsSync()) {
      return (candidate.path, workDir.path);
    }
    return null;
  }
}
