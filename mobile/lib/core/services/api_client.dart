import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';

class ApiException implements Exception {
  const ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<Map<String, dynamic>> get(String path) async {
    final decoded = await _request('GET', path);
    if (decoded is Map<String, dynamic>) return decoded;
    throw const ApiException(500, 'Unexpected object response');
  }

  Future<List<dynamic>> getList(String path) async {
    final decoded = await _request('GET', path);
    if (decoded is List<dynamic>) return decoded;
    throw const ApiException(500, 'Unexpected list response');
  }

  Future<dynamic> post(String path, {Map<String, dynamic>? body}) =>
      _request('POST', path, body: body);

  Future<dynamic> patch(String path, {Map<String, dynamic>? body}) =>
      _request('PATCH', path, body: body);

  Future<dynamic> delete(String path) => _request('DELETE', path);

  Future<dynamic> _request(String method, String path, {Map<String, dynamic>? body}) async {
    final session = Supabase.instance.client.auth.currentSession;
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    if (session?.accessToken.isNotEmpty == true) {
      headers['Authorization'] = 'Bearer ${session!.accessToken}';
    }

    final uri = Uri.parse(
      '${apiBaseUrl.replaceFirst(RegExp(r'/$'), '')}/${path.replaceFirst(RegExp(r'^/'), '')}',
    );

    late http.Response response;
    switch (method) {
      case 'GET':
        response = await _client.get(uri, headers: headers);
        break;
      case 'POST':
        response = await _client.post(uri, headers: headers, body: jsonEncode(body ?? {}));
        break;
      case 'PATCH':
        response = await _client.patch(uri, headers: headers, body: jsonEncode(body ?? {}));
        break;
      case 'DELETE':
        response = await _client.delete(uri, headers: headers);
        break;
      default:
        throw UnsupportedError('HTTP method $method is not implemented');
    }

    final decoded = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = decoded is Map ? decoded['detail']?.toString() : null;
      throw ApiException(response.statusCode, detail ?? 'Request failed');
    }

    return decoded;
  }
}
