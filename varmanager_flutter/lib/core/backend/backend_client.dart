import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/config.dart';
import '../models/download_models.dart';
import '../models/extra_models.dart';
import '../models/job_models.dart';
import '../models/scene_models.dart';
import '../models/var_models.dart';
import 'query_params.dart';

class BackendClient {
  BackendClient({required this.baseUrl, http.Client? httpClient})
      : _client = httpClient ?? http.Client();

  String baseUrl;
  final http.Client _client;

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse(baseUrl).replace(path: path, queryParameters: query);
  }

  Future<Map<String, dynamic>> _getJson(String path,
      [Map<String, String>? query]) async {
    final resp = await _client.get(_uri(path, query));
    if (resp.statusCode >= 400) {
      throw Exception('GET $path failed: ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _postJson(String path,
      [Map<String, dynamic>? body]) async {
    final resp = await _client.post(
      _uri(path),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body ?? {}),
    );
    if (resp.statusCode >= 400) {
      throw Exception('POST $path failed: ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _putJson(String path,
      Map<String, dynamic> body) async {
    final resp = await _client.put(
      _uri(path),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (resp.statusCode >= 400) {
      throw Exception('PUT $path failed: ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<AppConfig> getConfig() async {
    final json = await _getJson('/config');
    return AppConfig.fromJson(json);
  }

  Future<AppConfig> updateConfig(Map<String, dynamic> update) async {
    final json = await _putJson('/config', update);
    return AppConfig.fromJson(json);
  }

  Future<VarsListResponse> listVars(VarsQueryParams params) async {
    final json = await _getJson('/vars', params.toQuery());
    return VarsListResponse.fromJson(json);
  }

  Future<VarDetailResponse> getVarDetail(String name) async {
    final json = await _getJson('/vars/$name');
    return VarDetailResponse.fromJson(json);
  }

  Future<ScenesListResponse> listScenes(ScenesQueryParams params) async {
    final json = await _getJson('/scenes', params.toQuery());
    return ScenesListResponse.fromJson(json);
  }

  Future<List<String>> listCreators({
    String? query,
    int? offset,
    int? limit,
  }) async {
    final params = <String, String>{};
    if (query != null) {
      params['q'] = query;
    }
    if (offset != null) {
      params['offset'] = offset.toString();
    }
    if (limit != null) {
      params['limit'] = limit.toString();
    }
    final json =
        await _getJson('/creators', params.isEmpty ? null : params);
    final creators = json['creators'] as List<dynamic>? ?? [];
    return creators.map((item) => item.toString()).toList();
  }

  Future<List<String>> listHubOptions({
    required String kind,
    String? query,
    int? offset,
    int? limit,
  }) async {
    final params = <String, String>{
      'kind': kind,
    };
    if (query != null) {
      params['q'] = query;
    }
    if (offset != null) {
      params['offset'] = offset.toString();
    }
    if (limit != null) {
      params['limit'] = limit.toString();
    }
    final json = await _getJson('/hub/options', params);
    final items = json['items'] as List<dynamic>? ?? [];
    return items.map((item) => item.toString()).toList();
  }

  Future<PackSwitchListResponse> listPackSwitches() async {
    final json = await _getJson('/packswitch');
    return PackSwitchListResponse.fromJson(json);
  }

  Future<AnalysisAtomsResponse> listAnalysisAtoms(
      String varName, String entryName) async {
    final json = await _getJson('/analysis/atoms', {
      'var_name': varName,
      'entry_name': entryName,
    });
    return AnalysisAtomsResponse.fromJson(json);
  }

  Future<AnalysisSummaryResponse> getAnalysisSummary(
      String varName, String entryName) async {
    final json = await _getJson('/analysis/summary', {
      'var_name': varName,
      'entry_name': entryName,
    });
    return AnalysisSummaryResponse.fromJson(json);
  }

  Future<SavesTreeResponse> getSavesTree() async {
    final json = await _getJson('/saves/tree');
    return SavesTreeResponse.fromJson(json);
  }

  Future<ValidateOutputResponse> validateOutputDir(String path) async {
    final json = await _postJson('/saves/validate_output', {'path': path});
    return ValidateOutputResponse.fromJson(json);
  }

  Future<MissingMapResponse> saveMissingMap(
      String path, List<MissingMapItem> links) async {
    final json = await _postJson('/missing/map/save', {
      'path': path,
      'links': links.map((item) => item.toJson()).toList(),
    });
    return MissingMapResponse.fromJson(json);
  }

  Future<MissingMapResponse> loadMissingMap(String path) async {
    final json = await _postJson('/missing/map/load', {'path': path});
    return MissingMapResponse.fromJson(json);
  }

  Future<MissingMapResponse> listMissingLinks() async {
    final json = await _getJson('/missing/map/current');
    return MissingMapResponse.fromJson(json);
  }

  Future<ResolveVarsResponse> resolveVars(List<String> names) async {
    final json = await _postJson('/vars/resolve', {'names': names});
    return ResolveVarsResponse.fromJson(json);
  }

  Future<DependentsResponse> getDependents(String name) async {
    final json = await _getJson('/dependents', {'name': name});
    return DependentsResponse.fromJson(json);
  }

  Future<VarDependenciesResponse> listVarDependencies(
      List<String> varNames) async {
    final json = await _postJson('/vars/dependencies', {'var_names': varNames});
    return VarDependenciesResponse.fromJson(json);
  }

  Future<VarPreviewsResponse> listVarPreviews(List<String> varNames) async {
    final json = await _postJson('/vars/previews', {'var_names': varNames});
    return VarPreviewsResponse.fromJson(json);
  }

  Future<StartJobResponse> startJob(String kind,
      [Map<String, dynamic>? args]) async {
    final json = await _postJson('/jobs', {
      'kind': kind,
      if (args != null) 'args': args,
    });
    return StartJobResponse.fromJson(json);
  }

  Future<JobView> getJob(int id) async {
    final json = await _getJson('/jobs/$id');
    return JobView.fromJson(json);
  }

  Future<JobLogsResponse> getJobLogs(int id, {int? from}) async {
    final query = <String, String>{};
    if (from != null) {
      query['from'] = from.toString();
    }
    final json = await _getJson('/jobs/$id/logs', query);
    return JobLogsResponse.fromJson(json);
  }

  Future<dynamic> getJobResult(int id) async {
    final json = await _getJson('/jobs/$id/result');
    return json['result'];
  }

  Future<DownloadListResponse> getDownloads() async {
    final json = await _getJson('/downloads');
    return DownloadListResponse.fromJson(json);
  }

  Future<void> downloadAction(String action, List<int> ids) async {
    await _postJson('/downloads/actions', {
      'action': action,
      'ids': ids,
    });
  }

  Future<void> shutdown() async {
    await _postJson('/shutdown');
  }

  Future<Map<String, dynamic>> getHealth() async {
    return _getJson('/health');
  }

  String previewUrl({
    String? root,
    String? path,
    String? source,
    String? url,
  }) {
    final query = <String, String>{};
    if (source != null) {
      query['source'] = source;
    }
    if (url != null) {
      query['url'] = url;
    }
    if (root != null) {
      query['root'] = root;
    }
    if (path != null) {
      query['path'] = path;
    }
    return _uri('/preview', query).toString();
  }

  String hubImageUrl(String imageUrl) {
    return previewUrl(source: 'hub', url: imageUrl);
  }

  Future<Map<String, dynamic>> getCacheStats() async {
    return _getJson('/cache/stats');
  }

  Future<void> clearCache() async {
    await _postJson('/cache/clear');
  }
}
