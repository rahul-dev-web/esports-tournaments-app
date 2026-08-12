import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../../core/config.dart';
 
class TeamRemoteDataSource {
  final String baseUrl = apiBaseUrl;
  
  /// Get all teams
  Future<List<Map<String, dynamic>>> getTeams({
    String? game,
    int skip = 0,
    int limit = 10,
  }) async {
    String url = '$baseUrl/teams?skip=$skip&limit=$limit';
    if (game != null) {
      url += '&game=$game';
    }
 
    final response = await http.get(Uri.parse(url));
 
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load teams');
    }
  }
 
  /// Get single team details
  Future<Map<String, dynamic>> getTeamDetails(String teamId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/teams/$teamId'),
    );
 
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Team not found');
    }
  }
 
  /// Get team members
  Future<List<Map<String, dynamic>>> getTeamMembers(String teamId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/teams/$teamId/members'),
    );
 
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load team members');
    }
  }
 
  /// Get current user's teams
  Future<List<Map<String, dynamic>>> getMyTeams(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/teams/user/my-teams'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
 
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load your teams');
    }
  }
 
  /// Create team
  Future<Map<String, dynamic>> createTeam(
    String token, {
    required String name,
    required String game,
    required bool isPrivate,
    String? logoUrl,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/teams'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': name,
        'game': game,
        'is_private': isPrivate,
        'logo_url': logoUrl,
      }),
    );
 
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create team');
    }
  }
 
  /// Update team
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
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': name,
        'game': game,
        'is_private': isPrivate,
        'logo_url': logoUrl,
      }),
    );
 
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to update team');
    }
  }
 
  /// Delete team
  Future<void> deleteTeam(String token, String teamId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/teams/$teamId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
 
    if (response.statusCode != 200) {
      throw Exception('Failed to delete team');
    }
  }
 
  /// Send team invitation
  Future<Map<String, dynamic>> sendInvitation(
    String token,
    String teamId, {
    required String receiverId,
    String? message,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/teams/$teamId/invitations'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'receiver_id': receiverId,
        'message': message,
      }),
    );
 
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to send invitation');
    }
  }
 
  /// Get received invitations
  Future<List<Map<String, dynamic>>> getReceivedInvitations(
    String token, {
    String? status,
  }) async {
    String url = '$baseUrl/invitations/received';
    if (status != null) {
      url += '?status=$status';
    }
 
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
 
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load invitations');
    }
  }
 
  /// Accept invitation
  Future<void> acceptInvitation(
    String token,
    String teamId,
    String invitationId,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/teams/invitations/$invitationId/accept'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
 
    if (response.statusCode != 200) {
      throw Exception('Failed to accept invitation');
    }
  }
 
  /// Reject invitation
  Future<void> rejectInvitation(
    String token,
    String teamId,
    String invitationId,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/teams/invitations/$invitationId/reject'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
 
    if (response.statusCode != 200) {
      throw Exception('Failed to reject invitation');
    }
  }
 
  /// Search users
  Future<List<Map<String, dynamic>>> searchUsers(
    String token,
    String query,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/search?q=$query'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
 
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['results'] ?? []);
    } else {
      throw Exception('Failed to search users');
    }
  }
}
