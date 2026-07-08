// Stub implementation for non-web platforms.
// CSRF cookies don't exist on mobile — token is sent via Authorization header.

String? getPlatformCsrfToken() => null;

void platformConfigureDioForWeb(dynamic dio) {
  // No-op on mobile — cookies are not used for authentication.
}
