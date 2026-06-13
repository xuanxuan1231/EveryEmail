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
        // Hybrid Composition is required here, not TLHC. The mail body WebView is
        // sized to the full document height (the outer list scrolls, the WebView
        // never does), so the platform view is routinely far taller than the
        // screen. TLHC renders the view through a SurfaceTexture capped near the
        // display size, then stretches that buffer to fill the box — long emails
        // come out vertically smeared even though the measured height is correct.
        // HC composites the real native view at any height. Route-transition
        // animation (which HC views cannot do) is handled separately by the
        // native snapshot overlay in MessageHtmlView.
        displayWithHybridComposition: true,
      ),
    );
  }

  return WebViewWidget(
    controller: controller,
    gestureRecognizers: gestureRecognizers,
  );
}
