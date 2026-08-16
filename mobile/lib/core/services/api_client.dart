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
    return _request('GET', path);
  }

  Future<Map<String, dynamic>> _request(String method, String path) async {
    final session = Supabase.instance.client.auth.currentSession;
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    if (session?.accessToken.isNotEmpty == true) {
      headers['Authorization'] = 'Bearer ${session!.accessToken}';
    }

    final uri = Uri.parse('${apiBaseUrl.replaceFirst(RegExp(r'/$'), '')}/${path.replaceFirst(RegExp(r'^/'), '')}');

    late http.Response response;
    if (method == 'GET') {
      response = await _client.get(uri, headers: headers);
    } else {
      throw UnsupportedError('HTTP method $method is not implemented');
    }

    final decoded = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = decoded is Map ? decoded['detail']?.toString() : null;
      throw ApiException(response.statusCode, detail ?? 'Request failed');
    }

    if (decoded is Map<String, dynamic>) return decoded;
    throw const ApiException(500, 'Unexpected API response');
  }
}
