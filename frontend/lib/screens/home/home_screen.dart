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
      body: BlocBuilder<ChatBloc, ChatState>(
        builder: (context, state) {
          if (state is ChatLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is ChatConversationsLoaded) {
            if (state.conversations.isEmpty) {
              return _buildEmptyState(theme);
            }
            return _buildConversationList(state.conversations, theme, chatExt);
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
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // New DM
          FloatingActionButton.small(
            heroTag: 'new_dm',
            onPressed: () => _showNewDMDialog(context),
            child: const Icon(Icons.person_add_alt_1),
          ),
          const SizedBox(height: 12),
          // New Group
          FloatingActionButton(
            heroTag: 'new_group',
            onPressed: () => context.go('/create-group'),
            child: const Icon(Icons.group_add),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoading(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: theme.brightness == Brightness.dark ? const Color(0xFF1C2333) : const Color(0xFFE8ECF2),
          highlightColor: theme.brightness == Brightness.dark ? const Color(0xFF2C3548) : const Color(0xFFF7F8FC),
          child: Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(width: 52, height: 52, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(width: 140, height: 16, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
                        const SizedBox(height: 8),
                        Container(width: double.infinity, height: 12, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [theme.colorScheme.primary.withValues(alpha: 0.2), theme.colorScheme.secondary.withValues(alpha: 0.1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(Icons.chat_bubble_outline_rounded, size: 54, color: theme.colorScheme.primary),
            ),
          ),
          const SizedBox(height: 24),
          Text('No conversations yet', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text(
            'Tap + below to start a DM or create a new group',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodySmall?.color),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildConversationList(List<ConversationModel> conversations, ThemeData theme, ChatThemeExtension chatExt) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<ChatBloc>().add(ChatLoadConversations());
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: conversations.length,
        itemBuilder: (context, index) {
          final conv = conversations[index];
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

class _ConversationTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Avatar with 3D shadow
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: conversation.isGroup
                        ? [theme.colorScheme.secondary, theme.colorScheme.primary]
                        : [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: conversation.isGroup
                      ? const Icon(Icons.group, color: Colors.white, size: 24)
                      : Text(
                          conversation.initials,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
                        ),
                ),
              ),
              const SizedBox(width: 14),

              // Name & last message
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: conversation.hasUnread ? FontWeight.w800 : FontWeight.w600,
                            ),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (conversation.lastMessage != null)
                          Text(
                            _formatTime(conversation.lastMessage!.createdAt),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: conversation.hasUnread ? theme.colorScheme.primary : chatExt.textSecondary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.lastMessagePreview,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: conversation.hasUnread ? FontWeight.w600 : FontWeight.w400,
                            ),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (conversation.hasUnread)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${conversation.unreadCount}',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
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
