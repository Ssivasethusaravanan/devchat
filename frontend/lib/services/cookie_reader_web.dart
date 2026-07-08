import 'dart:html' as html;
import 'package:dio/dio.dart';
import 'package:dio/browser.dart';

/// Web implementation: reads CSRF token from browser cookies.
/// The csrf_token cookie is NOT HttpOnly, so JavaScript can read it.
String? getPlatformCsrfToken() {
  try {
    final cookies = html.document.cookie ?? '';
    for (final cookie in cookies.split(';')) {
      final parts = cookie.trim().split('=');
      if (parts.length == 2 && parts[0].trim() == 'csrf_token') {
        return parts[1].trim();
      }
    }
  } catch (_) {}
  return null;
}

/// Web implementation: configures Dio to send cookies with requests.
/// This sets withCredentials=true so the browser includes HttpOnly cookies.
void platformConfigureDioForWeb(dynamic dio) {
  if (dio is Dio) {
    (dio.httpClientAdapter as BrowserHttpClientAdapter).withCredentials = true;
  }
}
