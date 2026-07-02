import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/chat/chat_bloc.dart';
import '../../config/theme.dart';
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

  @override
  void initState() {
    super.initState();
    context.read<ChatBloc>().add(ChatLoadMessages(conversationId: widget.conversationId));
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatExt = theme.extension<ChatThemeExtension>()!;
    final authState = context.read<AuthBloc>().state;
    final currentUserId = authState is AuthAuthenticated ? authState.user.id : '';

    return Scaffold(
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
      body: Column(
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

                      return MessageBubble(
                        message: msg,
                        isMine: isMine,
                        showSender: showSender,
                      );
                    },
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ),

          // Input bar
          _buildInputBar(theme, chatExt),
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

    // Auto-detect content type
    String contentType = 'text';
    if (_isValidJson(text)) {
      contentType = 'json';
    }

    context.read<ChatBloc>().add(ChatSendMessage(
      conversationId: widget.conversationId,
      content: text,
      contentType: contentType,
    ));

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
    if (!_isTyping) {
      _isTyping = true;
      context.read<ChatBloc>().add(ChatSendTyping(conversationId: widget.conversationId, isTyping: true));
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), _stopTyping);
  }

  void _stopTyping() {
    if (_isTyping) {
      _isTyping = false;
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
