import 'message.dart';
import 'user.dart';

class ConversationModel {
  final String id;
  final String type; // 'direct' or 'group'
  final String name;
  final String description;
  final String avatarUrl;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<UserModel> members;
  final MessageModel? lastMessage;
  final int unreadCount;

  const ConversationModel({
    required this.id,
    required this.type,
    required this.name,
    this.description = '',
    this.avatarUrl = '',
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.members = const [],
    this.lastMessage,
    this.unreadCount = 0,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id'] ?? '',
      type: json['type'] ?? 'direct',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      avatarUrl: json['avatar_url'] ?? '',
      createdBy: json['created_by'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
      members: (json['members'] as List<dynamic>?)
              ?.map((m) => UserModel.fromJson(m))
              .toList() ??
          [],
      lastMessage: json['last_message'] != null
          ? MessageModel.fromJson(json['last_message'])
          : null,
      unreadCount: json['unread_count'] ?? 0,
    );
  }

  bool get isDirect => type == 'direct';
  bool get isGroup => type == 'group';
  bool get hasUnread => unreadCount > 0;

  String get lastMessagePreview {
    if (lastMessage == null) return 'No messages yet';
    switch (lastMessage!.contentType) {
      case 'code':
        return '📝 Code snippet';
      case 'json':
        return '📋 JSON data';
      case 'file':
        return '📎 File attachment';
      case 'image':
        return '🖼️ Image';
      default:
        final content = lastMessage!.content;
        return content.length > 60 ? '${content.substring(0, 60)}...' : content;
    }
  }

  String get initials {
    if (name.isEmpty) return '?';
    final parts = name.split(RegExp(r'[\s._-]'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  ConversationModel copyWith({
    MessageModel? lastMessage,
    int? unreadCount,
    List<UserModel>? members,
  }) {
    return ConversationModel(
      id: id,
      type: type,
      name: name,
      description: description,
      avatarUrl: avatarUrl,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      members: members ?? this.members,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}
