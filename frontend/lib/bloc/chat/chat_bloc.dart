import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../models/conversation.dart';
import '../../models/message.dart';
import '../../services/api_service.dart';
import '../../services/websocket_service.dart';

// ===== Events =====
abstract class ChatEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class ChatLoadConversations extends ChatEvent {}

class ChatStartDM extends ChatEvent {
  final String userId;
  ChatStartDM({required this.userId});
  @override
  List<Object?> get props => [userId];
}

class ChatLoadMessages extends ChatEvent {
  final String conversationId;
  final int page;
  ChatLoadMessages({required this.conversationId, this.page = 1});
  @override
  List<Object?> get props => [conversationId, page];
}

class ChatSendMessage extends ChatEvent {
  final String conversationId;
  final String content;
  final String contentType;
  final String? language;
  final String? replyToId;
  final String? r2Key;
  final String? fileName;
  final int? fileSize;
  final String? mimeType;
  ChatSendMessage({
    required this.conversationId,
    required this.content,
    this.contentType = 'text',
    this.language,
    this.replyToId,
    this.r2Key,
    this.fileName,
    this.fileSize,
    this.mimeType,
  });
  @override
  List<Object?> get props => [conversationId, content, contentType, replyToId];
}

class ChatEditMessage extends ChatEvent {
  final String messageId;
  final String content;
  ChatEditMessage({required this.messageId, required this.content});
  @override
  List<Object?> get props => [messageId, content];
}

class ChatDeleteMessage extends ChatEvent {
  final String messageId;
  ChatDeleteMessage({required this.messageId});
  @override
  List<Object?> get props => [messageId];
}

class ChatToggleReaction extends ChatEvent {
  final String messageId;
  final String emoji;
  ChatToggleReaction({required this.messageId, required this.emoji});
  @override
  List<Object?> get props => [messageId, emoji];
}

class ChatMessageReceived extends ChatEvent {
  final MessageModel message;
  ChatMessageReceived({required this.message});
  @override
  List<Object?> get props => [message];
}

class ChatMessageEditedReceived extends ChatEvent {
  final MessageModel message;
  ChatMessageEditedReceived({required this.message});
  @override
  List<Object?> get props => [message];
}

class ChatMessageDeletedReceived extends ChatEvent {
  final String messageId;
  final String conversationId;
  ChatMessageDeletedReceived({required this.messageId, required this.conversationId});
  @override
  List<Object?> get props => [messageId, conversationId];
}

class ChatMessageReactionReceived extends ChatEvent {
  final String messageId;
  final String conversationId;
  final List<ReactionModel> reactions;
  ChatMessageReactionReceived({required this.messageId, required this.conversationId, required this.reactions});
  @override
  List<Object?> get props => [messageId, conversationId, reactions];
}

class ChatTypingReceived extends ChatEvent {
  final String conversationId;
  final String username;
  final bool isTyping;
  ChatTypingReceived({required this.conversationId, required this.username, required this.isTyping});
  @override
  List<Object?> get props => [conversationId, username, isTyping];
}

class ChatSendTyping extends ChatEvent {
  final String conversationId;
  final bool isTyping;
  ChatSendTyping({required this.conversationId, required this.isTyping});
  @override
  List<Object?> get props => [conversationId, isTyping];
}

// ===== States =====
abstract class ChatState extends Equatable {
  @override
  List<Object?> get props => [];
}

class ChatInitial extends ChatState {}

class ChatLoading extends ChatState {}

class ChatConversationsLoaded extends ChatState {
  final List<ConversationModel> conversations;
  ChatConversationsLoaded({required this.conversations});
  @override
  List<Object?> get props => [conversations];
}

class ChatMessagesLoaded extends ChatState {
  final String conversationId;
  final List<MessageModel> messages;
  final bool hasMore;
  final int page;
  final Map<String, String> typingUsers; // conversationId -> username
  ChatMessagesLoaded({
    required this.conversationId,
    required this.messages,
    this.hasMore = true,
    this.page = 1,
    this.typingUsers = const {},
  });
  @override
  List<Object?> get props => [conversationId, messages, hasMore, page, typingUsers];

  ChatMessagesLoaded copyWith({
    List<MessageModel>? messages,
    bool? hasMore,
    int? page,
    Map<String, String>? typingUsers,
  }) {
    return ChatMessagesLoaded(
      conversationId: conversationId,
      messages: messages ?? this.messages,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      typingUsers: typingUsers ?? this.typingUsers,
    );
  }
}

class ChatDMCreated extends ChatState {
  final ConversationModel conversation;
  ChatDMCreated({required this.conversation});
  @override
  List<Object?> get props => [conversation];
}

class ChatError extends ChatState {
  final String message;
  ChatError({required this.message});
  @override
  List<Object?> get props => [message];
}

// ===== Bloc =====
class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ApiService _apiService = ApiService();
  final WebSocketService _wsService = WebSocketService();
  StreamSubscription? _wsSubscription;

  // Cache conversations for quick updates
  List<ConversationModel> _conversations = [];
  List<ConversationModel> get cachedConversations => _conversations;

  ChatBloc() : super(ChatInitial()) {
    on<ChatLoadConversations>(_onLoadConversations);
    on<ChatStartDM>(_onStartDM);
    on<ChatLoadMessages>(_onLoadMessages);
    on<ChatSendMessage>(_onSendMessage);
    on<ChatEditMessage>(_onEditMessage);
    on<ChatDeleteMessage>(_onDeleteMessage);
    on<ChatToggleReaction>(_onToggleReaction);
    on<ChatMessageReceived>(_onMessageReceived);
    on<ChatMessageEditedReceived>(_onMessageEditedReceived);
    on<ChatMessageDeletedReceived>(_onMessageDeletedReceived);
    on<ChatMessageReactionReceived>(_onMessageReactionReceived);
    on<ChatTypingReceived>(_onTypingReceived);
    on<ChatSendTyping>(_onSendTyping);

    // Listen to WebSocket messages
    _wsSubscription = _wsService.messageStream.listen((data) {
      final type = data['type'] as String?;
      if (type == 'message' && data['payload'] != null) {
        final payload = data['payload'] as Map<String, dynamic>;
        if (payload['message'] != null) {
          final msg = MessageModel.fromJson(payload['message']);
          add(ChatMessageReceived(message: msg));
        }
      } else if (type == 'message_edited' && data['payload'] != null) {
        final payload = data['payload'] as Map<String, dynamic>;
        if (payload['message'] != null) {
          final msg = MessageModel.fromJson(payload['message']);
          add(ChatMessageEditedReceived(message: msg));
        }
      } else if (type == 'message_deleted' && data['payload'] != null) {
        final payload = data['payload'] as Map<String, dynamic>;
        add(ChatMessageDeletedReceived(
          messageId: payload['message_id'] ?? '',
          conversationId: payload['conversation_id'] ?? '',
        ));
      } else if (type == 'message_reaction' && data['payload'] != null) {
        final payload = data['payload'] as Map<String, dynamic>;
        final list = (payload['reactions'] as List<dynamic>? ?? [])
            .map((r) => ReactionModel.fromJson(r))
            .toList();
        add(ChatMessageReactionReceived(
          messageId: payload['message_id'] ?? '',
          conversationId: payload['conversation_id'] ?? '',
          reactions: list,
        ));
      } else if (type == 'typing' && data['payload'] != null) {
        final payload = data['payload'] as Map<String, dynamic>;
        add(ChatTypingReceived(
          conversationId: data['conversation_id'] ?? '',
          username: payload['username'] ?? '',
          isTyping: true,
        ));
      } else if (type == 'stop_typing' && data['payload'] != null) {
        final payload = data['payload'] as Map<String, dynamic>;
        add(ChatTypingReceived(
          conversationId: data['conversation_id'] ?? '',
          username: payload['username'] ?? '',
          isTyping: false,
        ));
      }
    });
  }

  Future<void> _onLoadConversations(ChatLoadConversations event, Emitter<ChatState> emit) async {
    if (_conversations.isEmpty) {
      emit(ChatLoading());
    } else {
      emit(ChatConversationsLoaded(conversations: _conversations));
    }
    try {
      final response = await _apiService.getConversations();
      if (response['success'] == true) {
        final data = response['data'] as List<dynamic>? ?? [];
        _conversations = data.map((c) => ConversationModel.fromJson(c)).toList();
        emit(ChatConversationsLoaded(conversations: _conversations));
      } else if (_conversations.isEmpty) {
        emit(ChatError(message: response['error'] ?? 'Failed to load conversations'));
      }
    } catch (e) {
      if (_conversations.isEmpty) {
        emit(ChatError(message: 'Failed to load conversations'));
      }
    }
  }

  Future<void> _onStartDM(ChatStartDM event, Emitter<ChatState> emit) async {
    emit(ChatLoading());
    try {
      final response = await _apiService.getOrCreateDM(event.userId);
      if (response['success'] == true && response['data'] != null) {
        final conv = ConversationModel.fromJson(response['data']);
        _wsService.joinRoom(conv.id);
        emit(ChatDMCreated(conversation: conv));
      } else {
        emit(ChatError(message: response['error'] ?? 'Failed to start conversation'));
      }
    } catch (e) {
      emit(ChatError(message: 'Failed to start conversation'));
    }
  }

  Future<void> _onLoadMessages(ChatLoadMessages event, Emitter<ChatState> emit) async {
    _wsService.joinRoom(event.conversationId);
    try {
      final response = await _apiService.getMessages(event.conversationId, page: event.page);
      if (response['success'] == true && response['data'] != null) {
        final data = response['data'];
        final messages = (data['messages'] as List<dynamic>? ?? [])
            .map((m) => MessageModel.fromJson(m))
            .toList();
        final hasMore = data['has_more'] ?? false;

        // If loading more pages, append to existing
        List<MessageModel> allMessages = messages;
        if (event.page > 1 && state is ChatMessagesLoaded) {
          final currentState = state as ChatMessagesLoaded;
          if (currentState.conversationId == event.conversationId) {
            allMessages = [...messages, ...currentState.messages];
          }
        }

        emit(ChatMessagesLoaded(
          conversationId: event.conversationId,
          messages: allMessages,
          hasMore: hasMore,
          page: event.page,
        ));
      } else {
        emit(ChatError(message: response['error'] ?? 'Failed to load messages'));
      }
    } catch (e) {
      emit(ChatError(message: 'Failed to load messages'));
    }
  }

  void _onSendMessage(ChatSendMessage event, Emitter<ChatState> emit) {
    _wsService.joinRoom(event.conversationId);
    _wsService.sendChatMessage(
      conversationId: event.conversationId,
      content: event.content,
      contentType: event.contentType,
      language: event.language,
      replyToId: event.replyToId,
      r2Key: event.r2Key,
      fileName: event.fileName,
      fileSize: event.fileSize,
      mimeType: event.mimeType,
    );
  }

  Future<void> _onEditMessage(ChatEditMessage event, Emitter<ChatState> emit) async {
    try {
      await _apiService.editMessage(event.messageId, event.content);
    } catch (e) {
      // API error handled silently or via state if needed
    }
  }

  Future<void> _onDeleteMessage(ChatDeleteMessage event, Emitter<ChatState> emit) async {
    try {
      await _apiService.deleteMessage(event.messageId);
    } catch (e) {
      // API error handled silently
    }
  }

  Future<void> _onToggleReaction(ChatToggleReaction event, Emitter<ChatState> emit) async {
    try {
      await _apiService.toggleReaction(event.messageId, event.emoji);
    } catch (e) {
      // API error handled silently
    }
  }

  void _onMessageReceived(ChatMessageReceived event, Emitter<ChatState> emit) {
    if (state is ChatMessagesLoaded) {
      final currentState = state as ChatMessagesLoaded;
      if (currentState.conversationId == event.message.conversationId) {
        emit(currentState.copyWith(
          messages: [...currentState.messages, event.message],
        ));
      }
    }

    // Update conversation list cache
    final idx = _conversations.indexWhere((c) => c.id == event.message.conversationId);
    if (idx >= 0) {
      _conversations[idx] = _conversations[idx].copyWith(
        lastMessage: event.message,
        unreadCount: _conversations[idx].unreadCount + 1,
      );
    }
  }

  void _onMessageEditedReceived(ChatMessageEditedReceived event, Emitter<ChatState> emit) {
    if (state is ChatMessagesLoaded) {
      final currentState = state as ChatMessagesLoaded;
      if (currentState.conversationId == event.message.conversationId) {
        final updated = currentState.messages.map((m) {
          return m.id == event.message.id ? event.message : m;
        }).toList();
        emit(currentState.copyWith(messages: updated));
      }
    }
  }

  void _onMessageDeletedReceived(ChatMessageDeletedReceived event, Emitter<ChatState> emit) {
    if (state is ChatMessagesLoaded) {
      final currentState = state as ChatMessagesLoaded;
      if (currentState.conversationId == event.conversationId) {
        final updated = currentState.messages.where((m) => m.id != event.messageId).toList();
        emit(currentState.copyWith(messages: updated));
      }
    }
  }

  void _onMessageReactionReceived(ChatMessageReactionReceived event, Emitter<ChatState> emit) {
    if (state is ChatMessagesLoaded) {
      final currentState = state as ChatMessagesLoaded;
      if (currentState.conversationId == event.conversationId) {
        final updated = currentState.messages.map((m) {
          if (m.id == event.messageId) {
            return m.copyWith(reactions: event.reactions);
          }
          return m;
        }).toList();
        emit(currentState.copyWith(messages: updated));
      }
    }
  }

  void _onTypingReceived(ChatTypingReceived event, Emitter<ChatState> emit) {
    if (state is ChatMessagesLoaded) {
      final currentState = state as ChatMessagesLoaded;
      final typingUsers = Map<String, String>.from(currentState.typingUsers);
      if (event.isTyping) {
        typingUsers[event.conversationId] = event.username;
      } else {
        typingUsers.remove(event.conversationId);
      }
      emit(currentState.copyWith(typingUsers: typingUsers));
    }
  }

  void _onSendTyping(ChatSendTyping event, Emitter<ChatState> emit) {
    if (event.isTyping) {
      _wsService.sendTyping(event.conversationId);
    } else {
      _wsService.sendStopTyping(event.conversationId);
    }
  }

  @override
  Future<void> close() {
    _wsSubscription?.cancel();
    return super.close();
  }
}
