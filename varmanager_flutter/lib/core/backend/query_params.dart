class VarsQueryParams {
  VarsQueryParams({
    this.page = 1,
    this.perPage = 50,
    this.search = '',
    this.creator = '',
    this.package = '',
    this.version = '',
    this.installed = 'all',
    this.disabled = 'all',
    this.minSize,
    this.maxSize,
    this.minDependency,
    this.maxDependency,
    this.hasScene = 'all',
    this.hasLook = 'all',
    this.hasCloth = 'all',
    this.hasHair = 'all',
    this.hasSkin = 'all',
    this.hasPose = 'all',
    this.hasMorph = 'all',
    this.hasPlugin = 'all',
    this.hasScript = 'all',
    this.hasAsset = 'all',
    this.hasTexture = 'all',
    this.hasSubScene = 'all',
    this.hasAppearance = 'all',
    this.sort = 'meta_date',
    this.order = 'desc',
  });

  final int page;
  final int perPage;
  final String search;
  final String creator;
  final String package;
  final String version;
  final String installed;
  final String disabled;
  final double? minSize;
  final double? maxSize;
  final int? minDependency;
  final int? maxDependency;
  final String hasScene;
  final String hasLook;
  final String hasCloth;
  final String hasHair;
  final String hasSkin;
  final String hasPose;
  final String hasMorph;
  final String hasPlugin;
  final String hasScript;
  final String hasAsset;
  final String hasTexture;
  final String hasSubScene;
  final String hasAppearance;
  final String sort;
  final String order;

  Map<String, String> toQuery() {
    final query = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
      'sort': sort,
      'order': order,
    };
    if (search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }
    if (creator.trim().isNotEmpty && creator.trim() != 'ALL') {
      query['creator'] = creator.trim();
    }
    if (package.trim().isNotEmpty) {
      query['package'] = package.trim();
    }
    if (version.trim().isNotEmpty) {
      query['version'] = version.trim();
    }
    if (installed != 'all') {
      query['installed'] = installed;
    }
    if (disabled != 'all') {
      query['disabled'] = disabled;
    }
    if (minSize != null) {
      query['min_size'] = minSize!.toString();
    }
    if (maxSize != null) {
      query['max_size'] = maxSize!.toString();
    }
    if (minDependency != null) {
      query['min_dependency'] = minDependency!.toString();
    }
    if (maxDependency != null) {
      query['max_dependency'] = maxDependency!.toString();
    }
    if (hasScene != 'all') {
      query['has_scene'] = hasScene;
    }
    if (hasLook != 'all') {
      query['has_look'] = hasLook;
    }
    if (hasCloth != 'all') {
      query['has_cloth'] = hasCloth;
    }
    if (hasHair != 'all') {
      query['has_hair'] = hasHair;
    }
    if (hasSkin != 'all') {
      query['has_skin'] = hasSkin;
    }
    if (hasPose != 'all') {
      query['has_pose'] = hasPose;
    }
    if (hasMorph != 'all') {
      query['has_morph'] = hasMorph;
    }
    if (hasPlugin != 'all') {
      query['has_plugin'] = hasPlugin;
    }
    if (hasScript != 'all') {
      query['has_script'] = hasScript;
    }
    if (hasAsset != 'all') {
      query['has_asset'] = hasAsset;
    }
    if (hasTexture != 'all') {
      query['has_texture'] = hasTexture;
    }
    if (hasSubScene != 'all') {
      query['has_sub_scene'] = hasSubScene;
    }
    if (hasAppearance != 'all') {
      query['has_appearance'] = hasAppearance;
    }
    return query;
  }

  VarsQueryParams copyWith({
    int? page,
    int? perPage,
    String? search,
    String? creator,
    String? package,
    String? version,
    String? installed,
    String? disabled,
    double? minSize,
    double? maxSize,
    int? minDependency,
    int? maxDependency,
    String? hasScene,
    String? hasLook,
    String? hasCloth,
    String? hasHair,
    String? hasSkin,
    String? hasPose,
    String? hasMorph,
    String? hasPlugin,
    String? hasScript,
    String? hasAsset,
    String? hasTexture,
    String? hasSubScene,
    String? hasAppearance,
    String? sort,
    String? order,
  }) {
    return VarsQueryParams(
      page: page ?? this.page,
      perPage: perPage ?? this.perPage,
      search: search ?? this.search,
      creator: creator ?? this.creator,
      package: package ?? this.package,
      version: version ?? this.version,
      installed: installed ?? this.installed,
      disabled: disabled ?? this.disabled,
      minSize: minSize ?? this.minSize,
      maxSize: maxSize ?? this.maxSize,
      minDependency: minDependency ?? this.minDependency,
      maxDependency: maxDependency ?? this.maxDependency,
      hasScene: hasScene ?? this.hasScene,
      hasLook: hasLook ?? this.hasLook,
      hasCloth: hasCloth ?? this.hasCloth,
      hasHair: hasHair ?? this.hasHair,
      hasSkin: hasSkin ?? this.hasSkin,
      hasPose: hasPose ?? this.hasPose,
      hasMorph: hasMorph ?? this.hasMorph,
      hasPlugin: hasPlugin ?? this.hasPlugin,
      hasScript: hasScript ?? this.hasScript,
      hasAsset: hasAsset ?? this.hasAsset,
      hasTexture: hasTexture ?? this.hasTexture,
      hasSubScene: hasSubScene ?? this.hasSubScene,
      hasAppearance: hasAppearance ?? this.hasAppearance,
      sort: sort ?? this.sort,
      order: order ?? this.order,
    );
  }
}

class ScenesQueryParams {
  ScenesQueryParams({
    this.page = 1,
    this.perPage = 50,
    this.search = '',
    this.creator = '',
    this.category = 'scenes',
    this.installed = 'all',
    this.hideFav = 'all',
    this.location = '',
    this.sort = 'var_date',
    this.order = 'desc',
  });

  final int page;
  final int perPage;
  final String search;
  final String creator;
  final String category;
  final String installed;
  final String hideFav;
  final String location;
  final String sort;
  final String order;

  Map<String, String> toQuery() {
    final query = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
      'sort': sort,
      'order': order,
    };
    if (search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }
    if (creator.trim().isNotEmpty && creator.trim() != 'ALL') {
      query['creator'] = creator.trim();
    }
    if (category.trim().isNotEmpty) {
      query['category'] = category.trim();
    }
    if (installed != 'all') {
      query['installed'] = installed;
    }
    if (hideFav != 'all') {
      query['hide_fav'] = hideFav;
    }
    if (location.trim().isNotEmpty) {
      query['location'] = location.trim();
    }
    return query;
  }

  ScenesQueryParams copyWith({
    int? page,
    int? perPage,
    String? search,
    String? creator,
    String? category,
    String? installed,
    String? hideFav,
    String? location,
    String? sort,
    String? order,
  }) {
    return ScenesQueryParams(
      page: page ?? this.page,
      perPage: perPage ?? this.perPage,
      search: search ?? this.search,
      creator: creator ?? this.creator,
      category: category ?? this.category,
      installed: installed ?? this.installed,
      hideFav: hideFav ?? this.hideFav,
      location: location ?? this.location,
      sort: sort ?? this.sort,
      order: order ?? this.order,
    );
  }
}
