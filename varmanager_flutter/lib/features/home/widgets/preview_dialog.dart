import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../core/backend/backend_client.dart';
import '../../../widgets/image_preview_dialog.dart';
import '../models.dart';

class PreviewDialog extends StatelessWidget {
  const PreviewDialog({
    super.key,
    required this.items,
    required this.initialIndex,
    required this.client,
    required this.onIndexChanged,
  });

  final List<PreviewItem> items;
  final int initialIndex;
  final BackendClient client;
  final ValueChanged<int> onIndexChanged;

  String? _previewPath(PreviewItem item) {
    if (item.previewPic == null || item.previewPic!.isEmpty) {
      return null;
    }
    return '___PreviewPics___/${item.atomType}/${item.varName}/${item.previewPic}';
  }

  String _sceneTitle(PreviewItem item) {
    final title = p.basenameWithoutExtension(item.scenePath);
    if (title.isEmpty) {
      return '${item.atomType}_${item.varName}';
    }
    return title;
  }

  @override
  Widget build(BuildContext context) {
    final previewItems = items.map((item) {
      final previewPath = _previewPath(item);
      final imageUrl = previewPath == null
          ? null
          : client.previewUrl(root: 'varspath', path: previewPath);
      return ImagePreviewItem(
        title: _sceneTitle(item),
        subtitle: item.atomType,
        footer: item.varName,
        imageUrl: imageUrl,
      );
    }).toList();

    return ImagePreviewDialog(
      items: previewItems,
      initialIndex: initialIndex,
      onIndexChanged: onIndexChanged,
      showFooter: false,
      wrapNavigation: true,
    );
  }
}
