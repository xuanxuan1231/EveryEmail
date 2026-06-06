import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/platform/mail_webview_widget.dart';
import '../../../core/platform/webview_platform_bootstrap.dart';

/// Renders email HTML using the platform browser engine.
///
/// Complex email templates can contain hundreds of nested tables and inline
/// styles. Building that as a Flutter widget tree is expensive, so the message
/// body is always delegated to WebView. Platforms without a WebView plugin show
/// an unavailable state instead of falling back to Flutter HTML rendering.
class MessageHtmlView extends StatefulWidget {
  const MessageHtmlView({
    required this.htmlBody,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.linkColor,
    required this.borderColor,
    required this.onOpenUrl,
    this.textStyle,
    super.key,
  });

  final String htmlBody;
  final TextStyle? textStyle;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color linkColor;
  final Color borderColor;
  final Future<bool> Function(String url) onOpenUrl;

  @override
  State<MessageHtmlView> createState() => _MessageHtmlViewState();
}

class _MessageHtmlViewState extends State<MessageHtmlView>
    with AutomaticKeepAliveClientMixin<MessageHtmlView> {
  static const String _baseUrl = 'https://everyemail.local/';
  static const String _baseHost = 'everyemail.local';
  static const double _initialHeight = 220;
  static const double _minHeight = 96;
  static const int _asyncBuildThreshold = 8192;
  static const List<Duration> _heightProbeDelays = [
    Duration(milliseconds: 120),
    Duration(milliseconds: 600),
    Duration(milliseconds: 1800),
  ];

  WebViewController? _controller;
  Object? _controllerError;
  final List<Timer> _heightTimers = [];
  double _height = _initialHeight;
  double? _pendingHeight;
  int _progress = 0;
  int _loadSerial = 0;
  bool _pageLoaded = false;
  bool _heightUpdateScheduled = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _createController();
  }

  @override
  void didUpdateWidget(covariant MessageHtmlView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_controller == null && _controllerError == null) {
      _createController();
    }

    if (_shouldReload(oldWidget)) {
      unawaited(
        _loadHtml(
          resetHeight: oldWidget.htmlBody != widget.htmlBody,
        ).catchError((Object error) {
          _setControllerError(error);
        }),
      );
    }
  }

  @override
  void dispose() {
    _cancelHeightTimers();
    super.dispose();
  }

  void _createController() {
    try {
      ensureWebViewPlatformRegistered();
      final controller = WebViewController();
      _controller = controller;
      _controllerError = null;
      unawaited(
        _configureController(controller).catchError((Object error) {
          _setControllerError(error);
        }),
      );
    } catch (error) {
      _setControllerError(error);
    }
  }

  Future<void> _configureController(WebViewController controller) async {
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await controller.setBackgroundColor(widget.backgroundColor);
    await controller.addJavaScriptChannel(
      'EveryEmailHeight',
      onMessageReceived: _handleHeightMessage,
    );
    await controller.setNavigationDelegate(
      NavigationDelegate(
        onProgress: _handleProgress,
        onPageFinished: _handlePageFinished,
        onNavigationRequest: _handleNavigationRequest,
      ),
    );

    if (!mounted || _controller != controller) return;
    await _loadHtml();
  }

  bool _shouldReload(MessageHtmlView oldWidget) {
    return oldWidget.htmlBody != widget.htmlBody ||
        oldWidget.textStyle != widget.textStyle ||
        oldWidget.backgroundColor != widget.backgroundColor ||
        oldWidget.foregroundColor != widget.foregroundColor ||
        oldWidget.linkColor != widget.linkColor ||
        oldWidget.borderColor != widget.borderColor;
  }

  Future<void> _loadHtml({bool resetHeight = true}) async {
    final controller = _controller;
    if (controller == null) return;

    final loadSerial = ++_loadSerial;
    _cancelHeightTimers();
    _pageLoaded = false;
    _pendingHeight = null;
    if (mounted) {
      setState(() {
        if (resetHeight) {
          _height = _initialHeight;
        }
        _progress = 0;
      });
    }

    final input = _EmailHtmlDocumentInput(
      rawHtml: widget.htmlBody,
      fontSize: widget.textStyle?.fontSize ?? 14,
      lineHeight: widget.textStyle?.height ?? 1.45,
      fontWeight: widget.textStyle?.fontWeight?.value ?? 400,
      backgroundColorValue: widget.backgroundColor.toARGB32(),
      foregroundColorValue: widget.foregroundColor.toARGB32(),
      linkColorValue: widget.linkColor.toARGB32(),
      borderColorValue: widget.borderColor.toARGB32(),
    );
    final document = await _buildDocument(input);

    if (!mounted || _controller != controller || loadSerial != _loadSerial) {
      return;
    }
    await controller.setBackgroundColor(widget.backgroundColor);
    if (!mounted || _controller != controller || loadSerial != _loadSerial) {
      return;
    }
    await controller.loadHtmlString(document, baseUrl: _baseUrl);
  }

  Future<String> _buildDocument(_EmailHtmlDocumentInput input) {
    if (kIsWeb || input.rawHtml.length < _asyncBuildThreshold) {
      return Future.value(_buildEmailHtmlDocument(input));
    }
    return compute(_buildEmailHtmlDocument, input);
  }

  void _setControllerError(Object error) {
    _controller = null;
    _cancelHeightTimers();
    if (!mounted) {
      _controllerError = error;
      return;
    }
    setState(() {
      _controllerError = error;
      _progress = 0;
      _height = _initialHeight;
    });
  }

  void _handleProgress(int progress) {
    final nextProgress = progress.clamp(0, 100).toInt();
    if (!mounted || nextProgress == _progress) return;
    if (nextProgress < 100 &&
        _progress > 0 &&
        (nextProgress - _progress).abs() < 8) {
      return;
    }
    setState(() => _progress = nextProgress);
  }

  void _handlePageFinished(String _) {
    _pageLoaded = true;
    if (mounted && _progress != 100) {
      setState(() => _progress = 100);
    }
    _scheduleHeightChecks();
  }

  void _handleHeightMessage(JavaScriptMessage message) {
    final measuredHeight = _parseJsNumber(message.message);
    if (measuredHeight == null) return;
    _queueHeightUpdate(measuredHeight);
  }

  NavigationDecision _handleNavigationRequest(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.prevent;

    if (_isInternalNavigation(uri)) {
      return NavigationDecision.navigate;
    }

    if (_isOpenableExternalUri(uri)) {
      unawaited(widget.onOpenUrl(request.url));
    }
    return NavigationDecision.prevent;
  }

  bool _isInternalNavigation(Uri uri) {
    if (uri.scheme == 'about' || uri.scheme == 'data') return true;
    if (uri.host != _baseHost) return false;

    // Allow the initial document load and in-message anchor jumps. Relative
    // links without a fragment would otherwise navigate to the local base URL.
    return !_pageLoaded || uri.fragment.isNotEmpty;
  }

  bool _isOpenableExternalUri(Uri uri) {
    return switch (uri.scheme.toLowerCase()) {
      'http' || 'https' || 'mailto' || 'tel' => true,
      _ => false,
    };
  }

  void _scheduleHeightChecks() {
    _cancelHeightTimers();
    for (final delay in _heightProbeDelays) {
      _heightTimers.add(
        Timer(delay, () {
          unawaited(_updateHeight());
        }),
      );
    }
  }

  void _cancelHeightTimers() {
    for (final timer in _heightTimers) {
      timer.cancel();
    }
    _heightTimers.clear();
  }

  Future<void> _updateHeight() async {
    final controller = _controller;
    if (!mounted || controller == null) return;

    try {
      final result = await controller.runJavaScriptReturningResult('''
(() => {
  const body = document.body;
  const html = document.documentElement;
  const root = document.getElementById('email-root');
  return Math.ceil(Math.max(
    body ? body.scrollHeight : 0,
    body ? body.offsetHeight : 0,
    html ? html.clientHeight : 0,
    html ? html.scrollHeight : 0,
    html ? html.offsetHeight : 0,
    root ? root.scrollHeight : 0,
    root ? root.offsetHeight : 0
  ));
})()
''');
      final measuredHeight = _parseJsNumber(result);
      if (measuredHeight == null) return;
      _queueHeightUpdate(measuredHeight);
    } catch (_) {
      // A height probe can race page navigation or disposal. The next scheduled
      // probe will retry; failing silently keeps mail reading uninterrupted.
    }
  }

  void _queueHeightUpdate(num measuredHeight) {
    if (measuredHeight <= 0 || !mounted) return;

    final nextHeight = measuredHeight < _minHeight
        ? _minHeight
        : measuredHeight.toDouble();
    final comparisonHeight = _pendingHeight ?? _height;
    if ((nextHeight - comparisonHeight).abs() < 2) return;

    _pendingHeight = nextHeight;
    if (_heightUpdateScheduled) return;

    _heightUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _heightUpdateScheduled = false;
      final pendingHeight = _pendingHeight;
      _pendingHeight = null;
      if (!mounted || pendingHeight == null) return;
      if ((pendingHeight - _height).abs() < 2) return;
      setState(() => _height = pendingHeight);
    });
  }

  double? _parseJsNumber(Object? value) {
    if (value is num) return value.toDouble();
    final text = value?.toString().replaceAll('"', '').trim();
    if (text == null || text.isEmpty) return null;
    return double.tryParse(text);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final controller = _controller;
    final controllerError = _controllerError;
    if (controllerError != null) {
      return _buildUnavailable(controllerError);
    }

    if (controller == null) {
      return _buildFrame(
        child: const SizedBox(
          height: _initialHeight,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return _buildFrame(
      child: Stack(
        children: [
          SizedBox(
            height: _height,
            child: buildMailWebViewWidget(
              controller: controller,
              gestureRecognizers: {
                Factory<OneSequenceGestureRecognizer>(
                  LongPressGestureRecognizer.new,
                ),
              },
            ),
          ),
          if (_progress < 100)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                minHeight: 2,
                value: _progress <= 0 ? null : _progress / 100,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUnavailable(Object error) {
    return _buildFrame(
      child: SizedBox(
        height: 180,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.web_asset_off_outlined,
                  size: 40,
                  color: widget.foregroundColor.withValues(alpha: 0.65),
                ),
                const SizedBox(height: 12),
                Text(
                  '当前平台不支持 WebView 邮件正文渲染',
                  style: widget.textStyle?.copyWith(
                    color: widget.foregroundColor,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  '$error',
                  style: widget.textStyle?.copyWith(
                    color: widget.foregroundColor.withValues(alpha: 0.65),
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFrame({required Widget child, EdgeInsetsGeometry? padding}) {
    final content = padding == null
        ? child
        : Padding(padding: padding, child: child);

    return RepaintBoundary(
      child: ColoredBox(color: widget.backgroundColor, child: content),
    );
  }
}

String _buildEmailHtmlDocument(_EmailHtmlDocumentInput input) {
  return _EmailHtmlDocument(
    rawHtml: input.rawHtml,
    fontSize: input.fontSize,
    lineHeight: input.lineHeight,
    fontWeight: input.fontWeight,
    backgroundColorValue: input.backgroundColorValue,
    foregroundColorValue: input.foregroundColorValue,
    linkColorValue: input.linkColorValue,
    borderColorValue: input.borderColorValue,
  ).build();
}

@immutable
class _EmailHtmlDocumentInput {
  const _EmailHtmlDocumentInput({
    required this.rawHtml,
    required this.fontSize,
    required this.lineHeight,
    required this.fontWeight,
    required this.backgroundColorValue,
    required this.foregroundColorValue,
    required this.linkColorValue,
    required this.borderColorValue,
  });

  final String rawHtml;
  final double fontSize;
  final double lineHeight;
  final int fontWeight;
  final int backgroundColorValue;
  final int foregroundColorValue;
  final int linkColorValue;
  final int borderColorValue;
}

class _EmailHtmlDocument {
  const _EmailHtmlDocument({
    required this.rawHtml,
    required this.fontSize,
    required this.lineHeight,
    required this.fontWeight,
    required this.backgroundColorValue,
    required this.foregroundColorValue,
    required this.linkColorValue,
    required this.borderColorValue,
  });

  static final RegExp _controlAndWhitespace = RegExp(r'[\x00-\x20]+');
  static final RegExp _cssExpression = RegExp(
    r'expression\s*\([^)]*\)',
    caseSensitive: false,
  );
  static final RegExp _cssUnsafeUrl = RegExp(
    r'''url\s*\(\s*(['"]?)\s*(?:javascript|vbscript|file):[^)]*\)''',
    caseSensitive: false,
  );
  static final RegExp _cssBehavior = RegExp(
    r'behavior\s*:[^;]+;?',
    caseSensitive: false,
  );
  static final RegExp _cssPointerSelection = RegExp(
    r'(?:-webkit-|-moz-|-ms-)?user-select\s*:[^;]+;?',
    caseSensitive: false,
  );
  static final RegExp _cssTouchCallout = RegExp(
    r'-webkit-touch-callout\s*:[^;]+;?',
    caseSensitive: false,
  );
  static final RegExp _cssImport = RegExp(
    r'@import[^;]+;',
    caseSensitive: false,
  );

  static const Set<String> _blockedTags = {
    'applet',
    'base',
    'button',
    'embed',
    'form',
    'frame',
    'frameset',
    'iframe',
    'input',
    'link',
    'meta',
    'object',
    'script',
    'select',
    'textarea',
  };

  static const Set<String> _uriAttributes = {
    'action',
    'background',
    'formaction',
    'href',
    'poster',
    'src',
    'srcset',
    'xlink:href',
  };

  final String rawHtml;
  final double fontSize;
  final double lineHeight;
  final int fontWeight;
  final int backgroundColorValue;
  final int foregroundColorValue;
  final int linkColorValue;
  final int borderColorValue;

  String build() {
    final document = html_parser.parse(rawHtml);
    _sanitizeNode(document);

    final preservedHeadStyles =
        document.head
            ?.querySelectorAll('style')
            .map((element) => element.outerHtml)
            .join('\n') ??
        '';
    final bodyHtml = document.body?.innerHtml.trim();
    final safeBodyHtml = bodyHtml == null || bodyHtml.isEmpty
        ? _escapeHtml(rawHtml)
        : bodyHtml;

    final background = _cssColor(backgroundColorValue);
    final foreground = _cssColor(foregroundColorValue);
    final link = _cssColor(linkColorValue);
    final border = _cssColor(borderColorValue);

    return '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    html,
    body {
      width: 100%;
      min-height: 100%;
      margin: 0;
      background: $background;
      color: $foreground;
      overflow: hidden;
      -webkit-text-size-adjust: 100%;
    }

    body {
      padding: 12px 0;
      font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      font-size: ${fontSize.toStringAsFixed(1)}px;
      font-weight: $fontWeight;
      line-height: ${lineHeight.toStringAsFixed(2)};
      overflow: hidden;
      overscroll-behavior: none;
      word-break: normal;
      overflow-wrap: anywhere;
    }

    a {
      color: $link;
      text-decoration-color: color-mix(in srgb, $link 45%, transparent);
    }

    pre,
    code {
      white-space: pre-wrap;
      word-break: break-word;
    }

    blockquote {
      margin: 0 0 0 12px;
      padding-left: 12px;
      border-left: 3px solid $border;
    }
  </style>
  $preservedHeadStyles
  <style>
    *,
    *::before,
    *::after {
      box-sizing: border-box;
    }

    img,
    svg,
    video,
    canvas {
      max-width: 100% !important;
      height: auto !important;
    }

    table {
      max-width: 100% !important;
      border-collapse: collapse;
    }

    td,
    th {
      max-width: 100%;
      overflow-wrap: anywhere;
    }

    body,
    #email-root {
      max-width: 100%;
    }

    html,
    body,
    #email-root,
    #email-root * {
      -webkit-touch-callout: default !important;
      -webkit-user-select: text !important;
      user-select: text !important;
    }

    #email-root > :first-child {
      margin-top: 0 !important;
    }

    #email-root > :last-child {
      margin-bottom: 0 !important;
    }
  </style>
  <script>
    (() => {
      const measure = () => {
        const body = document.body;
        const html = document.documentElement;
        const root = document.getElementById('email-root');
        return Math.ceil(Math.max(
          body ? body.scrollHeight : 0,
          body ? body.offsetHeight : 0,
          html ? html.clientHeight : 0,
          html ? html.scrollHeight : 0,
          html ? html.offsetHeight : 0,
          root ? root.scrollHeight : 0,
          root ? root.offsetHeight : 0
        ));
      };
      const postHeight = () => {
        const height = measure();
        if (height > 0 && window.EveryEmailHeight) {
          window.EveryEmailHeight.postMessage(String(height));
        }
      };
      const schedule = () => {
        requestAnimationFrame(() => {
          postHeight();
          requestAnimationFrame(postHeight);
        });
      };
      window.addEventListener('load', schedule);
      window.addEventListener('resize', schedule);
      document.addEventListener('DOMContentLoaded', () => {
        schedule();
        if ('ResizeObserver' in window) {
          const observer = new ResizeObserver(schedule);
          observer.observe(document.documentElement);
          if (document.body) observer.observe(document.body);
          const root = document.getElementById('email-root');
          if (root) observer.observe(root);
        }
      });
      document.addEventListener('load', (event) => {
        if (event.target && event.target.tagName === 'IMG') schedule();
      }, true);
      schedule();
    })();
  </script>
</head>
<body>
  <div id="email-root">$safeBodyHtml</div>
</body>
</html>
''';
  }

  void _sanitizeNode(dom.Node node) {
    for (final child in node.nodes.toList()) {
      if (child is! dom.Element) {
        continue;
      }

      final tag = child.localName?.toLowerCase();
      if (tag == null || _blockedTags.contains(tag)) {
        child.remove();
        continue;
      }

      _sanitizeAttributes(child);
      if (tag == 'style') {
        child.text = _sanitizeCss(child.text).replaceAll(_cssImport, '');
      }
      _sanitizeNode(child);
    }
  }

  void _sanitizeAttributes(dom.Element element) {
    for (final key in element.attributes.keys.toList()) {
      final name = key.toString().toLowerCase();
      final value = element.attributes[key] ?? '';

      if (name.startsWith('on') || name == 'srcdoc') {
        element.attributes.remove(key);
        continue;
      }

      if (_uriAttributes.contains(name) && _isUnsafeUri(name, value)) {
        element.attributes.remove(key);
        continue;
      }

      if (name == 'style') {
        final sanitized = _sanitizeCss(value).trim();
        if (sanitized.isEmpty) {
          element.attributes.remove(key);
        } else {
          element.attributes[key] = sanitized;
        }
      }
    }

    if (element.localName?.toLowerCase() == 'a') {
      element.attributes['target'] = '_blank';
      element.attributes['rel'] = 'noopener noreferrer';
    }
  }

  bool _isUnsafeUri(String attributeName, String value) {
    final normalized = value
        .trimLeft()
        .replaceAll(_controlAndWhitespace, '')
        .toLowerCase();
    if (normalized.isEmpty || normalized.startsWith('#')) return false;
    if (normalized.startsWith('javascript:') ||
        normalized.startsWith('vbscript:') ||
        normalized.startsWith('file:')) {
      return true;
    }

    if (attributeName == 'href' && normalized.startsWith('data:')) {
      return true;
    }

    if (normalized.startsWith('data:') &&
        !normalized.startsWith('data:image/')) {
      return true;
    }

    return false;
  }

  String _sanitizeCss(String css) {
    return css
        .replaceAll(_cssExpression, '')
        .replaceAll(_cssUnsafeUrl, 'none')
        .replaceAll(_cssBehavior, '')
        .replaceAll(_cssPointerSelection, '')
        .replaceAll(_cssTouchCallout, '');
  }

  String _cssColor(int value) {
    final alpha = (value >> 24) & 0xff;
    final red = (value >> 16) & 0xff;
    final green = (value >> 8) & 0xff;
    final blue = value & 0xff;

    if (alpha == 0xff) {
      return '#${red.toRadixString(16).padLeft(2, '0')}'
          '${green.toRadixString(16).padLeft(2, '0')}'
          '${blue.toRadixString(16).padLeft(2, '0')}';
    }

    final opacity = alpha / 255;
    return 'rgba($red, $green, $blue, ${opacity.toStringAsFixed(3)})';
  }

  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}
