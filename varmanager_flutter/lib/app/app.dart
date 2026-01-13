import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:varmanager_flutter/l10n/app_localizations.dart';
import 'package:window_manager/window_manager.dart';

import '../core/app_version.dart';
import '../core/backend/job_log_controller.dart';
import '../features/home/home_page.dart';
import '../features/hub/hub_page.dart';
import '../features/scenes/scenes_page.dart';
import '../features/settings/settings_page.dart';
import '../features/bootstrap/bootstrap_controller.dart';
import '../features/bootstrap/bootstrap_gate.dart';
import '../features/bootstrap/bootstrap_keys.dart';
import '../widgets/download_manager.dart';
import '../widgets/job_log_panel.dart';
import '../l10n/l10n.dart';
import 'providers.dart';
import 'theme.dart';

class VarManagerApp extends ConsumerWidget {
  const VarManagerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeType = ref.watch(themeProvider);
    return MaterialApp(
      title: 'varManager',
      theme: AppTheme.build(themeType),
      debugShowCheckedModeBanner: false,
      locale: ref.watch(localeProvider),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AppShell(),
    );
  }
}

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with WindowListener {
  bool _ready = false;
  String? _error;
  String _appVersion = '';
  bool _closing = false;

  List<_NavEntry> _buildPages(AppLocalizations l10n) {
    return [
      _NavEntry(
        label: l10n.navHome,
        icon: Icons.dashboard,
        page: const HomePage(),
      ),
      _NavEntry(
        label: l10n.navScenes,
        icon: Icons.photo_library,
        page: const ScenesPage(),
      ),
      _NavEntry(
        label: l10n.navHub,
        icon: Icons.cloud_download,
        page: const HubPage(),
      ),
      _NavEntry(
        label: l10n.navSettings,
        icon: Icons.tune,
        page: const SettingsPage(),
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.addListener(this);
      unawaited(windowManager.setPreventClose(true));
    }
    Future.microtask(_initBackend);
  }

  @override
  void dispose() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.removeListener(this);
      unawaited(windowManager.setPreventClose(false));
    }
    super.dispose();
  }

  @override
  void onWindowClose() {
    if (_closing) return;
    _closing = true;
    // Send shutdown signal to backend but don't wait
    unawaited(
      ref.read(backendProcessManagerProvider).shutdown().catchError((_) {}),
    );
    // Close window immediately
    unawaited(_performShutdown());
  }

  Future<void> _performShutdown() async {
    try {
      await windowManager.setPreventClose(false);
      await windowManager.destroy();
    } catch (_) {
      exit(0);
    }
  }

  Future<void> _initBackend() async {
    try {
      // Load app version
      final version = await loadAppVersion();
      if (!mounted) return;
      setState(() {
        _appVersion = version;
      });
      // baseUrl is already resolved and injected in main.dart via overrideWithValue
      await ref.read(backendProcessManagerProvider).start();
      if (!mounted) return;
      // Load theme from config after backend is ready
      await ref.read(themeProvider.notifier).loadFromConfig();
      // Load locale from config after backend is ready
      await ref.read(localeProvider.notifier).loadFromConfig();
      await ref.read(localeProvider.notifier).persistInitialIfNeeded();
      if (!mounted) return;
      setState(() {
        _ready = true;
      });
      await ref.read(bootstrapProvider.notifier).loadIfNeeded();
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final index = ref.watch(navIndexProvider);
    final isCompact = MediaQuery.of(context).size.width < 900;
    final pages = _buildPages(l10n);

    // Listen for job errors and show snackbar
    ref.listen<JobErrorNotice?>(jobErrorProvider, (previous, next) {
      if (!mounted || next == null) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.jobFailed(next.kind, next.message)),
          backgroundColor: Colors.red.shade700,
        ),
      );
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _appVersion.isNotEmpty ? 'varManager $_appVersion' : 'varManager',
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: Text(
                _ready
                    ? l10n.backendReady
                    : _error != null
                    ? l10n.backendError
                    : l10n.backendStarting,
                style: TextStyle(
                  color: _ready
                      ? Colors.green.shade700
                      : _error != null
                      ? Colors.red.shade700
                      : Colors.orange.shade700,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          final colorScheme = Theme.of(context).colorScheme;
          final isDark = colorScheme.brightness == Brightness.dark;
          return Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [
                            colorScheme.surface,
                            colorScheme.surface.withValues(alpha: 0.95),
                          ]
                        : [
                            Theme.of(context).scaffoldBackgroundColor,
                            HSLColor.fromColor(
                              Theme.of(context).scaffoldBackgroundColor,
                            ).withLightness(0.88).toColor(),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: isCompact
                    ? Column(
                        children: [
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 350),
                              child: _error != null
                                  ? _ErrorPane(message: _error!)
                                  : !_ready
                                  ? const _LoadingPane()
                                  : pages[index].page,
                            ),
                          ),
                          const JobLogPanel(),
                          NavigationBar(
                            selectedIndex: index,
                            onDestinationSelected: (value) {
                              ref
                                  .read(navIndexProvider.notifier)
                                  .setIndex(value);
                            },
                            destinations: pages
                                .map(
                                  (entry) => NavigationDestination(
                                    icon: Icon(entry.icon),
                                    label: entry.label,
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          SizedBox(
                            width: 92,
                            child: Column(
                              children: [
                                Expanded(
                                  child: NavigationRail(
                                    selectedIndex: index,
                                    labelType: NavigationRailLabelType.all,
                                    onDestinationSelected: (value) {
                                      ref
                                          .read(navIndexProvider.notifier)
                                          .setIndex(value);
                                    },
                                    destinations: pages
                                        .map(
                                          (entry) => NavigationRailDestination(
                                            icon: Icon(entry.icon),
                                            label: Text(entry.label),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: DownloadManagerBubble(
                                    key: BootstrapKeys.downloadManagerBubble,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                Expanded(
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 350),
                                    child: _error != null
                                        ? _ErrorPane(message: _error!)
                                        : !_ready
                                        ? const _LoadingPane()
                                        : pages[index].page,
                                  ),
                                ),
                                const JobLogPanel(),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
              if (_ready && _error == null) const BootstrapGate(),
            ],
          );
        },
      ),
    );
  }
}

class _NavEntry {
  const _NavEntry({
    required this.label,
    required this.icon,
    required this.page,
  });

  final String label;
  final IconData icon;
  final Widget page;
}

class _LoadingPane extends StatelessWidget {
  const _LoadingPane();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(l10n.backendStartingHint),
        ],
      ),
    );
  }
}

class _ErrorPane extends StatelessWidget {
  const _ErrorPane({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(child: Text(l10n.backendStartFailed(message)));
  }
}
