import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

Widget buildMailWebViewWidgetImpl({
  required WebViewController controller,
  required Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers,
}) {
  if (Platform.isAndroid) {
    return WebViewWidget.fromPlatformCreationParams(
      params: AndroidWebViewWidgetCreationParams(
        controller: controller.platform,
        gestureRecognizers: gestureRecognizers,
        displayWithHybridComposition: false,
      ),
    );
  }

  return WebViewWidget(
    controller: controller,
    gestureRecognizers: gestureRecognizers,
  );
}
