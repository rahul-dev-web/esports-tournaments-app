import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/auth_providers.dart';
import '../../data/datasources/team_remote_datasource.dart';

final teamDataSourceProvider = Provider<TeamRemoteDataSource>((ref) {
  return TeamRemoteDataSource();
});

final teamsProvider = FutureProvider.family<List<Map<String, dynamic>>, String?>((ref, game) async {
  final dataSource = ref.watch(teamDataSourceProvider);
  return dataSource.getTeams(game: game);
});

final teamDetailsProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, teamId) async {
  final dataSource = ref.watch(teamDataSourceProvider);
  return dataSource.getTeamDetails(teamId);
});

final teamMembersProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, teamId) async {
  final dataSource = ref.watch(teamDataSourceProvider);
  return dataSource.getTeamMembers(teamId);
});

final myTeamsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dataSource = ref.watch(teamDataSourceProvider);
  final token = ref.watch(currentAccessTokenProvider);
  if (token == null) throw Exception('Not authenticated');
  return dataSource.getMyTeams(token);
});

final createTeamProvider = FutureProvider.family<Map<String, dynamic>, Map<String, dynamic>>((ref, params) async {
  final dataSource = ref.watch(teamDataSourceProvider);
  final token = ref.watch(currentAccessTokenProvider);
  if (token == null) throw Exception('Not authenticated');

  final result = await dataSource.createTeam(
    token,
    name: params['name'] as String,
    game: params['game'] as String,
    isPrivate: params['is_private'] as bool? ?? false,
    logoUrl: params['logo_url'] as String?,
  );

  ref.invalidate(myTeamsProvider);
  ref.invalidate(teamsProvider);
  return result;
});

final updateTeamProvider = FutureProvider.family<Map<String, dynamic>, Map<String, dynamic>>((ref, params) async {
  final dataSource = ref.watch(teamDataSourceProvider);
  final token = ref.watch(currentAccessTokenProvider);
  if (token == null) throw Exception('Not authenticated');

  final result = await dataSource.updateTeam(
    token,
    params['team_id'] as String,
    name: params['name'] as String,
    game: params['game'] as String,
    isPrivate: params['is_private'] as bool? ?? false,
    logoUrl: params['logo_url'] as String?,
  );

  ref.invalidate(teamDetailsProvider);
  ref.invalidate(myTeamsProvider);
  ref.invalidate(teamsProvider);
  return result;
});

final deleteTeamProvider = FutureProvider.family<void, String>((ref, teamId) async {
  final dataSource = ref.watch(teamDataSourceProvider);
  final token = ref.watch(currentAccessTokenProvider);
  if (token == null) throw Exception('Not authenticated');

  await dataSource.deleteTeam(token, teamId);
  ref.invalidate(myTeamsProvider);
  ref.invalidate(teamsProvider);
  ref.invalidate(teamDetailsProvider);
});

final joinTeamProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, teamId) async {
  final dataSource = ref.watch(teamDataSourceProvider);
  final token = ref.watch(currentAccessTokenProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (token == null || userId == null) throw Exception('Not authenticated');

  final result = await dataSource.joinTeam(token, teamId, userId);
  ref.invalidate(myTeamsProvider);
  ref.invalidate(teamMembersProvider(teamId));
  ref.invalidate(teamDetailsProvider(teamId));
  ref.invalidate(teamsProvider);
  return result;
});

final receivedInvitationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dataSource = ref.watch(teamDataSourceProvider);
  final token = ref.watch(currentAccessTokenProvider);
  if (token == null) throw Exception('Not authenticated');
  return dataSource.getReceivedInvitations(token);
});

final teamInvitationsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, teamId) async {
  final dataSource = ref.watch(teamDataSourceProvider);
  final token = ref.watch(currentAccessTokenProvider);
  if (token == null) throw Exception('Not authenticated');
  return dataSource.getTeamInvitations(token, teamId);
});

final acceptInvitationProvider = FutureProvider.family<void, String>((ref, invitationId) async {
  final dataSource = ref.watch(teamDataSourceProvider);
  final token = ref.watch(currentAccessTokenProvider);
  if (token == null) throw Exception('Not authenticated');

  await dataSource.acceptInvitation(token, invitationId);
  ref.invalidate(receivedInvitationsProvider);
  ref.invalidate(myTeamsProvider);
  ref.invalidate(teamsProvider);
});

final rejectInvitationProvider = FutureProvider.family<void, String>((ref, invitationId) async {
  final dataSource = ref.watch(teamDataSourceProvider);
  final token = ref.watch(currentAccessTokenProvider);
  if (token == null) throw Exception('Not authenticated');

  await dataSource.rejectInvitation(token, invitationId);
  ref.invalidate(receivedInvitationsProvider);
});

final sendInvitationProvider = FutureProvider.family<Map<String, dynamic>, Map<String, dynamic>>((ref, params) async {
  final dataSource = ref.watch(teamDataSourceProvider);
  final token = ref.watch(currentAccessTokenProvider);
  if (token == null) throw Exception('Not authenticated');

  final result = await dataSource.sendInvitation(
    token,
    params['team_id'] as String,
    receiverId: params['receiver_id'] as String,
    message: params['message'] as String?,
  );

  ref.invalidate(teamInvitationsProvider(params['team_id'] as String));
  return result;
});

final removeMemberProvider = FutureProvider.family<void, Map<String, String>>((ref, params) async {
  final dataSource = ref.watch(teamDataSourceProvider);
  final token = ref.watch(currentAccessTokenProvider);
  if (token == null) throw Exception('Not authenticated');

  await dataSource.removeMember(
    token,
    params['team_id']!,
    params['member_user_id']!,
  );
  ref.invalidate(teamMembersProvider(params['team_id']!));
  ref.invalidate(teamDetailsProvider(params['team_id']!));
  ref.invalidate(myTeamsProvider);
});

final searchUsersProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, query) async {
  final dataSource = ref.watch(teamDataSourceProvider);
  final token = ref.watch(currentAccessTokenProvider);
  if (token == null) throw Exception('Not authenticated');
  if (query.trim().length < 2) return [];
  return dataSource.searchUsers(token, query.trim());
});
