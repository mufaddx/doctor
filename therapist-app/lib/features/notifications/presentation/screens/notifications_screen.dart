import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../data/notifications_repository.dart';
import '../providers/notifications_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  ({IconData icon, Color color}) _styleFor(String type, BuildContext context) {
    return switch (type) {
      'APPOINTMENT' => (
        icon: Icons.event_available_outlined,
        color: Theme.of(context).colorScheme.primary,
      ),
      'PAYMENT' => (icon: Icons.payments_outlined, color: AppColors.success),
      'CHAT' => (icon: Icons.chat_bubble_outline, color: AppColors.info),
      'OFFER' => (icon: Icons.local_offer_outlined, color: AppColors.warning),
      'REMINDER' => (icon: Icons.alarm_outlined, color: AppColors.warning),
      _ => (icon: Icons.notifications_none, color: Colors.grey),
    };
  }

  /// Deep-links to whatever the notification refers to, when it carries an id.
  void _handleTap(
    BuildContext context,
    WidgetRef ref,
    NotificationModel notification,
  ) {
    if (!notification.isRead) {
      ref.read(notificationsRepositoryProvider).markRead(notification.id).then((
        _,
      ) {
        ref.invalidate(notificationsProvider);
        ref.invalidate(unreadNotificationCountProvider);
      });
    }

    final String? appointmentId =
        notification.data?['appointmentId'] as String?;
    final String? threadId = notification.data?['threadId'] as String?;

    if (appointmentId != null) {
      context.go('/appointments/detail/$appointmentId');
    } else if (threadId != null) {
      context.go('/chat/thread/$threadId');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(notificationsRepositoryProvider).markAllRead();
              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadNotificationCountProvider);

              if (!context.mounted) return;
              AppSnackbar.success(context, 'All notifications marked as read');
            },
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const AppListSkeleton(itemHeight: 76),
        error: (error, _) => AppErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(notificationsProvider),
        ),
        data: (notifications) {
          if (notifications.isEmpty) {
            return const AppEmptyView(
              title: 'No notifications',
              message: 'Booking updates and offers will appear here.',
              icon: Icons.notifications_none,
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadNotificationCountProvider);
            },
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
              itemBuilder: (context, index) {
                final notification = notifications[index];
                final style = _styleFor(notification.type, context);

                return Dismissible(
                  key: ValueKey(notification.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: AppSpacing.lg),
                    color: AppColors.danger,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) async {
                    await ref
                        .read(notificationsRepositoryProvider)
                        .remove(notification.id);
                    ref.invalidate(notificationsProvider);
                  },
                  child: Container(
                    // Unread rows get a subtle tint instead of a dot marker
                    color: notification.isRead
                        ? null
                        : theme.colorScheme.primary.withValues(alpha: 0.04),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: 6,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: style.color.withValues(alpha: 0.12),
                        child: Icon(style.icon, color: style.color, size: 20),
                      ),
                      title: Text(
                        notification.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: notification.isRead
                              ? FontWeight.w500
                              : FontWeight.w700,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notification.body,
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat(
                              'd MMM, h:mm a',
                            ).format(notification.createdAt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      onTap: () => _handleTap(context, ref, notification),
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
}
