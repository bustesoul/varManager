import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../app/providers.dart';
import '../../core/backend/backend_client.dart';
import '../../core/models/config.dart';
import 'bootstrap_state.dart';

final bootstrapProvider =
    NotifierProvider<BootstrapController, BootstrapState>(BootstrapController.new);

class BootstrapController extends Notifier<BootstrapState> {
  static const String _installMarkerName = 'INSTALL.txt';
  static const String _vamDesktopBat = 'VaM (Desktop Mode).bat';

  final List<BootstrapStep> _steps = const [
    BootstrapStep.welcome,
    BootstrapStep.features,
    BootstrapStep.config,
    BootstrapStep.checks,
    BootstrapStep.tourHome,
    BootstrapStep.tourScenes,
    BootstrapStep.tourHubTags,
    BootstrapStep.tourHubDownloads,
    BootstrapStep.tourDownloadManager,
    BootstrapStep.tourSettings,
    BootstrapStep.finish,
  ];

  @override
  BootstrapState build() => BootstrapState.inactive();

  Future<void> loadIfNeeded() async {
    if (state.active) return;
    final markerPath = await _findInstallMarker();
    if (markerPath == null) return;

    final client = ref.read(backendClientProvider);
    AppConfig? config;
    try {
      config = await client.getConfig();
    } catch (_) {
      config = null;
    }

    final resolved = _resolveBootstrapConfig(config);
    state = state.copyWith(
      active: true,
      step: BootstrapStep.welcome,
      config: resolved,
      installMarkerPath: markerPath,
      errorMessage: null,
    );
  }

  void nextStep() {
    final index = _steps.indexOf(state.step);
    if (index < 0 || index >= _steps.length - 1) return;
    _goToStep(_steps[index + 1]);
  }

  void previousStep() {
    final index = _steps.indexOf(state.step);
    if (index <= 0) return;
    _goToStep(_steps[index - 1]);
  }

  void goToStep(BootstrapStep step) {
    _goToStep(step);
  }

  Future<bool> saveConfig(BootstrapConfig config) async {
    state = state.copyWith(savingConfig: true, errorMessage: null);
    final client = ref.read(backendClientProvider);
    try {
      await client.updateConfig({
        'varspath': config.varspath.trim(),
        'vampath': config.vampath.trim(),
        'vam_exec': config.vamExec.trim(),
        'downloader_save_path': config.downloaderSavePath.trim(),
        'proxy_mode': config.proxyMode.trim(),
        'proxy': {
          'host': config.proxyHost.trim(),
          'port': int.tryParse(config.proxyPort.trim()) ?? 0,
          'username': config.proxyUsername.trim(),
          'password': config.proxyPassword.trim(),
        },
      });
      state = state.copyWith(config: config, savingConfig: false);
      return true;
    } catch (err) {
      state = state.copyWith(
        savingConfig: false,
        errorMessage: err.toString(),
      );
      return false;
    }
  }

  Future<void> runChecks(
    String backendLabel,
    String varspathLabel,
    String vampathLabel,
    String downloaderLabel,
    String fileOpsLabel,
    String symlinkLabel,
    String vamExecLabel, {
    required String varspathHint,
    required String vampathHint,
    required String downloaderHint,
    required String fileOpsHint,
    required String symlinkHint,
    required String vamExecHint,
    required String varspathName,
    required String vampathName,
  }) async {
    state = state.copyWith(checksRunning: true, checksRan: true, errorMessage: null);

    final config = state.config;
    final varspath = config.varspath.trim();
    final vampath = config.vampath.trim();
    final samePaths = _pathsMatch(varspath, vampath);
    final varFileOpsLabel = _withPathSuffix(fileOpsLabel, varspathName);
    final vampathFileOpsLabel = _withPathSuffix(fileOpsLabel, vampathName);
    final varSymlinkLabel = _withPathSuffix(symlinkLabel, varspathName);
    final vampathSymlinkLabel = _withPathSuffix(symlinkLabel, vampathName);

    final checks = <BootstrapCheckItem>[];
    checks.add(_pending('backend', backendLabel));
    checks.add(_pending('varspath', varspathLabel));
    if (!samePaths) {
      checks.add(_pending('vampath', vampathLabel));
    }
    checks.add(_pending('downloader', downloaderLabel));
    checks.add(_pending('fileops_varspath', varFileOpsLabel));
    if (!samePaths) {
      checks.add(_pending('fileops_vampath', vampathFileOpsLabel));
    }
    checks.add(_pending('symlink_varspath', varSymlinkLabel));
    if (!samePaths) {
      checks.add(_pending('symlink_vampath', vampathSymlinkLabel));
    }
    checks.add(_pending('vamexec', vamExecLabel));
    state = state.copyWith(checks: checks);

    final client = ref.read(backendClientProvider);

    final backendCheck = await _checkBackend(client, backendLabel);
    _setCheck(backendCheck);

    final varspathCheck = await _checkPathExists(
      'varspath',
      varspath,
      varspathLabel,
      varspathHint,
      emptyMessage: '$varspathName not set',
    );
    _setCheck(varspathCheck);

    if (!samePaths) {
      final vampathCheck = await _checkPathExists(
        'vampath',
        vampath,
        vampathLabel,
        vampathHint,
        emptyMessage: '$vampathName not set',
      );
      _setCheck(vampathCheck);
    }

    final downloaderCheck =
        await _checkDownloaderPath(config, downloaderLabel, downloaderHint);
    _setCheck(downloaderCheck);

    final fileOpsVarCheck = await _checkFileOps(
      'fileops_varspath',
      varspath,
      varFileOpsLabel,
      fileOpsHint,
      emptyMessage: '$varspathName not set',
    );
    _setCheck(fileOpsVarCheck);

    if (!samePaths) {
      final fileOpsVamCheck = await _checkFileOps(
        'fileops_vampath',
        vampath,
        vampathFileOpsLabel,
        fileOpsHint,
        emptyMessage: '$vampathName not set',
      );
      _setCheck(fileOpsVamCheck);
    }

    final symlinkVarCheck = await _checkSymlink(
      'symlink_varspath',
      varspath,
      varSymlinkLabel,
      symlinkHint,
      emptyMessage: '$varspathName not set',
    );
    _setCheck(symlinkVarCheck);

    if (!samePaths) {
      final symlinkVamCheck = await _checkSymlink(
        'symlink_vampath',
        vampath,
        vampathSymlinkLabel,
        symlinkHint,
        emptyMessage: '$vampathName not set',
      );
      _setCheck(symlinkVamCheck);
    }

    final vamExecCheck =
        await _checkVamExec(config, vamExecLabel, vamExecHint);
    _setCheck(vamExecCheck);

    state = state.copyWith(checksRunning: false);
  }

  Future<bool> complete() async {
    final path = state.installMarkerPath;
    if (path == null) {
      state = state.copyWith(active: false, errorMessage: null);
      ref.read(navIndexProvider.notifier).setIndex(0);
      return true;
    }
    String? error;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (err) {
      error = err.toString();
    }
    state = state.copyWith(active: false, errorMessage: error);
    ref.read(navIndexProvider.notifier).setIndex(0);
    return error == null;
  }

  Future<bool> skip() async {
    return complete();
  }

  void updateLocalConfig(BootstrapConfig config) {
    state = state.copyWith(config: config);
  }

  BootstrapConfig _resolveBootstrapConfig(AppConfig? config) {
    var varspath = config?.varspath ?? '';
    final vampath = config?.vampath ?? '';
    if (varspath.trim().isEmpty && vampath.trim().isNotEmpty) {
      varspath = vampath;
    }
    final downloader = config?.downloaderSavePath ?? '';
    var vamExec = config?.vamExec ?? '';
    final proxy = config?.proxy ?? ProxyConfig.empty;
    final proxyMode = config?.proxyMode ?? ProxyMode.system;

    // Normalize vam_exec: extract filename if full path provided
    if (vamExec.trim().isNotEmpty) {
      vamExec = p.basename(vamExec.trim());
    }
    if (vamExec.trim().isEmpty) {
      vamExec = _vamDesktopBat;
    }

    String resolvedDownloader = downloader;
    if (resolvedDownloader.trim().isEmpty && varspath.trim().isNotEmpty) {
      resolvedDownloader = p.join(varspath.trim(), 'AddonPackages');
    }

    return BootstrapConfig(
      varspath: varspath,
      vampath: vampath,
      vamExec: vamExec,
      downloaderSavePath: resolvedDownloader,
      proxyMode: proxyMode.name,
      proxyHost: proxy.host,
      proxyPort: proxy.port > 0 ? proxy.port.toString() : '',
      proxyUsername: proxy.username ?? '',
      proxyPassword: proxy.password ?? '',
    );
  }

  void _goToStep(BootstrapStep step) {
    state = state.copyWith(step: step);
    final navIndex = _navIndexForStep(step);
    if (navIndex != null) {
      ref.read(navIndexProvider.notifier).setIndex(navIndex);
    }
  }

  int? _navIndexForStep(BootstrapStep step) {
    switch (step) {
      case BootstrapStep.tourHome:
        return 0;
      case BootstrapStep.tourScenes:
        return 1;
      case BootstrapStep.tourHubTags:
      case BootstrapStep.tourHubDownloads:
      case BootstrapStep.tourDownloadManager:
        return 2;
      case BootstrapStep.tourSettings:
        return 3;
      case BootstrapStep.welcome:
      case BootstrapStep.features:
      case BootstrapStep.config:
      case BootstrapStep.checks:
      case BootstrapStep.finish:
        return null;
    }
  }

  BootstrapCheckItem _pending(String id, String label) {
    return BootstrapCheckItem(
      id: id,
      label: label,
      status: BootstrapCheckStatus.pending,
      message: '',
      hints: const [],
    );
  }

  void _setCheck(BootstrapCheckItem next) {
    final items = [...state.checks];
    final index = items.indexWhere((item) => item.id == next.id);
    if (index >= 0) {
      items[index] = next;
      state = state.copyWith(checks: items);
    }
  }

  String _normalizePath(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    return p.normalize(trimmed).toLowerCase();
  }

  bool _pathsMatch(String left, String right) {
    return _normalizePath(left) == _normalizePath(right);
  }

  String _withPathSuffix(String label, String pathName) {
    return '$label ($pathName)';
  }

  Future<BootstrapCheckItem> _checkBackend(
    BackendClient client,
    String label,
  ) async {
    try {
      await client.getHealth();
      return BootstrapCheckItem(
        id: 'backend',
        label: label,
        status: BootstrapCheckStatus.pass,
        message: 'OK',
        hints: const [],
      );
    } catch (err) {
      return BootstrapCheckItem(
        id: 'backend',
        label: label,
        status: BootstrapCheckStatus.fail,
        message: err.toString(),
        hints: const [],
      );
    }
  }

  Future<BootstrapCheckItem> _checkPathExists(
    String id,
    String path,
    String label,
    String hint, {
    required String emptyMessage,
  }) async {
    if (path.isEmpty) {
      return BootstrapCheckItem(
        id: id,
        label: label,
        status: BootstrapCheckStatus.fail,
        message: emptyMessage,
        hints: [hint],
      );
    }
    final dir = Directory(path);
    if (!await dir.exists()) {
      return BootstrapCheckItem(
        id: id,
        label: label,
        status: BootstrapCheckStatus.fail,
        message: 'Directory not found',
        hints: [hint],
      );
    }
    return BootstrapCheckItem(
      id: id,
      label: label,
      status: BootstrapCheckStatus.pass,
      message: 'OK',
      hints: const [],
    );
  }

  Future<BootstrapCheckItem> _checkDownloaderPath(
    BootstrapConfig config,
    String label,
    String hint,
  ) async {
    final path = config.downloaderSavePath.trim();
    if (path.isEmpty) {
      return BootstrapCheckItem(
        id: 'downloader',
        label: label,
        status: BootstrapCheckStatus.warn,
        message: 'downloader_save_path not set',
        hints: [hint],
      );
    }
    try {
      final dir = Directory(path);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final testFile = File(p.join(path, '.vm_check_download.txt'));
      await testFile.writeAsString('ok');
      await testFile.delete();
      return BootstrapCheckItem(
        id: 'downloader',
        label: label,
        status: BootstrapCheckStatus.pass,
        message: 'OK',
        hints: const [],
      );
    } catch (err) {
      return BootstrapCheckItem(
        id: 'downloader',
        label: label,
        status: BootstrapCheckStatus.fail,
        message: err.toString(),
        hints: [hint],
      );
    }
  }

  Future<BootstrapCheckItem> _checkFileOps(
    String id,
    String path,
    String label,
    String hint, {
    required String emptyMessage,
  }) async {
    if (path.isEmpty) {
      return BootstrapCheckItem(
        id: id,
        label: label,
        status: BootstrapCheckStatus.fail,
        message: emptyMessage,
        hints: [hint],
      );
    }

    final checkDir = Directory(p.join(path, '.vm_check'));
    try {
      if (!await checkDir.exists()) {
        await checkDir.create(recursive: true);
      }
      final fileA = File(p.join(checkDir.path, 'file_a.txt'));
      final fileB = File(p.join(checkDir.path, 'file_b.txt'));
      final fileC = File(p.join(checkDir.path, 'file_c.txt'));
      final fileD = File(p.join(checkDir.path, 'file_d.txt'));
      const content = 'varManager-bootstrap-check';
      await fileA.writeAsString(content);
      await fileA.copy(fileB.path);
      await fileB.rename(fileC.path);
      await fileC.rename(fileD.path);
      final readBack = await fileD.readAsString();
      if (readBack != content) {
        throw Exception('content mismatch');
      }
      await fileA.delete().onError((_, _) => fileA);
      await fileD.delete().onError((_, _) => fileD);
      return BootstrapCheckItem(
        id: id,
        label: label,
        status: BootstrapCheckStatus.pass,
        message: 'OK',
        hints: const [],
      );
    } catch (err) {
      return BootstrapCheckItem(
        id: id,
        label: label,
        status: BootstrapCheckStatus.fail,
        message: err.toString(),
        hints: [hint],
      );
    } finally {
      await _cleanupCheckDir(checkDir);
    }
  }

  Future<BootstrapCheckItem> _checkSymlink(
    String id,
    String path,
    String label,
    String hint, {
    required String emptyMessage,
  }) async {
    if (path.isEmpty) {
      return BootstrapCheckItem(
        id: id,
        label: label,
        status: BootstrapCheckStatus.fail,
        message: emptyMessage,
        hints: [hint],
      );
    }

    final checkDir = Directory(p.join(path, '.vm_check'));
    try {
      if (!await checkDir.exists()) {
        await checkDir.create(recursive: true);
      }
      final target = File(p.join(checkDir.path, 'symlink_target.txt'));
      const content = 'symlink-check';
      await target.writeAsString(content);
      final linkPath = p.join(checkDir.path, 'symlink_link.txt');
      final movedPath = p.join(checkDir.path, 'symlink_link_moved.txt');
      final link = Link(linkPath);
      await link.create(target.path);
      final readBack = await File(link.path).readAsString();
      if (readBack != content) {
        throw Exception('symlink content mismatch');
      }
      final moved = await link.rename(movedPath);
      final readMoved = await File(moved.path).readAsString();
      if (readMoved != content) {
        throw Exception('symlink moved content mismatch');
      }
      await moved.delete().onError((_, _) => moved);
      await target.delete().onError((_, _) => target);
      return BootstrapCheckItem(
        id: id,
        label: label,
        status: BootstrapCheckStatus.pass,
        message: 'OK',
        hints: const [],
      );
    } catch (err) {
      return BootstrapCheckItem(
        id: id,
        label: label,
        status: BootstrapCheckStatus.fail,
        message: err.toString(),
        hints: [hint],
      );
    } finally {
      await _cleanupCheckDir(checkDir);
    }
  }

  Future<BootstrapCheckItem> _checkVamExec(
    BootstrapConfig config,
    String label,
    String hint,
  ) async {
    final path = config.vamExec.trim();
    if (path.isEmpty) {
      return BootstrapCheckItem(
        id: 'vamexec',
        label: label,
        status: BootstrapCheckStatus.warn,
        message: 'vam_exec not set',
        hints: [hint],
      );
    }
    final vampath = config.vampath.trim();
    final resolvedPath =
        p.isAbsolute(path) ? path : (vampath.isEmpty ? path : p.join(vampath, path));
    final file = File(resolvedPath);
    if (await file.exists()) {
      return BootstrapCheckItem(
        id: 'vamexec',
        label: label,
        status: BootstrapCheckStatus.pass,
        message: 'OK',
        hints: const [],
      );
    }
    return BootstrapCheckItem(
      id: 'vamexec',
      label: label,
      status: BootstrapCheckStatus.warn,
      message: 'file not found',
      hints: [hint],
    );
  }

  Future<void> _cleanupCheckDir(Directory dir) async {
    try {
      if (await dir.exists()) {
        final entries = await dir.list().toList();
        if (entries.isEmpty) {
          await dir.delete();
        }
      }
    } catch (_) {}
  }

  Future<String?> _findInstallMarker() async {
    final exeDir = p.dirname(Platform.resolvedExecutable);
    final exeCandidate = File(p.join(exeDir, _installMarkerName));
    if (await exeCandidate.exists()) {
      return exeCandidate.path;
    }
    final workCandidate = File(p.join(Directory.current.path, _installMarkerName));
    if (await workCandidate.exists()) {
      return workCandidate.path;
    }
    return null;
  }
}
