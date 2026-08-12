import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/auth_providers.dart';
import '../../data/datasources/team_remote_datasource.dart';
 
// Data source provider
final teamDataSourceProvider = Provider((ref) {
  return TeamRemoteDataSource();
});
 
// ============================================================
// TEAMS LIST
// ============================================================
 
final teamsProvider = FutureProvider.family<List<Map<String, dynamic>>, String?>((ref, game) async {
  final dataSource = ref.watch(teamDataSourceProvider);
  return dataSource.getTeams(game: game);
});
 
// ============================================================
// TEAM DETAILS
// ============================================================
 
final teamDetailsProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, teamId) async {
  final dataSource = ref.watch(teamDataSourceProvider);
  return dataSource.getTeamDetails(teamId);
});
 
// ============================================================
// TEAM MEMBERS
// ============================================================
 
final teamMembersProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, teamId) async {
  final dataSource = ref.watch(teamDataSourceProvider);
  return dataSource.getTeamMembers(teamId);
});
 
// ============================================================
// MY TEAMS
// ============================================================
 
final myTeamsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dataSource = ref.watch(teamDataSourceProvider);
  final token = ref.watch(currentAccessTokenProvider);
  
  if (token == null) throw Exception('Not authenticated');
  
  return dataSource.getMyTeams(token);
});
 
// ============================================================
// CREATE TEAM
// ============================================================
 
final createTeamProvider = FutureProvider.family<Map<String, dynamic>, Map<String, dynamic>>((ref, params) async {
  final dataSource = ref.watch(teamDataSourceProvider);
  final token = ref.watch(currentAccessTokenProvider);
  
  if (token == null) throw Exception('Not authenticated');
  
  final result = await dataSource.createTeam(
    token,
    name: params['name'],
    game: params['game'],
    isPrivate: params['is_private'] ?? false,
    logoUrl: params['logo_url'],
  );
  
  // Invalidate my teams cache
  ref.invalidate(myTeamsProvider);
  ref.invalidate(teamsProvider);
  
  return result;
});
 
// ============================================================
// UPDATE TEAM
// ============================================================
 
final updateTeamProvider = FutureProvider.family<Map<String, dynamic>, Map<String, dynamic>>((ref, params) async {
  final dataSource = ref.watch(teamDataSourceProvider);
  final token = ref.watch(currentAccessTokenProvider);
  
  if (token == null) throw Exception('Not authenticated');
  
  final result = await dataSource.updateTeam(
    token,
    params['team_id'],
    name: params['name'],
    game: params['game'],
    isPrivate: params['is_private'],
    logoUrl: params['logo_url'],
  );
  
  // Invalidate caches
  ref.invalidate(teamDetailsProvider);
  ref.invalidate(myTeamsProvider);
  ref.invalidate(teamsProvider);
  
  return result;
});
 
// ============================================================
// DELETE TEAM
// ============================================================
 
final deleteTeamProvider = FutureProvider.family<void, String>((ref, teamId) async {
  final dataSource = ref.watch(teamDataSourceProvider);
  final token = ref.watch(currentAccessTokenProvider);
  
  if (token == null) throw Exception('Not authenticated');
  
  await dataSource.deleteTeam(token, teamId);
  
  // Invalidate caches
  ref.invalidate(myTeamsProvider);
  ref.invalidate(teamsProvider);
  ref.invalidate(teamDetailsProvider);
});
 
// ============================================================
// INVITATIONS
// ============================================================
 
final receivedInvitationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dataSource = ref.watch(teamDataSourceProvider);
  final token = ref.watch(currentAccessTokenProvider);
  
  if (token == null) throw Exception('Not authenticated');
  
  return dataSource.getReceivedInvitations(token, status: 'pending');
});
 
final acceptInvitationProvider = FutureProvider.family<void, Map<String, String>>((ref, params) async {
  final dataSource = ref.watch(teamDataSourceProvider);
  final token = ref.watch(currentAccessTokenProvider);
  
  if (token == null) throw Exception('Not authenticated');
  
  await dataSource.acceptInvitation(token, params['team_id']!, params['invitation_id']!);
  
  // Invalidate caches
  ref.invalidate(receivedInvitationsProvider);
  ref.invalidate(myTeamsProvider);
});
 
final rejectInvitationProvider = FutureProvider.family<void, Map<String, String>>((ref, params) async {
  final dataSource = ref.watch(teamDataSourceProvider);
  final token = ref.watch(currentAccessTokenProvider);
  
  if (token == null) throw Exception('Not authenticated');
  
  await dataSource.rejectInvitation(token, params['team_id']!, params['invitation_id']!);
  
  // Invalidate caches
  ref.invalidate(receivedInvitationsProvider);
});
 
final sendInvitationProvider = FutureProvider.family<Map<String, dynamic>, Map<String, dynamic>>((ref, params) async {
  final dataSource = ref.watch(teamDataSourceProvider);
  final token = ref.watch(currentAccessTokenProvider);
  
  if (token == null) throw Exception('Not authenticated');
  
  return dataSource.sendInvitation(
    token,
    params['team_id'],
    receiverId: params['receiver_id'],
    message: params['message'],
  );
});
 
// ============================================================
// SEARCH USERS
// ============================================================
 
final searchUsersProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, query) async {
  final dataSource = ref.watch(teamDataSourceProvider);
  final token = ref.watch(currentAccessTokenProvider);
  
  if (token == null) throw Exception('Not authenticated');
  if (query.length < 2) return [];
  
  return dataSource.searchUsers(token, query);
});
