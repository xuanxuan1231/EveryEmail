import 'webview_platform_bootstrap_stub.dart'
    if (dart.library.io) 'webview_platform_bootstrap_io.dart';

void ensureWebViewPlatformRegistered() {
  ensureWebViewPlatformRegisteredImpl();
}
