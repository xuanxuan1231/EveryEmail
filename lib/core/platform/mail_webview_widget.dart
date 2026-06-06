import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'mail_webview_widget_stub.dart'
    if (dart.library.io) 'mail_webview_widget_io.dart';

Widget buildMailWebViewWidget({
  required WebViewController controller,
  required Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers,
}) {
  return buildMailWebViewWidgetImpl(
    controller: controller,
    gestureRecognizers: gestureRecognizers,
  );
}
