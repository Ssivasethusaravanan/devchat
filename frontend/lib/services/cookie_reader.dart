import 'cookie_reader_stub.dart'
    if (dart.library.html) 'cookie_reader_web.dart';

/// Read the CSRF token from the browser cookie.
/// On non-web platforms, this always returns null.
String? getCsrfTokenFromCookie() => getPlatformCsrfToken();

/// Configure Dio for web (withCredentials).
/// On non-web platforms, this is a no-op.
void configureDioForWeb(dynamic dio) => platformConfigureDioForWeb(dio);
