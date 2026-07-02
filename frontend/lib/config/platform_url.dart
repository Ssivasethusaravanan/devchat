import 'platform_url_stub.dart'
    if (dart.library.html) 'platform_url_web.dart';

String getDynamicBaseUrl(String defaultValue) {
  return getPlatformBaseUrl(defaultValue);
}

String getDynamicWsUrl(String defaultValue) {
  return getPlatformWsUrl(defaultValue);
}
