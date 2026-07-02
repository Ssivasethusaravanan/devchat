import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../bloc/chat/chat_bloc.dart';
import '../../models/conversation.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';

class GroupDetailsScreen extends StatefulWidget {
  final String groupId;
  const GroupDetailsScreen({super.key, required this.groupId});

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  ConversationModel? _group;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGroup();
  }

  Future<void> _loadGroup() async {
    try {
      final response = await ApiService().getGroup(widget.groupId);
      if (response['success'] == true && response['data'] != null) {
        setState(() {
          _group = ConversationModel.fromJson(response['data']);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          context.read<ChatBloc>().add(ChatLoadConversations());
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Group Details'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded),
            onPressed: () {
              context.read<ChatBloc>().add(ChatLoadConversations());
              context.pop();
            },
          ),
        ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _group == null
              ? const Center(child: Text('Group not found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Group avatar
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [theme.colorScheme.secondary, theme.colorScheme.primary],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withValues(alpha: 0.3),
                              blurRadius: 16, offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.group, color: Colors.white, size: 40),
                      ),
                      const SizedBox(height: 16),
                      Text(_group!.name, style: theme.textTheme.headlineMedium),
                      if (_group!.description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(_group!.description, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
                      ],
                      const SizedBox(height: 24),

                      // Members
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Members (${_group!.members.length})', style: theme.textTheme.titleMedium),
                          IconButton(
                            icon: const Icon(Icons.person_add_alt_1),
                            onPressed: () => _showAddMemberDialog(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      ...(_group!.members.map((member) => Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: theme.colorScheme.primary,
                            child: Text(member.initials, style: const TextStyle(color: Colors.white)),
                          ),
                          title: Text(member.username),
                          subtitle: Text(member.email),
                          trailing: member.isOnline
                              ? Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle))
                              : null,
                        ),
                      ))),
                    ],
                  ),
                ),
      ),
    );
  }

  void _showAddMemberDialog(BuildContext context) {
    final searchController = TextEditingController();
    List<UserModel> results = [];

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: const Text('Add Member'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: searchController,
                  decoration: const InputDecoration(hintText: 'Search by username...', prefixIcon: Icon(Icons.search)),
                  onChanged: (q) async {
                    if (q.isNotEmpty) {
                      final resp = await ApiService().searchUsers(q);
                      if (resp['success'] == true) {
                        setDialogState(() {
                          results = (resp['data'] as List)
                              .map((u) => UserModel.fromJson(u))
                              .where((u) => !_group!.members.any((m) => m.id == u.id))
                              .toList();
                        });
                      }
                    }
                  },
                ),
                if (results.isNotEmpty)
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: results.length,
                      itemBuilder: (_, i) => ListTile(
                        title: Text(results[i].username),
                        onTap: () async {
                          final resp = await ApiService().addGroupMember(widget.groupId, results[i].username);
                          if (dialogContext.mounted && resp['success'] == true) {
                            Navigator.pop(dialogContext);
                            _loadGroup();
                          }
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel'))],
        ),
      ),
    );
  }
}
