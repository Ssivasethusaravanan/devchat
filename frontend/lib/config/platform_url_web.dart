import 'dart:html' as html;

String getPlatformBaseUrl(String defaultValue) {
  final origin = html.window.location.origin;
  // If running locally on a port other than the Go backend port (8080),
  // e.g., 'flutter run -d chrome' running on localhost:XXXXX,
  // fall back to the default localhost:8080.
  if (origin.contains('localhost') && !origin.contains('8080')) {
    return defaultValue;
  }
  return origin;
}

String getPlatformWsUrl(String defaultValue) {
  final origin = html.window.location.origin;
  if (origin.contains('localhost') && !origin.contains('8080')) {
    return defaultValue;
  }
  final protocol = html.window.location.protocol == 'https:' ? 'wss:' : 'ws:';
  final host = html.window.location.host;
  return '$protocol//$host/ws';
}
