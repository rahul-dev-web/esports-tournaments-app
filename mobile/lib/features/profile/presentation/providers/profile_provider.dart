import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/datasources/profile_remote_datasource.dart';

// Data source provider
final profileDataSourceProvider = Provider((ref) {
  return ProfileRemoteDataSource();
});

String? _sessionToken() => Supabase.instance.client.auth.currentSession?.accessToken;

// User profile provider
final userProfileProvider = FutureProvider((ref) async {
  final dataSource = ref.watch(profileDataSourceProvider);
  final token = _sessionToken();
  
  if (token == null) throw Exception('Not authenticated');
  
  return dataSource.getUserProfile(token);
});

// Update profile provider
final updateProfileProvider = FutureProvider.family((ref, Map<String, dynamic> data) async {
  final dataSource = ref.watch(profileDataSourceProvider);
  final token = _sessionToken();
  
  if (token == null) throw Exception('Not authenticated');
  
  final result = await dataSource.updateProfile(token, data);
  
  // Invalidate cache to refetch
  ref.invalidate(userProfileProvider);
  
  return result;
});

// Search users provider
final searchUsersProvider = FutureProvider.family((ref, String query) async {
  final dataSource = ref.watch(profileDataSourceProvider);
  final token = _sessionToken();
  
  if (token == null) throw Exception('Not authenticated');
  if (query.length < 2) return [];
  
  return dataSource.searchUsers(token, query);
});
