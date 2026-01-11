import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:varmanager_flutter/l10n/app_localizations.dart';

import '../app/providers.dart';
import '../core/backend/download_controller.dart';
import '../core/backend/job_log_controller.dart';
import '../core/models/download_models.dart';
import '../l10n/l10n.dart';

class DownloadManagerBubble extends ConsumerStatefulWidget {
  const DownloadManagerBubble({super.key});

  @override
  ConsumerState<DownloadManagerBubble> createState() => _DownloadManagerBubbleState();
}

class _DownloadManagerBubbleState extends ConsumerState<DownloadManagerBubble> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _pinned = false;
  bool _hoverBubble = false;
  bool _hoverPanel = false;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _updateOverlay() {
    final shouldShow = _pinned || _hoverBubble || _hoverPanel;
    if (shouldShow && _overlayEntry == null) {
      _overlayEntry = _buildOverlay();
      Overlay.of(context).insert(_overlayEntry!);
    } else if (!shouldShow && _overlayEntry != null) {
      _removeOverlay();
    }
  }

  OverlayEntry _buildOverlay() {
    return OverlayEntry(
      builder: (context) {
        return Positioned.fill(
          child: IgnorePointer(
            ignoring: false,
            child: Stack(
              children: [
                CompositedTransformFollower(
                  link: _link,
                  targetAnchor: Alignment.topLeft,
                  followerAnchor: Alignment.bottomLeft,
                  offset: const Offset(0, -12),
                  showWhenUnlinked: false,
                  child: MouseRegion(
                    onEnter: (_) {
                      setState(() => _hoverPanel = true);
                      _updateOverlay();
                    },
                    onExit: (_) {
                      setState(() => _hoverPanel = false);
                      _updateOverlay();
                    },
                    child: const _DownloadManagerPanel(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final downloads = ref.watch(downloadListProvider);
    final data = downloads.value ?? DownloadListResponse.empty();
    final total = data.items.length;
    final completed =
        data.items.where((item) => item.status == 'completed').length;
    final progress = total == 0 || completed >= total
        ? 1.0
        : (completed / total).clamp(0.0, 1.0);
    final colorScheme = Theme.of(context).colorScheme;

    return CompositedTransformTarget(
      link: _link,
      child: MouseRegion(
        onEnter: (_) {
          setState(() => _hoverBubble = true);
          _updateOverlay();
        },
        onExit: (_) {
          setState(() => _hoverBubble = false);
          _updateOverlay();
        },
        child: GestureDetector(
          onTap: () {
            setState(() => _pinned = !_pinned);
            _updateOverlay();
          },
          child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.surface,
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.35),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 4,
                      backgroundColor:
                          colorScheme.primary.withValues(alpha: 0.15),
                      valueColor:
                          AlwaysStoppedAnimation(colorScheme.primary),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.download_rounded, size: 16),
                      Text(
                        total == 0 ? '0' : '$completed/$total',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ),
    );
  }
}

class _DownloadManagerPanel extends ConsumerStatefulWidget {
  const _DownloadManagerPanel();

  @override
  ConsumerState<_DownloadManagerPanel> createState() =>
      _DownloadManagerPanelState();
}

class _DownloadManagerPanelState extends ConsumerState<_DownloadManagerPanel> {
  final Set<int> _selected = {};

  static int _statusPriority(String status) {
    switch (status) {
      case 'paused':
        return 0;
      case 'downloading':
        return 1;
      case 'queued':
        return 2;
      case 'failed':
        return 3;
      case 'completed':
        return 4;
      default:
        return 5;
    }
  }

  List<DownloadItem> _sortedItems(List<DownloadItem> items) {
    final sorted = List<DownloadItem>.from(items);
    sorted.sort((a, b) {
      final priorityA = _statusPriority(a.status);
      final priorityB = _statusPriority(b.status);
      if (priorityA != priorityB) {
        return priorityA.compareTo(priorityB);
      }
      final nameA = a.name?.toLowerCase() ?? '';
      final nameB = b.name?.toLowerCase() ?? '';
      return nameA.compareTo(nameB);
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final downloads = ref.watch(downloadListProvider);
    final data = downloads.value ?? DownloadListResponse.empty();
    final items = _sortedItems(data.items);
    final summary = data.summary;
    final colorScheme = Theme.of(context).colorScheme;
    final selectedCount = _selected.length;
    final hasSelection = selectedCount > 0;

    if (_selected.isNotEmpty) {
      final existingIds = items.map((item) => item.id).toSet();
      _selected.removeWhere((id) => !existingIds.contains(id));
    }

    return Material(
      elevation: 8,
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 380,
        height: 420,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: colorScheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.downloading_rounded, size: 18),
                const SizedBox(width: 6),
                Text(
                  l10n.downloadManagerTitle,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Tooltip(
                  message: l10n.downloadImportTooltip,
                  child: TextButton.icon(
                    onPressed: _importFromFile,
                    icon: const Icon(Icons.file_open_outlined, size: 16),
                    label: Text(l10n.downloadImportLabel),
                  ),
                ),
                if (items.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        if (_selected.length == items.length) {
                          _selected.clear();
                        } else {
                          _selected
                            ..clear()
                            ..addAll(items.map((item) => item.id));
                        }
                      });
                    },
                    child: Text(
                      _selected.length == items.length
                          ? l10n.commonClear
                          : l10n.commonSelectAll,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            _SummaryRow(summary: summary),
            const SizedBox(height: 8),
            _ActionRow(
              enabled: hasSelection,
              onPause: () => _applyAction('pause', _selected.toList()),
              onResume: () => _applyAction('resume', _selected.toList()),
              onRemove: () => _applyAction('remove', _selected.toList()),
              onDelete: () => _applyAction('delete', _selected.toList()),
              selectionLabel: hasSelection
                  ? l10n.downloadSelectionCount(selectedCount)
                  : l10n.downloadNoSelection,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text(
                        l10n.downloadNoActive,
                        style: TextStyle(
                          color:
                              colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const Divider(height: 12),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final isSelected = _selected.contains(item.id);
                        return _DownloadRow(
                          item: item,
                          selected: isSelected,
                          onSelected: (value) {
                            setState(() {
                              if (value == true) {
                                _selected.add(item.id);
                              } else {
                                _selected.remove(item.id);
                              }
                            });
                          },
                          onPause: () => _applyAction('pause', [item.id]),
                          onResume: () => _applyAction('resume', [item.id]),
                          onRemove: () => _applyAction('remove', [item.id]),
                          onDelete: () => _applyAction('delete', [item.id]),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _applyAction(String action, List<int> ids) async {
    if (ids.isEmpty) {
      return;
    }
    if (!mounted) return;
    final client = ref.read(backendClientProvider);
    await client.downloadAction(action, ids);
  }

  Future<void> _importFromFile() async {
    final l10n = context.l10n;
    final file = await openFile(acceptedTypeGroups: [
      XTypeGroup(label: l10n.textFileTypeLabel, extensions: const ['txt'])
    ]);
    if (file == null) return;

    final content = await file.readAsString();
    final items = <Map<String, String>>[];
    for (final line in content.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      // 格式: "名字 链接" 或纯链接
      final lastSpace = trimmed.lastIndexOf(' ');
      if (lastSpace > 0 && trimmed.substring(lastSpace + 1).startsWith('http')) {
        items.add({
          'name': trimmed.substring(0, lastSpace),
          'url': trimmed.substring(lastSpace + 1),
        });
      } else if (trimmed.startsWith('http')) {
        items.add({'url': trimmed});
      }
    }

    if (!mounted) return;

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.downloadImportEmpty)),
      );
      return;
    }

    final runner = ref.read(jobRunnerProvider);
    final log = ref.read(jobLogProvider.notifier);
    await runner.runJob('hub_download_all', args: {'items': items}, onLog: log.addEntry);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.downloadImportSuccess(items.length))),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.summary});

  final DownloadSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final total = summary.total;
    final completed = summary.completed;
    final percent = total == 0 ? 0.0 : completed / total;
    final sizeLabel = summary.totalBytes > 0
        ? '${_formatBytes(summary.downloadedBytes)} / ${_formatBytes(summary.totalBytes)}'
        : _formatBytes(summary.downloadedBytes);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(l10n.downloadItemsProgress(completed, total),
                style: const TextStyle(fontSize: 12)),
            const Spacer(),
            Text(sizeLabel, style: const TextStyle(fontSize: 12)),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(value: percent),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.enabled,
    required this.onPause,
    required this.onResume,
    required this.onRemove,
    required this.onDelete,
    required this.selectionLabel,
  });

  final bool enabled;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onRemove;
  final VoidCallback onDelete;
  final String selectionLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    return Row(
      children: [
        Text(selectionLabel, style: TextStyle(fontSize: 11, color: muted)),
        const Spacer(),
        IconButton(
          onPressed: enabled ? onPause : null,
          icon: const Icon(Icons.pause_circle_filled, size: 20),
          tooltip: l10n.downloadActionPause,
        ),
        IconButton(
          onPressed: enabled ? onResume : null,
          icon: const Icon(Icons.play_circle_filled, size: 20),
          tooltip: l10n.downloadActionResume,
        ),
        IconButton(
          onPressed: enabled ? onRemove : null,
          icon: const Icon(Icons.clear, size: 20),
          tooltip: l10n.downloadActionRemoveRecord,
        ),
        _DeleteIconButton(
          onConfirmed: onDelete,
          icon: Icons.delete,
          tooltip: l10n.downloadActionDeleteFile,
          enabled: enabled,
          size: 20,
        ),
      ],
    );
  }
}

class _DownloadRow extends StatelessWidget {
  const _DownloadRow({
    required this.item,
    required this.selected,
    required this.onSelected,
    required this.onPause,
    required this.onResume,
    required this.onRemove,
    required this.onDelete,
  });

  final DownloadItem item;
  final bool selected;
  final ValueChanged<bool?> onSelected;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onRemove;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final total = item.totalBytes ?? 0;
    final progress = total > 0 ? item.downloadedBytes / total : null;
    final statusColor = _statusColor(item.status, colorScheme);
    final statusLabel = _statusLabel(l10n, item.status);
    final name = item.name?.trim().isNotEmpty == true
        ? item.name!.trim()
        : _nameFromUrl(item.url);
    final speedLabel = item.speedBytes > 0
        ? '${_formatBytes(item.speedBytes)}/s'
        : '';
    final sizeLabel = total > 0
        ? '${_formatBytes(item.downloadedBytes)} / ${_formatBytes(total)}'
        : _formatBytes(item.downloadedBytes);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(value: selected, onChanged: onSelected),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 10,
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (speedLabel.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(speedLabel,
                        style:
                            TextStyle(fontSize: 11, color: statusColor)),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(sizeLabel, style: const TextStyle(fontSize: 11)),
              const SizedBox(height: 6),
              if (progress != null)
                LinearProgressIndicator(value: progress),
            ],
          ),
        ),
        Column(
          children: [
            IconButton(
              onPressed: _canPause(item.status) ? onPause : null,
              icon: const Icon(Icons.pause, size: 18),
              tooltip: l10n.downloadActionPause,
            ),
            IconButton(
              onPressed: _canResume(item.status) ? onResume : null,
              icon: const Icon(Icons.play_arrow, size: 18),
              tooltip: l10n.downloadActionResume,
            ),
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.clear, size: 18),
              tooltip: l10n.downloadActionRemoveRecord,
            ),
            _DeleteIconButton(
              onConfirmed: onDelete,
              icon: Icons.delete_outline,
              tooltip: l10n.downloadActionDeleteFile,
            ),
          ],
        ),
      ],
    );
  }
}

bool _canPause(String status) {
  return status == 'downloading' || status == 'queued';
}

bool _canResume(String status) {
  return status == 'paused' || status == 'failed';
}

Color _statusColor(String status, ColorScheme scheme) {
  switch (status) {
    case 'completed':
      return Colors.green.shade600;
    case 'failed':
      return Colors.red.shade600;
    case 'paused':
      return Colors.orange.shade700;
    case 'downloading':
      return scheme.primary;
    default:
      return scheme.onSurface.withValues(alpha: 0.6);
  }
}

String _statusLabel(AppLocalizations l10n, String status) {
  switch (status) {
    case 'paused':
      return l10n.downloadStatusPaused;
    case 'downloading':
      return l10n.downloadStatusDownloading;
    case 'queued':
      return l10n.downloadStatusQueued;
    case 'failed':
      return l10n.downloadStatusFailed;
    case 'completed':
      return l10n.downloadStatusCompleted;
    default:
      return status;
  }
}

String _nameFromUrl(String url) {
  final clean = url.split('?').first;
  final parts = clean.split('/');
  return parts.isEmpty ? url : parts.last;
}

String _formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  double size = bytes.toDouble();
  int unitIndex = 0;
  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024;
    unitIndex += 1;
  }
  final precision = size >= 10 || unitIndex == 0 ? 0 : 1;
  return '${size.toStringAsFixed(precision)} ${units[unitIndex]}';
}

class _DeleteIconButton extends StatefulWidget {
  const _DeleteIconButton({
    required this.onConfirmed,
    required this.icon,
    required this.tooltip,
    this.enabled = true,
    this.size = 18,
  });

  final VoidCallback onConfirmed;
  final IconData icon;
  final String tooltip;
  final bool enabled;
  final double size;

  @override
  State<_DeleteIconButton> createState() => _DeleteIconButtonState();
}

class _DeleteIconButtonState extends State<_DeleteIconButton> {
  bool _hovering = false;

  Future<void> _handleTap() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.confirmDeleteTitle),
        content: Text(l10n.confirmDeleteMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      widget.onConfirmed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.enabled && _hovering ? Colors.red : null;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: IconButton(
        onPressed: widget.enabled ? _handleTap : null,
        icon: Icon(widget.icon, size: widget.size, color: color),
        tooltip: widget.tooltip,
      ),
    );
  }
}
