import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _searchController = TextEditingController();
  final List<UserModel> _selectedMembers = [];
  List<UserModel> _searchResults = [];
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Group'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.go('/'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Group Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Group Name',
                prefixIcon: Icon(Icons.group),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                prefixIcon: Icon(Icons.description_outlined),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            // Add Members
            Text('Add Members', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),

            // Selected members chips
            if (_selectedMembers.isNotEmpty)
              Wrap(
                spacing: 8, runSpacing: 8,
                children: _selectedMembers.map((user) => Chip(
                  avatar: CircleAvatar(
                    backgroundColor: theme.colorScheme.primary,
                    child: Text(user.initials, style: const TextStyle(color: Colors.white, fontSize: 10)),
                  ),
                  label: Text(user.username),
                  onDeleted: () => setState(() => _selectedMembers.remove(user)),
                )).toList(),
              ),
            const SizedBox(height: 12),

            // Search users
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search users to add...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (query) async {
                if (query.length >= 1) {
                  final response = await ApiService().searchUsers(query);
                  if (response['success'] == true) {
                    final data = response['data'] as List<dynamic>? ?? [];
                    setState(() {
                      _searchResults = data
                          .map((u) => UserModel.fromJson(u))
                          .where((u) => !_selectedMembers.any((m) => m.id == u.id))
                          .toList();
                    });
                  }
                } else {
                  setState(() => _searchResults = []);
                }
              },
            ),

            // Search results
            if (_searchResults.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 8),
                constraints: const BoxConstraints(maxHeight: 200),
                child: Card(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _searchResults.length,
                    itemBuilder: (_, i) {
                      final user = _searchResults[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: theme.colorScheme.primary,
                          child: Text(user.initials, style: const TextStyle(color: Colors.white)),
                        ),
                        title: Text(user.username),
                        subtitle: Text(user.email),
                        onTap: () {
                          setState(() {
                            _selectedMembers.add(user);
                            _searchResults.remove(user);
                            _searchController.clear();
                          });
                        },
                      );
                    },
                  ),
                ),
              ),

            const SizedBox(height: 32),

            // Create button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isCreating ? null : _createGroup,
                icon: _isCreating
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.group_add),
                label: Text(_isCreating ? 'Creating...' : 'Create Group'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group name')),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final response = await ApiService().createGroup(
        name,
        _descController.text.trim(),
        _selectedMembers.map((u) => u.username).toList(),
      );

      if (response['success'] == true && response['data'] != null && mounted) {
        final groupId = response['data']['id'];
        context.go('/chat/$groupId?name=${Uri.encodeComponent(name)}&type=group');
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['error'] ?? 'Failed to create group')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create group')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }
}
