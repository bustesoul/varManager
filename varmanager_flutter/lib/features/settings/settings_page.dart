import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
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
  final _downloaderPath = TextEditingController();
  final _downloaderSavePath = TextEditingController();

  AppConfig? _config;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final client = ref.read(backendClientProvider);
    final cfg = await client.getConfig();
    if (!mounted) return;
    setState(() {
      _config = cfg;
      _listenHost.text = cfg.listenHost;
      _listenPort.text = cfg.listenPort.toString();
      _logLevel.text = cfg.logLevel;
      _jobConcurrency.text = cfg.jobConcurrency.toString();
      _varspath.text = cfg.varspath ?? '';
      _vampath.text = cfg.vampath ?? '';
      _vamExec.text = cfg.vamExec ?? '';
      _downloaderPath.text = cfg.downloaderPath ?? '';
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
    _downloaderPath.dispose();
    _downloaderSavePath.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final client = ref.read(backendClientProvider);
    final update = <String, dynamic>{
      'listen_host': _listenHost.text.trim(),
      'listen_port': int.tryParse(_listenPort.text.trim()) ?? 57123,
      'log_level': _logLevel.text.trim(),
      'job_concurrency': int.tryParse(_jobConcurrency.text.trim()) ?? 2,
      'varspath': _varspath.text.trim(),
      'vampath': _vampath.text.trim(),
      'vam_exec': _vamExec.text.trim(),
      'downloader_path': _downloaderPath.text.trim(),
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
                  _field(_varspath, 'varspath'),
                  _field(_vampath, 'vampath'),
                  _field(_vamExec, 'vam_exec'),
                  _field(_downloaderPath, 'downloader_path'),
                  _field(_downloaderSavePath, 'downloader_save_path'),
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
}
