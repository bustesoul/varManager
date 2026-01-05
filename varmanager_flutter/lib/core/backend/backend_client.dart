import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/config.dart';
import '../models/job_models.dart';
import '../models/scene_models.dart';
import '../models/stats.dart';
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

  Future<List<String>> listCreators() async {
    final json = await _getJson('/creators');
    final creators = json['creators'] as List<dynamic>? ?? [];
    return creators.map((item) => item.toString()).toList();
  }

  Future<StatsResponse> getStats() async {
    final json = await _getJson('/stats');
    return StatsResponse.fromJson(json);
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

  Future<void> shutdown() async {
    await _postJson('/shutdown');
  }

  String previewUrl({required String root, required String path}) {
    final query = <String, String>{
      'root': root,
      'path': path,
    };
    return _uri('/preview', query).toString();
  }
}
