import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_provider.dart';
import '../data/notification_models.dart';
import '../data/notification_remote_datasource.dart';

final notificationDataSourceProvider = Provider<NotificationRemoteDataSource>(
  (ref) => NotificationRemoteDataSource(ref.read(apiClientProvider)),
);

final notificationsProvider =
    AsyncNotifierProvider<NotificationsController, List<NotificationItem>>(
  NotificationsController.new,
);

class NotificationsController extends AsyncNotifier<List<NotificationItem>> {
  @override
  Future<List<NotificationItem>> build() => _load();

  Future<List<NotificationItem>> _load() =>
      ref.read(notificationDataSourceProvider).fetch();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  Future<void> markRead(NotificationItem item) async {
    if (item.isRead) return;
    await ref.read(notificationDataSourceProvider).markRead(item.id);
    state = await AsyncValue.guard(_load);
  }
}

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.read(notificationsProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: notifications.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorView(
          message: error.toString(),
          onRetry: () => ref.read(notificationsProvider.notifier).refresh(),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_none_rounded, size: 54),
                    SizedBox(height: 12),
                    Text('No notifications yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    SizedBox(height: 6),
                    Text('Tournament and registration updates will appear here.', textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(notificationsProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = items[index];
                return Material(
                  color: item.isRead
                      ? Theme.of(context).colorScheme.surface
                      : Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => ref.read(notificationsProvider.notifier).markRead(item),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            item.isRead ? Icons.notifications_none_rounded : Icons.notifications_active_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                const SizedBox(height: 5),
                                Text(item.body),
                                const SizedBox(height: 8),
                                Text(_relativeTime(item.createdAt), style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                          ),
                          if (!item.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(left: 8, top: 6),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  static String _relativeTime(DateTime date) {
    final delta = DateTime.now().difference(date.toLocal());
    if (delta.inMinutes < 1) return 'Just now';
    if (delta.inHours < 1) return '${delta.inMinutes}m ago';
    if (delta.inDays < 1) return '${delta.inHours}h ago';
    if (delta.inDays < 7) return '${delta.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48),
              const SizedBox(height: 12),
              const Text('Could not load notifications', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      );
}
