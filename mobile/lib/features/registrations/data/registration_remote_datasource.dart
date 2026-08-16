import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config.dart';
import 'registration_models.dart';

class RegistrationRemoteDataSource {
  RegistrationRemoteDataSource({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Map<String, String> get _headers => {
        'Authorization': 'Bearer ${Supabase.instance.client.auth.currentSession?.accessToken ?? ''}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  Future<RegistrationModel> start({required String tournamentId, required String teamId}) async {
    final response = await _client.post(
      Uri.parse('$apiBaseUrl/tournaments/$tournamentId/teams/$teamId'),
      headers: _headers,
    );
    return _decodeRegistration(response, 'Unable to start registration');
  }

  Future<RegistrationModel> getById(String registrationId) async {
    final response = await _client.get(
      Uri.parse('$apiBaseUrl/registrations/$registrationId'),
      headers: _headers,
    );
    return _decodeRegistration(response, 'Unable to load registration');
  }

  Future<List<RegistrationModel>> getMine() async {
    final response = await _client.get(
      Uri.parse('$apiBaseUrl/registrations/user/me'),
      headers: _headers,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_error(response, 'Unable to load registrations'));
    }
    final data = jsonDecode(response.body);
    if (data is! List) throw Exception('Unexpected registration response');
    return data.map((item) => RegistrationModel.fromJson(Map<String, dynamic>.from(item as Map))).toList();
  }

  Future<RegistrationStatusModel> getStatus(String registrationId) async {
    final response = await _client.get(
      Uri.parse('$apiBaseUrl/registrations/status/$registrationId'),
      headers: _headers,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_error(response, 'Unable to load registration status'));
    }
    final data = jsonDecode(response.body);
    if (data is! Map) throw Exception('Unexpected registration status response');
    return RegistrationStatusModel.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> cancel(String registrationId) async {
    final response = await _client.post(
      Uri.parse('$apiBaseUrl/registrations/$registrationId/cancel'),
      headers: _headers,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_error(response, 'Unable to cancel registration'));
    }
  }

  RegistrationModel _decodeRegistration(http.Response response, String fallback) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_error(response, fallback));
    }
    final data = jsonDecode(response.body);
    if (data is! Map) throw Exception('Unexpected registration response');
    return RegistrationModel.fromJson(Map<String, dynamic>.from(data));
  }

  String _error(http.Response response, String fallback) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map && data['detail'] != null) return data['detail'].toString();
    } catch (_) {}
    return fallback;
  }
}
