class AtomTreeNode {
  AtomTreeNode({
    required this.name,
    required this.path,
    required this.children,
  });

  final String name;
  final String? path;
  final List<AtomTreeNode> children;

  factory AtomTreeNode.fromJson(Map<String, dynamic> json) {
    return AtomTreeNode(
      name: json['name'] as String? ?? '',
      path: json['path'] as String?,
      children: (json['children'] as List<dynamic>? ?? [])
          .map((item) => AtomTreeNode.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class AnalysisAtomsResponse {
  AnalysisAtomsResponse({
    required this.atoms,
    required this.personAtoms,
  });

  final List<AtomTreeNode> atoms;
  final List<String> personAtoms;

  factory AnalysisAtomsResponse.fromJson(Map<String, dynamic> json) {
    return AnalysisAtomsResponse(
      atoms: (json['atoms'] as List<dynamic>? ?? [])
          .map((item) => AtomTreeNode.fromJson(item as Map<String, dynamic>))
          .toList(),
      personAtoms: (json['person_atoms'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
    );
  }
}

class SavesTreeItem {
  SavesTreeItem({
    required this.path,
    required this.name,
    required this.preview,
    required this.modified,
  });

  final String path;
  final String name;
  final String? preview;
  final String? modified;

  factory SavesTreeItem.fromJson(Map<String, dynamic> json) {
    return SavesTreeItem(
      path: json['path'] as String? ?? '',
      name: json['name'] as String? ?? '',
      preview: json['preview'] as String?,
      modified: json['modified'] as String?,
    );
  }
}

class SavesTreeGroup {
  SavesTreeGroup({
    required this.id,
    required this.title,
    required this.items,
  });

  final String id;
  final String title;
  final List<SavesTreeItem> items;

  factory SavesTreeGroup.fromJson(Map<String, dynamic> json) {
    return SavesTreeGroup(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      items: (json['items'] as List<dynamic>? ?? [])
          .map((item) => SavesTreeItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class SavesTreeResponse {
  SavesTreeResponse({required this.groups});

  final List<SavesTreeGroup> groups;

  factory SavesTreeResponse.fromJson(Map<String, dynamic> json) {
    return SavesTreeResponse(
      groups: (json['groups'] as List<dynamic>? ?? [])
          .map((item) => SavesTreeGroup.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ValidateOutputResponse {
  ValidateOutputResponse({required this.ok, required this.reason});

  final bool ok;
  final String? reason;

  factory ValidateOutputResponse.fromJson(Map<String, dynamic> json) {
    return ValidateOutputResponse(
      ok: json['ok'] as bool? ?? false,
      reason: json['reason'] as String?,
    );
  }
}

class MissingMapItem {
  MissingMapItem({required this.missingVar, required this.destVar});

  final String missingVar;
  final String destVar;

  factory MissingMapItem.fromJson(Map<String, dynamic> json) {
    return MissingMapItem(
      missingVar: json['missing_var'] as String? ?? '',
      destVar: json['dest_var'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'missing_var': missingVar,
      'dest_var': destVar,
    };
  }
}

class MissingMapResponse {
  MissingMapResponse({required this.links});

  final List<MissingMapItem> links;

  factory MissingMapResponse.fromJson(Map<String, dynamic> json) {
    return MissingMapResponse(
      links: (json['links'] as List<dynamic>? ?? [])
          .map((item) => MissingMapItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ResolveVarsResponse {
  ResolveVarsResponse({required this.resolved});

  final Map<String, String> resolved;

  factory ResolveVarsResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['resolved'] as Map<String, dynamic>? ?? {};
    return ResolveVarsResponse(
      resolved:
          raw.map((key, value) => MapEntry(key, value?.toString() ?? 'missing')),
    );
  }
}

class DependentsResponse {
  DependentsResponse({required this.dependents, required this.dependentSaves});

  final List<String> dependents;
  final List<String> dependentSaves;

  factory DependentsResponse.fromJson(Map<String, dynamic> json) {
    return DependentsResponse(
      dependents: (json['dependents'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
      dependentSaves: (json['dependent_saves'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
    );
  }
}

class PackSwitchListResponse {
  PackSwitchListResponse({required this.current, required this.switches});

  final String current;
  final List<String> switches;

  factory PackSwitchListResponse.fromJson(Map<String, dynamic> json) {
    return PackSwitchListResponse(
      current: json['current'] as String? ?? 'default',
      switches: (json['switches'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
    );
  }
}

class VarDependencyItem {
  VarDependencyItem({required this.varName, required this.dependency});

  final String varName;
  final String dependency;

  factory VarDependencyItem.fromJson(Map<String, dynamic> json) {
    return VarDependencyItem(
      varName: json['var_name'] as String? ?? '',
      dependency: json['dependency'] as String? ?? '',
    );
  }
}

class VarDependenciesResponse {
  VarDependenciesResponse({required this.items});

  final List<VarDependencyItem> items;

  factory VarDependenciesResponse.fromJson(Map<String, dynamic> json) {
    return VarDependenciesResponse(
      items: (json['items'] as List<dynamic>? ?? [])
          .map((item) => VarDependencyItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class VarPreviewItem {
  VarPreviewItem({
    required this.varName,
    required this.atomType,
    required this.previewPic,
    required this.scenePath,
    required this.isPreset,
    required this.isLoadable,
  });

  final String varName;
  final String atomType;
  final String? previewPic;
  final String scenePath;
  final bool isPreset;
  final bool isLoadable;

  factory VarPreviewItem.fromJson(Map<String, dynamic> json) {
    return VarPreviewItem(
      varName: json['var_name'] as String? ?? '',
      atomType: json['atom_type'] as String? ?? '',
      previewPic: json['preview_pic'] as String?,
      scenePath: json['scene_path'] as String? ?? '',
      isPreset: json['is_preset'] as bool? ?? false,
      isLoadable: json['is_loadable'] as bool? ?? false,
    );
  }
}

class VarPreviewsResponse {
  VarPreviewsResponse({required this.items});

  final List<VarPreviewItem> items;

  factory VarPreviewsResponse.fromJson(Map<String, dynamic> json) {
    return VarPreviewsResponse(
      items: (json['items'] as List<dynamic>? ?? [])
          .map((item) => VarPreviewItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
