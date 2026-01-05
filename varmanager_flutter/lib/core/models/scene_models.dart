class SceneListItem {
  SceneListItem({
    required this.varName,
    required this.atomType,
    required this.previewPic,
    required this.scenePath,
    required this.isPreset,
    required this.isLoadable,
    required this.creatorName,
    required this.packageName,
    required this.metaDate,
    required this.varDate,
    required this.version,
    required this.installed,
    required this.disabled,
    required this.hide,
    required this.fav,
    required this.hideFav,
    required this.location,
  });

  final String varName;
  final String atomType;
  final String? previewPic;
  final String scenePath;
  final bool isPreset;
  final bool isLoadable;
  final String? creatorName;
  final String? packageName;
  final String? metaDate;
  final String? varDate;
  final String? version;
  final bool installed;
  final bool disabled;
  final bool hide;
  final bool fav;
  final int hideFav;
  final String location;

  factory SceneListItem.fromJson(Map<String, dynamic> json) {
    return SceneListItem(
      varName: json['var_name'] as String,
      atomType: json['atom_type'] as String,
      previewPic: json['preview_pic'] as String?,
      scenePath: json['scene_path'] as String,
      isPreset: json['is_preset'] as bool? ?? false,
      isLoadable: json['is_loadable'] as bool? ?? false,
      creatorName: json['creator_name'] as String?,
      packageName: json['package_name'] as String?,
      metaDate: json['meta_date'] as String?,
      varDate: json['var_date'] as String?,
      version: json['version'] as String?,
      installed: json['installed'] as bool? ?? false,
      disabled: json['disabled'] as bool? ?? false,
      hide: json['hide'] as bool? ?? false,
      fav: json['fav'] as bool? ?? false,
      hideFav: (json['hide_fav'] as num?)?.toInt() ?? 0,
      location: json['location'] as String? ?? '',
    );
  }
}

class ScenesListResponse {
  ScenesListResponse({
    required this.items,
    required this.page,
    required this.perPage,
    required this.total,
  });

  final List<SceneListItem> items;
  final int page;
  final int perPage;
  final int total;

  factory ScenesListResponse.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List<dynamic>? ?? [])
        .map((item) => SceneListItem.fromJson(item as Map<String, dynamic>))
        .toList();
    return ScenesListResponse(
      items: items,
      page: (json['page'] as num?)?.toInt() ?? 1,
      perPage: (json['per_page'] as num?)?.toInt() ?? 50,
      total: (json['total'] as num?)?.toInt() ?? items.length,
    );
  }
}
