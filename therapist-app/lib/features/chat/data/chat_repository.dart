import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../services/socket_service.dart';

/// Conversation list entry.
class ChatThreadSummary {
  const ChatThreadSummary({
    required this.id,
    required this.participantName,
    required this.unreadCount,
    required this.updatedAt,
    this.participantUserId,
    this.participantAvatarUrl,
    this.specialization,
    this.lastMessage,
  });

  final String id;
  final String? participantUserId;
  final String participantName;
  final String? participantAvatarUrl;
  final String? specialization;
  final String? lastMessage;
  final int unreadCount;
  final DateTime updatedAt;

  factory ChatThreadSummary.fromJson(Map<String, dynamic> json) {
    final participant = json['participant'] as Map<String, dynamic>?;
    final lastMessage = json['lastMessage'] as Map<String, dynamic>?;
    final specializations = json['specialization'] as List<dynamic>?;

    return ChatThreadSummary(
      id: json['id'] as String,
      participantUserId: participant?['id'] as String?,
      participantName: participant?['fullName'] as String? ?? 'Conversation',
      participantAvatarUrl: participant?['avatarUrl'] as String?,
      specialization: (specializations?.isNotEmpty ?? false)
          ? specializations!.first.toString()
          : null,
      // An attachment-only message still needs a label in the list
      lastMessage: lastMessage == null
          ? null
          : ((lastMessage['content'] as String?)?.isNotEmpty ?? false)
          ? lastMessage['content'] as String
          : 'Attachment',
      unreadCount: json['unreadCount'] as int? ?? 0,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class ChatRepository {
  ChatRepository(this._api);

  final ApiClient _api;

  Future<List<ChatThreadSummary>> threads() async {
    final data = await _api.get<List<dynamic>>(ApiRoutes.chatThreads);

    return data
        .map((e) => ChatThreadSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Opens or reuses the conversation with a therapist, returning its id.
  Future<String> openThread(String recipientUserId) async {
    final data = await _api.post<Map<String, dynamic>>(
      ApiRoutes.chatThreads,
      body: {'recipientUserId': recipientUserId},
    );

    return data['id'] as String;
  }

  Future<List<ChatMessage>> messages(String threadId, {int page = 1}) async {
    final data = await _api.get<Map<String, dynamic>>(
      '${ApiRoutes.chatThreads}/$threadId/messages',
      query: {'page': page, 'limit': 50},
    );

    return (data['items'] as List<dynamic>)
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> markRead(String threadId) =>
      _api.patch('${ApiRoutes.chatThreads}/$threadId/read');

  Future<int> unreadCount() async {
    final data = await _api.get<Map<String, dynamic>>(ApiRoutes.chatUnread);
    return data['count'] as int? ?? 0;
  }

  Future<String> uploadAttachment(String threadId, String filePath) async {
    final data = await _api.upload<Map<String, dynamic>>(
      '${ApiRoutes.chatThreads}/$threadId/attachment',
      filePath: filePath,
    );

    return data['attachmentUrl'] as String;
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.watch(apiClientProvider));
});
