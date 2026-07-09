import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';
import '../models/conversation.dart';
import '../models/message.dart';

class LocalStorageService {
  static const String _conversationsBox = 'conversations_box';
  static const String _messagesBox = 'messages_box';
  
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox<String>(_conversationsBox);
    await Hive.openBox<String>(_messagesBox);
  }

  // --- Conversations ---

  List<ConversationModel> getCachedConversations() {
    final box = Hive.box<String>(_conversationsBox);
    final data = box.get('all_conversations');
    if (data != null) {
      try {
        final List<dynamic> decoded = jsonDecode(data);
        return decoded.map((c) => ConversationModel.fromJson(c)).toList();
      } catch (e) {
        return [];
      }
    }
    return [];
  }

  Future<void> saveConversations(List<ConversationModel> conversations) async {
    final box = Hive.box<String>(_conversationsBox);
    final encoded = jsonEncode(conversations.map((c) => c.toJson()).toList());
    await box.put('all_conversations', encoded);
  }

  // --- Messages ---

  List<MessageModel> getCachedMessages(String conversationId) {
    final box = Hive.box<String>(_messagesBox);
    final data = box.get(conversationId);
    if (data != null) {
      try {
        final List<dynamic> decoded = jsonDecode(data);
        return decoded.map((m) => MessageModel.fromJson(m)).toList();
      } catch (e) {
        return [];
      }
    }
    return [];
  }

  Future<void> saveMessages(String conversationId, List<MessageModel> messages) async {
    final box = Hive.box<String>(_messagesBox);
    final encoded = jsonEncode(messages.map((m) => m.toJson()).toList());
    await box.put(conversationId, encoded);
  }

  Future<void> clearAll() async {
    await Hive.box<String>(_conversationsBox).clear();
    await Hive.box<String>(_messagesBox).clear();
  }
}
