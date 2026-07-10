import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/chat/chat_bloc.dart';
import '../../config/theme.dart';
import '../../models/message.dart';
import '../../services/api_service.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/code_input_dialog.dart';
import '../../widgets/premium_snackbar.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String name;
  final String type;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.name,
    required this.type,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _typingTimer;
  bool _isTyping = false;
  DateTime? _lastTypingSent;
  MessageModel? _replyingTo;
  MessageModel? _editingMessage;

  @override
  void initState() {
    super.initState();
    context.read<ChatBloc>().add(ChatLoadMessages(conversationId: widget.conversationId));
    context.read<ChatBloc>().add(ChatSendReadReceipt(conversationId: widget.conversationId));
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    if (_isTyping) {
      context.read<ChatBloc>().add(ChatSendTyping(conversationId: widget.conversationId, isTyping: false));
    }
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatLastSeen(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (_isSameDay(date, now.subtract(const Duration(days: 1)))) return 'yesterday at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateSeparator(DateTime date) {
    final now = DateTime.now();
    if (_isSameDay(date, now)) return 'Today';
    if (_isSameDay(date, now.subtract(const Duration(days: 1)))) return 'Yesterday';
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showMessageContextMenu(BuildContext context, MessageModel msg, bool isMine) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final theme = Theme.of(context);
        const emojis = ['👍', '❤️', '😂', '😮', '😢', '🔥', '🎉', '🚀'];

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Quick emoji reaction bar
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: emojis.map((emoji) {
                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(sheetContext);
                          context.read<ChatBloc>().add(ChatToggleReaction(messageId: msg.id, emoji: emoji));
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceVariant,
                            shape: BoxShape.circle,
                          ),
                          child: Text(emoji, style: const TextStyle(fontSize: 22)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),

                // Actions
                ListTile(
                  leading: const Icon(Icons.reply_rounded),
                  title: const Text('Reply'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    setState(() {
                      _replyingTo = msg;
                      _editingMessage = null;
                    });
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.copy_rounded),
                  title: const Text('Copy Text'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Clipboard.setData(ClipboardData(text: msg.content));
                    PremiumSnackbar.show(context, 'Copied to clipboard', isSuccess: true);
                  },
                ),
                if (isMine && msg.contentType == 'text')
                  ListTile(
                    leading: const Icon(Icons.edit_rounded),
                    title: const Text('Edit'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      setState(() {
                        _editingMessage = msg;
                        _replyingTo = null;
                        _messageController.text = msg.content;
                      });
                    },
                  ),
                if (isMine)
                  ListTile(
                    leading: const Icon(Icons.delete_rounded, color: Colors.redAccent),
                    title: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      context.read<ChatBloc>().add(ChatDeleteMessage(messageId: msg.id));
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatExt = theme.extension<ChatThemeExtension>()!;
    final authState = context.read<AuthBloc>().state;
    final currentUserId = authState is AuthAuthenticated ? authState.user.id : '';

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          context.read<ChatBloc>().add(ChatLoadConversations());
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded),
            onPressed: () {
              context.read<ChatBloc>().add(ChatLoadConversations());
              context.go('/');
            },
          ),
        title: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: widget.type == 'group'
                          ? [theme.colorScheme.secondary, theme.colorScheme.primary]
                          : [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.7)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: widget.type == 'group'
                        ? const Icon(Icons.group, color: Colors.white, size: 18)
                        : Text(
                            widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                  ),
                ),
                if (widget.type == 'direct')
                  BlocBuilder<ChatBloc, ChatState>(
                    builder: (context, state) {
                      if (state is ChatMessagesLoaded) {
                        final peerMatches = state.conversation.members.where((m) => m.id != currentUserId);
                        final peer = peerMatches.isNotEmpty ? peerMatches.first : null;
                      if (peer != null && peer.isOnline) {
                        return Positioned(
                          right: 0, bottom: 0,
                          child: Container(
                            width: 10, height: 10,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(color: theme.scaffoldBackgroundColor, width: 1.5),
                            ),
                          ),
                        );
                      }
                      }
                      return const SizedBox.shrink();
                    },
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.name, style: theme.textTheme.titleMedium, overflow: TextOverflow.ellipsis),
                  BlocBuilder<ChatBloc, ChatState>(
                    builder: (context, state) {
                      if (state is ChatMessagesLoaded && state.typingUsers.containsKey(widget.conversationId)) {
                        return Text(
                          '${state.typingUsers[widget.conversationId]} is typing...',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontStyle: FontStyle.italic,
                          ),
                        );
                      }
                      if (widget.type == 'direct') {
                        if (state is ChatMessagesLoaded) {
                          final peerMatches = state.conversation.members.where((m) => m.id != currentUserId);
                          final peer = peerMatches.isNotEmpty ? peerMatches.first : null;
                        if (peer != null) {
                          if (peer.isOnline) {
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                                const SizedBox(width: 4),
                                Text('Online', style: theme.textTheme.bodySmall?.copyWith(color: Colors.green, fontSize: 11)),
                              ],
                            );
                          } else if (!peer.hideLastSeen && peer.lastSeen != null) {
                            return Text('Last seen ${_formatLastSeen(peer.lastSeen!)}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 11));
                          } else {
                            return Text('Offline', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 11));
                          }
                        }
                        }
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (widget.type == 'group')
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () => context.go('/group/${widget.conversationId}'),
            ),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            children: [
              // Messages
          Expanded(
            child: BlocConsumer<ChatBloc, ChatState>(
              listener: (context, state) {
                if (state is ChatMessagesLoaded) {
                  _scrollToBottom();
                }
              },
              builder: (context, state) {
                if (state is ChatLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state is ChatMessagesLoaded) {
                  if (state.messages.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_outlined, size: 64, color: chatExt.textSecondary.withValues(alpha: 0.4)),
                          const SizedBox(height: 12),
                          Text('No messages yet', style: theme.textTheme.bodyLarge?.copyWith(color: chatExt.textSecondary)),
                          const SizedBox(height: 4),
                          Text('Send the first message!', style: theme.textTheme.bodySmall),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: state.messages.length,
                    itemBuilder: (context, index) {
                      final msg = state.messages[index];
                      final isMine = msg.senderId == currentUserId;
                      final showSender = !isMine && widget.type == 'group' &&
                          (index == 0 || state.messages[index - 1].senderId != msg.senderId);

                      final showDate = index == 0 || !_isSameDay(state.messages[index - 1].createdAt, msg.createdAt);
                      final bubble = MessageBubble(
                        message: msg,
                        isMine: isMine,
                        showSender: showSender,
                        onLongPress: () => _showMessageContextMenu(context, msg, isMine),
                      );

                      if (!showDate) return bubble;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Center(
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceVariant.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                _formatDateSeparator(msg.createdAt),
                                style: theme.textTheme.labelSmall?.copyWith(fontSize: 11.5, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          bubble,
                        ],
                      );
                    },
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ),

          if (_replyingTo != null) _buildReplyPreview(theme),
          if (_editingMessage != null) _buildEditPreview(theme),

          // Input bar
          _buildInputBar(theme, chatExt),
        ],
      ),
    ),
    ),
    ),
    );
  }

  Widget _buildReplyPreview(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.surfaceVariant.withValues(alpha: 0.5),
      child: Row(
        children: [
          Icon(Icons.reply_rounded, color: theme.colorScheme.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Replying to ${_replyingTo!.sender?.username ?? 'message'}',
                  style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                ),
                Text(
                  _replyingTo!.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: () => setState(() => _replyingTo = null),
          ),
        ],
      ),
    );
  }

  Widget _buildEditPreview(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
      child: Row(
        children: [
          Icon(Icons.edit_rounded, color: theme.colorScheme.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Editing message',
                  style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                ),
                Text(
                  _editingMessage!.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: () {
              setState(() {
                _editingMessage = null;
                _messageController.clear();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(ThemeData theme, ChatThemeExtension chatExt) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Attach file
            IconButton(
              icon: const Icon(Icons.attach_file_rounded),
              onPressed: () => _showAttachmentMenu(context),
              color: chatExt.textSecondary,
            ),

            // Code snippet
            IconButton(
              icon: const Icon(Icons.code_rounded),
              onPressed: () => _showCodeInputDialog(context),
              color: chatExt.textSecondary,
            ),

            // Text input
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  maxLines: 4,
                  minLines: 1,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onChanged: (_) => _handleTyping(),
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Send button
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.white),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    if (_editingMessage != null) {
      context.read<ChatBloc>().add(ChatEditMessage(
        messageId: _editingMessage!.id,
        content: text,
      ));
      setState(() {
        _editingMessage = null;
      });
      _messageController.clear();
      _stopTyping();
      return;
    }

    // Auto-detect content type
    String contentType = 'text';
    if (_isValidJson(text)) {
      contentType = 'json';
    }

    context.read<ChatBloc>().add(ChatSendMessage(
      conversationId: widget.conversationId,
      content: text,
      contentType: contentType,
      replyToId: _replyingTo?.id,
    ));

    setState(() {
      _replyingTo = null;
    });
    _messageController.clear();
    _stopTyping();
  }

  void _showCodeInputDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => CodeInputDialog(
        onSubmit: (code, language) {
          context.read<ChatBloc>().add(ChatSendMessage(
            conversationId: widget.conversationId,
            content: code,
            contentType: 'code',
            language: language,
          ));
        },
      ),
    );
  }

  void _handleTyping() {
    final text = _messageController.text;
    if (text.isEmpty) {
      _stopTyping();
      return;
    }

    final now = DateTime.now();
    if (!_isTyping || _lastTypingSent == null || now.difference(_lastTypingSent!) > const Duration(seconds: 3)) {
      _isTyping = true;
      _lastTypingSent = now;
      context.read<ChatBloc>().add(ChatSendTyping(conversationId: widget.conversationId, isTyping: true));
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), _stopTyping);
  }

  void _stopTyping() {
    _typingTimer?.cancel();
    if (_isTyping) {
      _isTyping = false;
      _lastTypingSent = null;
      context.read<ChatBloc>().add(ChatSendTyping(conversationId: widget.conversationId, isTyping: false));
    }
  }

  bool _isValidJson(String text) {
    try {
      if (text.startsWith('{') || text.startsWith('[')) {
        // Quick heuristic check
        int braces = 0;
        for (var c in text.runes) {
          if (c == '{'.codeUnitAt(0) || c == '['.codeUnitAt(0)) braces++;
          if (c == '}'.codeUnitAt(0) || c == ']'.codeUnitAt(0)) braces--;
        }
        return braces == 0 && text.length > 2;
      }
    } catch (_) {}
    return false;
  }

  void _showAttachmentMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final theme = Theme.of(context);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Share Content', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildAttachOption(
                      context,
                      icon: Icons.insert_drive_file_rounded,
                      label: 'Document',
                      color: const Color(0xFFE53935),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _pickAndSendFile(FileType.any);
                      },
                    ),
                    _buildAttachOption(
                      context,
                      icon: Icons.image_rounded,
                      label: 'Image',
                      color: const Color(0xFF8E44AD),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _pickAndSendFile(FileType.image);
                      },
                    ),
                    _buildAttachOption(
                      context,
                      icon: Icons.code_rounded,
                      label: 'Code',
                      color: const Color(0xFF16A085),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _showCodeInputDialog(context);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttachOption(BuildContext context, {required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndSendFile([FileType type = FileType.any]) async {
    try {
      final result = await FilePicker.platform.pickFiles(type: type, withData: true);
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final fileName = file.name;
        final fileSize = file.size;
        final fileBytes = file.bytes;

        if (fileBytes == null) {
          if (mounted) {
            PremiumSnackbar.show(context, 'Could not read file data.', icon: Icons.error_outline_rounded, isError: true);
          }
          return;
        }

        if (mounted) {
          PremiumSnackbar.show(context, 'Uploading $fileName...', icon: Icons.cloud_upload_rounded);
        }

        String mimeType = 'application/octet-stream';
        final ext = fileName.split('.').last.toLowerCase();
        if (['png', 'jpg', 'jpeg', 'gif', 'webp'].contains(ext)) {
          mimeType = 'image/$ext';
        } else if (['pdf'].contains(ext)) {
          mimeType = 'application/pdf';
        } else if (['zip', 'rar'].contains(ext)) {
          mimeType = 'application/zip';
        } else if (['txt', 'md', 'json', 'dart', 'py', 'js'].contains(ext)) {
          mimeType = 'text/plain';
        }

        final contentType = mimeType.startsWith('image/') ? 'image' : 'file';

        try {
          // Reliable direct server upload (prevents browser CORS & R2 config errors)
          final uploadRes = await ApiService().uploadDirectFile(fileName, fileBytes, mimeType);
          if (uploadRes['success'] == true && uploadRes['data'] != null) {
            final r2Key = uploadRes['data']['r2_key'];

            if (mounted) {
              context.read<ChatBloc>().add(ChatSendMessage(
                conversationId: widget.conversationId,
                content: fileName,
                contentType: contentType,
                r2Key: r2Key,
                fileName: fileName,
                fileSize: fileSize,
                mimeType: mimeType,
              ));
              PremiumSnackbar.show(context, 'Shared $fileName successfully!', icon: Icons.check_circle_rounded, isSuccess: true);
            }
          } else {
            throw Exception(uploadRes['error'] ?? 'Upload failed');
          }
        } catch (err) {
          if (mounted) {
            PremiumSnackbar.show(context, 'Failed to upload $fileName: $err', icon: Icons.error_outline_rounded, isError: true);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        PremiumSnackbar.show(context, 'Error picking file: $e', icon: Icons.error_outline_rounded, isError: true);
      }
    }
  }
}
