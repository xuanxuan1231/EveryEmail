import 'dart:io' show Platform;

import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

void ensureWebViewPlatformRegisteredImpl() {
  if (Platform.isAndroid) {
    AndroidWebViewPlatform.registerWith();
  } else if (Platform.isIOS || Platform.isMacOS) {
    WebKitWebViewPlatform.registerWith();
  }
}
