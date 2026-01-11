import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/l10n.dart';
import 'bootstrap_controller.dart';
import 'bootstrap_keys.dart';
import 'bootstrap_state.dart';

class BootstrapGate extends ConsumerStatefulWidget {
  const BootstrapGate({super.key});

  @override
  ConsumerState<BootstrapGate> createState() => _BootstrapGateState();
}

class _BootstrapGateState extends ConsumerState<BootstrapGate> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bootstrapProvider);
    if (!state.active) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    if (state.isTourStep) {
      return Positioned.fill(
        child: BootstrapTourCoach(step: state.step),
      );
    }
    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: Colors.black.withOpacity(0.35),
          ),
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _buildModal(context, ref, state, l10n),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModal(
    BuildContext context,
    WidgetRef ref,
    BootstrapState state,
    AppLocalizations l10n,
  ) {
    switch (state.step) {
      case BootstrapStep.welcome:
        return _WelcomeStep(
          onSkip: () => confirmBootstrapSkip(context, ref, l10n),
          onNext: () => ref.read(bootstrapProvider.notifier).nextStep(),
        );
      case BootstrapStep.features:
        return _FeaturesStep(
          onBack: () => ref.read(bootstrapProvider.notifier).previousStep(),
          onNext: () => ref.read(bootstrapProvider.notifier).nextStep(),
        );
      case BootstrapStep.config:
        return const _ConfigStep();
      case BootstrapStep.checks:
        return const _ChecksStep();
      case BootstrapStep.finish:
        return _FinishStep(
          onBack: () => ref.read(bootstrapProvider.notifier).previousStep(),
          onFinish: () async {
            final ok = await ref.read(bootstrapProvider.notifier).complete();
            if (!ok && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.bootstrapFinishDeleteFailed)),
              );
            }
          },
        );
      case BootstrapStep.tourHome:
      case BootstrapStep.tourScenes:
      case BootstrapStep.tourHubTags:
      case BootstrapStep.tourHubDownloads:
      case BootstrapStep.tourSettings:
        return const SizedBox.shrink();
    }
  }

  
}

class BootstrapTourData {
  const BootstrapTourData({
    required this.targetKey,
    required this.title,
    required this.body,
  });

  final GlobalKey targetKey;
  final String title;
  final String body;
}

BootstrapTourData resolveBootstrapTourData(
  BootstrapStep step,
  AppLocalizations l10n,
) {
  switch (step) {
    case BootstrapStep.tourHome:
      return BootstrapTourData(
        targetKey: BootstrapKeys.homeUpdateDbButton,
        title: l10n.bootstrapTourHomeTitle,
        body: l10n.bootstrapTourHomeBody,
      );
    case BootstrapStep.tourScenes:
      return BootstrapTourData(
        targetKey: BootstrapKeys.scenesColumnHeader,
        title: l10n.bootstrapTourScenesTitle,
        body: l10n.bootstrapTourScenesBody,
      );
    case BootstrapStep.tourHubTags:
      return BootstrapTourData(
        targetKey: BootstrapKeys.hubTagFilter,
        title: l10n.bootstrapTourHubTagsTitle,
        body: l10n.bootstrapTourHubTagsBody,
      );
    case BootstrapStep.tourHubDownloads:
      return BootstrapTourData(
        targetKey: BootstrapKeys.hubDownloadAllButton,
        title: l10n.bootstrapTourHubDownloadsTitle,
        body: l10n.bootstrapTourHubDownloadsBody,
      );
    case BootstrapStep.tourSettings:
      return BootstrapTourData(
        targetKey: BootstrapKeys.settingsThemeSelector,
        title: l10n.bootstrapTourSettingsTitle,
        body: l10n.bootstrapTourSettingsBody,
      );
    case BootstrapStep.welcome:
    case BootstrapStep.features:
    case BootstrapStep.config:
    case BootstrapStep.checks:
    case BootstrapStep.finish:
      return BootstrapTourData(
        targetKey: BootstrapKeys.homeUpdateDbButton,
        title: '',
        body: '',
      );
  }
}

bool hasPreviousBootstrapStep(BootstrapStep step) {
  return step != BootstrapStep.welcome;
}

Future<bool> confirmBootstrapSkip(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations l10n,
) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(l10n.bootstrapSkipConfirmTitle),
        content: Text(l10n.bootstrapSkipConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.bootstrapSkipConfirmYes),
          ),
        ],
      );
    },
  );
  if (result != true) return false;
  final ok = await ref.read(bootstrapProvider.notifier).skip();
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.bootstrapFinishDeleteFailed)),
    );
  }
  return true;
}

class BootstrapTourCoach extends ConsumerStatefulWidget {
  const BootstrapTourCoach({super.key, required this.step});

  final BootstrapStep step;

  @override
  ConsumerState<BootstrapTourCoach> createState() => _BootstrapTourCoachState();
}

class _BootstrapTourCoachState extends ConsumerState<BootstrapTourCoach> {
  static const double _focusPadding = 8;
  static const double _focusRadius = 12;
  static const Duration _targetRetryDelay = Duration(milliseconds: 80);
  static const int _targetRetryCount = 10;
  static const double _hubPanelWidth = 340;
  static const double _hubPanelPadding = 16;
  static const double _navRailWidth = 92;

  TutorialCoachMark? _coachMark;
  int _showToken = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showForStep(widget.step));
  }

  @override
  void didUpdateWidget(covariant BootstrapTourCoach oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.step != widget.step) {
      _showForStep(widget.step);
    }
  }

  @override
  void dispose() {
    _coachMark?.removeOverlayEntry();
    _coachMark = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }

  Future<void> _showForStep(BootstrapStep step) async {
    final data = resolveBootstrapTourData(step, context.l10n);
    final token = ++_showToken;
    final isHubStep = _isHubStep(step);
    Rect? rect;
    TargetPosition? targetPosition;
    GlobalKey? keyTarget;
    if (isHubStep) {
      if (step == BootstrapStep.tourHubDownloads) {
        await _scrollToTarget(data.targetKey);
      }
      rect = _resolveTargetRect(data.targetKey);
      if (rect != null) {
        keyTarget = data.targetKey;
      } else {
        rect = _resolveHubFallbackRect(step);
        targetPosition = TargetPosition(rect.size, rect.topLeft);
      }
    } else {
      final ready = await _waitForTarget(data.targetKey);
      if (!mounted || token != _showToken || !ready) {
        return;
      }
      rect = _resolveTargetRect(data.targetKey);
      if (rect == null) {
        return;
      }
      keyTarget = data.targetKey;
    }
    if (!mounted || token != _showToken) {
      return;
    }
    final align = _resolveContentAlign(rect, MediaQuery.of(context).size);
    final target = _buildTarget(
      step,
      data,
      align,
      keyTarget: keyTarget,
      targetPosition: targetPosition,
    );

    _coachMark?.removeOverlayEntry();
    _coachMark = TutorialCoachMark(
      targets: [target],
      hideSkip: true,
      colorShadow: Colors.black,
      opacityShadow: 0.28,
      paddingFocus: _focusPadding,
      useSafeArea: true,
      onFinish: () {},
      onSkip: () => true,
    );
    _coachMark?.show(context: context, rootOverlay: true);
  }

  TargetFocus _buildTarget(
    BootstrapStep step,
    BootstrapTourData data,
    ContentAlign align,
    {GlobalKey? keyTarget, TargetPosition? targetPosition}
  ) {
    final l10n = context.l10n;
    final onBack = hasPreviousBootstrapStep(step)
        ? () => _handleBack()
        : null;
    return TargetFocus(
      identify: step.name,
      keyTarget: keyTarget,
      targetPosition: targetPosition,
      shape: ShapeLightFocus.RRect,
      radius: _focusRadius,
      paddingFocus: _focusPadding,
      borderSide: BorderSide(
        color: Theme.of(context).colorScheme.primary,
        width: 2,
      ),
      enableOverlayTab: false,
      enableTargetTab: false,
      contents: [
        TargetContent(
          align: align,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          builder: (context, controller) {
            final size = MediaQuery.of(context).size;
            final bubbleWidth = size.width < 520 ? size.width - 32 : 420.0;
            return Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: bubbleWidth),
                child: _CoachBubble(
                  title: data.title,
                  message: data.body,
                  onBack: onBack,
                  onNext: _handleNext,
                  onSkip: _handleSkip,
                  nextLabel: l10n.commonNext,
                  backLabel: l10n.commonBack,
                  skipLabel: l10n.commonSkip,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  ContentAlign _resolveContentAlign(Rect? rect, Size screenSize) {
    if (rect == null) {
      return ContentAlign.bottom;
    }
    final placeBelow = rect.bottom + 220 < screenSize.height;
    return placeBelow ? ContentAlign.bottom : ContentAlign.top;
  }

  bool _isHubStep(BootstrapStep step) {
    return step == BootstrapStep.tourHubTags ||
        step == BootstrapStep.tourHubDownloads;
  }

  Rect _resolveHubFallbackRect(BootstrapStep step) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final isCompact = size.width < 900;
    final navWidth = isCompact ? 0.0 : _navRailWidth;
    final left = navWidth + _hubPanelPadding;
    final maxWidth = size.width - left - _hubPanelPadding;
    final width = maxWidth < 220 ? maxWidth : _hubPanelWidth;
    final top = media.padding.top + kToolbarHeight + _hubPanelPadding;
    final bottom = media.padding.bottom + _hubPanelPadding;
    final availableHeight = size.height - top - bottom;
    final panelHeight = availableHeight.clamp(260.0, size.height);
    final filterHeight = panelHeight * 0.5;
    final downloadHeight = panelHeight * 0.28;

    if (step == BootstrapStep.tourHubTags) {
      return Rect.fromLTWH(left, top + 8, width, filterHeight);
    }
    final downloadTop = top + panelHeight - downloadHeight - 8;
    return Rect.fromLTWH(left, downloadTop, width, downloadHeight);
  }

  Future<void> _scrollToTarget(GlobalKey key) async {
    for (var i = 0; i < _targetRetryCount; i++) {
      if (!mounted) return;
      final targetContext = key.currentContext;
      if (targetContext != null) {
        await Scrollable.ensureVisible(
          targetContext,
          alignment: 0.5,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
        await Future.delayed(const Duration(milliseconds: 60));
        return;
      }
      await Future.delayed(_targetRetryDelay);
    }
  }

  Future<bool> _waitForTarget(GlobalKey key) async {
    for (var i = 0; i < _targetRetryCount; i++) {
      if (_hasTarget(key)) {
        return true;
      }
      await Future.delayed(_targetRetryDelay);
    }
    return _hasTarget(key);
  }

  bool _hasTarget(GlobalKey key) {
    final targetContext = key.currentContext;
    final renderObject = targetContext?.findRenderObject();
    return renderObject is RenderBox &&
        renderObject.hasSize &&
        renderObject.attached;
  }

  Rect? _resolveTargetRect(GlobalKey key) {
    final targetContext = key.currentContext;
    final renderObject = targetContext?.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize && renderObject.attached) {
      final offset = renderObject.localToGlobal(Offset.zero);
      return offset & renderObject.size;
    }
    return null;
  }

  void _handleNext() {
    _coachMark?.removeOverlayEntry();
    ref.read(bootstrapProvider.notifier).nextStep();
  }

  void _handleBack() {
    _coachMark?.removeOverlayEntry();
    ref.read(bootstrapProvider.notifier).previousStep();
  }

  Future<void> _handleSkip() async {
    _coachMark?.removeOverlayEntry();
    final skipped = await confirmBootstrapSkip(context, ref, context.l10n);
    if (!skipped && mounted) {
      final state = ref.read(bootstrapProvider);
      if (state.active && state.step == widget.step) {
        _showForStep(widget.step);
      }
    }
  }
}

class _CoachBubble extends StatelessWidget {
  const _CoachBubble({
    required this.title,
    required this.message,
    required this.onNext,
    required this.onSkip,
    required this.nextLabel,
    required this.skipLabel,
    this.onBack,
    this.backLabel,
  });

  final String title;
  final String message;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final VoidCallback? onBack;
  final String nextLabel;
  final String skipLabel;
  final String? backLabel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(message),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: onSkip,
                  child: Text(skipLabel),
                ),
                const Spacer(),
                if (onBack != null)
                  OutlinedButton(
                    onPressed: onBack,
                    child: Text(backLabel ?? ''),
                  ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: onNext,
                  child: Text(nextLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeStep extends ConsumerWidget {
  const _WelcomeStep({
    required this.onSkip,
    required this.onNext,
  });

  final VoidCallback onSkip;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return BootstrapDialogFrame(
      key: const ValueKey('welcome'),
      title: l10n.bootstrapWelcomeTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.bootstrapWelcomeBody),
          const SizedBox(height: 16),
          Text(l10n.bootstrapWelcomeHint,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onSkip,
          child: Text(l10n.bootstrapWelcomeSkip),
        ),
        FilledButton(
          onPressed: onNext,
          child: Text(l10n.bootstrapWelcomeStart),
        ),
      ],
    );
  }
}

class _FeaturesStep extends ConsumerWidget {
  const _FeaturesStep({
    required this.onBack,
    required this.onNext,
  });

  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final items = [
      _FeatureItem(Icons.inventory_2_outlined, l10n.bootstrapFeatureVars),
      _FeatureItem(Icons.photo_library_outlined, l10n.bootstrapFeatureScenes),
      _FeatureItem(Icons.cloud_download_outlined, l10n.bootstrapFeatureHub),
      _FeatureItem(Icons.switch_access_shortcut_outlined,
          l10n.bootstrapFeaturePacks),
    ];
    return BootstrapDialogFrame(
      key: const ValueKey('features'),
      title: l10n.bootstrapFeaturesTitle,
      child: Column(
        children: [
          for (final item in items) ...[
            _FeatureRow(item: item),
            const SizedBox(height: 12),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: onBack,
          child: Text(l10n.commonBack),
        ),
        FilledButton(
          onPressed: onNext,
          child: Text(l10n.commonNext),
        ),
      ],
    );
  }
}

class _FeatureItem {
  const _FeatureItem(this.icon, this.text);

  final IconData icon;
  final String text;
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.item});

  final _FeatureItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(item.icon, size: 22, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(child: Text(item.text)),
      ],
    );
  }
}

class _ConfigStep extends ConsumerStatefulWidget {
  const _ConfigStep();

  @override
  ConsumerState<_ConfigStep> createState() => _ConfigStepState();
}

class _ConfigStepState extends ConsumerState<_ConfigStep> {
  final _formKey = GlobalKey<FormState>();
  final _varspath = TextEditingController();
  final _vampath = TextEditingController();
  final _vamExec = TextEditingController();
  final _downloaderSavePath = TextEditingController();
  bool _loaded = false;

  @override
  void dispose() {
    _varspath.dispose();
    _vampath.dispose();
    _vamExec.dispose();
    _downloaderSavePath.dispose();
    super.dispose();
  }

  void _loadConfigIfNeeded(BootstrapConfig config) {
    if (_loaded) return;
    _loaded = true;
    _varspath.text = config.varspath;
    _vampath.text = config.vampath;
    _vamExec.text = config.vamExec;
    _downloaderSavePath.text = config.downloaderSavePath;
  }

  void _applyVarspathDefaults(String path) {
    if (path.trim().isEmpty) return;
    if (_downloaderSavePath.text.trim().isEmpty) {
      _downloaderSavePath.text = p.join(path.trim(), 'AddonPackages');
    }
    if (_vamExec.text.trim().isEmpty || _vamExec.text.trim() == 'VaM (Desktop Mode).bat') {
      _vamExec.text = 'VaM (Desktop Mode).bat';
    }
  }

  Future<void> _pickVarspath() async {
    final path = await getDirectoryPath();
    if (path == null) return;
    setState(() {
      _varspath.text = path;
      _applyVarspathDefaults(path);
    });
  }

  Future<void> _pickDirectory(TextEditingController controller) async {
    final path = await getDirectoryPath();
    if (path == null) return;
    setState(() {
      controller.text = path;
    });
  }

  Future<void> _pickFile(TextEditingController controller) async {
    final file = await openFile();
    if (file == null) return;
    setState(() {
      controller.text = file.path;
    });
  }

  BootstrapConfig _currentConfig() {
    return BootstrapConfig(
      varspath: _varspath.text.trim(),
      vampath: _vampath.text.trim(),
      vamExec: _vamExec.text.trim(),
      downloaderSavePath: _downloaderSavePath.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bootstrapProvider);
    final l10n = context.l10n;
    _loadConfigIfNeeded(state.config);

    return BootstrapDialogFrame(
      key: const ValueKey('config'),
      title: l10n.bootstrapConfigTitle,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Text(l10n.bootstrapConfigBody),
            const SizedBox(height: 12),
            _pathField(
              controller: _varspath,
              label: l10n.varspathLabel,
              hint: l10n.chooseVamHint,
              onBrowse: _pickVarspath,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.bootstrapConfigVarspathRequired;
                }
                return null;
              },
              onChanged: (value) => _applyVarspathDefaults(value),
            ),
            _pathField(
              controller: _vampath,
              label: l10n.vampathLabel,
              hint: l10n.chooseVamHint,
              onBrowse: () => _pickDirectory(_vampath),
            ),
            _pathField(
              controller: _vamExec,
              label: l10n.vamExecLabel,
              hint: l10n.bootstrapConfigVamExecHint,
              onBrowse: () => _pickFile(_vamExec),
            ),
            _pathField(
              controller: _downloaderSavePath,
              label: l10n.downloaderSavePathLabel,
              hint: l10n.chooseAddonPackagesHint,
              onBrowse: () => _pickDirectory(_downloaderSavePath),
            ),
            if (state.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                state.errorMessage!,
                style: TextStyle(color: Colors.red.shade700),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => ref.read(bootstrapProvider.notifier).previousStep(),
          child: Text(l10n.commonBack),
        ),
        FilledButton(
          onPressed: state.savingConfig
              ? null
              : () async {
                  if (!_formKey.currentState!.validate()) return;
                  final ok = await ref
                      .read(bootstrapProvider.notifier)
                      .saveConfig(_currentConfig());
                  if (ok) {
                    ref.read(bootstrapProvider.notifier).nextStep();
                  }
                },
          child: Text(l10n.commonNext),
        ),
      ],
    );
  }

  Widget _pathField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required VoidCallback onBrowse,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: controller,
              onChanged: onChanged,
              validator: validator,
              decoration: InputDecoration(
                labelText: label,
                hintText: hint,
                floatingLabelBehavior: FloatingLabelBehavior.always,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onBrowse,
            child: Text(l10n.commonBrowse),
          ),
        ],
      ),
    );
  }
}

class _ChecksStep extends ConsumerWidget {
  const _ChecksStep();

  Future<bool> _confirmSkipChecks(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.bootstrapChecksSkipTitle),
          content: Text(l10n.bootstrapChecksSkipBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.commonNext),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bootstrapProvider);
    final l10n = context.l10n;

    return BootstrapDialogFrame(
      key: const ValueKey('checks'),
      title: l10n.bootstrapChecksTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.bootstrapChecksBody),
          const SizedBox(height: 12),
          SizedBox(
            height: 260,
            child: ListView.builder(
              itemCount: state.checks.length,
              itemBuilder: (context, index) {
                final item = state.checks[index];
                return _CheckTile(item: item);
              },
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: state.checksRunning
                  ? null
                  : () => ref.read(bootstrapProvider.notifier).runChecks(
                        l10n.bootstrapCheckBackendLabel,
                        l10n.bootstrapCheckVarspathLabel,
                        l10n.bootstrapCheckDownloaderLabel,
                        l10n.bootstrapCheckFileOpsLabel,
                        l10n.bootstrapCheckSymlinkLabel,
                        l10n.bootstrapCheckVamExecLabel,
                        varspathHint: l10n.bootstrapCheckVarspathHint,
                        downloaderHint: l10n.bootstrapCheckDownloaderHint,
                        fileOpsHint: l10n.bootstrapCheckFileOpsHint,
                        symlinkHint: l10n.bootstrapCheckSymlinkHint,
                        vamExecHint: l10n.bootstrapCheckVamExecHint,
                      ),
              icon: state.checksRunning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.fact_check_outlined),
              label: Text(l10n.bootstrapRunChecks),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => ref.read(bootstrapProvider.notifier).previousStep(),
          child: Text(l10n.commonBack),
        ),
        FilledButton(
          onPressed: state.checksRunning
              ? null
              : () async {
                  if (!state.checksRan) {
                    final ok = await _confirmSkipChecks(context, l10n);
                    if (!ok) return;
                  }
                  ref.read(bootstrapProvider.notifier).nextStep();
                },
          child: Text(l10n.commonNext),
        ),
      ],
    );
  }
}

class _CheckTile extends StatelessWidget {
  const _CheckTile({required this.item});

  final BootstrapCheckItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (icon, color, label) = _statusMeta(context, item.status, l10n);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(label, style: TextStyle(color: color)),
              ],
            ),
            if (item.message.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(item.message, style: const TextStyle(fontSize: 12)),
            ],
            if (item.hints.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                item.hints.join('\n'),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  (IconData, Color, String) _statusMeta(
    BuildContext context,
    BootstrapCheckStatus status,
    AppLocalizations l10n,
  ) {
    switch (status) {
      case BootstrapCheckStatus.pass:
        return (Icons.check_circle, Colors.green.shade700, l10n.bootstrapCheckStatusPass);
      case BootstrapCheckStatus.warn:
        return (Icons.warning_amber_rounded, Colors.orange.shade700,
            l10n.bootstrapCheckStatusWarn);
      case BootstrapCheckStatus.fail:
        return (Icons.error_outline, Colors.red.shade700, l10n.bootstrapCheckStatusFail);
      case BootstrapCheckStatus.pending:
        return (Icons.hourglass_empty, Colors.blueGrey.shade400,
            l10n.bootstrapCheckStatusPending);
    }
  }
}

class _FinishStep extends ConsumerWidget {
  const _FinishStep({
    required this.onBack,
    required this.onFinish,
  });

  final VoidCallback onBack;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return BootstrapDialogFrame(
      key: const ValueKey('finish'),
      title: l10n.bootstrapFinishTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.bootstrapFinishBody),
          const SizedBox(height: 12),
          Text(
            l10n.bootstrapFinishHint,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onBack,
          child: Text(l10n.commonBack),
        ),
        FilledButton(
          onPressed: onFinish,
          child: Text(l10n.bootstrapFinishStart),
        ),
      ],
    );
  }
}

class BootstrapDialogFrame extends StatelessWidget {
  const BootstrapDialogFrame({
    super.key,
    required this.title,
    required this.child,
    required this.actions,
  });

  final String title;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          elevation: 8,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                child,
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
