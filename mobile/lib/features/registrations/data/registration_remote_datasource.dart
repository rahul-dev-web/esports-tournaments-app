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
    // Backend registration router is mounted at /api/registrations.
    // The start-registration endpoint is:
    // POST /api/registrations/tournaments/{tournamentId}/teams/{teamId}
    final response = await _client.post(
      Uri.parse('$apiBaseUrl/registrations/tournaments/$tournamentId/teams/$teamId'),
      headers: _headers,
    );
    return _decodeRegistration(response, 'Unable to start registration');
  }

  Future<AdSessionModel> createAdSession(String registrationId) async {
    final response = await _client.post(
      Uri.parse('$apiBaseUrl/registrations/$registrationId/ads/session'),
      headers: _headers,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_error(response, 'Unable to create rewarded-ad session'));
    }
    final data = jsonDecode(response.body);
    if (data is! Map) throw Exception('Unexpected ad-session response');
    return AdSessionModel.fromJson(Map<String, dynamic>.from(data));
  }

  Future<RegistrationModel> startAdVerification(String registrationId) async {
    final response = await _client.post(
      Uri.parse('$apiBaseUrl/registrations/$registrationId/ads/start'),
      headers: _headers,
    );
    return _decodeRegistration(response, 'Unable to start ad verification');
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

class AdSessionModel {
  const AdSessionModel({required this.registrationId, required this.sessionId, required this.sessionToken, required this.expiresAt});

  final String registrationId;
  final String sessionId;
  final String sessionToken;
  final DateTime expiresAt;

  factory AdSessionModel.fromJson(Map<String, dynamic> json) => AdSessionModel(
        registrationId: json['registration_id'].toString(),
        sessionId: json['session_id'].toString(),
        sessionToken: json['session_token'].toString(),
        expiresAt: DateTime.parse(json['expires_at'].toString()),
      );
}
