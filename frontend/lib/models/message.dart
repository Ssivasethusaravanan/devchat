import 'user.dart';

class ReplySnippetModel {
  final String id;
  final String senderId;
  final String username;
  final String content;
  final String contentType;

  const ReplySnippetModel({
    required this.id,
    required this.senderId,
    required this.username,
    required this.content,
    required this.contentType,
  });

  factory ReplySnippetModel.fromJson(Map<String, dynamic> json) {
    return ReplySnippetModel(
      id: json['id'] ?? '',
      senderId: json['sender_id'] ?? '',
      username: json['username'] ?? '',
      content: json['content'] ?? '',
      contentType: json['content_type'] ?? 'text',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sender_id': senderId,
        'username': username,
        'content': content,
        'content_type': contentType,
      };
}

class ReactionModel {
  final String id;
  final String messageId;
  final String userId;
  final String username;
  final String emoji;

  const ReactionModel({
    required this.id,
    required this.messageId,
    required this.userId,
    required this.username,
    required this.emoji,
  });

  factory ReactionModel.fromJson(Map<String, dynamic> json) {
    return ReactionModel(
      id: json['id'] ?? '',
      messageId: json['message_id'] ?? '',
      userId: json['user_id'] ?? '',
      username: json['username'] ?? '',
      emoji: json['emoji'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'message_id': messageId,
        'user_id': userId,
        'username': username,
        'emoji': emoji,
      };
}

class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final String contentType; // text, code, json, file, image
  final String language;
  final bool isEdited;
  final String status; // sent, delivered, read
  final String? replyToId;
  final ReplySnippetModel? replyTo;
  final List<ReactionModel> reactions;
  final DateTime createdAt;
  final DateTime updatedAt;
  final UserModel? sender;
  final List<AttachmentModel> attachments;

  const MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    this.contentType = 'text',
    this.language = '',
    this.isEdited = false,
    this.status = 'sent',
    this.replyToId,
    this.replyTo,
    this.reactions = const [],
    required this.createdAt,
    required this.updatedAt,
    this.sender,
    this.attachments = const [],
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] ?? '',
      conversationId: json['conversation_id'] ?? '',
      senderId: json['sender_id'] ?? '',
      content: json['content'] ?? '',
      contentType: json['content_type'] ?? 'text',
      language: json['language'] ?? '',
      isEdited: json['is_edited'] ?? false,
      status: json['status'] ?? 'sent',
      replyToId: json['reply_to_id'],
      replyTo: json['reply_to'] != null ? ReplySnippetModel.fromJson(json['reply_to']) : null,
      reactions: (json['reactions'] as List<dynamic>?)
              ?.map((r) => ReactionModel.fromJson(r))
              .toList() ??
          [],
      createdAt: DateTime.tryParse(json['created_at'] ?? '')?.toLocal() ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '')?.toLocal() ?? DateTime.now(),
      sender: json['sender'] != null ? UserModel.fromJson(json['sender']) : null,
      attachments: (json['attachments'] as List<dynamic>?)
              ?.map((a) => AttachmentModel.fromJson(a))
              .toList() ??
          [],
    );
  }

  MessageModel copyWith({
    String? content,
    bool? isEdited,
    String? status,
    List<ReactionModel>? reactions,
  }) {
    return MessageModel(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      content: content ?? this.content,
      contentType: contentType,
      language: language,
      isEdited: isEdited ?? this.isEdited,
      status: status ?? this.status,
      replyToId: replyToId,
      replyTo: replyTo,
      reactions: reactions ?? this.reactions,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      sender: sender,
      attachments: attachments,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'conversation_id': conversationId,
        'sender_id': senderId,
        'content': content,
        'content_type': contentType,
        'language': language,
        'is_edited': isEdited,
        'status': status,
        'reply_to_id': replyToId,
        'reply_to': replyTo?.toJson(),
        'reactions': reactions.map((r) => r.toJson()).toList(),
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'sender': sender?.toJson(),
        'attachments': attachments.map((a) => a.toJson()).toList(),
      };

  bool get isSent => status == 'sent';
  bool get isDelivered => status == 'delivered' || status == 'read';
  bool get isRead => status == 'read';
  bool get isCode => contentType == 'code';
  bool get isJson => contentType == 'json';
  bool get isFile => contentType == 'file';
  bool get isImage => contentType == 'image';
  bool get isText => contentType == 'text';
  bool get hasAttachments => attachments.isNotEmpty;
}

class AttachmentModel {
  final String id;
  final String messageId;
  final String fileName;
  final int fileSize;
  final String mimeType;
  final String r2Key;
  final DateTime createdAt;

  const AttachmentModel({
    required this.id,
    required this.messageId,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
    required this.r2Key,
    required this.createdAt,
  });

  factory AttachmentModel.fromJson(Map<String, dynamic> json) {
    return AttachmentModel(
      id: json['id'] ?? '',
      messageId: json['message_id'] ?? '',
      fileName: json['file_name'] ?? '',
      fileSize: json['file_size'] ?? 0,
      mimeType: json['mime_type'] ?? '',
      r2Key: json['r2_key'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'message_id': messageId,
        'file_name': fileName,
        'file_size': fileSize,
        'mime_type': mimeType,
        'r2_key': r2Key,
        'created_at': createdAt.toUtc().toIso8601String(),
      };

  String get fileSizeFormatted {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  bool get isImage => mimeType.startsWith('image/');
}
