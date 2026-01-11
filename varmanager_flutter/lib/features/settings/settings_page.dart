import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:varmanager_flutter/l10n/app_localizations.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/app_version.dart';
import '../../core/models/config.dart';
import '../../l10n/l10n.dart';
import '../../l10n/locale_config.dart';
import '../bootstrap/bootstrap_keys.dart';

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
  final _proxyHost = TextEditingController();
  final _proxyPort = TextEditingController();
  final _proxyUsername = TextEditingController();
  final _proxyPassword = TextEditingController();
  ProxyMode _proxyMode = ProxyMode.system;

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
      _proxyHost.text = cfg.proxy.host;
      _proxyPort.text = cfg.proxy.port > 0 ? cfg.proxy.port.toString() : '';
      _proxyUsername.text = cfg.proxy.username ?? '';
      _proxyPassword.text = cfg.proxy.password ?? '';
      _proxyMode = cfg.proxyMode;
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
    _proxyHost.dispose();
    _proxyPort.dispose();
    _proxyUsername.dispose();
    _proxyPassword.dispose();
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
      'proxy_mode': _proxyMode.name,
      'proxy': {
        'host': _proxyHost.text.trim(),
        'port': int.tryParse(_proxyPort.text.trim()) ?? 0,
        'username': _proxyUsername.text.trim(),
        'password': _proxyPassword.text.trim(),
      },
    };
    final cfg = await client.updateConfig(update);
    if (!mounted) return;
    setState(() {
      _config = cfg;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.configSavedRestartHint)),
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
    final l10n = context.l10n;
    final manualProxy = _proxyMode == ProxyMode.manual;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            _section(
              title: l10n.settingsSectionUi,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildThemeSelector(l10n),
                  const SizedBox(height: 16),
                  _buildLanguageSelector(l10n),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _section(
              title: l10n.settingsSectionListen,
              child: Column(
                children: [
                  _field(_listenHost, l10n.listenHostLabel),
                  _field(_listenPort, l10n.listenPortLabel,
                      keyboard: TextInputType.number),
                  _field(_logLevel, l10n.logLevelLabel),
                  _field(_jobConcurrency, l10n.jobConcurrencyLabel,
                      keyboard: TextInputType.number),
                  const SizedBox(height: 4),
                  Text(l10n.proxySectionLabel,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<ProxyMode>(
                    value: _proxyMode,
                    decoration: InputDecoration(
                      labelText: l10n.proxyModeLabel,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: ProxyMode.system,
                        child: Text(l10n.proxyModeSystem),
                      ),
                      DropdownMenuItem(
                        value: ProxyMode.manual,
                        child: Text(l10n.proxyModeManual),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _proxyMode = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  if (manualProxy) ...[
                    _field(_proxyHost, l10n.proxyHostLabel),
                    _field(_proxyPort, l10n.proxyPortLabel,
                        keyboard: TextInputType.number),
                    _field(_proxyUsername, l10n.proxyUserLabel),
                    _field(
                      _proxyPassword,
                      l10n.proxyPasswordLabel,
                      obscureText: true,
                      enableSuggestions: false,
                      autocorrect: false,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            _section(
              title: l10n.settingsSectionPaths,
              child: Column(
                children: [
                  _pathField(
                    _varspath,
                    l10n.varspathLabel,
                    hintText: l10n.chooseVamHint,
                    onBrowse: _pickVarspathDirectory,
                  ),
                  _pathField(
                    _vampath,
                    l10n.vampathLabel,
                    hintText: l10n.chooseVamHint,
                    onBrowse: () => _pickDirectory(_vampath),
                  ),
                  _pathField(
                    _vamExec,
                    l10n.vamExecLabel,
                    onBrowse: () => _pickFile(_vamExec),
                  ),
                  _pathField(
                    _downloaderSavePath,
                    l10n.downloaderSavePathLabel,
                    hintText: l10n.chooseAddonPackagesHint,
                    onBrowse: () => _pickDirectory(_downloaderSavePath),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _section(
              title: l10n.settingsSectionAbout,
              child: Column(
                children: [
                  _infoRow(l10n.appVersionLabel, _appVersion ?? '-'),
                  _infoRow(l10n.backendVersionLabel, _backendVersion ?? '-'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _save,
                child: Text(l10n.commonSave),
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
      {TextInputType keyboard = TextInputType.text,
      bool obscureText = false,
      bool enableSuggestions = true,
      bool autocorrect = true,
      bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        obscureText: obscureText,
        enableSuggestions: enableSuggestions,
        autocorrect: autocorrect,
        enabled: enabled,
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
    Key? anchorKey,
  }) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        key: anchorKey,
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
              child: Text(l10n.commonBrowse),
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

  Widget _buildThemeSelector(AppLocalizations l10n) {
    final currentTheme = ref.watch(themeProvider);
    return Column(
      key: BootstrapKeys.settingsThemeSelector,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.themeLabel, style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: AppThemeType.values.map((theme) {
            final isSelected = currentTheme == theme;
            return _ThemeCard(
              theme: theme,
              label: _themeLabel(theme, l10n),
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

  Widget _buildLanguageSelector(AppLocalizations l10n) {
    final locale = ref.watch(localeProvider);
    final currentTag = localeTagFromLocale(locale);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.languageLabel, style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: currentTag,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: [
            DropdownMenuItem(
              value: kEnglishLocaleTag,
              child: Text(l10n.languageEnglish),
            ),
            DropdownMenuItem(
              value: kChineseLocaleTag,
              child: Text(l10n.languageChinese),
            ),
          ],
          onChanged: (value) {
            if (value == null) return;
            ref.read(localeProvider.notifier).setLocale(localeFromTag(value));
          },
        ),
      ],
    );
  }

  String _themeLabel(AppThemeType theme, AppLocalizations l10n) {
    switch (theme) {
      case AppThemeType.defaultTheme:
        return l10n.themeDefault;
      case AppThemeType.ocean:
        return l10n.themeOcean;
      case AppThemeType.forest:
        return l10n.themeForest;
      case AppThemeType.rose:
        return l10n.themeRose;
      case AppThemeType.dark:
        return l10n.themeDark;
    }
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.theme,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final AppThemeType theme;
  final String label;
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
                label,
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
