import 'user.dart';

class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final String contentType; // text, code, json, file, image
  final String language;
  final bool isEdited;
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
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
      sender: json['sender'] != null ? UserModel.fromJson(json['sender']) : null,
      attachments: (json['attachments'] as List<dynamic>?)
              ?.map((a) => AttachmentModel.fromJson(a))
              .toList() ??
          [],
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
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

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

  String get fileSizeFormatted {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  bool get isImage => mimeType.startsWith('image/');
}
