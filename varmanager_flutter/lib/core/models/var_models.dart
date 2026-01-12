class VarListItem {
  VarListItem({
    required this.varName,
    this.creatorName,
    this.packageName,
    this.metaDate,
    this.varDate,
    this.version,
    this.description,
    this.morph,
    this.cloth,
    this.hair,
    this.skin,
    this.pose,
    this.scene,
    this.script,
    this.plugin,
    this.asset,
    this.texture,
    this.look,
    this.subScene,
    this.appearance,
    this.dependencyCnt,
    this.fsize,
    required this.installed,
    required this.disabled,
  });

  final String varName;
  final String? creatorName;
  final String? packageName;
  final String? metaDate;
  final String? varDate;
  final String? version;
  final String? description;
  final int? morph;
  final int? cloth;
  final int? hair;
  final int? skin;
  final int? pose;
  final int? scene;
  final int? script;
  final int? plugin;
  final int? asset;
  final int? texture;
  final int? look;
  final int? subScene;
  final int? appearance;
  final int? dependencyCnt;
  final double? fsize;
  final bool installed;
  final bool disabled;

  factory VarListItem.fromJson(Map<String, dynamic> json) {
    return VarListItem(
      varName: json['var_name'] as String,
      creatorName: json['creator_name'] as String?,
      packageName: json['package_name'] as String?,
      metaDate: json['meta_date'] as String?,
      varDate: json['var_date'] as String?,
      version: json['version'] as String?,
      description: json['description'] as String?,
      morph: (json['morph'] as num?)?.toInt(),
      cloth: (json['cloth'] as num?)?.toInt(),
      hair: (json['hair'] as num?)?.toInt(),
      skin: (json['skin'] as num?)?.toInt(),
      pose: (json['pose'] as num?)?.toInt(),
      scene: (json['scene'] as num?)?.toInt(),
      script: (json['script'] as num?)?.toInt(),
      plugin: (json['plugin'] as num?)?.toInt(),
      asset: (json['asset'] as num?)?.toInt(),
      texture: (json['texture'] as num?)?.toInt(),
      look: (json['look'] as num?)?.toInt(),
      subScene: (json['sub_scene'] as num?)?.toInt(),
      appearance: (json['appearance'] as num?)?.toInt(),
      dependencyCnt: (json['dependency_cnt'] as num?)?.toInt(),
      fsize: (json['fsize'] as num?)?.toDouble(),
      installed: json['installed'] as bool? ?? false,
      disabled: json['disabled'] as bool? ?? false,
    );
  }
}

class VarsListResponse {
  VarsListResponse({
    required this.items,
    required this.page,
    required this.perPage,
    required this.total,
  });

  final List<VarListItem> items;
  final int page;
  final int perPage;
  final int total;

  factory VarsListResponse.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List<dynamic>? ?? [])
        .map((item) => VarListItem.fromJson(item as Map<String, dynamic>))
        .toList();
    return VarsListResponse(
      items: items,
      page: (json['page'] as num?)?.toInt() ?? 1,
      perPage: (json['per_page'] as num?)?.toInt() ?? 50,
      total: (json['total'] as num?)?.toInt() ?? items.length,
    );
  }
}

class DependencyStatus {
  DependencyStatus({
    required this.name,
    required this.resolved,
    required this.missing,
    required this.closest,
  });

  final String name;
  final String resolved;
  final bool missing;
  final bool closest;

  factory DependencyStatus.fromJson(Map<String, dynamic> json) {
    return DependencyStatus(
      name: json['name'] as String,
      resolved: json['resolved'] as String,
      missing: json['missing'] as bool? ?? false,
      closest: json['closest'] as bool? ?? false,
    );
  }
}

class ScenePreviewItem {
  ScenePreviewItem({
    required this.atomType,
    required this.previewPic,
    required this.scenePath,
    required this.isPreset,
    required this.isLoadable,
  });

  final String atomType;
  final String? previewPic;
  final String scenePath;
  final bool isPreset;
  final bool isLoadable;

  factory ScenePreviewItem.fromJson(Map<String, dynamic> json) {
    return ScenePreviewItem(
      atomType: json['atom_type'] as String,
      previewPic: json['preview_pic'] as String?,
      scenePath: json['scene_path'] as String,
      isPreset: json['is_preset'] as bool? ?? false,
      isLoadable: json['is_loadable'] as bool? ?? false,
    );
  }
}

class VarDetailResponse {
  VarDetailResponse({
    required this.varInfo,
    required this.dependencies,
    required this.dependents,
    required this.dependentSaves,
    required this.scenes,
  });

  final VarListItem varInfo;
  final List<DependencyStatus> dependencies;
  final List<String> dependents;
  final List<String> dependentSaves;
  final List<ScenePreviewItem> scenes;

  factory VarDetailResponse.fromJson(Map<String, dynamic> json) {
    return VarDetailResponse(
      varInfo: VarListItem.fromJson(json['var_info'] as Map<String, dynamic>),
      dependencies: (json['dependencies'] as List<dynamic>? ?? [])
          .map(
            (item) => DependencyStatus.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      dependents: (json['dependents'] as List<dynamic>? ?? [])
          .map((item) => item as String)
          .toList(),
      dependentSaves: (json['dependent_saves'] as List<dynamic>? ?? [])
          .map((item) => item as String)
          .toList(),
      scenes: (json['scenes'] as List<dynamic>? ?? [])
          .map(
            (item) => ScenePreviewItem.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}
