import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/notifications_repository.dart';

final notificationsProvider =
    FutureProvider.autoDispose<List<NotificationModel>>((ref) {
  return ref.watch(notificationsRepositoryProvider).list();
});

/// Kept alive (not autoDispose) so the home screen badge survives navigation.
final unreadNotificationCountProvider = FutureProvider<int>((ref) {
  return ref.watch(notificationsRepositoryProvider).unreadCount();
});
