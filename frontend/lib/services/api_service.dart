import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/constants.dart';

class ApiService {
  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.apiUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: AppConstants.tokenKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        handler.next(error);
      },
    ));
  }

  // ===== Auth =====

  Future<Map<String, dynamic>> register(String username, String email, String password) async {
    final response = await _dio.post('/auth/register', data: {
      'username': username,
      'email': email,
      'password': password,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await _dio.post('/auth/login', data: {
      'username': username,
      'password': password,
    });

    if (response.data['success'] == true && response.data['data'] != null) {
      final token = response.data['data']['token'];
      await _storage.write(key: AppConstants.tokenKey, value: token);
    }

    return response.data;
  }

  Future<Map<String, dynamic>> verifyEmail(String email, String code) async {
    final response = await _dio.post('/auth/verify-email', data: {
      'email': email,
      'code': code,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> resendVerification(String email) async {
    final response = await _dio.post('/auth/resend-verification', data: {
      'email': email,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> getMe() async {
    final response = await _dio.get('/auth/me');
    return response.data;
  }

  Future<void> logout() async {
    await _storage.delete(key: AppConstants.tokenKey);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: AppConstants.tokenKey);
  }

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    final response = await _dio.post('/auth/forgot-password', data: {
      'email': email,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> resetPassword(String email, String code, String newPassword) async {
    final response = await _dio.post('/auth/reset-password', data: {
      'email': email,
      'code': code,
      'new_password': newPassword,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> changePassword(String currentPassword, String newPassword) async {
    final response = await _dio.put('/auth/change-password', data: {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> updateProfile({String? username, String? avatarUrl}) async {
    final response = await _dio.put('/auth/profile', data: {
      if (username != null && username.isNotEmpty) 'username': username,
      if (avatarUrl != null && avatarUrl.isNotEmpty) 'avatar_url': avatarUrl,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> deleteAccount(String password) async {
    final response = await _dio.delete('/auth/account', data: {
      'password': password,
    });
    await _storage.delete(key: AppConstants.tokenKey);
    return response.data;
  }

  // ===== Users =====

  Future<Map<String, dynamic>> searchUsers(String query) async {
    final response = await _dio.get('/users/search', queryParameters: {'q': query});
    return response.data;
  }

  Future<Map<String, dynamic>> getUser(String userId) async {
    final response = await _dio.get('/users/$userId');
    return response.data;
  }

  Future<Map<String, dynamic>> getOnlineUsers() async {
    final response = await _dio.get('/users/online');
    return response.data;
  }

  // ===== Conversations =====

  Future<Map<String, dynamic>> getConversations() async {
    final response = await _dio.get('/conversations');
    return response.data;
  }

  Future<Map<String, dynamic>> getOrCreateDM(String userId) async {
    final response = await _dio.post('/conversations/dm/$userId');
    return response.data;
  }

  Future<Map<String, dynamic>> getMessages(String conversationId, {int page = 1, int limit = 50}) async {
    final response = await _dio.get(
      '/conversations/$conversationId/messages',
      queryParameters: {'page': page, 'limit': limit},
    );
    return response.data;
  }

  Future<Map<String, dynamic>> editMessage(String messageId, String content) async {
    final response = await _dio.put('/messages/$messageId', data: {'content': content});
    return response.data;
  }

  Future<Map<String, dynamic>> deleteMessage(String messageId) async {
    final response = await _dio.delete('/messages/$messageId');
    return response.data;
  }

  Future<Map<String, dynamic>> toggleReaction(String messageId, String emoji) async {
    final response = await _dio.post('/messages/$messageId/reactions', data: {'emoji': emoji});
    return response.data;
  }

  // ===== Groups =====

  Future<Map<String, dynamic>> createGroup(String name, String description, List<String> members) async {
    final response = await _dio.post('/groups', data: {
      'name': name,
      'description': description,
      'members': members,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> getGroup(String groupId) async {
    final response = await _dio.get('/groups/$groupId');
    return response.data;
  }

  Future<Map<String, dynamic>> updateGroup(String groupId, {String? name, String? description}) async {
    final response = await _dio.put('/groups/$groupId', data: {
      if (name != null) 'name': name,
      if (description != null) 'description': description,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> addGroupMember(String groupId, String username) async {
    final response = await _dio.post('/groups/$groupId/members', data: {
      'username': username,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> removeGroupMember(String groupId, String userId) async {
    final response = await _dio.delete('/groups/$groupId/members/$userId');
    return response.data;
  }

  // ===== File Upload =====

  Future<Map<String, dynamic>> getPresignedUploadUrl(String fileName, String contentType, int fileSize) async {
    final response = await _dio.post('/upload/presign', data: {
      'file_name': fileName,
      'content_type': contentType,
      'file_size': fileSize,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> getPresignedDownloadUrl(String key) async {
    final response = await _dio.get('/upload/download/$key');
    return response.data;
  }

  Future<void> uploadFileToR2(String presignedUrl, List<int> fileBytes, String contentType) async {
    final uploadDio = Dio();
    await uploadDio.put(
      presignedUrl,
      data: Stream.fromIterable([fileBytes]),
      options: Options(
        headers: {
          'Content-Type': contentType,
          'Content-Length': fileBytes.length,
        },
      ),
    );
  }

  Future<Map<String, dynamic>> uploadDirectFile(String fileName, List<int> fileBytes, String contentType) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(fileBytes, filename: fileName),
    });
    final response = await _dio.post('/upload/direct', data: formData);
    return response.data;
  }
}
