import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/chat/chat_bloc.dart';
import '../../bloc/theme/theme_cubit.dart';
import '../../config/theme.dart';
import '../../models/conversation.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';
import '../../services/websocket_service.dart';
import 'package:shimmer/shimmer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ChatBloc>().add(ChatLoadConversations());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatExt = theme.extension<ChatThemeExtension>()!;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.code_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('CoderTalk'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(context.watch<ThemeCubit>().isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => context.read<ThemeCubit>().toggleTheme(),
            tooltip: 'Toggle Theme',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'profile') {
                context.push('/profile');
              } else if (value == 'logout') {
                context.read<AuthBloc>().add(AuthLogoutRequested());
                context.go('/login');
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [Icon(Icons.person_outline_rounded, size: 20), SizedBox(width: 8), Text('Profile & Settings')],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [Icon(Icons.logout, size: 20), SizedBox(width: 8), Text('Logout')],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          StreamBuilder<bool>(
            stream: WebSocketService().connectionStream,
            initialData: WebSocketService().isConnected,
            builder: (context, snapshot) {
              final isConnected = snapshot.data ?? true;
              if (!isConnected) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                  color: theme.colorScheme.errorContainer,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi_off_rounded, size: 16, color: theme.colorScheme.onErrorContainer),
                      const SizedBox(width: 8),
                      Text(
                        'Offline • Connecting to live servers...',
                        style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onErrorContainer, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          Expanded(
            child: BlocBuilder<ChatBloc, ChatState>(
              builder: (context, state) {
                final cached = context.read<ChatBloc>().cachedConversations;

                if (state is ChatConversationsLoaded) {
                  if (state.conversations.isEmpty) {
                    return _buildEmptyState(theme);
                  }
                  return _buildConversationList(state.conversations, theme, chatExt);
                }

                if (cached.isNotEmpty) {
                  return _buildConversationList(cached, theme, chatExt);
                }

                if (state is ChatLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

          if (state is ChatError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                  const SizedBox(height: 12),
                  Text(state.message),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.read<ChatBloc>().add(ChatLoadConversations()),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return _buildSkeletonLoading(theme);
        },
      ),
    ),
  ],
),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // New DM
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [theme.colorScheme.secondary, theme.colorScheme.primary],
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: () => _showNewDMDialog(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text('New DM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // New Group
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [theme.colorScheme.primary, const Color(0xFF6366F1)],
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: () => context.go('/create-group'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.group_add_rounded, color: Colors.white, size: 22),
                      SizedBox(width: 8),
                      Text('New Group', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoading(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: theme.brightness == Brightness.dark ? const Color(0xFF1C2333) : const Color(0xFFE8ECF2),
          highlightColor: theme.brightness == Brightness.dark ? const Color(0xFF2C3548) : const Color(0xFFF7F8FC),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(width: 54, height: 54, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 150, height: 16, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
                      const SizedBox(height: 10),
                      Container(width: double.infinity, height: 12, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [theme.colorScheme.primary.withValues(alpha: 0.25), theme.colorScheme.secondary.withValues(alpha: 0.15)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
                border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3), width: 1.5),
              ),
              child: Center(
                child: Icon(Icons.forum_rounded, size: 60, color: theme.colorScheme.primary),
              ),
            ),
            const SizedBox(height: 28),
            Text('No Active Channels', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.5)),
            const SizedBox(height: 12),
            Text(
              'Your communications hub is quiet. Use the speed dial actions below to connect with teammates or initiate a group channel.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodySmall?.color, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationList(List<ConversationModel> conversations, ThemeData theme, ChatThemeExtension chatExt) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<ChatBloc>().add(ChatLoadConversations());
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        itemCount: conversations.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildHeaderStatusStrip(theme, conversations.length);
          }
          final conv = conversations[index - 1];
          return _ConversationTile(
            conversation: conv,
            theme: theme,
            chatExt: chatExt,
            onTap: () {
              context.go(
                '/chat/${conv.id}?name=${Uri.encodeComponent(conv.name)}&type=${conv.type}',
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHeaderStatusStrip(ThemeData theme, int totalChats) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 14, left: 4, right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E283D), const Color(0xFF141C2E)]
              : [const Color(0xFFF3F6FC), const Color(0xFFE8EEF8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.25), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.hub_rounded, color: theme.colorScheme.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Active Channels & DMs',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  '$totalChats active conversations synced in real time',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.textTheme.bodySmall?.color),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF00E676).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: Color(0xFF00E676), shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                const Text('ONLINE', style: TextStyle(color: Color(0xFF00C853), fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showNewDMDialog(BuildContext context) {
    final searchController = TextEditingController();
    List<UserModel> results = [];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Start a Conversation'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search by username...',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (query) async {
                        if (query.isNotEmpty) {
                          final response = await ApiService().searchUsers(query);
                          if (response['success'] == true) {
                            final data = response['data'] as List<dynamic>? ?? [];
                            setDialogState(() {
                              results = data.map((u) => UserModel.fromJson(u)).toList();
                            });
                          }
                        } else {
                          setDialogState(() => results = []);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    if (results.isNotEmpty)
                      SizedBox(
                        height: 200,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: results.length,
                          itemBuilder: (_, i) {
                            final user = results[i];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                child: Text(user.initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                              ),
                              title: Text(user.username),
                              subtitle: Text(user.email),
                              trailing: user.isOnline
                                  ? Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle))
                                  : null,
                              onTap: () {
                                Navigator.pop(dialogContext);
                                context.read<ChatBloc>().add(ChatStartDM(userId: user.id));
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
              ],
            );
          },
        );
      },
    );
  }
}

class _ConversationTile extends StatefulWidget {
  final ConversationModel conversation;
  final ThemeData theme;
  final ChatThemeExtension chatExt;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.conversation,
    required this.theme,
    required this.chatExt,
    required this.onTap,
  });

  @override
  State<_ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<_ConversationTile> with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conv = widget.conversation;
    final theme = widget.theme;
    final chatExt = widget.chatExt;
    final isDark = theme.brightness == Brightness.dark;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTapDown: (_) => _scaleController.forward(),
        onTapUp: (_) {
          _scaleController.reverse();
          widget.onTap();
        },
        onTapCancel: () => _scaleController.reverse(),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF192030).withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: conv.hasUnread
                  ? theme.colorScheme.primary.withValues(alpha: 0.5)
                  : theme.dividerColor.withValues(alpha: 0.3),
              width: conv.hasUnread ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: conv.hasUnread
                    ? theme.colorScheme.primary.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Avatar with glowing gradient & status badge
                Stack(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: conv.isGroup
                              ? [theme.colorScheme.secondary, theme.colorScheme.primary]
                              : [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.65)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: conv.isGroup
                            ? const Icon(Icons.group_rounded, color: Colors.white, size: 26)
                            : Text(
                                conv.initials,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                      ),
                    ),
                    if (conv.hasUnread)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondary,
                            shape: BoxShape.circle,
                            border: Border.all(color: theme.scaffoldBackgroundColor, width: 2),
                          ),
                        ),
                      ),
                    if (conv.isDirect)
                      Builder(
                        builder: (context) {
                          final authState = context.read<AuthBloc>().state;
                          final currentUserId = authState is AuthAuthenticated ? authState.user.id : '';
                          final peerMatches = conv.members.where((m) => m.id != currentUserId);
                          final peer = peerMatches.isNotEmpty ? peerMatches.first : null;
                          if (peer != null && peer.isOnline) {
                            return Positioned(
                              bottom: -2,
                              right: -2,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00E676),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: theme.scaffoldBackgroundColor, width: 2),
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                  ],
                ),
                const SizedBox(width: 16),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              conv.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: conv.hasUnread ? FontWeight.w800 : FontWeight.w600,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (conv.lastMessage != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: conv.hasUnread
                                    ? theme.colorScheme.primary.withValues(alpha: 0.15)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _formatTime(conv.lastMessage!.createdAt),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: conv.hasUnread ? theme.colorScheme.primary : chatExt.textSecondary,
                                  fontWeight: conv.hasUnread ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              conv.lastMessagePreview,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: conv.hasUnread ? theme.textTheme.bodyLarge?.color : chatExt.textSecondary,
                                fontWeight: conv.hasUnread ? FontWeight.w600 : FontWeight.w400,
                                fontSize: 13.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (conv.hasUnread)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${conv.unreadCount}',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, color: theme.dividerColor.withValues(alpha: 0.6), size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${time.day}/${time.month}';
  }
}
