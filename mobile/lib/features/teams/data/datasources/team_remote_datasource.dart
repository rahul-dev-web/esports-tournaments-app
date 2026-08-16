import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/config.dart';

class TeamRemoteDataSource {
  final String baseUrl = apiBaseUrl;

  Future<List<Map<String, dynamic>>> getTeams({
    String? game,
    int skip = 0,
    int limit = 20,
  }) async {
    var url = '$baseUrl/teams?skip=$skip&limit=$limit';
    if (game != null && game.trim().isNotEmpty) {
      url += '&game=${Uri.encodeQueryComponent(game.trim())}';
    }

    final response = await http.get(Uri.parse(url));
    return _decodeList(response, fallback: 'Failed to load teams');
  }

  Future<Map<String, dynamic>> getTeamDetails(String teamId) async {
    final response = await http.get(Uri.parse('$baseUrl/teams/$teamId'));
    return _decodeMap(response, fallback: 'Team not found');
  }

  Future<List<Map<String, dynamic>>> getTeamMembers(String teamId) async {
    final response = await http.get(Uri.parse('$baseUrl/teams/$teamId/members'));
    return _decodeList(response, fallback: 'Failed to load team members');
  }

  Future<List<Map<String, dynamic>>> getMyTeams(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/teams/user/my-teams'),
      headers: _authHeaders(token),
    );
    return _decodeList(response, fallback: 'Failed to load your teams');
  }

  Future<Map<String, dynamic>> createTeam(
    String token, {
    required String name,
    required String game,
    required bool isPrivate,
    String? logoUrl,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/teams'),
      headers: _authHeaders(token),
      body: jsonEncode({
        'name': name.trim(),
        'game': game.trim(),
        'is_private': isPrivate,
        'logo_url': logoUrl,
      }),
    );
    return _decodeMap(response, fallback: 'Failed to create team');
  }

  Future<Map<String, dynamic>> updateTeam(
    String token,
    String teamId, {
    required String name,
    required String game,
    required bool isPrivate,
    String? logoUrl,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/teams/$teamId'),
      headers: _authHeaders(token),
      body: jsonEncode({
        'name': name.trim(),
        'game': game.trim(),
        'is_private': isPrivate,
        'logo_url': logoUrl,
      }),
    );
    return _decodeMap(response, fallback: 'Failed to update team');
  }

  Future<void> deleteTeam(String token, String teamId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/teams/$teamId'),
      headers: _authHeaders(token),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response, 'Failed to delete team'));
    }
  }

  /// Join an open team through the backend's authenticated join flow.
  Future<Map<String, dynamic>> joinTeam(String token, String teamId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/teams/$teamId/members/current-user'),
      headers: _authHeaders(token),
    );

    // The backend currently exposes the self-join operation using
    // /{team_id}/members/{new_user_id}. The caller must supply the current
    // user id, so this method is intentionally implemented by joinTeamWithUserId.
    return _decodeMap(response, fallback: 'Failed to join team');
  }

  Future<Map<String, dynamic>> joinTeamWithUserId(
    String token,
    String teamId,
    String userId,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/teams/$teamId/members/$userId'),
      headers: _authHeaders(token),
    );
    return _decodeMap(response, fallback: 'Failed to join team');
  }

  Future<Map<String, dynamic>> sendInvitation(
    String token,
    String teamId, {
    required String receiverId,
    String? message,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/teams/$teamId/invitations'),
      headers: _authHeaders(token),
      body: jsonEncode({
        'receiver_id': receiverId,
        'message': message,
      }),
    );
    return _decodeMap(response, fallback: 'Failed to send invitation');
  }

  Future<List<Map<String, dynamic>>> getReceivedInvitations(
    String token, {
    String? status,
  }) async {
    var url = '$baseUrl/teams/invitations/received';
    if (status != null) {
      url += '?status=${Uri.encodeQueryComponent(status)}';
    }
    final response = await http.get(
      Uri.parse(url),
      headers: _authHeaders(token),
    );
    return _decodeList(response, fallback: 'Failed to load invitations');
  }

  Future<List<Map<String, dynamic>>> getTeamInvitations(
    String token,
    String teamId,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/teams/$teamId/invitations'),
      headers: _authHeaders(token),
    );
    return _decodeList(response, fallback: 'Failed to load team invitations');
  }

  Future<void> acceptInvitation(String token, String invitationId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/teams/invitations/$invitationId/accept'),
      headers: _authHeaders(token),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response, 'Failed to accept invitation'));
    }
  }

  Future<void> rejectInvitation(String token, String invitationId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/teams/invitations/$invitationId/reject'),
      headers: _authHeaders(token),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response, 'Failed to reject invitation'));
    }
  }

  Future<void> removeMember(
    String token,
    String teamId,
    String memberUserId,
  ) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/teams/$teamId/members/$memberUserId'),
      headers: _authHeaders(token),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response, 'Failed to remove member'));
    }
  }

  Future<List<Map<String, dynamic>>> searchUsers(
    String token,
    String query,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/search?q=${Uri.encodeQueryComponent(query)}'),
      headers: _authHeaders(token),
    );
    final map = _decodeMap(response, fallback: 'Failed to search users');
    return List<Map<String, dynamic>>.from(map['results'] ?? const []);
  }

  Map<String, String> _authHeaders(String token) => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

  List<Map<String, dynamic>> _decodeList(
    http.Response response, {
    required String fallback,
  }) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response, fallback));
    }
    final data = jsonDecode(response.body);
    if (data is! List) throw Exception(fallback);
    return List<Map<String, dynamic>>.from(data);
  }

  Map<String, dynamic> _decodeMap(
    http.Response response, {
    required String fallback,
  }) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response, fallback));
    }
    final data = jsonDecode(response.body);
    if (data is! Map) throw Exception(fallback);
    return Map<String, dynamic>.from(data);
  }

  String _errorMessage(http.Response response, String fallback) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map && data['detail'] != null) {
        return data['detail'].toString();
      }
    } catch (_) {}
    return fallback;
  }
}
