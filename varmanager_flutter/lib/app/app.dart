import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/backend/job_log_controller.dart';
import '../features/home/home_page.dart';
import '../features/hub/hub_page.dart';
import '../features/scenes/scenes_page.dart';
import '../features/settings/settings_page.dart';
import '../widgets/job_log_panel.dart';
import 'providers.dart';
import 'theme.dart';

class VarManagerApp extends StatelessWidget {
  const VarManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'varManager',
      theme: AppTheme.build(),
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
      // baseUrl is already resolved and injected in main.dart via overrideWithValue
      await ref.read(backendProcessManagerProvider).start();
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
        title: const Text('varManager'),
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF2EEE9), Color(0xFFE9E2D9)],
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
                  NavigationRail(
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
