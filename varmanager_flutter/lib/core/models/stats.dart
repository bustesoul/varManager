class StatsResponse {
  StatsResponse({
    required this.varsTotal,
    required this.varsInstalled,
    required this.varsDisabled,
    required this.scenesTotal,
    required this.missingDeps,
  });

  final int varsTotal;
  final int varsInstalled;
  final int varsDisabled;
  final int scenesTotal;
  final int missingDeps;

  factory StatsResponse.fromJson(Map<String, dynamic> json) {
    return StatsResponse(
      varsTotal: (json['vars_total'] as num?)?.toInt() ?? 0,
      varsInstalled: (json['vars_installed'] as num?)?.toInt() ?? 0,
      varsDisabled: (json['vars_disabled'] as num?)?.toInt() ?? 0,
      scenesTotal: (json['scenes_total'] as num?)?.toInt() ?? 0,
      missingDeps: (json['missing_deps'] as num?)?.toInt() ?? 0,
    );
  }
}
