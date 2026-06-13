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
    this.senderEmail,
    this.autoLoadRemoteImages = false,
    this.onTrustSender,
    super.key,
  });

  final String htmlBody;
  final TextStyle? textStyle;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color linkColor;
  final Color borderColor;
  final Future<bool> Function(String url) onOpenUrl;

  /// 发件人地址，用于「信任该发件人」提示文案。
  final String? senderEmail;

  /// 发件人已受信（用户名单或预置名单）：远程图片直接加载，不显示拦截条。
  final bool autoLoadRemoteImages;

  /// 用户在手动加载图片后选择信任发件人时回调（由调用方持久化）。
  /// 为 null（或 [senderEmail] 为空）时不提供信任入口。
  final Future<void> Function()? onTrustSender;

  @override
  State<MessageHtmlView> createState() => _MessageHtmlViewState();
}

class _MessageHtmlViewState extends State<MessageHtmlView>
    with AutomaticKeepAliveClientMixin<MessageHtmlView> {
  static const String _baseUrl = 'https://everyemail.local/';
  static const String _baseHost = 'everyemail.local';
  static const double _initialHeight = 220;
  // Floor for the measured body height. The body keeps 12px top/bottom
  // padding, so an essentially empty document is ~24px; clamp to that (rather
  // than a tall fixed minimum) so short replies hug their content instead of
  // being padded out with blank space in the conversation list.
  static const double _contentFloorHeight = 24;
  static const double _heightUpdateTolerance = 4;
  static const int _asyncBuildThreshold = 8192;
  static const Duration _preRenderedRevealDelay = Duration(milliseconds: 80);
  static const Duration _revealFallbackDelay = Duration(milliseconds: 1200);
  static const Duration _absoluteRevealDelay = Duration(milliseconds: 3000);
  static const Duration _revealGrowthDuration = Duration(milliseconds: 240);
  static const List<Duration> _heightProbeDelays = [
    Duration(milliseconds: 120),
    Duration(milliseconds: 600),
    Duration(milliseconds: 1800),
  ];

  WebViewController? _controller;
  Object? _controllerError;
  final GlobalKey _webViewKey = GlobalKey();
  final List<Timer> _heightTimers = [];
  ScrollPosition? _scrollPosition;
  Timer? _snapshotRefreshTimer;
  Timer? _preRenderedRevealTimer;
  Timer? _revealFallbackTimer;
  Timer? _absoluteRevealTimer;
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
  bool _documentReady = false;
  bool _webViewVisible = false;
  bool _heightUpdateScheduled = false;
  bool _controllerCreateScheduled = false;
  bool _snapshotCaptureInFlight = false;
  bool _inPredictiveBackTransition = false;
  bool _hasRemoteImages = false;
  bool _loadRemoteImages = false;
  bool _trustOfferVisible = false;
  bool _contextMenuOpen = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadRemoteImages = widget.autoLoadRemoteImages;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bindScrollPosition();
    _ensureControllerCreated();
  }

  @override
  void didUpdateWidget(covariant MessageHtmlView oldWidget) {
    super.didUpdateWidget(oldWidget);

    var needsReload = _shouldReload(oldWidget);
    if (oldWidget.htmlBody != widget.htmlBody) {
      _clearTransitionSnapshot();
      _hasRemoteImages = false;
      _loadRemoteImages = widget.autoLoadRemoteImages;
      _trustOfferVisible = false;
    } else if (widget.autoLoadRemoteImages && !oldWidget.autoLoadRemoteImages) {
      // 阅读期间发件人被信任（比如会话里另一张同发件人卡片上点了「信任」）：
      // 提示条不再需要；尚未手动加载过的正文就地重载出图。
      _trustOfferVisible = false;
      if (!_loadRemoteImages) {
        _loadRemoteImages = true;
        needsReload = needsReload || _hasRemoteImages;
      }
    }

    if (_controller == null && _controllerError == null) {
      _ensureControllerCreated();
    }

    if (needsReload) {
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
    _scrollPosition?.removeListener(_handleAncestorScroll);
    _snapshotRefreshTimer?.cancel();
    _preRenderedRevealTimer?.cancel();
    _revealFallbackTimer?.cancel();
    _absoluteRevealTimer?.cancel();
    _cancelHeightTimers();
    super.dispose();
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

  void _ensureControllerCreated() {
    if (_controller != null ||
        _controllerError != null ||
        _controllerCreateScheduled) {
      return;
    }

    _controllerCreateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controllerCreateScheduled = false;
      if (!mounted || _controller != null || _controllerError != null) {
        return;
      }
      _createController();
    });
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
      'EveryEmailReady',
      onMessageReceived: _handleReadyMessage,
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
    await _tryConfigureWebView(() async {
      if (!await controller.supportsSetScrollBarsEnabled()) return;
      await controller.setVerticalScrollBarEnabled(false);
      await controller.setHorizontalScrollBarEnabled(false);
    });
    await _tryConfigureWebView(
      () => controller.setOverScrollMode(WebViewOverScrollMode.never),
    );

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
    _preRenderedRevealTimer?.cancel();
    _revealFallbackTimer?.cancel();
    _absoluteRevealTimer?.cancel();
    _clearTransitionSnapshot();
    _pageLoaded = false;
    _documentReady = false;
    _webViewVisible = false;
    _pendingHeight = null;
    if (mounted) {
      setState(() {
        if (resetHeight) {
          _height = _initialHeight;
        }
        _progress = 0;
        _webViewVisible = false;
      });
    }

    final input = _EmailHtmlDocumentInput(
      loadToken: loadSerial,
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
    _scheduleAbsoluteReveal(loadSerial);
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
    _preRenderedRevealTimer?.cancel();
    _revealFallbackTimer?.cancel();
    _absoluteRevealTimer?.cancel();
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
    _scheduleRevealFallback();
    _schedulePreRenderedReveal();
  }

  void _handleHeightMessage(JavaScriptMessage message) {
    final measuredHeight = _parseCurrentDocumentHeight(message.message);
    if (measuredHeight == null) return;
    _queueHeightUpdate(measuredHeight);
  }

  void _handleReadyMessage(JavaScriptMessage message) {
    final measuredHeight = _parseCurrentDocumentHeight(message.message);
    if (measuredHeight == null) return;
    _queueHeightUpdate(measuredHeight);
    _documentReady = true;
    _schedulePreRenderedReveal();
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

  /// 是否能在手动加载图片后给出「信任该发件人」提示。
  bool get _canOfferTrust {
    final senderEmail = widget.senderEmail?.trim();
    return !widget.autoLoadRemoteImages &&
        widget.onTrustSender != null &&
        senderEmail != null &&
        senderEmail.isNotEmpty;
  }

  Future<void> _enableRemoteImages() async {
    if (_loadRemoteImages) return;
    final offerTrust = _canOfferTrust;
    setState(() {
      _loadRemoteImages = true;
      _trustOfferVisible = offerTrust;
    });
    await _loadHtml(resetHeight: false);
    // 提示条本身已说明图片在加载，仅在没有信任入口时用快讯兜底反馈。
    if (!offerTrust) _showSnackBar('已允许加载此邮件的图片');
  }

  Future<void> _trustSender() async {
    final onTrustSender = widget.onTrustSender;
    if (onTrustSender == null) return;
    setState(() => _trustOfferVisible = false);
    try {
      await onTrustSender();
      _showSnackBar('已信任该发件人，其邮件中的图片将自动加载');
    } catch (_) {
      if (mounted) setState(() => _trustOfferVisible = true);
      _showSnackBar('保存信任发件人失败，请重试');
    }
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
  if (typeof window.__EveryEmailMeasureHeight === 'function') {
    return window.__EveryEmailMeasureHeight();
  }
  const body = document.body;
  const viewport = document.getElementById('email-viewport');
  const root = document.getElementById('email-root');
  const bodyStyle = body ? window.getComputedStyle(body) : null;
  const paddingTop = bodyStyle ? parseFloat(bodyStyle.paddingTop) || 0 : 0;
  const paddingBottom = bodyStyle ? parseFloat(bodyStyle.paddingBottom) || 0 : 0;
  const viewportRect = viewport ? viewport.getBoundingClientRect() : null;
  const rootRect = root ? root.getBoundingClientRect() : null;
  return Math.ceil(Math.max(
    viewportRect ? viewportRect.height : 0,
    viewport ? viewport.offsetHeight : 0,
    rootRect ? rootRect.height : 0,
    root ? root.offsetHeight : 0
  ) + paddingTop + paddingBottom);
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

    final nextHeight = measuredHeight < _contentFloorHeight
        ? _contentFloorHeight
        : measuredHeight.toDouble();
    final comparisonHeight = _pendingHeight ?? _height;
    if ((nextHeight - comparisonHeight).abs() < _heightUpdateTolerance) return;

    _pendingHeight = nextHeight;
    if (_heightUpdateScheduled) return;

    _heightUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _heightUpdateScheduled = false;
      final pendingHeight = _pendingHeight;
      _pendingHeight = null;
      if (!mounted || pendingHeight == null) return;
      if ((pendingHeight - _height).abs() < _heightUpdateTolerance) return;
      setState(() => _height = pendingHeight);
      _schedulePreRenderedReveal();
      _scheduleSnapshotRefresh(const Duration(milliseconds: 160));
    });
  }

  double? _parseJsNumber(Object? value) {
    if (value is num) return value.toDouble();
    final text = value?.toString().replaceAll('"', '').trim();
    if (text == null || text.isEmpty) return null;
    return double.tryParse(text);
  }

  double? _parseCurrentDocumentHeight(String message) {
    final separator = message.indexOf(':');
    if (separator <= 0) {
      return _parseJsNumber(message);
    }

    final token = int.tryParse(message.substring(0, separator));
    if (token != _loadSerial) return null;
    return _parseJsNumber(message.substring(separator + 1));
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

  void _schedulePreRenderedReveal() {
    if (!mounted || _webViewVisible || !_pageLoaded || !_documentReady) {
      return;
    }

    _preRenderedRevealTimer?.cancel();
    _preRenderedRevealTimer = Timer(_preRenderedRevealDelay, _revealNow);
  }

  void _scheduleRevealFallback() {
    if (_webViewVisible || _documentReady) return;

    _revealFallbackTimer?.cancel();
    _revealFallbackTimer = Timer(_revealFallbackDelay, () {
      if (!mounted || _webViewVisible || !_pageLoaded) return;
      // The in-page readiness signal never arrived (a script error in the
      // document, a channel hiccup, or a platform quirk). Reveal anyway: a
      // height probe has almost certainly measured the body by now, and it must
      // never be left stuck permanently behind the skeleton.
      _documentReady = true;
      _revealNow();
    });
  }

  void _scheduleAbsoluteReveal(int loadSerial) {
    _absoluteRevealTimer?.cancel();
    _absoluteRevealTimer = Timer(_absoluteRevealDelay, () {
      if (!mounted || _webViewVisible || loadSerial != _loadSerial) return;
      // Last-resort safety net for the case the pageFinished callback itself
      // never fires (a dropped platform callback), which would otherwise leave
      // _scheduleRevealFallback unarmed and the body stuck forever. Local HTML
      // has almost certainly finished loading by now, so force the document
      // ready and reveal — scrollbars are disabled, there is no other way out.
      _pageLoaded = true;
      _documentReady = true;
      _revealNow();
    });
  }

  void _revealNow() {
    if (!mounted || _webViewVisible || !_pageLoaded) return;

    _preRenderedRevealTimer?.cancel();
    _revealFallbackTimer?.cancel();
    _absoluteRevealTimer?.cancel();
    // The WebView has been measured and fully painted behind the skeleton, so
    // flip it visible in a single step. _buildFrame's AnimatedSize turns the
    // placeholder -> content height delta into one smooth growth instead of the
    // height ratcheting up probe by probe.
    setState(() => _webViewVisible = true);
    _scheduleSnapshotRefresh(const Duration(milliseconds: 160));
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
    final loadedContent = _buildLoadedContent(webView);
    if (!_webViewVisible) {
      return _buildFrame(child: _buildPreRenderedPlaceholder(loadedContent));
    }

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

      return _buildFrame(child: loadedContent);
    }

    return _buildFrame(
      child: Stack(
        children: [
          loadedContent,
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

  Widget _buildPreRenderedPlaceholder(Widget content) {
    // Keep the live (still hidden) WebView mounted at its measured height so it
    // is fully painted by the time we reveal it, but clip it to a stable
    // placeholder height. Without this clamp the surrounding conversation list
    // would grow bit by bit as the height probes settle; instead the single
    // growth to the final height happens once, animated, in _buildFrame when
    // [_webViewVisible] flips.
    return SizedBox(
      height: _initialHeight,
      child: ClipRect(
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(child: content),
            ),
            Positioned.fill(
              child: ColoredBox(
                color: widget.backgroundColor,
                child: _buildDeferredPlaceholder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadedContent(Widget webViewContent) {
    if (_hasRemoteImages && !_loadRemoteImages) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [_buildRemoteImagePrompt(), webViewContent],
      );
    }

    if (_trustOfferVisible) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [_buildTrustSenderOffer(), webViewContent],
      );
    }

    return webViewContent;
  }

  Widget _buildRemoteImagePrompt() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
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
      ),
    );
  }

  /// 手动加载图片后的跟进提示：可一键信任该发件人，以后自动加载。
  Widget _buildTrustSenderOffer() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
          child: Row(
            children: [
              Icon(
                Icons.verified_user_outlined,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '信任 ${widget.senderEmail?.trim()}？其邮件中的图片将自动加载',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => unawaited(_trustSender()),
                child: const Text('信任'),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                iconSize: 18,
                tooltip: '关闭',
                onPressed: () => setState(() => _trustOfferVisible = false),
              ),
            ],
          ),
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
        child: AnimatedSize(
          duration: _revealGrowthDuration,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: SizedBox(width: double.infinity, child: content),
        ),
      ),
    );
  }
}

_PreparedEmailHtmlDocument _buildEmailHtmlDocument(
  _EmailHtmlDocumentInput input,
) {
  return _EmailHtmlDocument(
    loadToken: input.loadToken,
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
  int backgroundColorValue = 0xffffffff,
  int foregroundColorValue = 0xff000000,
  int linkColorValue = 0xff1a73e8,
  int borderColorValue = 0xffdadce0,
}) {
  return _EmailHtmlDocument(
    loadToken: 0,
    rawHtml: rawHtml,
    fontSize: 14,
    lineHeight: 1.45,
    fontWeight: 400,
    backgroundColorValue: backgroundColorValue,
    foregroundColorValue: foregroundColorValue,
    linkColorValue: linkColorValue,
    borderColorValue: borderColorValue,
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
    required this.loadToken,
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

  final int loadToken;
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
    required this.loadToken,
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
  // Length tokens used to decide whether a blocked image declares a reservable
  // box (see [_isReservableLength]). Zero is rejected by the numeric check, not
  // these patterns.
  static final RegExp _reservableLength = RegExp(
    r'^\d+(?:\.\d+)?(?:px|em|rem|ex|ch|pt|pc|cm|mm|in|vh|vw|vmin|vmax)?$',
  );
  static final RegExp _reservablePercent = RegExp(r'^\d+(?:\.\d+)?%$');
  static final RegExp _leadingNumber = RegExp(r'^\d+(?:\.\d+)?');
  static const int _scriptNonceByteCount = 16;
  // Standard light-theme link blue. In dark mode the document is rendered with
  // a light palette and flipped by an invert+hue-rotate filter, which turns
  // this into a readable bright blue while keeping the hue.
  static const int _lightLinkValue = 0xff1a73e8;

  // Signals that an email ships its own dark styling, so we honor it (render
  // natively dark) instead of applying the invert filter.
  static final RegExp _prefersColorSchemeDark = RegExp(
    r'prefers-color-scheme\s*:\s*dark',
    caseSensitive: false,
  );
  static final RegExp _colorSchemeDeclaresDark = RegExp(
    r'color-scheme\s*:\s*[^;{}]*dark',
    caseSensitive: false,
  );
  static final RegExp _metaColorSchemeDark = RegExp(
    r'<meta[^>]*color-scheme[^>]*dark',
    caseSensitive: false,
  );

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

  final int loadToken;
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

    final isDark = _isDarkColor(backgroundColorValue);
    // Gmail-style policy: if the email ships its own dark styling (a
    // prefers-color-scheme:dark block, a color-scheme:dark declaration, or a
    // color-scheme meta), trust it and render natively dark — no inversion.
    // Only legacy light-only emails fall back to the CSS invert+hue-rotate
    // filter. On that filtered path the document is rendered with a light,
    // pre-compensated palette so the filter lands back on the app's dark colors
    // (see the [data-ee-invert] rules), turning genuine light backgrounds dark
    // instead of letting them glare against the dark UI.
    final emailDeclaresDark = isDark && _declaresDarkColorScheme();
    final useInvertFilter = isDark && !emailDeclaresDark;
    final invertAttr = useInvertFilter ? ' data-ee-invert="on"' : '';
    // color-scheme follows the rendered palette: dark only when we honor the
    // email's own dark styling (so its prefers-color-scheme:dark rules match and
    // UA defaults darken); light when rendering light or pre-inverted-for-filter.
    final colorSchemeName = emailDeclaresDark ? 'dark' : 'light';
    // On the filter path our own surface/text/border must land EXACTLY on the
    // app palette so the body is seamless with the Flutter card. The filter is
    // invert(1) THEN hue-rotate(180deg); inverting alone (the obvious choice)
    // ignores the hue-rotate, which shifts a tinted surface to the opposite hue
    // — e.g. the indigo-tinted dark card #302f37 came out warm #303129 (blue
    // channel off by 14), a visible gray seam against the card. Pre-image under
    // the full filter (invert∘hue-rotate, both self-inverse) lands it dead on.
    final background = _cssColor(
      useInvertFilter
          ? _preInvertForFilter(backgroundColorValue)
          : backgroundColorValue,
    );
    final foreground = _cssColor(
      useInvertFilter
          ? _preInvertForFilter(foregroundColorValue)
          : foregroundColorValue,
    );
    final link = _cssColor(useInvertFilter ? _lightLinkValue : linkColorValue);
    final border = _cssColor(
      useInvertFilter ? _preInvertForFilter(borderColorValue) : borderColorValue,
    );
    final scriptNonce = _createCspNonce();
    final imageSources = loadRemoteImages
        ? 'data: cid: http: https:'
        : 'data: cid:';

    final html =
        '''
<!doctype html>
<html$invertAttr>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="color-scheme" content="$colorSchemeName">
  <meta name="supported-color-schemes" content="light dark">
  <meta http-equiv="Content-Security-Policy" content="default-src 'none'; base-uri 'none'; child-src 'none'; connect-src 'none'; font-src 'none'; form-action 'none'; frame-src 'none'; img-src $imageSources; media-src 'none'; object-src 'none'; script-src 'nonce-$scriptNonce'; style-src 'unsafe-inline'">
  <style>
    :root {
      color-scheme: $colorSchemeName;
      --ee-bg: $background;
      --ee-fg: $foreground;
      --ee-link: $link;
      --ee-border: $border;
    }

    html,
    body {
      width: 100%;
      max-width: 100%;
      min-width: 0;
      min-height: 0;
      margin: 0;
      background: var(--ee-bg);
      color: var(--ee-fg);
      overflow: hidden;
      overscroll-behavior: none;
      scrollbar-width: none;
      -ms-overflow-style: none;
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

    html::-webkit-scrollbar,
    body::-webkit-scrollbar {
      width: 0;
      height: 0;
      display: none;
    }

    a {
      color: var(--ee-link);
      text-decoration-color: color-mix(in srgb, var(--ee-link) 45%, transparent);
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
    html,
    body {
      background: var(--ee-bg) !important;
      color: var(--ee-fg) !important;
      overflow: hidden !important;
      /* Contain any horizontal padding (ours, or one the email sets on body via
         a preserved <style>) inside the 100% width. Without this the body is
         content-box, so e.g. an email's `body{padding:10px}` adds 10px OUTSIDE
         the forced width:100% — shoving content right and clipping it against
         the WebView's right edge (a real browser dodges this: its body width is
         auto, not 100%). */
      box-sizing: border-box !important;
    }

    #email-viewport,
    #email-root {
      box-sizing: border-box;
    }

    #email-viewport {
      width: 100%;
      max-width: 100%;
      min-width: 0;
      overflow: hidden;
      scrollbar-width: none;
      -ms-overflow-style: none;
      background: transparent;
    }

    #email-viewport::-webkit-scrollbar {
      width: 0;
      height: 0;
      display: none;
    }

    #email-root {
      display: block;
      width: auto;
      max-width: none;
      min-width: 0;
      overflow: visible;
      color: inherit;
      transform-origin: top left;
    }

    #email-root.ee-scaled {
      width: var(--ee-layout-width) !important;
      transform: scale(var(--ee-scale));
    }

    #email-root a:not([style*="color" i]) {
      color: var(--ee-link);
    }

    /* Cap every email image — blocked placeholder and loaded image alike — to
       its containing block so neither overflows a fluid container. max-width
       is container-relative, so fixed-width table layouts (which scale as a
       whole) are untouched. Height is intentionally left to the image's own
       attributes/CSS so a declared height is preserved in both states. */
    #email-root img {
      max-width: 100%;
    }

    /* Blocked image placeholder: paint-only hint. Its box comes entirely from
       the shared #email-root img rule above plus the image's own declared size,
       so the placeholder occupies the same box the image will once loaded. */
    img[data-ee-remote-src]:not([src]) {
      border-radius: 8px;
      box-shadow: inset 0 0 0 1px color-mix(in srgb, var(--ee-border) 55%, transparent);
      background:
        linear-gradient(135deg, color-mix(in srgb, var(--ee-border) 22%, transparent) 25%, transparent 25%) 0 0 / 16px 16px,
        color-mix(in srgb, var(--ee-border) 10%, transparent);
      object-fit: contain;
    }

    /* Keep a placeholder visible and long-pressable to "load images", but floor
       ONLY the axis the image does not size itself on. Flooring an axis the
       image already declares (e.g. a width="24" icon) would inflate horizontal
       table rows and shrink the whole email down while images are blocked —
       data-ee-w / data-ee-h are set by the sanitizer per declared axis. */
    img[data-ee-remote-src]:not([data-ee-w]):not([src]) {
      min-width: 112px;
    }

    img[data-ee-remote-src]:not([data-ee-h]):not([src]) {
      min-height: 64px;
    }

    blockquote {
      border-left-color: var(--ee-border);
    }

    html,
    body,
    #email-viewport,
    #email-root,
    #email-root * {
      -webkit-touch-callout: default !important;
      -webkit-user-select: text !important;
      user-select: text !important;
    }

    html[data-ee-invert] body {
      /* The document is rendered with a light palette; flip the whole body to
         dark in one pass. invert reverses lightness, hue-rotate(180deg) brings
         hues back so brand colors survive and only light/dark swaps. Genuine
         light backgrounds in the email become dark instead of glaring. */
      filter: invert(1) hue-rotate(180deg);
    }

    html[data-ee-invert] #email-root img,
    html[data-ee-invert] #email-root svg,
    html[data-ee-invert] #email-root video,
    html[data-ee-invert] #email-root canvas,
    html[data-ee-invert] #email-root picture {
      /* Undo the body inversion for real media so photos render normally. */
      filter: invert(1) hue-rotate(180deg);
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

      const getLayoutNodes = () => {
        return {
          body: document.body,
          viewport: document.getElementById('email-viewport'),
          root: document.getElementById('email-root')
        };
      };

      const parsePixels = (value) => {
        const parsed = Number.parseFloat(value);
        return Number.isFinite(parsed) ? parsed : 0;
      };

      const resetFit = (root) => {
        root.classList.remove('ee-scaled');
        root.style.removeProperty('--ee-layout-width');
        root.style.removeProperty('--ee-scale');
      };

      const measureNaturalWidth = (root) => {
        const rootRect = root.getBoundingClientRect();
        const rootLeft = rootRect.left;
        let width = Math.max(root.scrollWidth, root.offsetWidth, rootRect.width);

        root
          .querySelectorAll(
            'table, img, svg, video, canvas, pre, blockquote, [width], [style]'
          )
          .forEach((element) => {
            const rect = element.getBoundingClientRect();
            if (rect.width > 0) {
              width = Math.max(width, rect.right - rootLeft);
            }
            if (element.scrollWidth > 0) {
              const offsetLeft = Math.max(0, rect.left - rootLeft);
              width = Math.max(width, offsetLeft + element.scrollWidth);
            }
          });

        return Math.ceil(width);
      };

      const fitContent = () => {
        const { viewport, root } = getLayoutNodes();
        if (!viewport || !root) {
          return { height: 0, scaled: false };
        }

        resetFit(root);
        const viewportWidth = Math.floor(
          viewport.clientWidth ||
          document.documentElement.clientWidth ||
          window.innerWidth ||
          0
        );
        if (viewportWidth <= 0) {
          return { height: 0, scaled: false };
        }

        const naturalWidth = Math.max(viewportWidth, measureNaturalWidth(root));
        const shouldScale = naturalWidth > viewportWidth + 2;
        if (shouldScale) {
          const scale = Math.min(1, viewportWidth / naturalWidth);
          root.style.setProperty('--ee-layout-width', naturalWidth + 'px');
          root.style.setProperty('--ee-scale', String(scale));
          root.classList.add('ee-scaled');

          const scaledHeight = Math.ceil(root.getBoundingClientRect().height);
          viewport.style.height = scaledHeight + 'px';
          return { height: scaledHeight, scaled: true };
        }

        viewport.style.removeProperty('height');
        const rootRect = root.getBoundingClientRect();
        const height = Math.ceil(Math.max(
          viewport.offsetHeight,
          viewport.scrollHeight,
          root.offsetHeight,
          root.scrollHeight,
          rootRect.height
        ));
        return { height, scaled: false };
      };

      const measure = () => {
        const { body } = getLayoutNodes();
        if (!body) return 0;

        const bodyStyle = window.getComputedStyle(body);
        const paddingTop = parsePixels(bodyStyle.paddingTop);
        const paddingBottom = parsePixels(bodyStyle.paddingBottom);
        const contentBox = fitContent();
        return Math.ceil(contentBox.height + paddingTop + paddingBottom);
      };

      window.__EveryEmailMeasureHeight = measure;

      let lastPostedHeight = 0;
      let loadComplete = document.readyState === 'complete';
      let readyPosted = false;
      const documentToken = '$loadToken';
      const postHeight = () => {
        const height = measure();
        if (
          height > 0 &&
          window.EveryEmailHeight &&
          Math.abs(height - lastPostedHeight) >= 1
        ) {
          lastPostedHeight = height;
          window.EveryEmailHeight.postMessage(documentToken + ':' + String(height));
        }
      };
      const postReady = () => {
        if (!loadComplete || readyPosted || !window.EveryEmailReady) return;
        const height = measure();
        if (height <= 0) return;
        readyPosted = true;
        window.EveryEmailReady.postMessage(documentToken + ':' + String(height));
      };
      const schedule = () => {
        requestAnimationFrame(() => {
          postHeight();
          requestAnimationFrame(() => {
            postHeight();
            postReady();
          });
        });
      };
      window.addEventListener('load', () => {
        loadComplete = true;
        schedule();
      });
      window.addEventListener('resize', schedule);
      document.addEventListener('DOMContentLoaded', () => {
        schedule();
        if ('ResizeObserver' in window) {
          const root = document.getElementById('email-root');
          // Observe only the content node, never documentElement/body: those
          // track the Flutter-set frame height and observing them is what made
          // the height feed back on itself. #email-root is content-driven, so a
          // height-only frame change cannot retrigger it, while genuine late
          // reflow (web font swap, image decode, details toggle) still does.
          if (root) new ResizeObserver(schedule).observe(root);
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
  <div id="email-viewport">
    <div id="email-root">$safeBodyHtml</div>
  </div>
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
      // Blocked placeholder: mark each axis the image already sizes itself on so
      // the min-width/min-height floors apply ONLY to the unknown axis. A small
      // icon that declares width="24" but no height must keep its 24px width —
      // flooring it to 112px would inflate horizontal table rows and scale the
      // whole email down while remote images are blocked.
      if (element.attributes.containsKey('data-ee-remote-src') &&
          !element.attributes.containsKey('src')) {
        if (_hasUsableWidth(element)) element.attributes['data-ee-w'] = '';
        if (_hasUsableHeight(element)) element.attributes['data-ee-h'] = '';
      }
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

  /// Whether a blocked image declares a width we can reserve, so its placeholder
  /// keeps that width instead of being floored to the dimensionless min-width.
  bool _hasUsableWidth(dom.Element element) {
    return _isReservableLength(element.attributes['width'], allowPercent: true) ||
        _styleDeclaresLength(
          element.attributes['style'],
          'width',
          allowPercent: true,
        );
  }

  /// Whether a blocked image declares a height we can reserve. A positive height
  /// attribute counts even with inline `height:auto`, since paired with a width
  /// attribute the browser maps it to an aspect-ratio that reserves the box.
  bool _hasUsableHeight(dom.Element element) {
    return _isReservableLength(element.attributes['height'], allowPercent: false) ||
        _styleDeclaresLength(
          element.attributes['style'],
          'height',
          allowPercent: false,
        );
  }

  bool _styleDeclaresLength(
    String? style,
    String property, {
    required bool allowPercent,
  }) {
    if (style == null || style.isEmpty) return false;
    for (final declaration in style.split(';')) {
      final separator = declaration.indexOf(':');
      if (separator <= 0) continue;
      final name = declaration.substring(0, separator).trim().toLowerCase();
      if (name != property) continue;
      return _isReservableLength(
        declaration.substring(separator + 1),
        allowPercent: allowPercent,
      );
    }
    return false;
  }

  /// A length is reservable when it resolves to a positive, concrete box: a
  /// positive number with an absolute/relative unit (px, em, vh, …) or a bare
  /// number (HTML width/height attributes are pixels). Percentages count only
  /// where [allowPercent] is set — a percentage width tracks its container, but
  /// a percentage height usually resolves against an auto-height parent (0).
  bool _isReservableLength(String? raw, {required bool allowPercent}) {
    if (raw == null) return false;
    final value = raw.trim().toLowerCase().replaceAll('!important', '').trim();
    if (value.isEmpty) return false;
    final isPercent = value.endsWith('%');
    if (isPercent && !allowPercent) return false;
    final matched = isPercent
        ? _reservablePercent.hasMatch(value)
        : _reservableLength.hasMatch(value);
    if (!matched) return false;
    final number = double.tryParse(
      _leadingNumber.firstMatch(value)?.group(0) ?? '',
    );
    return number != null && number > 0;
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

  bool _isDarkColor(int value) {
    final red = ((value >> 16) & 0xff) / 255;
    final green = ((value >> 8) & 0xff) / 255;
    final blue = (value & 0xff) / 255;

    double linearize(double component) {
      return component <= 0.03928
          ? component / 12.92
          : math.pow((component + 0.055) / 1.055, 2.4).toDouble();
    }

    final luminance =
        0.2126 * linearize(red) +
        0.7152 * linearize(green) +
        0.0722 * linearize(blue);
    return luminance < 0.5;
  }

  int _invertColorValue(int value) {
    final alpha = value & 0xff000000;
    final red = 0xff - ((value >> 16) & 0xff);
    final green = 0xff - ((value >> 8) & 0xff);
    final blue = 0xff - (value & 0xff);
    return alpha | (red << 16) | (green << 8) | blue;
  }

  /// Pre-image of [value] under the `data-ee-invert` filter, so a color rendered
  /// as this lands back EXACTLY on [value] after the WebView applies
  /// `invert(1) hue-rotate(180deg)`. Both primitives are self-inverse, so the
  /// pre-image of `hue-rotate(180) ∘ invert` is `invert ∘ hue-rotate(180)`.
  /// Inverting alone leaves the hue-rotate uncompensated and shifts tinted
  /// surfaces off-hue (the dark-mode card seam this corrects).
  int _preInvertForFilter(int value) => _invertColorValue(_hueRotate180(value));

  /// Applies the CSS `hue-rotate(180deg)` color matrix to an sRGB value (alpha
  /// preserved). Coefficients are the spec luma values with a=cos180°=-1,
  /// b=sin180°=0; rows sum to 1 so neutral grays are unchanged and only the
  /// chroma axis flips. Self-inverse (180° twice == 360°).
  int _hueRotate180(int value) {
    final alpha = value & 0xff000000;
    final red = (value >> 16) & 0xff;
    final green = (value >> 8) & 0xff;
    final blue = value & 0xff;
    int channel(double v) => v.clamp(0, 255).round();
    final r = channel(-0.574 * red + 1.430 * green + 0.144 * blue);
    final g = channel(0.426 * red + 0.430 * green + 0.144 * blue);
    final b = channel(0.426 * red + 1.430 * green - 0.856 * blue);
    return alpha | (r << 16) | (g << 8) | b;
  }

  /// Whether the email ships its own dark-mode styling, in which case we honor
  /// it (render natively dark) instead of applying the invert filter.
  bool _declaresDarkColorScheme() {
    return _prefersColorSchemeDark.hasMatch(rawHtml) ||
        _colorSchemeDeclaresDark.hasMatch(rawHtml) ||
        _metaColorSchemeDark.hasMatch(rawHtml);
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
