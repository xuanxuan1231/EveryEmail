import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../../../core/navigation/predictive_back_transition_scope.dart';
import '../../../core/platform/mail_webview_snapshot.dart';
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
  final GlobalKey _webViewKey = GlobalKey();
  final List<Timer> _heightTimers = [];
  Animation<double>? _routeAnimation;
  ScrollPosition? _scrollPosition;
  Timer? _snapshotRefreshTimer;
  MemoryImage? _transitionSnapshotImage;
  DateTime? _lastContextMenuAt;
  double _height = _initialHeight;
  double? _pendingHeight;
  double _transitionSnapshotTop = 0;
  double _transitionSnapshotWidth = 0;
  double _transitionSnapshotHeight = 0;
  int _snapshotSerial = 0;
  int _progress = 0;
  int _loadSerial = 0;
  bool _pageLoaded = false;
  bool _heightUpdateScheduled = false;
  bool _controllerCreateScheduled = false;
  bool _snapshotCaptureInFlight = false;
  bool _inPredictiveBackTransition = false;
  bool _hasRemoteImages = false;
  bool _loadRemoteImages = false;
  bool _contextMenuOpen = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bindRouteAnimation(ModalRoute.of(context)?.animation);
    _bindScrollPosition();
    _ensureControllerCreatedAfterEntrance();
  }

  @override
  void didUpdateWidget(covariant MessageHtmlView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.htmlBody != widget.htmlBody) {
      _clearTransitionSnapshot();
      _hasRemoteImages = false;
      _loadRemoteImages = false;
    }

    if (_controller == null && _controllerError == null) {
      _ensureControllerCreatedAfterEntrance();
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
    _routeAnimation?.removeStatusListener(_handleRouteAnimationStatus);
    _scrollPosition?.removeListener(_handleAncestorScroll);
    _snapshotRefreshTimer?.cancel();
    _cancelHeightTimers();
    super.dispose();
  }

  void _bindRouteAnimation(Animation<double>? animation) {
    if (identical(animation, _routeAnimation)) return;

    _routeAnimation?.removeStatusListener(_handleRouteAnimationStatus);
    _routeAnimation = animation;
    _routeAnimation?.addStatusListener(_handleRouteAnimationStatus);
  }

  void _bindScrollPosition() {
    final position = Scrollable.maybeOf(context)?.position;
    if (identical(position, _scrollPosition)) return;

    _scrollPosition?.removeListener(_handleAncestorScroll);
    _scrollPosition = position;
    _scrollPosition?.addListener(_handleAncestorScroll);
  }

  void _handleAncestorScroll() {
    if (_inPredictiveBackTransition) return;
    _clearTransitionSnapshot();
    _scheduleSnapshotRefresh(const Duration(milliseconds: 180));
  }

  void _handleRouteAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _ensureControllerCreatedAfterEntrance();
    }
  }

  void _ensureControllerCreatedAfterEntrance() {
    if (_controller != null ||
        _controllerError != null ||
        _controllerCreateScheduled ||
        !_routeEntranceComplete) {
      return;
    }

    _controllerCreateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controllerCreateScheduled = false;
      if (!mounted ||
          _controller != null ||
          _controllerError != null ||
          !_routeEntranceComplete) {
        return;
      }
      _createController();
    });
  }

  bool get _routeEntranceComplete {
    final animation = _routeAnimation;
    return animation == null ||
        animation.status == AnimationStatus.completed ||
        animation.value >= 1;
  }

  void _createController() {
    try {
      ensureWebViewPlatformRegistered();
      final controller = WebViewController(
        onPermissionRequest: (request) {
          unawaited(request.deny());
        },
      );
      setState(() {
        _controller = controller;
        _controllerError = null;
      });
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
    await _configureWebViewSecurity(controller);
    await controller.setBackgroundColor(widget.backgroundColor);
    await controller.addJavaScriptChannel(
      'EveryEmailHeight',
      onMessageReceived: _handleHeightMessage,
    );
    await controller.addJavaScriptChannel(
      'EveryEmailContext',
      onMessageReceived: _handleContextMenuMessage,
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

  Future<void> _configureWebViewSecurity(WebViewController controller) async {
    await _tryConfigureWebView(() {
      return controller.setOnJavaScriptAlertDialog((_) async {});
    });
    await _tryConfigureWebView(() {
      return controller.setOnJavaScriptConfirmDialog((_) async => false);
    });
    await _tryConfigureWebView(() {
      return controller.setOnJavaScriptTextInputDialog((_) async => '');
    });

    final platformController = controller.platform;
    if (platformController is AndroidWebViewController) {
      await _tryConfigureWebView(
        () => platformController.setAllowFileAccess(false),
      );
      await _tryConfigureWebView(
        () => platformController.setAllowContentAccess(false),
      );
      await _tryConfigureWebView(
        () => platformController.setGeolocationEnabled(false),
      );
      await _tryConfigureWebView(
        () => platformController.setMediaPlaybackRequiresUserGesture(true),
      );
      await _tryConfigureWebView(
        () =>
            platformController.setMixedContentMode(MixedContentMode.neverAllow),
      );
      await _tryConfigureWebView(() async {
        final supported = await platformController.isWebViewFeatureSupported(
          WebViewFeatureType.paymentRequest,
        );
        if (supported) {
          await platformController.setPaymentRequestEnabled(false);
        }
      });
    } else if (platformController is WebKitWebViewController) {
      await _tryConfigureWebView(
        () => platformController.setAllowsLinkPreview(false),
      );
    }
  }

  Future<void> _tryConfigureWebView(Future<void> Function() configure) async {
    try {
      await configure();
    } catch (_) {
      // Some settings are platform/version specific. Treat them as defense in
      // depth so an unsupported toggle does not make the message unreadable.
    }
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
    _clearTransitionSnapshot();
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
      loadRemoteImages: _loadRemoteImages,
    );
    final document = await _buildDocument(input);

    if (!mounted || _controller != controller || loadSerial != _loadSerial) {
      return;
    }
    if (document.hasRemoteImages != _hasRemoteImages) {
      setState(() => _hasRemoteImages = document.hasRemoteImages);
    }
    await _configureRemoteImageLoading(controller);
    if (!mounted || _controller != controller || loadSerial != _loadSerial) {
      return;
    }
    await controller.setBackgroundColor(widget.backgroundColor);
    if (!mounted || _controller != controller || loadSerial != _loadSerial) {
      return;
    }
    await controller.loadHtmlString(document.html, baseUrl: _baseUrl);
  }

  Future<_PreparedEmailHtmlDocument> _buildDocument(
    _EmailHtmlDocumentInput input,
  ) {
    if (kIsWeb || input.rawHtml.length < _asyncBuildThreshold) {
      return Future.value(_buildEmailHtmlDocument(input));
    }
    return compute(_buildEmailHtmlDocument, input);
  }

  Future<void> _configureRemoteImageLoading(
    WebViewController controller,
  ) async {
    final platformController = controller.platform;
    if (platformController is! AndroidWebViewController) return;

    await _tryConfigureWebView(
      () => platformController.setMixedContentMode(
        _loadRemoteImages
            ? MixedContentMode.compatibilityMode
            : MixedContentMode.neverAllow,
      ),
    );
  }

  void _setControllerError(Object error) {
    _controller = null;
    _clearTransitionSnapshot();
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
    _scheduleSnapshotRefresh(const Duration(milliseconds: 260));
  }

  void _handleHeightMessage(JavaScriptMessage message) {
    final measuredHeight = _parseJsNumber(message.message);
    if (measuredHeight == null) return;
    _queueHeightUpdate(measuredHeight);
  }

  void _handleContextMenuMessage(JavaScriptMessage message) {
    final now = DateTime.now();
    final lastContextMenuAt = _lastContextMenuAt;
    if (lastContextMenuAt != null &&
        now.difference(lastContextMenuAt) < const Duration(milliseconds: 450)) {
      return;
    }
    _lastContextMenuAt = now;

    try {
      final decoded = jsonDecode(message.message);
      if (decoded is! Map<String, dynamic>) return;
      final target = _EmailHtmlContextTarget.fromJson(decoded);
      if (!target.hasActionableContent) return;
      unawaited(_showContextActions(target));
    } catch (_) {
      // Ignore malformed context messages from the WebView document.
    }
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
    if (uri.scheme == 'about') return true;
    if (uri.scheme == 'data') return false;
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

  Future<void> _showContextActions(_EmailHtmlContextTarget target) async {
    if (_contextMenuOpen || !mounted) return;

    final actions = _buildContextActions(target);
    if (actions.isEmpty) return;

    _contextMenuOpen = true;
    try {
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Text(
                    target.displayTitle,
                    style: Theme.of(sheetContext).textTheme.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                for (final action in actions)
                  ListTile(
                    leading: Icon(action.icon),
                    title: Text(action.label),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      unawaited(action.run());
                    },
                  ),
              ],
            ),
          );
        },
      );
    } finally {
      _contextMenuOpen = false;
    }
  }

  List<_EmailHtmlContextAction> _buildContextActions(
    _EmailHtmlContextTarget target,
  ) {
    final actions = <_EmailHtmlContextAction>[];
    final imageUrl = target.imageUrl;
    final linkUrl = target.linkUrl;
    final text = target.text;

    if (target.isImage) {
      if (target.isBlockedRemoteImage && !_loadRemoteImages) {
        actions.add(
          _EmailHtmlContextAction(
            icon: Icons.image_outlined,
            label: '加载图片',
            run: _enableRemoteImages,
          ),
        );
      }

      if (imageUrl != null) {
        if (_canOpenImageUrl(imageUrl)) {
          actions.add(
            _EmailHtmlContextAction(
              icon: Icons.open_in_new,
              label: '打开图片',
              run: () => _openExternalUrl(imageUrl),
            ),
          );
        }
        actions.add(
          _EmailHtmlContextAction(
            icon: Icons.content_copy,
            label: '复制图片地址',
            run: () => _copyText(imageUrl, '已复制图片地址'),
          ),
        );
      }
    }

    if (linkUrl != null) {
      if (_canOpenExternalUrl(linkUrl)) {
        actions.add(
          _EmailHtmlContextAction(
            icon: Icons.open_in_new,
            label: '打开链接',
            run: () => _openExternalUrl(linkUrl),
          ),
        );
      }
      actions.add(
        _EmailHtmlContextAction(
          icon: Icons.link,
          label: '复制链接',
          run: () => _copyText(linkUrl, '已复制链接'),
        ),
      );
    }

    if (text != null) {
      actions.add(
        _EmailHtmlContextAction(
          icon: Icons.text_fields,
          label: '复制文本',
          run: () => _copyText(text, '已复制文本'),
        ),
      );
    }

    return actions;
  }

  bool _canOpenImageUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  bool _canOpenExternalUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null && _isOpenableExternalUri(uri);
  }

  Future<void> _openExternalUrl(String url) async {
    if (!_canOpenExternalUrl(url)) {
      _showSnackBar('无法打开链接');
      return;
    }
    await widget.onOpenUrl(url);
  }

  Future<void> _copyText(String text, String message) async {
    await Clipboard.setData(ClipboardData(text: text));
    _showSnackBar(message);
  }

  Future<void> _enableRemoteImages() async {
    if (_loadRemoteImages) return;
    setState(() => _loadRemoteImages = true);
    await _loadHtml(resetHeight: false);
    _showSnackBar('已允许加载此邮件的图片');
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
      _scheduleSnapshotRefresh(const Duration(milliseconds: 160));
    });
  }

  double? _parseJsNumber(Object? value) {
    if (value is num) return value.toDouble();
    final text = value?.toString().replaceAll('"', '').trim();
    if (text == null || text.isEmpty) return null;
    return double.tryParse(text);
  }

  void _scheduleSnapshotRefresh(Duration delay) {
    if (!mounted ||
        _controller == null ||
        !_pageLoaded ||
        _snapshotCaptureInFlight) {
      return;
    }

    _snapshotRefreshTimer?.cancel();
    _snapshotRefreshTimer = Timer(delay, () {
      unawaited(_captureVisibleWebViewSnapshot());
    });
  }

  void _ensureTransitionSnapshotScheduled() {
    if (_transitionSnapshotImage != null || _snapshotCaptureInFlight) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_inPredictiveBackTransition) return;
      unawaited(_captureVisibleWebViewSnapshot());
    });
  }

  Future<void> _captureVisibleWebViewSnapshot() async {
    if (_snapshotCaptureInFlight || !mounted || !_pageLoaded) return;

    final request = _buildSnapshotRequest();
    if (request == null) return;

    final serial = ++_snapshotSerial;
    _snapshotCaptureInFlight = true;
    try {
      final bytes = await MailWebViewSnapshot.captureVisibleRect(
        webViewIdentifier: request.webViewIdentifier,
        cropLeft: request.cropLeft,
        cropTop: request.cropTop,
        width: request.width,
        height: request.height,
      );
      if (!mounted || serial != _snapshotSerial || bytes == null) return;

      final image = MemoryImage(bytes);
      unawaited(precacheImage(image, context));
      setState(() {
        _transitionSnapshotImage = image;
        _transitionSnapshotTop = request.localTop;
        _transitionSnapshotWidth = request.logicalWidth;
        _transitionSnapshotHeight = request.logicalHeight;
      });
    } catch (_) {
      // Snapshotting is an animation optimization. If the native capture is not
      // available, keep the live WebView path instead of disrupting reading.
    } finally {
      _snapshotCaptureInFlight = false;
    }
  }

  _WebViewSnapshotRequest? _buildSnapshotRequest() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;

    final controller = _controller;
    final platformController = controller?.platform;
    if (platformController is! AndroidWebViewController) return null;

    final snapshotContext = _webViewKey.currentContext;
    if (snapshotContext == null) return null;

    final renderObject = snapshotContext.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize) {
      return null;
    }

    final screenSize = MediaQuery.sizeOf(context);
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final topLeft = renderObject.localToGlobal(Offset.zero);
    final localTop = math.max(0.0, -topLeft.dy);
    final localBottom = math.min(
      renderObject.size.height,
      screenSize.height - topLeft.dy,
    );
    final logicalHeight = localBottom - localTop;
    final logicalWidth = renderObject.size.width;
    if (logicalWidth <= 1 || logicalHeight <= 1) return null;

    return _WebViewSnapshotRequest(
      webViewIdentifier: platformController.webViewIdentifier,
      cropLeft: 0,
      cropTop: localTop * devicePixelRatio,
      width: logicalWidth * devicePixelRatio,
      height: logicalHeight * devicePixelRatio,
      localTop: localTop,
      logicalWidth: logicalWidth,
      logicalHeight: logicalHeight,
    );
  }

  void _clearTransitionSnapshot() {
    unawaited(_transitionSnapshotImage?.evict() ?? Future<void>.value());
    _transitionSnapshotImage = null;
    _transitionSnapshotTop = 0;
    _transitionSnapshotWidth = 0;
    _transitionSnapshotHeight = 0;
    _snapshotSerial++;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final controller = _controller;
    final controllerError = _controllerError;
    if (controllerError != null) {
      return _buildUnavailable(controllerError);
    }

    final inPredictiveBackTransition = PredictiveBackTransitionScope.isActive(
      context,
    );
    _inPredictiveBackTransition = inPredictiveBackTransition;
    if (controller == null) {
      return _buildFrame(child: _buildDeferredPlaceholder());
    }

    final webView = _buildWebView(controller);
    if (inPredictiveBackTransition) {
      _ensureTransitionSnapshotScheduled();
      final snapshot = _buildTransitionSnapshot();
      if (snapshot != null) {
        return _buildFrame(
          child: _buildLoadedContent(
            Stack(
              children: [
                Offstage(offstage: true, child: webView),
                snapshot,
              ],
            ),
          ),
        );
      }

      return _buildFrame(child: _buildLoadedContent(webView));
    }

    return _buildFrame(
      child: _buildLoadedContent(
        Stack(
          children: [
            webView,
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
      ),
    );
  }

  Widget _buildLoadedContent(Widget webViewContent) {
    if (!_hasRemoteImages || _loadRemoteImages) {
      return webViewContent;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [_buildRemoteImagePrompt(), webViewContent],
    );
  }

  Widget _buildRemoteImagePrompt() {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(
              Icons.image_not_supported_outlined,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '远程图片已阻止',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            TextButton(
              onPressed: () => unawaited(_enableRemoteImages()),
              child: const Text('加载图片'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebView(WebViewController controller) {
    return SizedBox(
      key: _webViewKey,
      width: double.infinity,
      height: _height,
      child: buildMailWebViewWidget(
        controller: controller,
        gestureRecognizers: {
          Factory<OneSequenceGestureRecognizer>(LongPressGestureRecognizer.new),
        },
      ),
    );
  }

  Widget? _buildTransitionSnapshot() {
    final image = _transitionSnapshotImage;
    if (image == null ||
        _transitionSnapshotWidth <= 0 ||
        _transitionSnapshotHeight <= 0) {
      return null;
    }

    return SizedBox(
      width: double.infinity,
      height: _height,
      child: ClipRect(
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: _transitionSnapshotTop,
              width: _transitionSnapshotWidth,
              height: _transitionSnapshotHeight,
              child: Image(
                image: image,
                fit: BoxFit.fill,
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ],
        ),
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

  Widget _buildDeferredPlaceholder({double height = _initialHeight}) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ClipRect(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _placeholderLine(widthFactor: 0.92),
              const SizedBox(height: 12),
              _placeholderLine(widthFactor: 0.78),
              const SizedBox(height: 12),
              _placeholderLine(widthFactor: 0.86),
              const SizedBox(height: 20),
              _placeholderLine(widthFactor: 0.64),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholderLine({required double widthFactor}) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: AlignmentDirectional.centerStart,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: widget.foregroundColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const SizedBox(height: 14),
      ),
    );
  }

  Widget _buildFrame({required Widget child, EdgeInsetsGeometry? padding}) {
    final content = padding == null
        ? child
        : Padding(padding: padding, child: child);

    return RepaintBoundary(
      child: ColoredBox(
        color: widget.backgroundColor,
        child: SizedBox(width: double.infinity, child: content),
      ),
    );
  }
}

_PreparedEmailHtmlDocument _buildEmailHtmlDocument(
  _EmailHtmlDocumentInput input,
) {
  return _EmailHtmlDocument(
    rawHtml: input.rawHtml,
    fontSize: input.fontSize,
    lineHeight: input.lineHeight,
    fontWeight: input.fontWeight,
    backgroundColorValue: input.backgroundColorValue,
    foregroundColorValue: input.foregroundColorValue,
    linkColorValue: input.linkColorValue,
    borderColorValue: input.borderColorValue,
    loadRemoteImages: input.loadRemoteImages,
  ).build();
}

@visibleForTesting
String buildSanitizedEmailHtmlForTesting(
  String rawHtml, {
  bool loadRemoteImages = false,
}) {
  return _EmailHtmlDocument(
    rawHtml: rawHtml,
    fontSize: 14,
    lineHeight: 1.45,
    fontWeight: 400,
    backgroundColorValue: 0xffffffff,
    foregroundColorValue: 0xff000000,
    linkColorValue: 0xff1a73e8,
    borderColorValue: 0xffdadce0,
    loadRemoteImages: loadRemoteImages,
  ).build().html;
}

@immutable
class _PreparedEmailHtmlDocument {
  const _PreparedEmailHtmlDocument({
    required this.html,
    required this.hasRemoteImages,
  });

  final String html;
  final bool hasRemoteImages;
}

class _WebViewSnapshotRequest {
  const _WebViewSnapshotRequest({
    required this.webViewIdentifier,
    required this.cropLeft,
    required this.cropTop,
    required this.width,
    required this.height,
    required this.localTop,
    required this.logicalWidth,
    required this.logicalHeight,
  });

  final int webViewIdentifier;
  final double cropLeft;
  final double cropTop;
  final double width;
  final double height;
  final double localTop;
  final double logicalWidth;
  final double logicalHeight;
}

class _EmailHtmlContextTarget {
  const _EmailHtmlContextTarget({
    required this.type,
    required this.imageUrl,
    required this.linkUrl,
    required this.text,
    required this.isBlockedRemoteImage,
  });

  factory _EmailHtmlContextTarget.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? '';
    return _EmailHtmlContextTarget(
      type: type,
      imageUrl: _clean(json['imageUrl']),
      linkUrl: _clean(json['linkUrl']),
      text: _clean(json['text']),
      isBlockedRemoteImage: json['imageBlocked'] == true,
    );
  }

  final String type;
  final String? imageUrl;
  final String? linkUrl;
  final String? text;
  final bool isBlockedRemoteImage;

  bool get isImage => type == 'image';

  bool get hasActionableContent {
    return imageUrl != null || linkUrl != null || text != null;
  }

  String get displayTitle {
    if (isImage) {
      return imageUrl ?? linkUrl ?? '图片';
    }
    return linkUrl ?? text ?? '链接';
  }

  static String? _clean(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class _EmailHtmlContextAction {
  const _EmailHtmlContextAction({
    required this.icon,
    required this.label,
    required this.run,
  });

  final IconData icon;
  final String label;
  final Future<void> Function() run;
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
    required this.loadRemoteImages,
  });

  final String rawHtml;
  final double fontSize;
  final double lineHeight;
  final int fontWeight;
  final int backgroundColorValue;
  final int foregroundColorValue;
  final int linkColorValue;
  final int borderColorValue;
  final bool loadRemoteImages;
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
    required this.loadRemoteImages,
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
  static final RegExp _cssUrl = RegExp(
    r'''url\s*\(\s*(['"]?)(.*?)\1\s*\)''',
    caseSensitive: false,
    dotAll: true,
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
  static final RegExp _cssFontFace = RegExp(
    r'@font-face\s*\{[^}]*\}',
    caseSensitive: false,
    dotAll: true,
  );
  static final RegExp _cssFixedPosition = RegExp(
    r'position\s*:\s*(?:fixed|sticky)\s*;?',
    caseSensitive: false,
  );
  static const int _scriptNonceByteCount = 16;

  static const Set<String> _blockedTags = {
    'applet',
    'audio',
    'base',
    'button',
    'canvas',
    'embed',
    'form',
    'frame',
    'frameset',
    'foreignobject',
    'iframe',
    'input',
    'link',
    'math',
    'meta',
    'object',
    'script',
    'select',
    'source',
    'svg',
    'template',
    'textarea',
    'track',
    'video',
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

  static const Set<String> _blockedAttributes = {
    'allow',
    'allowfullscreen',
    'autofocus',
    'autoplay',
    'download',
    'form',
    'formaction',
    'nonce',
    'ping',
    'srcdoc',
  };

  final String rawHtml;
  final double fontSize;
  final double lineHeight;
  final int fontWeight;
  final int backgroundColorValue;
  final int foregroundColorValue;
  final int linkColorValue;
  final int borderColorValue;
  final bool loadRemoteImages;

  _PreparedEmailHtmlDocument build() {
    final document = html_parser.parse(rawHtml);
    final hasRemoteImages = _sanitizeNode(document);

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
    final scriptNonce = _createCspNonce();
    final imageSources = loadRemoteImages
        ? 'data: cid: http: https:'
        : 'data: cid:';

    final html =
        '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta http-equiv="Content-Security-Policy" content="default-src 'none'; base-uri 'none'; child-src 'none'; connect-src 'none'; font-src 'none'; form-action 'none'; frame-src 'none'; img-src $imageSources; media-src 'none'; object-src 'none'; script-src 'nonce-$scriptNonce'; style-src 'unsafe-inline'">
  <style>
    html,
    body {
      width: 100%;
      max-width: 100%;
      min-width: 0;
      min-height: 100%;
      margin: 0;
      background: $background;
      color: $foreground;
      overflow-x: hidden;
      overflow-y: hidden;
      -webkit-text-size-adjust: 100%;
    }

    body {
      max-width: 100vw !important;
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

    #email-root {
      display: block;
      width: 100% !important;
      max-width: 100% !important;
      min-width: 0 !important;
      overflow-x: hidden;
    }

    #email-root *,
    #email-root *::before,
    #email-root *::after {
      max-width: 100% !important;
      min-width: 0 !important;
    }

    img,
    svg,
    video,
    canvas {
      max-width: 100% !important;
      height: auto !important;
    }

    img[data-ee-remote-src]:not([src]) {
      display: inline-block;
      min-width: 112px;
      min-height: 64px;
      border: 1px dashed $border;
      border-radius: 8px;
      background:
        linear-gradient(135deg, color-mix(in srgb, $border 22%, transparent) 25%, transparent 25%) 0 0 / 16px 16px,
        color-mix(in srgb, $border 10%, transparent);
      object-fit: contain;
    }

    table {
      width: auto !important;
      max-width: 100% !important;
      min-width: 0 !important;
      border-collapse: collapse;
    }

    table[width],
    table[style*="width" i],
    table[style*="min-width" i] {
      width: 100% !important;
    }

    col,
    colgroup {
      width: auto !important;
      max-width: 100% !important;
      min-width: 0 !important;
    }

    td,
    th {
      width: auto !important;
      max-width: 100% !important;
      min-width: 0 !important;
      overflow-wrap: anywhere;
    }

    [nowrap],
    [style*="white-space" i] {
      white-space: normal !important;
    }

    [width],
    [style*="width" i],
    [style*="min-width" i] {
      max-width: 100% !important;
      min-width: 0 !important;
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
  <script nonce="$scriptNonce">
    (() => {
      const contextTargetFor = (rawTarget) => {
        const target = rawTarget instanceof Element
          ? rawTarget
          : rawTarget && rawTarget.parentElement;
        if (!target) return null;

        const image = target.closest('img');
        const link = target.closest('a[href]');
        if (!image && !link) return null;

        const imageUrl = image
          ? image.currentSrc || image.getAttribute('src') || image.dataset.eeRemoteSrc || ''
          : '';
        const linkUrl = link ? link.getAttribute('href') || link.href || '' : '';
        const text = (link ? link.innerText : target.innerText || '').trim();

        return {
          type: image ? 'image' : 'link',
          imageUrl,
          linkUrl,
          text,
          imageBlocked: Boolean(image && image.dataset.eeRemoteSrc && !image.getAttribute('src'))
        };
      };

      const postContextTarget = (target) => {
        if (!target || !window.EveryEmailContext) return;
        window.EveryEmailContext.postMessage(JSON.stringify(target));
      };

      let longPressTimer = null;
      let longPressTarget = null;
      let touchStartX = 0;
      let touchStartY = 0;
      let lastContextPostAt = 0;

      const clearLongPress = () => {
        if (longPressTimer) window.clearTimeout(longPressTimer);
        longPressTimer = null;
        longPressTarget = null;
      };

      const scheduleLongPress = (event, clientX, clientY) => {
        clearLongPress();
        longPressTarget = contextTargetFor(event.target);
        if (!longPressTarget) return;
        touchStartX = clientX;
        touchStartY = clientY;
        longPressTimer = window.setTimeout(() => {
          lastContextPostAt = Date.now();
          postContextTarget(longPressTarget);
          clearLongPress();
        }, 560);
      };

      const handleTouchMove = (event) => {
        if (!longPressTimer || !event.touches || event.touches.length === 0) return;
        const touch = event.touches[0];
        if (
          Math.abs(touch.clientX - touchStartX) > 10 ||
          Math.abs(touch.clientY - touchStartY) > 10
        ) {
          clearLongPress();
        }
      };

      document.addEventListener('touchstart', (event) => {
        if (!event.touches || event.touches.length !== 1) return;
        const touch = event.touches[0];
        scheduleLongPress(event, touch.clientX, touch.clientY);
      }, { passive: true });
      document.addEventListener('touchmove', handleTouchMove, { passive: true });
      document.addEventListener('touchend', clearLongPress, { passive: true });
      document.addEventListener('touchcancel', clearLongPress, { passive: true });
      document.addEventListener('mousedown', (event) => {
        if (event.button !== 0) return;
        scheduleLongPress(event, event.clientX, event.clientY);
      });
      document.addEventListener('mouseup', clearLongPress);
      document.addEventListener('mouseleave', clearLongPress);
      document.addEventListener('contextmenu', (event) => {
        const target = contextTargetFor(event.target);
        if (!target) return;
        event.preventDefault();
        const now = Date.now();
        if (now - lastContextPostAt < 450) return;
        lastContextPostAt = now;
        postContextTarget(target);
      });

      const constrainWidth = () => {
        const root = document.getElementById('email-root');
        if (!root) return;

        const viewportWidth = Math.max(
          root.clientWidth || 0,
          document.documentElement ? document.documentElement.clientWidth : 0,
          window.innerWidth || 0
        );
        if (viewportWidth <= 0) return;

        root
          .querySelectorAll(
            'table, col, colgroup, td, th, img, svg, video, canvas, pre, [width], [nowrap], [style]'
          )
          .forEach((element) => {
            const tagName = element.tagName;
            const styleText = (element.getAttribute('style') || '').toLowerCase();
            const constrainsWidth =
              element.hasAttribute('width') ||
              element.hasAttribute('nowrap') ||
              styleText.includes('width') ||
              styleText.includes('min-width') ||
              styleText.includes('white-space') ||
              element.scrollWidth > viewportWidth;

            if (!constrainsWidth && tagName !== 'TABLE') return;

            element.style.setProperty('max-width', '100%', 'important');
            element.style.setProperty('min-width', '0', 'important');

            if (tagName === 'TABLE') {
              element.style.setProperty('width', '100%', 'important');
            } else if (
              tagName === 'TD' ||
              tagName === 'TH' ||
              tagName === 'COL' ||
              tagName === 'COLGROUP' ||
              element.scrollWidth > viewportWidth
            ) {
              element.style.setProperty('width', 'auto', 'important');
            }

            if (
              element.hasAttribute('nowrap') ||
              styleText.includes('white-space')
            ) {
              element.style.setProperty('white-space', 'normal', 'important');
            }
          });
      };
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
        constrainWidth();
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
    return _PreparedEmailHtmlDocument(
      html: html,
      hasRemoteImages: hasRemoteImages,
    );
  }

  bool _sanitizeNode(dom.Node node) {
    var hasRemoteImages = false;
    for (final child in node.nodes.toList()) {
      if (child is! dom.Element) {
        continue;
      }

      final tag = child.localName?.toLowerCase();
      if (tag == null || _blockedTags.contains(tag)) {
        child.remove();
        continue;
      }

      hasRemoteImages = _sanitizeAttributes(child) || hasRemoteImages;
      if (tag == 'style') {
        hasRemoteImages =
            _containsRemoteImageCss(child.text) || hasRemoteImages;
        child.text = _sanitizeCss(child.text).replaceAll(_cssImport, '');
      }
      hasRemoteImages = _sanitizeNode(child) || hasRemoteImages;
    }
    return hasRemoteImages;
  }

  bool _sanitizeAttributes(dom.Element element) {
    var hasRemoteImages = false;
    final tag = element.localName?.toLowerCase();

    for (final key in element.attributes.keys.toList()) {
      final name = key.toString().toLowerCase();
      final value = element.attributes[key] ?? '';

      if (name.startsWith('on') || _blockedAttributes.contains(name)) {
        element.attributes.remove(key);
        continue;
      }

      if (tag == 'img' && name == 'src') {
        final remoteImageUrl = _safeRemoteImageUri(value);
        if (remoteImageUrl != null) {
          hasRemoteImages = true;
          if (!loadRemoteImages) {
            element.attributes.remove(key);
            element.attributes['data-ee-remote-src'] = remoteImageUrl;
            element.attributes.putIfAbsent('alt', () => '远程图片未加载');
          } else {
            element.attributes[key] = remoteImageUrl;
          }
          continue;
        }
      }

      if (tag == 'img' && name == 'srcset') {
        final remoteImageUrl = _firstSafeRemoteSrcsetUri(value);
        if (remoteImageUrl != null) {
          hasRemoteImages = true;
          if (!loadRemoteImages &&
              !element.attributes.containsKey('src') &&
              !element.attributes.containsKey('data-ee-remote-src')) {
            element.attributes['data-ee-remote-src'] = remoteImageUrl;
            element.attributes.putIfAbsent('alt', () => '远程图片未加载');
          } else if (loadRemoteImages &&
              !element.attributes.containsKey('src')) {
            element.attributes['src'] = remoteImageUrl;
          }
        }
        element.attributes.remove(key);
        continue;
      }

      if (_uriAttributes.contains(name) && _isUnsafeUri(name, value)) {
        element.attributes.remove(key);
        continue;
      }

      if (name == 'style') {
        hasRemoteImages = _containsRemoteImageCss(value) || hasRemoteImages;
        final sanitized = _sanitizeCss(value).trim();
        if (sanitized.isEmpty) {
          element.attributes.remove(key);
        } else {
          element.attributes[key] = sanitized;
        }
      }
    }

    if (tag == 'img') {
      element.attributes['referrerpolicy'] = 'no-referrer';
      element.attributes['decoding'] = 'async';
      element.attributes['loading'] = 'lazy';
    }

    if (tag == 'a') {
      element.attributes['target'] = '_blank';
      element.attributes['rel'] = 'noopener noreferrer nofollow';
      element.attributes['referrerpolicy'] = 'no-referrer';
    }

    return hasRemoteImages;
  }

  bool _isUnsafeUri(String attributeName, String value) {
    if (attributeName == 'srcset') {
      return true;
    }

    final normalized = value
        .trimLeft()
        .replaceAll(_controlAndWhitespace, '')
        .toLowerCase();
    if (normalized.isEmpty) return false;
    if (attributeName == 'href' && normalized.startsWith('#')) return false;
    if (normalized.startsWith('javascript:') ||
        normalized.startsWith('vbscript:') ||
        normalized.startsWith('file:')) {
      return true;
    }

    if (attributeName == 'href') {
      final uri = Uri.tryParse(normalized);
      if (uri == null || !uri.hasScheme) return true;
      return switch (uri.scheme) {
        'http' || 'https' || 'mailto' || 'tel' => false,
        _ => true,
      };
    }

    if (_isAllowedInlineImageUri(normalized) || normalized.startsWith('cid:')) {
      return false;
    }

    if (loadRemoteImages && _safeRemoteImageUri(normalized) != null) {
      return false;
    }

    return true;
  }

  String _sanitizeCss(String css) {
    return css
        .replaceAll(_cssExpression, '')
        .replaceAll(_cssUnsafeUrl, 'none')
        .replaceAllMapped(_cssUrl, (match) {
          final url = (match.group(2) ?? '')
              .trimLeft()
              .replaceAll(_controlAndWhitespace, '')
              .toLowerCase();
          if (_isAllowedInlineImageUri(url) ||
              url.startsWith('cid:') ||
              (loadRemoteImages && _safeRemoteImageUri(url) != null)) {
            return match.group(0) ?? '';
          }
          return 'none';
        })
        .replaceAll(_cssBehavior, '')
        .replaceAll(_cssPointerSelection, '')
        .replaceAll(_cssTouchCallout, '')
        .replaceAll(_cssImport, '')
        .replaceAll(_cssFontFace, '')
        .replaceAll(_cssFixedPosition, '');
  }

  String? _safeRemoteImageUri(String value) {
    final cleaned = value.trimLeft().replaceAll(_controlAndWhitespace, '');
    final uri = Uri.tryParse(cleaned);
    if (uri == null || !uri.hasScheme) return null;
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return null;
    if (uri.host.isEmpty) return null;
    return cleaned;
  }

  String? _firstSafeRemoteSrcsetUri(String value) {
    for (final candidate in value.split(',')) {
      final parts = candidate.trim().split(RegExp(r'\s+'));
      if (parts.isEmpty) continue;
      final url = _safeRemoteImageUri(parts.first);
      if (url != null) return url;
    }
    return null;
  }

  bool _containsRemoteImageCss(String css) {
    return _cssUrl.allMatches(css).any((match) {
      final url = match.group(2);
      return url != null && _safeRemoteImageUri(url) != null;
    });
  }

  bool _isAllowedInlineImageUri(String normalized) {
    return normalized.startsWith('data:image/png') ||
        normalized.startsWith('data:image/jpeg') ||
        normalized.startsWith('data:image/jpg') ||
        normalized.startsWith('data:image/gif') ||
        normalized.startsWith('data:image/webp') ||
        normalized.startsWith('data:image/bmp') ||
        normalized.startsWith('data:image/avif');
  }

  String _createCspNonce() {
    final random = math.Random.secure();
    final bytes = List<int>.generate(
      _scriptNonceByteCount,
      (_) => random.nextInt(256),
      growable: false,
    );
    return base64Url.encode(bytes).replaceAll('=', '');
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
