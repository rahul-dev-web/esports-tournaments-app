import '../../../core/services/api_client.dart';
import 'notification_models.dart';

class NotificationRemoteDataSource {
  NotificationRemoteDataSource(this._api);

  final ApiClient _api;

  Future<List<NotificationItem>> fetch({bool unreadOnly = false}) async {
    final items = await _api.getList(
      '/notifications/me?unread_only=$unreadOnly&limit=100',
    );
    return items
        .whereType<Map<String, dynamic>>()
        .map(NotificationItem.fromJson)
        .toList();
  }

  Future<NotificationItem> markRead(String id) async {
    final response = await _api.patch('/notifications/$id/read');
    return NotificationItem.fromJson(response as Map<String, dynamic>);
  }

  Future<int> markAllRead() async {
    final response = await _api.post('/notifications/read-all');
    if (response is Map<String, dynamic>) {
      final updated = response['updated'];
      if (updated is int) return updated;
    }
    return 0;
  }
}
