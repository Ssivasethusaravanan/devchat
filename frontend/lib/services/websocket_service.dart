import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/constants.dart';

typedef WSMessageCallback = void Function(Map<String, dynamic> message);

class WebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  Timer? _pingTimer;

  String? _token;
  bool _isConnected = false;
  bool _shouldReconnect = true;
  int _reconnectAttempts = 0;

  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  bool get isConnected => _isConnected;

  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  /// Connect to the WebSocket server with the given JWT token.
  void connect(String token) {
    _token = token;
    _shouldReconnect = true;
    _reconnectAttempts = 0;
    _doConnect();
  }

  void _doConnect() {
    if (_token == null) return;

    try {
      final uri = Uri.parse('${AppConstants.wsUrl}?token=$_token');
      _channel = WebSocketChannel.connect(uri);

      _subscription = _channel!.stream.listen(
        (data) {
          _isConnected = true;
          _connectionController.add(true);
          _reconnectAttempts = 0;

          try {
            // Handle batched messages (separated by newlines)
            final messages = data.toString().split('\n');
            for (final msg in messages) {
              if (msg.trim().isEmpty) continue;
              final decoded = jsonDecode(msg) as Map<String, dynamic>;
              _messageController.add(decoded);
            }
          } catch (e) {
            // Ignore parse errors
          }
        },
        onError: (error) {
          _isConnected = false;
          _connectionController.add(false);
          _scheduleReconnect();
        },
        onDone: () {
          _isConnected = false;
          _connectionController.add(false);
          _scheduleReconnect();
        },
      );

      _isConnected = true;
      _connectionController.add(true);

      // Start ping timer to keep connection alive
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        sendRaw('{"type":"ping"}');
      });

    } catch (e) {
      _isConnected = false;
      _connectionController.add(false);
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect) return;

    _reconnectTimer?.cancel();
    _reconnectAttempts++;

    // Exponential backoff with jitter
    final delay = min(
      AppConstants.wsReconnectDelayMs * pow(2, _reconnectAttempts - 1).toInt(),
      AppConstants.wsMaxReconnectDelayMs,
    );
    final jitter = Random().nextInt(1000);

    _reconnectTimer = Timer(Duration(milliseconds: delay + jitter), () {
      _doConnect();
    });
  }

  /// Send a typed message over the WebSocket.
  void sendMessage({
    required String type,
    String? conversationId,
    Map<String, dynamic>? payload,
  }) {
    final message = {
      'type': type,
      if (conversationId != null) 'conversation_id': conversationId,
      if (payload != null) 'payload': payload,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };

    sendRaw(jsonEncode(message));
  }

  /// Send a chat message.
  void sendChatMessage({
    required String conversationId,
    required String content,
    required String contentType,
    String? language,
    String? replyToId,
    String? r2Key,
    String? fileName,
    int? fileSize,
    String? mimeType,
  }) {
    sendMessage(
      type: 'message',
      conversationId: conversationId,
      payload: {
        'content': content,
        'content_type': contentType,
        if (language != null) 'language': language,
        if (replyToId != null) 'reply_to_id': replyToId,
        if (r2Key != null) 'r2_key': r2Key,
        if (fileName != null) 'file_name': fileName,
        if (fileSize != null) 'file_size': fileSize,
        if (mimeType != null) 'mime_type': mimeType,
      },
    );
  }

  /// Send typing indicator.
  void sendTyping(String conversationId) {
    sendMessage(type: 'typing', conversationId: conversationId);
  }

  /// Send stop typing indicator.
  void sendStopTyping(String conversationId) {
    sendMessage(type: 'stop_typing', conversationId: conversationId);
  }

  /// Join a conversation room.
  void joinRoom(String conversationId) {
    sendMessage(type: 'join_room', conversationId: conversationId);
  }

  /// Send raw string data.
  void sendRaw(String data) {
    if (_channel != null && _isConnected) {
      try {
        _channel!.sink.add(data);
      } catch (_) {}
    }
  }

  /// Disconnect and clean up.
  void disconnect() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _isConnected = false;
    _connectionController.add(false);
  }

  /// Dispose all resources.
  void dispose() {
    disconnect();
    _messageController.close();
    _connectionController.close();
  }
}
