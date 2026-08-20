import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/auth_providers.dart';
import '../data/notification_remote_datasource.dart';

/// Small, cheap provider used by app chrome (for example the home header)
/// to show whether the user has unread notifications.
final unreadNotificationCountProvider = FutureProvider<int>((ref) async {
  final token = ref.watch(currentAccessTokenProvider);
  if (token == null) return 0;

  final dataSource = NotificationRemoteDataSource(ref.read(apiClientProvider));
  final items = await dataSource.fetch(unreadOnly: true);
  return items.length;
});
