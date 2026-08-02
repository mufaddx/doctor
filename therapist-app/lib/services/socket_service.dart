import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../core/constants/app_config.dart';
import '../core/storage/token_storage.dart';

/// A chat message as it travels over the socket and the REST history endpoint.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.threadId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.senderName,
    this.senderAvatarUrl,
    this.attachmentUrl,
    this.isRead = false,
    this.isPending = false,
  });

  final String id;
  final String threadId;
  final String senderId;
  final String content;
  final String? senderName;
  final String? senderAvatarUrl;
  final String? attachmentUrl;
  final bool isRead;
  final DateTime createdAt;

  /// True while an optimistic message waits for server acknowledgement.
  final bool isPending;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final sender = json['sender'] as Map<String, dynamic>?;

    return ChatMessage(
      id: json['id'] as String,
      threadId: json['threadId'] as String,
      senderId: json['senderId'] as String,
      content: json['content'] as String? ?? '',
      senderName: sender?['fullName'] as String?,
      senderAvatarUrl: sender?['avatarUrl'] as String?,
      attachmentUrl: json['attachmentUrl'] as String?,
      isRead: json['isRead'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

/// Wraps the Socket.IO connection. The gateway authenticates during the
/// handshake, so the access token is attached before connecting.
class SocketService {
  SocketService(this._tokenStorage);

  final TokenStorage _tokenStorage;

  io.Socket? _socket;

  final StreamController<ChatMessage> _messageController =
      StreamController<ChatMessage>.broadcast();
  final StreamController<({String threadId, String userId, bool isTyping})>
  _typingController = StreamController.broadcast();
  final StreamController<({String userId, bool online})> _presenceController =
      StreamController.broadcast();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  Stream<ChatMessage> get messages => _messageController.stream;
  Stream<({String threadId, String userId, bool isTyping})> get typing =>
      _typingController.stream;
  Stream<({String userId, bool online})> get presence =>
      _presenceController.stream;
  Stream<bool> get connectionState => _connectionController.stream;

  bool get isConnected => _socket?.connected ?? false;

  Future<void> connect() async {
    if (_socket != null && _socket!.connected) return;

    final String? token = await _tokenStorage.readAccessToken();
    if (token == null) return;

    _socket = io.io(
      '${AppConfig.socketUrl}/chat',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableReconnection()
          // Backing off avoids hammering the server on a flaky connection
          .setReconnectionAttempts(10)
          .setReconnectionDelay(1500)
          .setReconnectionDelayMax(10000)
          .disableAutoConnect()
          .build(),
    );

    _socket!
      ..onConnect((_) => _connectionController.add(true))
      ..onDisconnect((_) => _connectionController.add(false))
      ..onConnectError((error) {
        debugPrint('Socket connect error: $error');
        _connectionController.add(false);
      })
      ..on('message:new', (data) {
        _messageController.add(
          ChatMessage.fromJson(Map<String, dynamic>.from(data as Map)),
        );
      })
      ..on('typing', (data) {
        final map = Map<String, dynamic>.from(data as Map);
        _typingController.add((
          threadId: map['threadId'] as String,
          userId: map['userId'] as String,
          isTyping: map['isTyping'] as bool? ?? false,
        ));
      })
      ..on('user:online', (data) {
        final map = Map<String, dynamic>.from(data as Map);
        _presenceController.add((
          userId: map['userId'] as String,
          online: true,
        ));
      })
      ..on('user:offline', (data) {
        final map = Map<String, dynamic>.from(data as Map);
        _presenceController.add((
          userId: map['userId'] as String,
          online: false,
        ));
      });

    _socket!.connect();
  }

  void joinThread(String threadId) =>
      _socket?.emit('thread:join', {'threadId': threadId});

  void leaveThread(String threadId) =>
      _socket?.emit('thread:leave', {'threadId': threadId});

  void sendMessage({
    required String threadId,
    required String content,
    String? attachmentUrl,
  }) {
    _socket?.emit('message:send', {
      'threadId': threadId,
      'content': content,
      if (attachmentUrl != null) 'attachmentUrl': attachmentUrl,
    });
  }

  void setTyping(String threadId, bool isTyping) =>
      _socket?.emit('typing', {'threadId': threadId, 'isTyping': isTyping});

  void disconnect() {
    _socket?.dispose();
    _socket = null;
    _connectionController.add(false);
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _typingController.close();
    _presenceController.close();
    _connectionController.close();
  }
}

final socketServiceProvider = Provider<SocketService>((ref) {
  final service = SocketService(ref.watch(tokenStorageProvider));
  ref.onDispose(service.dispose);
  return service;
});
