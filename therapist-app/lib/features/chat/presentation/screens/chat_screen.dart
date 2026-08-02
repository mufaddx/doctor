import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../../../services/socket_service.dart';
import '../../../auth/data/auth_repository.dart';
import '../providers/chat_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.threadId, required this.title});

  final String threadId;
  final String title;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isTyping = false;
  bool _isUploading = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Emits typing state transitions only, not one event per keystroke.
  void _onTextChanged(String value) {
    final bool typing = value.trim().isNotEmpty;

    if (typing != _isTyping) {
      _isTyping = typing;
      ref.read(threadProvider(widget.threadId).notifier).setTyping(typing);
    }
  }

  void _send() {
    final String text = _messageController.text.trim();
    if (text.isEmpty) return;

    final String? userId = ref.read(currentTherapistProvider)?.id;
    if (userId == null) return;

    ref
        .read(threadProvider(widget.threadId).notifier)
        .send(text, myUserId: userId);

    _messageController.clear();
    _isTyping = false;
    ref.read(threadProvider(widget.threadId).notifier).setTyping(false);

    _scrollToBottom();
  }

  Future<void> _attachImage() async {
    final XFile? file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1600,
    );
    if (file == null) return;

    setState(() => _isUploading = true);

    try {
      final notifier = ref.read(threadProvider(widget.threadId).notifier);
      final String url = await notifier.uploadAttachment(file.path);

      final String? userId = ref.read(currentTherapistProvider)?.id;
      if (userId == null) return;

      notifier.send('', attachmentUrl: url, myUserId: userId);
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      AppSnackbar.error(context, error.toString());
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  /// Runs after the frame so the new message is already laid out.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThreadState state = ref.watch(threadProvider(widget.threadId));
    final String? myUserId = ref.watch(currentTherapistProvider)?.id;
    final theme = Theme.of(context);

    // Auto-scroll whenever a new message lands
    ref.listen(threadProvider(widget.threadId), (previous, next) {
      if ((previous?.messages.length ?? 0) < next.messages.length) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: theme.textTheme.titleMedium),
            Text(
              state.isPeerTyping
                  ? 'typing...'
                  : (state.isConnected ? 'Online' : 'Connecting...'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: state.isConnected ? AppColors.success : null,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),

      body: Column(
        children: [
          Expanded(child: _buildMessages(state, myUserId)),

          if (_isUploading) const LinearProgressIndicator(minHeight: 2),

          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(top: BorderSide(color: theme.dividerColor)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: _isUploading ? null : _attachImage,
                    icon: const Icon(Icons.attach_file),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      onChanged: _onTextChanged,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: theme.colorScheme.primary,
                    child: IconButton(
                      onPressed: _send,
                      icon: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessages(ThreadState state, String? myUserId) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.messages.isEmpty) {
      return AppErrorView(
        message: state.error!,
        onRetry: () =>
            ref.read(threadProvider(widget.threadId).notifier).loadHistory(),
      );
    }

    if (state.messages.isEmpty) {
      return const AppEmptyView(
        title: 'No messages yet',
        message: 'Send a message to start the conversation.',
        icon: Icons.chat_bubble_outline,
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: state.messages.length,
      itemBuilder: (context, index) {
        final ChatMessage message = state.messages[index];
        final bool isMine = message.senderId == myUserId;

        // A date divider is inserted whenever the calendar day changes
        final bool showDateDivider =
            index == 0 ||
            !_isSameDay(state.messages[index - 1].createdAt, message.createdAt);

        return Column(
          children: [
            if (showDateDivider) _DateDivider(date: message.createdAt),
            _MessageBubble(message: message, isMine: isMine),
          ],
        );
      },
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.date});

  final DateTime date;

  String get _label {
    final DateTime now = DateTime.now();
    final Duration difference = DateTime(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime(date.year, date.month, date.day));

    if (difference.inDays == 0) return 'Today';
    if (difference.inDays == 1) return 'Yesterday';
    return DateFormat('d MMMM yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontSize: 11),
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMine});

  final ChatMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Color bubbleColor = isMine
        ? theme.colorScheme.primary
        : (theme.brightness == Brightness.dark
              ? AppColors.darkSurface
              : Colors.white);

    final Color textColor = isMine
        ? Colors.white
        : (theme.textTheme.bodyMedium?.color ?? Colors.black);

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppSpacing.radiusLg),
            topRight: const Radius.circular(AppSpacing.radiusLg),
            // The flat corner points at the sender
            bottomLeft: Radius.circular(isMine ? AppSpacing.radiusLg : 4),
            bottomRight: Radius.circular(isMine ? 4 : AppSpacing.radiusLg),
          ),
          border: isMine ? null : Border.all(color: theme.dividerColor),
        ),
        child: Column(
          crossAxisAlignment: isMine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (message.attachmentUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                child: CachedNetworkImage(
                  imageUrl: message.attachmentUrl!,
                  width: 200,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => const SizedBox(
                    height: 140,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
                ),
              ),
              if (message.content.isNotEmpty) const SizedBox(height: 6),
            ],

            if (message.content.isNotEmpty)
              Text(
                message.content,
                style: TextStyle(color: textColor, fontSize: 14, height: 1.35),
              ),

            const SizedBox(height: 4),

            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('h:mm a').format(message.createdAt),
                  style: TextStyle(
                    fontSize: 10,
                    color: isMine
                        ? Colors.white.withValues(alpha: 0.75)
                        : theme.textTheme.bodySmall?.color,
                  ),
                ),
                if (isMine) ...[
                  const SizedBox(width: 4),
                  Icon(
                    // A clock marks a message still awaiting the server echo
                    message.isPending
                        ? Icons.schedule
                        : (message.isRead ? Icons.done_all : Icons.done),
                    size: 13,
                    color: message.isRead
                        ? Colors.lightBlueAccent
                        : Colors.white.withValues(alpha: 0.75),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
