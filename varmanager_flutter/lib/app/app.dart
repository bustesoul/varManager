import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_version.dart';
import '../core/backend/job_log_controller.dart';
import '../features/home/home_page.dart';
import '../features/hub/hub_page.dart';
import '../features/scenes/scenes_page.dart';
import '../features/settings/settings_page.dart';
import '../widgets/download_manager.dart';
import '../widgets/job_log_panel.dart';
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
      home: const AppShell(),
    );
  }
}

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _ready = false;
  String? _error;
  String _appVersion = '';

  final List<_NavEntry> _pages = const [
    _NavEntry(label: 'Home', icon: Icons.dashboard, page: HomePage()),
    _NavEntry(label: 'Scenes', icon: Icons.photo_library, page: ScenesPage()),
    _NavEntry(label: 'Hub', icon: Icons.cloud_download, page: HubPage()),
    _NavEntry(label: 'Settings', icon: Icons.tune, page: SettingsPage()),
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(_initBackend);
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
      if (!mounted) return;
      setState(() {
        _ready = true;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(navIndexProvider);
    final isCompact = MediaQuery.of(context).size.width < 900;

    // Listen for job errors and show snackbar
    ref.listen<JobErrorNotice?>(jobErrorProvider, (previous, next) {
      if (!mounted || next == null) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Job failed: ${next.kind} (${next.message})'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(_appVersion.isNotEmpty ? 'varManager $_appVersion' : 'varManager'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: Text(
                _ready
                    ? 'Backend ready'
                    : _error != null
                        ? 'Backend error'
                        : 'Starting backend',
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
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [colorScheme.surface, colorScheme.surface.withValues(alpha: 0.95)]
                    : [
                        Theme.of(context).scaffoldBackgroundColor,
                        HSLColor.fromColor(Theme.of(context).scaffoldBackgroundColor)
                            .withLightness(0.88)
                            .toColor(),
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
                              : _pages[index].page,
                    ),
                  ),
                  const JobLogPanel(),
                  NavigationBar(
                    selectedIndex: index,
                    onDestinationSelected: (value) {
                      ref.read(navIndexProvider.notifier).setIndex(value);
                    },
                    destinations: _pages
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
                              ref.read(navIndexProvider.notifier).setIndex(value);
                            },
                            destinations: _pages
                                .map(
                                  (entry) => NavigationRailDestination(
                                    icon: Icon(entry.icon),
                                    label: Text(entry.label),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: DownloadManagerBubble(),
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
                                    : _pages[index].page,
                          ),
                        ),
                        const JobLogPanel(),
                      ],
                    ),
                  ),
                ],
              ),
          );
        },
      ),
    );
  }
}

class _NavEntry {
  const _NavEntry({required this.label, required this.icon, required this.page});

  final String label;
  final IconData icon;
  final Widget page;
}

class _LoadingPane extends StatelessWidget {
  const _LoadingPane();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text('Starting backend...'),
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
    return Center(
      child: Text('Backend start failed: $message'),
    );
  }
}
