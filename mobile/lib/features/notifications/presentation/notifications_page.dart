import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_provider.dart';
import '../data/notification_models.dart';
import '../data/notification_remote_datasource.dart';
import 'notification_badge_provider.dart';

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
    ref.invalidate(unreadNotificationCountProvider);
  }

  Future<void> markRead(NotificationItem item) async {
    if (item.isRead) return;
    await ref.read(notificationDataSourceProvider).markRead(item.id);
    state = await AsyncValue.guard(_load);
    ref.invalidate(unreadNotificationCountProvider);
  }

  Future<int> markAllRead() async {
    final updated = await ref.read(notificationDataSourceProvider).markAllRead();
    state = await AsyncValue.guard(_load);
    ref.invalidate(unreadNotificationCountProvider);
    return updated;
  }
}

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  bool unreadOnly = false;
  bool markingAllRead = false;

  Future<void> _markAllRead() async {
    if (markingAllRead) return;
    setState(() => markingAllRead = true);
    try {
      await ref.read(notificationsProvider.notifier).markAllRead();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notifications marked as read')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not mark notifications as read: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => markingAllRead = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            tooltip: 'Mark all as read',
            onPressed: markingAllRead ? null : _markAllRead,
            icon: markingAllRead
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.done_all_rounded),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: () =>
                ref.read(notificationsProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: notifications.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorView(
          message: error.toString(),
          onRetry: () =>
              ref.read(notificationsProvider.notifier).refresh(),
        ),
        data: (items) {
          final unreadCount = items.where((item) => !item.isRead).length;
          final visibleItems = unreadOnly
              ? items.where((item) => !item.isRead).toList()
              : items;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        unreadCount == 0
                            ? 'All caught up'
                            : '$unreadCount unread notification${unreadCount == 1 ? '' : 's'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    FilterChip(
                      selected: unreadOnly,
                      label: const Text('Unread only'),
                      onSelected: (value) =>
                          setState(() => unreadOnly = value),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: visibleItems.isEmpty
                    ? _EmptyView(unreadOnly: unreadOnly)
                    : RefreshIndicator(
                        onRefresh: () => ref
                            .read(notificationsProvider.notifier)
                            .refresh(),
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                          itemCount: visibleItems.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = visibleItems[index];
                            return _NotificationCard(
                              item: item,
                              onTap: () => ref
                                  .read(notificationsProvider.notifier)
                                  .markRead(item),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item, required this.onTap});

  final NotificationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: item.isRead
          ? colorScheme.surface
          : colorScheme.primary.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                item.isRead
                    ? Icons.notifications_none_rounded
                    : Icons.notifications_active_rounded,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(item.body),
                    const SizedBox(height: 8),
                    Text(
                      _relativeTime(item.createdAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.unreadOnly});
  final bool unreadOnly;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.notifications_none_rounded,
                size: 44,
              ),
              const SizedBox(height: 12),
              Text(unreadOnly ? 'No unread notifications' : 'No notifications yet'),
            ],
          ),
        ),
      );
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
              const Icon(Icons.error_outline_rounded, size: 40),
              const SizedBox(height: 10),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 14),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      );
}

String _relativeTime(DateTime value) {
  final difference = DateTime.now().difference(value.toLocal());
  if (difference.inSeconds < 60) return 'Just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
  if (difference.inHours < 24) return '${difference.inHours}h ago';
  if (difference.inDays < 7) return '${difference.inDays}d ago';
  return '${value.day}/${value.month}/${value.year}';
}
