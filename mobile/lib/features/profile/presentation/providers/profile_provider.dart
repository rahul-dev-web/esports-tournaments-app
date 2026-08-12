import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/auth_providers.dart';
import '../../data/datasources/profile_remote_datasource.dart';

// Data source provider
final profileDataSourceProvider = Provider((ref) {
  return ProfileRemoteDataSource();
});

// User profile provider
final userProfileProvider = FutureProvider((ref) async {
  final dataSource = ref.watch(profileDataSourceProvider);
  final token = ref.watch(currentAccessTokenProvider);
  
  if (token == null) throw Exception('Not authenticated');
  
  return dataSource.getUserProfile(token);
});

// Update profile provider
final updateProfileProvider = FutureProvider.family((ref, Map<String, dynamic> data) async {
  final dataSource = ref.watch(profileDataSourceProvider);
  final token = ref.watch(currentAccessTokenProvider);
  
  if (token == null) throw Exception('Not authenticated');
  
  final result = await dataSource.updateProfile(token, data);
  
  // Invalidate cache to refetch
  ref.invalidate(userProfileProvider);
  
  return result;
});

// Search users provider
final searchUsersProvider = FutureProvider.family((ref, String query) async {
  final dataSource = ref.watch(profileDataSourceProvider);
  final token = ref.watch(currentAccessTokenProvider);
  
  if (token == null) throw Exception('Not authenticated');
  if (query.length < 2) return [];
  
  return dataSource.searchUsers(token, query);
});
