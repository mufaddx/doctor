import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../providers/chat_provider.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  /// Relative labels read better than absolute timestamps in a message list.
  String _formatTimestamp(DateTime time) {
    final Duration difference = DateTime.now().difference(time);

    if (difference.inMinutes < 1) return 'Now';
    if (difference.inHours < 1) return '${difference.inMinutes}m';
    if (difference.inDays < 1) return DateFormat('h:mm a').format(time);
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return DateFormat('EEE').format(time);
    return DateFormat('d MMM').format(time);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threadsAsync = ref.watch(chatThreadsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: threadsAsync.when(
        loading: () => const AppListSkeleton(itemHeight: 72),
        error: (error, _) => AppErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(chatThreadsProvider),
        ),
        data: (threads) {
          if (threads.isEmpty) {
            return AppEmptyView(
              title: 'No conversations yet',
              message:
                  'Message a therapist from their profile to start a conversation.',
              icon: Icons.chat_bubble_outline,
              actionLabel: 'Find a Therapist',
              onAction: () => context.go('/patients'),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(chatThreadsProvider);
              ref.invalidate(unreadChatCountProvider);
            },
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              itemCount: threads.length,
              separatorBuilder: (_, __) => const Divider(indent: 76, height: 1),
              itemBuilder: (context, index) {
                final thread = threads[index];
                final bool hasUnread = thread.unreadCount > 0;

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 4,
                  ),
                  leading: AppAvatar(
                    imageUrl: thread.participantAvatarUrl,
                    name: thread.participantName,
                    size: 48,
                  ),
                  title: Text(
                    thread.participantName,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    thread.lastMessage ?? 'Start a conversation',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: hasUnread ? FontWeight.w600 : null,
                      color: hasUnread
                          ? theme.textTheme.bodyMedium?.color
                          : theme.textTheme.bodySmall?.color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatTimestamp(thread.updatedAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: hasUnread ? theme.colorScheme.primary : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (hasUnread)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            thread.unreadCount > 99
                                ? '99+'
                                : '${thread.unreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else
                        const SizedBox(height: 18),
                    ],
                  ),
                  onTap: () => context.go(
                    '/chat/thread/${thread.id}'
                    '?name=${Uri.encodeComponent(thread.participantName)}',
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
