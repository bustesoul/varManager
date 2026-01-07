class PreviewItem {
  PreviewItem({
    required this.varName,
    required this.atomType,
    required this.previewPic,
    required this.scenePath,
    required this.isPreset,
    required this.isLoadable,
    required this.installed,
  });

  final String varName;
  final String atomType;
  final String? previewPic;
  final String scenePath;
  final bool isPreset;
  final bool isLoadable;
  final bool installed;
}
