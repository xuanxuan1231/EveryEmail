import 'package:flutter/services.dart';

class MailWebViewSnapshot {
  const MailWebViewSnapshot._();

  static const MethodChannel _channel = MethodChannel(
    'com.everyemail.app/webview_snapshot',
  );

  static Future<Uint8List?> captureVisibleRect({
    required int webViewIdentifier,
    required double cropLeft,
    required double cropTop,
    required double width,
    required double height,
  }) {
    return _channel.invokeMethod<Uint8List>('captureVisibleRect', {
      'webViewIdentifier': webViewIdentifier,
      'cropLeft': cropLeft,
      'cropTop': cropTop,
      'width': width,
      'height': height,
    });
  }
}
