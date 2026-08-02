import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../services/socket_service.dart';
import '../../data/chat_repository.dart';

export '../../data/chat_repository.dart' show chatRepositoryProvider;

/// Conversation list.
final chatThreadsProvider = FutureProvider.autoDispose<List<ChatThreadSummary>>(
  (ref) {
    return ref.watch(chatRepositoryProvider).threads();
  },
);

/// Drives the badge on the bottom navigation bar.
final unreadChatCountProvider = FutureProvider<int>((ref) {
  return ref.watch(chatRepositoryProvider).unreadCount();
});

class ThreadState {
  const ThreadState({
    this.messages = const [],
    this.isLoading = true,
    this.isConnected = false,
    this.isPeerTyping = false,
    this.error,
  });

  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isConnected;
  final bool isPeerTyping;
  final String? error;

  ThreadState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isConnected,
    bool? isPeerTyping,
    String? error,
    bool clearError = false,
  }) {
    return ThreadState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isConnected: isConnected ?? this.isConnected,
      isPeerTyping: isPeerTyping ?? this.isPeerTyping,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Merges the REST history with the live socket stream for one conversation.
class ThreadNotifier extends StateNotifier<ThreadState> {
  ThreadNotifier(this._repository, this._socket, this._threadId)
    : super(const ThreadState()) {
    _initialise();
  }

  final ChatRepository _repository;
  final SocketService _socket;
  final String _threadId;

  StreamSubscription<ChatMessage>? _messageSub;
  StreamSubscription<({String threadId, String userId, bool isTyping})>?
  _typingSub;
  StreamSubscription<bool>? _connectionSub;
  Timer? _typingResetTimer;

  Future<void> _initialise() async {
    await _socket.connect();
    _socket.joinThread(_threadId);

    _connectionSub = _socket.connectionState.listen((connected) {
      state = state.copyWith(isConnected: connected);
      // Rejoin after a reconnect, otherwise the room membership is lost
      if (connected) _socket.joinThread(_threadId);
    });

    _messageSub = _socket.messages.listen((message) {
      if (message.threadId != _threadId) return;

      // Drop the optimistic copy once the server echoes the real message
      final withoutPending = state.messages
          .where((m) => !(m.isPending && m.content == message.content))
          .toList();

      state = state.copyWith(
        messages: [...withoutPending, message],
        isPeerTyping: false,
      );
    });

    _typingSub = _socket.typing.listen((event) {
      if (event.threadId != _threadId) return;

      state = state.copyWith(isPeerTyping: event.isTyping);

      // Clear the indicator if the peer stops without sending a stop event
      _typingResetTimer?.cancel();
      if (event.isTyping) {
        _typingResetTimer = Timer(const Duration(seconds: 4), () {
          if (mounted) state = state.copyWith(isPeerTyping: false);
        });
      }
    });

    await loadHistory();
    await _repository.markRead(_threadId);
  }

  Future<void> loadHistory() async {
    try {
      final messages = await _repository.messages(_threadId);
      state = state.copyWith(messages: messages, isLoading: false);
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  /// Adds the message locally straight away so the UI feels instant, then
  /// lets the socket echo replace it with the authoritative record.
  void send(String content, {String? attachmentUrl, required String myUserId}) {
    final String trimmed = content.trim();
    if (trimmed.isEmpty && attachmentUrl == null) return;

    final optimistic = ChatMessage(
      id: 'pending_${DateTime.now().microsecondsSinceEpoch}',
      threadId: _threadId,
      senderId: myUserId,
      content: trimmed,
      attachmentUrl: attachmentUrl,
      createdAt: DateTime.now(),
      isPending: true,
    );

    state = state.copyWith(messages: [...state.messages, optimistic]);

    _socket.sendMessage(
      threadId: _threadId,
      content: trimmed,
      attachmentUrl: attachmentUrl,
    );
  }

  void setTyping(bool isTyping) => _socket.setTyping(_threadId, isTyping);

  Future<String> uploadAttachment(String filePath) =>
      _repository.uploadAttachment(_threadId, filePath);

  @override
  void dispose() {
    _messageSub?.cancel();
    _typingSub?.cancel();
    _connectionSub?.cancel();
    _typingResetTimer?.cancel();
    _socket.leaveThread(_threadId);
    super.dispose();
  }
}

final threadProvider = StateNotifierProvider.autoDispose
    .family<ThreadNotifier, ThreadState, String>((ref, threadId) {
      return ThreadNotifier(
        ref.watch(chatRepositoryProvider),
        ref.watch(socketServiceProvider),
        threadId,
      );
    });
