import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/network/api_client.dart';

class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.data,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final bool isRead;
  final Map<String, dynamic>? data;
  final DateTime createdAt;

  factory NotificationModel.fromJson(Map<String, dynamic> json) =>
      NotificationModel(
        id: json['id'] as String,
        type: json['type'] as String? ?? 'SYSTEM',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        isRead: json['isRead'] as bool? ?? false,
        data: json['data'] as Map<String, dynamic>?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class NotificationsRepository {
  NotificationsRepository(this._api);

  final ApiClient _api;

  Future<List<NotificationModel>> list({int page = 1}) async {
    final data = await _api.get<Map<String, dynamic>>(
      ApiRoutes.notifications,
      query: {'page': page, 'limit': AppConfig.pageSize},
    );

    return (data['items'] as List<dynamic>)
        .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> unreadCount() async {
    final data =
        await _api.get<Map<String, dynamic>>(ApiRoutes.notificationsUnread);
    return data['count'] as int? ?? 0;
  }

  Future<void> markRead(String id) =>
      _api.patch('${ApiRoutes.notifications}/$id/read');

  Future<void> markAllRead() =>
      _api.patch('${ApiRoutes.notifications}/read-all');

  Future<void> remove(String id) =>
      _api.delete('${ApiRoutes.notifications}/$id');
}

final notificationsRepositoryProvider =
    Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(ref.watch(apiClientProvider));
});
