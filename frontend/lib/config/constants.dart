import 'platform_url.dart';

class AppConstants {
  AppConstants._();

  // API Configuration
  static final String baseUrl = getDynamicBaseUrl(
    const String.fromEnvironment('API_URL', defaultValue: 'http://localhost:8080'),
  );
  static final String apiUrl = '$baseUrl/api';
  static final String wsUrl = getDynamicWsUrl(
    const String.fromEnvironment('WS_URL', defaultValue: 'ws://localhost:8080/ws'),
  );

  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String userKey = 'current_user';
  static const String themeKey = 'theme_mode';

  // Pagination
  static const int defaultPageSize = 50;

  // WebSocket
  static const int wsReconnectDelayMs = 1000;
  static const int wsMaxReconnectDelayMs = 30000;

  // File Upload
  static const int maxFileSizeMB = 50;
  static const List<String> supportedCodeLanguages = [
    'dart',
    'python',
    'javascript',
    'typescript',
    'java',
    'kotlin',
    'swift',
    'go',
    'rust',
    'c',
    'cpp',
    'csharp',
    'php',
    'ruby',
    'html',
    'css',
    'sql',
    'json',
    'yaml',
    'xml',
    'bash',
    'shell',
    'dockerfile',
    'markdown',
  ];
}
