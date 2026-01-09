import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/app_version.dart';
import '../../core/models/config.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _listenHost = TextEditingController();
  final _listenPort = TextEditingController();
  final _logLevel = TextEditingController();
  final _jobConcurrency = TextEditingController();
  final _varspath = TextEditingController();
  final _vampath = TextEditingController();
  final _vamExec = TextEditingController();
  final _downloaderSavePath = TextEditingController();

  AppConfig? _config;
  String? _backendVersion;
  String? _appVersion;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final client = ref.read(backendClientProvider);
    final cfg = await client.getConfig();
    final appVersion = await loadAppVersion();
    String? backendVersion;
    try {
      final health = await client.getHealth();
      backendVersion = health['version']?.toString();
    } catch (_) {
      backendVersion = null;
    }
    if (!mounted) return;
    setState(() {
      _config = cfg;
      _backendVersion = backendVersion;
      _appVersion = appVersion;
      _listenHost.text = cfg.listenHost;
      _listenPort.text = cfg.listenPort.toString();
      _logLevel.text = cfg.logLevel;
      _jobConcurrency.text = cfg.jobConcurrency.toString();
      _varspath.text = cfg.varspath ?? '';
      _vampath.text = cfg.vampath ?? '';
      _vamExec.text = cfg.vamExec ?? '';
      _downloaderSavePath.text = cfg.downloaderSavePath ?? '';
    });
  }

  @override
  void dispose() {
    _listenHost.dispose();
    _listenPort.dispose();
    _logLevel.dispose();
    _jobConcurrency.dispose();
    _varspath.dispose();
    _vampath.dispose();
    _vamExec.dispose();
    _downloaderSavePath.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_downloaderSavePath.text.trim().isEmpty) {
      final next = _addonPackagesPath(_varspath.text);
      if (next.isNotEmpty) {
        _downloaderSavePath.text = next;
      }
    }
    final client = ref.read(backendClientProvider);
    final update = <String, dynamic>{
      'listen_host': _listenHost.text.trim(),
      'listen_port': int.tryParse(_listenPort.text.trim()) ?? 57123,
      'log_level': _logLevel.text.trim(),
      'job_concurrency': int.tryParse(_jobConcurrency.text.trim()) ?? 10,
      'varspath': _varspath.text.trim(),
      'vampath': _vampath.text.trim(),
      'vam_exec': _vamExec.text.trim(),
      'downloader_save_path': _downloaderSavePath.text.trim(),
    };
    final cfg = await client.updateConfig(update);
    if (!mounted) return;
    setState(() {
      _config = cfg;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Config saved; listen_host/port applies after restart.')),
    );
  }

  Future<void> _pickDirectory(TextEditingController controller) async {
    final path = await getDirectoryPath();
    if (path == null) return;
    setState(() {
      controller.text = path;
    });
  }

  Future<void> _pickVarspathDirectory() async {
    final path = await getDirectoryPath();
    if (path == null) return;
    setState(() {
      _varspath.text = path;
      if (_downloaderSavePath.text.trim().isEmpty) {
        _downloaderSavePath.text = _addonPackagesPath(path);
      }
    });
  }

  Future<void> _pickFile(TextEditingController controller) async {
    final file = await openFile();
    if (file == null) return;
    setState(() {
      controller.text = file.path;
    });
  }

  String _addonPackagesPath(String base) {
    final trimmed = base.trim();
    if (trimmed.isEmpty) return '';
    return p.join(trimmed, 'AddonPackages');
  }

  @override
  Widget build(BuildContext context) {
    if (_config == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            _section(
              title: 'UI',
              child: _buildThemeSelector(),
            ),
            const SizedBox(height: 12),
            _section(
              title: 'Listen & Logs',
              child: Column(
                children: [
                  _field(_listenHost, 'listen_host'),
                  _field(_listenPort, 'listen_port', keyboard: TextInputType.number),
                  _field(_logLevel, 'log_level'),
                  _field(_jobConcurrency, 'job_concurrency',
                      keyboard: TextInputType.number),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _section(
              title: 'Paths',
              child: Column(
                children: [
                  _pathField(
                    _varspath,
                    'varspath',
                    hintText: 'choose virt_a_mate',
                    onBrowse: _pickVarspathDirectory,
                  ),
                  _pathField(
                    _vampath,
                    'vampath',
                    hintText: 'choose virt_a_mate',
                    onBrowse: () => _pickDirectory(_vampath),
                  ),
                  _pathField(
                    _vamExec,
                    'vam_exec',
                    onBrowse: () => _pickFile(_vamExec),
                  ),
                  _pathField(
                    _downloaderSavePath,
                    'downloader_save_path',
                    hintText: 'choose AddonPackages',
                    onBrowse: () => _pickDirectory(_downloaderSavePath),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _section(
              title: 'About',
              child: Column(
                children: [
                  _infoRow('App version', _appVersion ?? '-'),
                  _infoRow('Backend version', _backendVersion ?? '-'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _save,
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section({required String title, required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label,
      {TextInputType keyboard = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _pathField(
    TextEditingController controller,
    String label, {
    String? hintText,
    TextInputType keyboard = TextInputType.text,
    VoidCallback? onBrowse,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: keyboard,
              decoration: InputDecoration(
                labelText: label,
                hintText: hintText,
                floatingLabelBehavior: hintText == null
                    ? FloatingLabelBehavior.auto
                    : FloatingLabelBehavior.always,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          if (onBrowse != null) ...[
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: onBrowse,
              child: const Text('Browse'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildThemeSelector() {
    final currentTheme = ref.watch(themeProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Theme', style: TextStyle(fontSize: 14)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: AppThemeType.values.map((theme) {
            final isSelected = currentTheme == theme;
            return _ThemeCard(
              theme: theme,
              isSelected: isSelected,
              onTap: () {
                ref.read(themeProvider.notifier).setTheme(theme);
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.theme,
    required this.isSelected,
    required this.onTap,
  });

  final AppThemeType theme;
  final bool isSelected;
  final VoidCallback onTap;

  Color get _previewColor {
    switch (theme) {
      case AppThemeType.defaultTheme:
        return const Color(0xFF1F5E5B);
      case AppThemeType.ocean:
        return const Color(0xFF1565C0);
      case AppThemeType.forest:
        return const Color(0xFF2E7D32);
      case AppThemeType.rose:
        return const Color(0xFFC2185B);
      case AppThemeType.dark:
        return const Color(0xFF121212);
    }
  }

  Color get _secondaryColor {
    switch (theme) {
      case AppThemeType.defaultTheme:
        return const Color(0xFFB86B2B);
      case AppThemeType.ocean:
        return const Color(0xFF0288D1);
      case AppThemeType.forest:
        return const Color(0xFF558B2F);
      case AppThemeType.rose:
        return const Color(0xFFE91E63);
      case AppThemeType.dark:
        return const Color(0xFF80CBC4);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = theme == AppThemeType.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 120,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isDarkTheme ? _previewColor : _previewColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _previewColor, width: 3),
                ),
                child: Center(
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: _secondaryColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Icon(
                theme.icon,
                size: 20,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(height: 4),
              Text(
                theme.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
