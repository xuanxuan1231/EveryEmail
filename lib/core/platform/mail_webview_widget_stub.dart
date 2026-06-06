import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';

Widget buildMailWebViewWidgetImpl({
  required WebViewController controller,
  required Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers,
}) {
  return WebViewWidget(
    controller: controller,
    gestureRecognizers: gestureRecognizers,
  );
}
