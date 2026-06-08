import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show clampDouble, lerpDouble;

import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PredictiveBackEvent, SwipeEdge;

import '../navigation/predictive_back_shared_element.dart';
import '../navigation/predictive_back_transition_scope.dart';
import '../../data/settings/app_font_settings.dart';
import 'expressive_colors.dart';
import 'mail_list_colors.dart';
import 'motion_tokens.dart';
import 'shape_scale.dart';
import 'typography.dart';

/// 应用主题工厂。
///
/// 在基础 Material 3 之上叠加「表现力层」：表现力字阶、Spark 涟漪，
/// 以及动效/形状/语义色三组 [ThemeExtension]。配色由外部传入
/// （动态取色或品牌回退），[font] 决定字体（系统字体或打包的 Google Sans Flex），
/// 故 light/dark 共用同一构建逻辑。
class AppTheme {
  const AppTheme._();

  static ThemeData light(ColorScheme scheme, AppFont font) =>
      _build(scheme, font);
  static ThemeData dark(ColorScheme scheme, AppFont font) =>
      _build(scheme, font);

  static ThemeData _build(ColorScheme scheme, AppFont font) {
    final ThemeData base = ThemeData(colorScheme: scheme, useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      // 页面转场：Android 启用预见式返回（Predictive Back）。
      //
      // 默认的 [ZoomPageTransitionsBuilder] 不参与系统预见式返回手势的连续驱动，
      // 手势开始/松手提交时缩放值会发生突变——即「开始和结束各闪一下」的根因。
      // [PredictiveBackPageTransitionsBuilder] 在手势阶段跟手连续驱动并平滑提交，
      // 这里额外在手势期间对路由内容做快照，避免邮件 HTML 正文和列表文字在
      // 缩放/圆角裁剪中逐帧重绘。
      // 需配合 AndroidManifest 的 android:enableOnBackInvokedCallback="true"（已开启）。
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android:
              SnapshottingPredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      textTheme: buildExpressiveTextTheme(base.textTheme, font: font),
      splashFactory: InkSparkle.splashFactory,
      extensions: <ThemeExtension<dynamic>>[
        const MotionTokens(),
        const ShapeScale(),
        ExpressiveColors.fromScheme(scheme),
      ],
    );
  }
}

/// Android predictive back normally transforms live route widgets. That is
/// expensive for long mail bodies because text layout and HTML rendering can be
/// repainted while the route is scaled and clipped. Snapshotting only while the
/// system back gesture is active keeps the gesture smooth while preserving live
/// widgets outside the transition.
class SnapshottingPredictiveBackPageTransitionsBuilder
    extends PageTransitionsBuilder {
  const SnapshottingPredictiveBackPageTransitionsBuilder({this.fallbackColor});

  final Color? fallbackColor;

  @override
  Duration get transitionDuration => const Duration(
    milliseconds: FadeForwardsPageTransitionsBuilder.kTransitionMilliseconds,
  );

  @override
  Duration get reverseTransitionDuration => transitionDuration;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _ShadowedPredictiveBackGestureDetector(
      route: route,
      builder:
          (
            context,
            phase,
            startBackEvent,
            currentBackEvent,
            finishCommitBackGesture,
          ) {
            final usePredictiveBackTransition =
                route.popGestureInProgress ||
                phase == _ShadowedPredictiveBackPhase.commit;
            final scopedChild = _PredictiveBackGestureSnapshot(
              route: route,
              active: usePredictiveBackTransition,
              child: PredictiveBackTransitionScope(
                active: usePredictiveBackTransition,
                committing: phase == _ShadowedPredictiveBackPhase.commit,
                child: child,
              ),
            );
            if (usePredictiveBackTransition) {
              return _ShadowedPredictiveBackSharedElementPageTransition(
                animation: animation,
                phase: phase,
                secondaryAnimation: secondaryAnimation,
                startBackEvent: startBackEvent,
                currentBackEvent: currentBackEvent,
                onCommitBackGestureFinished: finishCommitBackGesture,
                route: route,
                child: scopedChild,
              );
            }

            return FadeForwardsPageTransitionsBuilder(
              backgroundColor: fallbackColor,
            ).buildTransitions(
              route,
              context,
              animation,
              secondaryAnimation,
              scopedChild,
            );
          },
    );
  }
}

typedef _ShadowedPredictiveBackGestureBuilder =
    Widget Function(
      BuildContext context,
      _ShadowedPredictiveBackPhase phase,
      PredictiveBackEvent? startBackEvent,
      PredictiveBackEvent? currentBackEvent,
      _ShadowedPredictiveBackCommitCallback finishCommitBackGesture,
    );

enum _ShadowedPredictiveBackPhase { idle, start, update, commit, cancel }

typedef _ShadowedPredictiveBackCommitCallback =
    void Function({required bool completeRouteAnimation});

class _ShadowedPredictiveBackGestureDetector extends StatefulWidget {
  const _ShadowedPredictiveBackGestureDetector({
    required this.route,
    required this.builder,
  });

  final PageRoute<dynamic> route;
  final _ShadowedPredictiveBackGestureBuilder builder;

  @override
  State<_ShadowedPredictiveBackGestureDetector> createState() =>
      _ShadowedPredictiveBackGestureDetectorState();
}

class _ShadowedPredictiveBackGestureDetectorState
    extends State<_ShadowedPredictiveBackGestureDetector>
    with WidgetsBindingObserver {
  static const Duration _commitFallbackDelay = Duration(
    milliseconds:
        _ShadowedPredictiveBackSharedElementPageTransitionState
            ._sharedElementCommitMilliseconds +
        220,
  );

  _ShadowedPredictiveBackPhase _phase = _ShadowedPredictiveBackPhase.idle;
  PredictiveBackEvent? _startBackEvent;
  PredictiveBackEvent? _currentBackEvent;
  bool _commitBackGestureFinished = true;
  Timer? _commitFallbackTimer;

  bool get _isEnabled =>
      widget.route.isCurrent && widget.route.popGestureEnabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _commitFallbackTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) {
    _syncGesture(
      phase: _ShadowedPredictiveBackPhase.start,
      startBackEvent: backEvent,
      currentBackEvent: backEvent,
    );

    final gestureInProgress = !backEvent.isButtonEvent && _isEnabled;
    if (!gestureInProgress) return false;

    widget.route.handleStartBackGesture(progress: 1 - backEvent.progress);
    return true;
  }

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) {
    _syncGesture(
      phase: _ShadowedPredictiveBackPhase.update,
      currentBackEvent: backEvent,
    );
    widget.route.handleUpdateBackGestureProgress(
      progress: 1 - backEvent.progress,
    );
  }

  @override
  void handleCancelBackGesture() {
    _commitFallbackTimer?.cancel();
    _commitBackGestureFinished = true;
    _syncGesture(
      phase: _ShadowedPredictiveBackPhase.cancel,
      startBackEvent: null,
      currentBackEvent: null,
    );
    widget.route.handleCancelBackGesture();
  }

  @override
  void handleCommitBackGesture() {
    _commitFallbackTimer?.cancel();
    _commitBackGestureFinished = false;
    _syncGesture(
      phase: _ShadowedPredictiveBackPhase.commit,
      startBackEvent: null,
      currentBackEvent: null,
    );
    _commitFallbackTimer = Timer(_commitFallbackDelay, () {
      _finishCommitBackGesture(completeRouteAnimation: false);
    });
  }

  void _finishCommitBackGesture({required bool completeRouteAnimation}) {
    if (_commitBackGestureFinished) return;

    _commitBackGestureFinished = true;
    _commitFallbackTimer?.cancel();
    _commitFallbackTimer = null;

    if (completeRouteAnimation && widget.route.isCurrent) {
      widget.route.handleUpdateBackGestureProgress(progress: 0);
    }
    widget.route.handleCommitBackGesture();
  }

  void _syncGesture({
    required _ShadowedPredictiveBackPhase phase,
    Object? startBackEvent = _sentinel,
    Object? currentBackEvent = _sentinel,
  }) {
    if (!mounted) return;
    setState(() {
      _phase = phase;
      if (!identical(startBackEvent, _sentinel)) {
        _startBackEvent = startBackEvent as PredictiveBackEvent?;
      }
      if (!identical(currentBackEvent, _sentinel)) {
        _currentBackEvent = currentBackEvent as PredictiveBackEvent?;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final keepGesturePhase =
        widget.route.popGestureInProgress ||
        _phase == _ShadowedPredictiveBackPhase.commit;
    final effectivePhase = keepGesturePhase
        ? _phase
        : _ShadowedPredictiveBackPhase.idle;
    return widget.builder(
      context,
      effectivePhase,
      _startBackEvent,
      _currentBackEvent,
      _finishCommitBackGesture,
    );
  }

  static const Object _sentinel = Object();
}

class _ShadowedPredictiveBackSharedElementPageTransition
    extends StatefulWidget {
  const _ShadowedPredictiveBackSharedElementPageTransition({
    required this.animation,
    required this.secondaryAnimation,
    required this.phase,
    required this.startBackEvent,
    required this.currentBackEvent,
    required this.onCommitBackGestureFinished,
    required this.route,
    required this.child,
  });

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final _ShadowedPredictiveBackPhase phase;
  final PredictiveBackEvent? startBackEvent;
  final PredictiveBackEvent? currentBackEvent;
  final _ShadowedPredictiveBackCommitCallback onCommitBackGestureFinished;
  final PageRoute<dynamic> route;
  final Widget child;

  @override
  State<_ShadowedPredictiveBackSharedElementPageTransition> createState() =>
      _ShadowedPredictiveBackSharedElementPageTransitionState();
}

class _ShadowedPredictiveBackSharedElementPageTransitionState
    extends State<_ShadowedPredictiveBackSharedElementPageTransition>
    with SingleTickerProviderStateMixin {
  static const double _minScale = 0.90;
  static const double _divisionFactor = 20;
  static const double _margin = 8;
  static const double _yPositionFactor = 0.1;
  static const int _routeCommitMilliseconds = 400;
  static const int _sharedElementCommitMilliseconds = 820;

  /// Commit the pop as soon as the collapse is *visually* finished rather than
  /// waiting for the controller to reach 1.0.
  ///
  /// The rect lerp runs `easeOutCubic` on top of the controller's
  /// `easeInOutCubicEmphasized`, so the page/preview reach the target button by
  /// `commitProgress ≈ 0.8` (~25% of the duration) and the shadow has settled
  /// shortly after. The remaining duration is invisible: the page is parked on
  /// the button but the route has not popped, so taps land on this transition
  /// instead of the revealed list. Finishing here removes that dead tail.
  static const double _commitRevealProgress = 0.82;
  static const curve = Curves.easeInOutCubicEmphasized;
  static const _commitInterval = Interval(
    0,
    _routeCommitMilliseconds /
        FadeForwardsPageTransitionsBuilder.kTransitionMilliseconds,
    curve: curve,
  );
  static const double _deviceBorderRadius = 32;
  static const double _sharedElementStart = 0.50;
  static const double _sharedElementContentFadeStart = 0.18;
  static const double _sharedElementContentFadeEnd = 0.44;
  static const double _fallbackCardRadius = 24;

  final _borderRadiusTween = Tween<double>(begin: 0, end: _deviceBorderRadius);
  final _opacityTween = Tween<double>(begin: 1, end: 0);
  final _scaleTween = Tween<double>(begin: 1, end: _minScale);
  final _commitAnimation = ProxyAnimation();
  final _bounceAnimation = ProxyAnimation();
  final _animation = ProxyAnimation();
  late final AnimationController _sharedElementCommitController;

  CurvedAnimation? _curvedAnimation;
  CurvedAnimation? _curvedAnimationReversed;
  late Animation<Offset> _positionAnimation;
  double _lastBounceAnimationValue = 0;
  Offset _lastDrag = Offset.zero;
  double _commitStartBackProgress = 0;
  Offset _commitStartPageOffset = Offset.zero;
  String? _cachedSharedElementId;
  Rect? _cachedSharedElementTargetRect;
  BorderRadius? _cachedSharedElementTargetBorderRadius;
  Color? _cachedSharedElementTargetColor;
  Color? _cachedSharedElementSourceColor;
  Widget? _cachedSharedElementPreview;
  bool _sharedElementPreviewResolved = false;
  bool _sharedElementCommitStarted = false;
  bool _commitBackGestureFinishScheduled = false;

  @override
  void initState() {
    super.initState();
    _sharedElementCommitController = AnimationController(
      duration: const Duration(milliseconds: _sharedElementCommitMilliseconds),
      vsync: this,
    )..addStatusListener(_handleSharedElementCommitStatus);
    _updateCurvedAnimations();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateAnimations(MediaQuery.sizeOf(context));
    if (widget.phase == _ShadowedPredictiveBackPhase.commit &&
        !_sharedElementCommitStarted) {
      _beginSharedElementCommit();
    }
  }

  @override
  void didUpdateWidget(
    covariant _ShadowedPredictiveBackSharedElementPageTransition oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (widget.animation != oldWidget.animation) {
      _updateCurvedAnimations();
    }
    if (widget.phase != oldWidget.phase &&
        widget.phase == _ShadowedPredictiveBackPhase.commit) {
      _beginSharedElementCommit();
      _updateAnimations(MediaQuery.sizeOf(context));
    } else if (widget.phase != _ShadowedPredictiveBackPhase.commit &&
        oldWidget.phase == _ShadowedPredictiveBackPhase.commit) {
      _sharedElementCommitStarted = false;
      _commitBackGestureFinishScheduled = false;
      _sharedElementCommitController.reset();
    }
  }

  @override
  void dispose() {
    _sharedElementCommitController.dispose();
    _curvedAnimation?.dispose();
    _curvedAnimationReversed?.dispose();
    super.dispose();
  }

  double _getYShiftPosition(double screenHeight) {
    final startTouchY = widget.startBackEvent?.touchOffset?.dy ?? 0;
    final currentTouchY = widget.currentBackEvent?.touchOffset?.dy ?? 0;
    final yShiftMax = (screenHeight / _divisionFactor) - _margin;
    final rawYShift = currentTouchY - startTouchY;
    final easedYShift =
        Curves.easeOut.transform(
          clampDouble(rawYShift.abs() / screenHeight, 0, 1),
        ) *
        rawYShift.sign *
        yShiftMax;

    return clampDouble(easedYShift, -yShiftMax, yShiftMax);
  }

  void _updateAnimations(Size screenSize) {
    _animation.parent = switch (widget.phase) {
      _ShadowedPredictiveBackPhase.commit => _curvedAnimationReversed,
      _ => widget.animation,
    };

    _bounceAnimation.parent = switch (widget.phase) {
      _ShadowedPredictiveBackPhase.commit => Tween<double>(
        begin: 0,
        end: _lastBounceAnimationValue,
      ).animate(_curvedAnimation!),
      _ => ReverseAnimation(widget.animation),
    };

    _commitAnimation.parent = switch (widget.phase) {
      _ShadowedPredictiveBackPhase.commit => _animation,
      _ => kAlwaysDismissedAnimation,
    };

    final xShift = (screenSize.width / _divisionFactor) - _margin;
    _positionAnimation = _animation.drive(switch (widget.phase) {
      _ShadowedPredictiveBackPhase.commit => Tween<Offset>(
        begin: _lastDrag,
        end: Offset(screenSize.height * _yPositionFactor, 0),
      ),
      _ => Tween<Offset>(
        begin: switch (widget.currentBackEvent?.swipeEdge) {
          SwipeEdge.left => Offset(
            xShift,
            _getYShiftPosition(screenSize.height),
          ),
          SwipeEdge.right => Offset(
            -xShift,
            _getYShiftPosition(screenSize.height),
          ),
          null => Offset(xShift, _getYShiftPosition(screenSize.height)),
        },
        end: Offset.zero,
      ),
    });
  }

  void _updateCurvedAnimations() {
    _curvedAnimation?.dispose();
    _curvedAnimationReversed?.dispose();
    _curvedAnimation = CurvedAnimation(
      parent: widget.animation,
      curve: _commitInterval,
    );
    _curvedAnimationReversed = CurvedAnimation(
      parent: ReverseAnimation(widget.animation),
      curve: _commitInterval,
    );
  }

  void _beginSharedElementCommit() {
    _sharedElementCommitStarted = true;
    _commitBackGestureFinishScheduled = false;
    _commitStartBackProgress = clampDouble(_lastBounceAnimationValue, 0, 1);
    _commitStartPageOffset = _lastDrag;
    _sharedElementCommitController.forward(from: 0);
  }

  void _handleSharedElementCommitStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed &&
        widget.phase == _ShadowedPredictiveBackPhase.commit) {
      _finishCommitBackGestureAfterFrame(completeRouteAnimation: true);
    }
  }

  void _finishCommitBackGestureAfterFrame({
    required bool completeRouteAnimation,
  }) {
    if (_commitBackGestureFinishScheduled) return;
    _commitBackGestureFinishScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onCommitBackGestureFinished(
        completeRouteAnimation: completeRouteAnimation,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenSize = _transitionSize(
          constraints,
          MediaQuery.sizeOf(context),
        );

        return AnimatedBuilder(
          animation: Listenable.merge([
            widget.animation,
            _sharedElementCommitController,
          ]),
          child: widget.child,
          builder: (context, child) {
            final rawBackProgress = clampDouble(_bounceAnimation.value, 0, 1);
            if (widget.phase != _ShadowedPredictiveBackPhase.commit) {
              _lastBounceAnimationValue = rawBackProgress;
            }

            final isCommit =
                widget.phase == _ShadowedPredictiveBackPhase.commit;
            final registry = PredictiveBackSharedElementRegistry.instance;
            final targetRect = _activeSharedElementTargetRect(
              registry,
              context,
              screenSize,
              keepCached: isCommit,
            );
            final targetBorderRadius = _activeSharedElementTargetBorderRadius(
              registry,
              keepCached: isCommit,
            );
            final targetColor = _activeSharedElementTargetColor(
              registry,
              keepCached: isCommit,
            );
            final sourceColor = _activeSharedElementSourceColor(
              registry,
              keepCached: isCommit,
            );
            final preview = _activeSharedElementPreview(
              registry,
              context,
              keepCached: isCommit,
            );
            final ownerRoute = registry.activeOwnerRoute;
            final ownerMatches =
                ownerRoute == null || identical(ownerRoute, widget.route);
            final showSharedElement =
                isCommit &&
                ownerMatches &&
                preview != null &&
                targetRect != null &&
                _isUsableSharedElementRect(targetRect, screenSize);
            final commitProgress = showSharedElement
                ? curve.transform(_sharedElementCommitController.value)
                : 0.0;
            if (isCommit && !showSharedElement) {
              _finishCommitBackGestureAfterFrame(completeRouteAnimation: false);
            } else if (isCommit && commitProgress >= _commitRevealProgress) {
              // Collapse is visually done — pop now instead of idling on the
              // button for the rest of the controller's run (see
              // [_commitRevealProgress]).
              _finishCommitBackGestureAfterFrame(completeRouteAnimation: true);
            }

            final sharedElementProgress = _sharedElementProgress(
              rawBackProgress,
              showSharedElement,
              commitProgress,
            );
            final pageBackProgress = showSharedElement
                ? _commitStartBackProgress
                : rawBackProgress;
            final pageScale = _scaleTween.transform(pageBackProgress);
            final pageOffset = _pageOffset(screenSize, showSharedElement);
            final pageOpacity = _opacityTween.evaluate(_commitAnimation);
            final pageBorderRadius = _pageBorderRadius(
              context,
              pageBackProgress,
            );
            final pageRect = _pageRectForTransform(
              screenSize,
              pageScale,
              pageOffset,
            );
            final sharedElementT = showSharedElement
                ? Curves.easeOutCubic.transform(commitProgress)
                : 0.0;
            final targetBorderRadiusGeometry =
                targetBorderRadius ??
                BorderRadius.circular(_fallbackCardRadius);
            final visiblePageRect = showSharedElement
                ? Rect.lerp(pageRect, targetRect, sharedElementT)!
                : pageRect;
            final visiblePageBorderRadius = showSharedElement
                ? BorderRadiusGeometry.lerp(
                    pageBorderRadius,
                    targetBorderRadiusGeometry,
                    sharedElementT,
                  )!
                : pageBorderRadius;
            final visiblePageOpacity = showSharedElement
                ? _shrinkingPageOpacity(commitProgress)
                : pageOpacity;
            final pageShadowProgress = showSharedElement
                ? _sharedElementOverlayShadowProgress(commitProgress)
                : rawBackProgress;

            return SizedBox(
              width: screenSize.width,
              height: screenSize.height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  _TransformedPageSurface(
                    screenSize: screenSize,
                    rect: visiblePageRect,
                    opacity: visiblePageOpacity,
                    borderRadius: visiblePageBorderRadius,
                    shadow: _pageShadow(pageShadowProgress),
                    child: child!,
                  ),
                  if (showSharedElement)
                    _SharedElementOverlay(
                      progress: sharedElementProgress,
                      sourceRect: pageRect,
                      targetRect: targetRect,
                      sourceBorderRadius: _sharedElementSourceBorderRadius(
                        pageBackProgress,
                      ),
                      targetBorderRadius: targetBorderRadiusGeometry,
                      sourceColor:
                          sourceColor ?? Theme.of(context).colorScheme.surface,
                      targetColor:
                          targetColor ??
                          mailListSurfaceColor(Theme.of(context)),
                      shadow: _pageShadow(
                        _sharedElementOverlayShadowProgress(commitProgress),
                      ),
                      contentFadeStart: _sharedElementContentFadeStart,
                      contentFadeEnd: _sharedElementContentFadeEnd,
                      child: preview,
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Size _transitionSize(BoxConstraints constraints, Size fallback) {
    final width = constraints.hasBoundedWidth && constraints.maxWidth > 0
        ? constraints.maxWidth
        : fallback.width;
    final height = constraints.hasBoundedHeight && constraints.maxHeight > 0
        ? constraints.maxHeight
        : fallback.height;

    return Size(math.max(1, width), math.max(1, height));
  }

  BorderRadiusGeometry _sharedElementSourceBorderRadius(double progress) {
    return BorderRadius.circular(_borderRadiusTween.transform(progress));
  }

  double _sharedElementProgress(
    double rawBackProgress,
    bool showSharedElement,
    double commitProgress,
  ) {
    if (!showSharedElement) {
      return rawBackProgress;
    }

    return lerpDouble(_sharedElementStart, 1, commitProgress)!;
  }

  double _shrinkingPageOpacity(double commitProgress) {
    final progress = clampDouble((commitProgress - 0.30) / 0.42, 0, 1);
    return 1 - Curves.easeInCubic.transform(progress);
  }

  double _sharedElementOverlayShadowProgress(double commitProgress) {
    final progress = clampDouble(commitProgress, 0, 1);
    final rise = Curves.easeOutCubic.transform(
      clampDouble(progress / 0.28, 0, 1),
    );
    final fadeOut =
        1 -
        Curves.easeOutCubic.transform(
          clampDouble((progress - 0.56) / 0.36, 0, 1),
        );
    return lerpDouble(_commitStartBackProgress, 1, rise)! * fadeOut;
  }

  BorderRadiusGeometry _pageBorderRadius(
    BuildContext context,
    double pageBackProgress,
  ) {
    return MediaQuery.displayCornerRadiiOf(context) ??
        BorderRadius.circular(_borderRadiusTween.transform(pageBackProgress));
  }

  Offset _pageOffset(Size screenSize, bool showSharedElement) {
    if (showSharedElement) {
      return _commitStartPageOffset;
    }

    return switch (widget.phase) {
      _ShadowedPredictiveBackPhase.commit => _positionAnimation.value,
      _ => _lastDrag = Offset(
        _positionAnimation.value.dx,
        _getYShiftPosition(screenSize.height),
      ),
    };
  }

  Rect _pageRectForTransform(Size screenSize, double scale, Offset offset) {
    final scaledSize = Size(
      screenSize.width * scale,
      screenSize.height * scale,
    );
    final scaledOffset = offset * scale;
    final screenCenter = Offset(screenSize.width / 2, screenSize.height / 2);
    return Rect.fromCenter(
      center: screenCenter + scaledOffset,
      width: scaledSize.width,
      height: scaledSize.height,
    );
  }

  Rect? _localTargetRect(BuildContext context, Rect? globalRect) {
    if (globalRect == null || !globalRect.isFinite) return null;

    final RenderObject? renderObject;
    try {
      renderObject = context.findRenderObject();
    } on FlutterError {
      return globalRect;
    }

    if (renderObject is! RenderBox || !renderObject.attached) {
      return globalRect;
    }

    try {
      return Rect.fromPoints(
        renderObject.globalToLocal(globalRect.topLeft),
        renderObject.globalToLocal(globalRect.bottomRight),
      );
    } on FlutterError {
      return globalRect;
    }
  }

  bool _isUsableSharedElementRect(Rect rect, Size screenSize) {
    return rect.isFinite &&
        !rect.isEmpty &&
        rect.width <= screenSize.width + 64 &&
        rect.height <= screenSize.height;
  }

  Rect? _activeSharedElementTargetRect(
    PredictiveBackSharedElementRegistry registry,
    BuildContext context,
    Size screenSize, {
    required bool keepCached,
  }) {
    final activeId = registry.activeId;
    if (activeId == null) {
      return keepCached ? _cachedSharedElementTargetRect : null;
    }

    if (_cachedSharedElementId != activeId) {
      _clearSharedElementPreviewCache();
      _cachedSharedElementId = activeId;
    }

    final targetRect = _localTargetRect(context, registry.activeTargetRect());
    if (targetRect != null &&
        _isUsableSharedElementRect(targetRect, screenSize)) {
      _cachedSharedElementTargetRect = targetRect;
    }
    _cachedSharedElementTargetBorderRadius = registry
        .activeTargetBorderRadius();

    return targetRect ?? (keepCached ? _cachedSharedElementTargetRect : null);
  }

  BorderRadius? _activeSharedElementTargetBorderRadius(
    PredictiveBackSharedElementRegistry registry, {
    required bool keepCached,
  }) {
    if (registry.activeId == null) {
      return keepCached ? _cachedSharedElementTargetBorderRadius : null;
    }

    return _cachedSharedElementTargetBorderRadius;
  }

  Color? _activeSharedElementTargetColor(
    PredictiveBackSharedElementRegistry registry, {
    required bool keepCached,
  }) {
    final activeId = registry.activeId;
    if (activeId == null) {
      return keepCached ? _cachedSharedElementTargetColor : null;
    }

    if (_cachedSharedElementId != activeId) {
      _clearSharedElementPreviewCache();
      _cachedSharedElementId = activeId;
    }

    final color = registry.activeTargetBackgroundColor();
    if (color != null) {
      _cachedSharedElementTargetColor = color;
    }

    return color ?? (keepCached ? _cachedSharedElementTargetColor : null);
  }

  Color? _activeSharedElementSourceColor(
    PredictiveBackSharedElementRegistry registry, {
    required bool keepCached,
  }) {
    final activeId = registry.activeId;
    if (activeId == null) {
      return keepCached ? _cachedSharedElementSourceColor : null;
    }

    if (_cachedSharedElementId != activeId) {
      _clearSharedElementPreviewCache();
      _cachedSharedElementId = activeId;
    }

    final color = registry.activeSourceBackgroundColor();
    if (color != null) {
      _cachedSharedElementSourceColor = color;
    }

    return color ?? (keepCached ? _cachedSharedElementSourceColor : null);
  }

  Widget? _activeSharedElementPreview(
    PredictiveBackSharedElementRegistry registry,
    BuildContext context, {
    required bool keepCached,
  }) {
    final activeId = registry.activeId;
    if (activeId == null) {
      if (!keepCached) {
        _clearSharedElementPreviewCache();
      }
      return keepCached ? _cachedSharedElementPreview : null;
    }

    if (_cachedSharedElementId != activeId) {
      _clearSharedElementPreviewCache();
      _cachedSharedElementId = activeId;
    }

    if (!_sharedElementPreviewResolved) {
      _cachedSharedElementPreview = registry.buildActivePreview(context);
      _sharedElementPreviewResolved = true;
    }

    return _cachedSharedElementPreview;
  }

  void _clearSharedElementPreviewCache() {
    _cachedSharedElementId = null;
    _cachedSharedElementTargetRect = null;
    _cachedSharedElementTargetBorderRadius = null;
    _cachedSharedElementTargetColor = null;
    _cachedSharedElementSourceColor = null;
    _cachedSharedElementPreview = null;
    _sharedElementPreviewResolved = false;
  }

  List<BoxShadow> _pageShadow(double progress) {
    final shadowProgress = clampDouble(progress, 0, 1);
    if (shadowProgress == 0) return const [];
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.22 * shadowProgress),
        blurRadius: 28 * shadowProgress,
        spreadRadius: 2 * shadowProgress,
        offset: Offset(0, 10 * shadowProgress),
      ),
    ];
  }
}

class _SharedElementOverlay extends StatelessWidget {
  const _SharedElementOverlay({
    required this.progress,
    required this.sourceRect,
    required this.targetRect,
    required this.sourceBorderRadius,
    required this.targetBorderRadius,
    required this.sourceColor,
    required this.targetColor,
    required this.shadow,
    required this.contentFadeStart,
    required this.contentFadeEnd,
    required this.child,
  });

  final double progress;
  final Rect sourceRect;
  final Rect targetRect;
  final BorderRadiusGeometry sourceBorderRadius;
  final BorderRadiusGeometry targetBorderRadius;
  final Color sourceColor;
  final Color targetColor;
  final List<BoxShadow> shadow;
  final double contentFadeStart;
  final double contentFadeEnd;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final rawT = clampDouble(
      (progress -
              _ShadowedPredictiveBackSharedElementPageTransitionState
                  ._sharedElementStart) /
          (1 -
              _ShadowedPredictiveBackSharedElementPageTransitionState
                  ._sharedElementStart),
      0,
      1,
    );
    if (rawT == 0) return const SizedBox.shrink();

    final easedT = Curves.easeOutCubic.transform(rawT);
    final rect = Rect.lerp(sourceRect, targetRect, easedT);
    if (rect == null || rect.isEmpty || !rect.isFinite) {
      return const SizedBox.shrink();
    }

    final borderRadius = BorderRadiusGeometry.lerp(
      sourceBorderRadius,
      targetBorderRadius,
      easedT,
    )!;
    final surfaceOpacity = Curves.easeOut.transform(
      clampDouble((rawT - 0.18) / 0.42, 0, 1),
    );
    final contentOpacity = Curves.easeOut.transform(
      clampDouble(
        (rawT - contentFadeStart) / (contentFadeEnd - contentFadeStart),
        0,
        1,
      ),
    );
    final color = Color.lerp(
      sourceColor,
      targetColor,
      easedT,
    )!.withValues(alpha: surfaceOpacity);
    final contentHeight = math.min(targetRect.height, rect.height);

    return Positioned.fromRect(
      rect: rect,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            boxShadow: shadow,
          ),
          child: ClipRRect(
            borderRadius: borderRadius,
            child: ColoredBox(
              color: color,
              child: Material(
                type: MaterialType.transparency,
                child: Opacity(
                  opacity: contentOpacity,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: rect.width,
                      height: contentHeight,
                      child: ClipRect(child: child),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TransformedPageSurface extends StatelessWidget {
  const _TransformedPageSurface({
    required this.screenSize,
    required this.rect,
    required this.opacity,
    required this.borderRadius,
    required this.shadow,
    required this.child,
  });

  final Size screenSize;
  final Rect rect;
  final double opacity;
  final BorderRadiusGeometry borderRadius;
  final List<BoxShadow> shadow;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scaleX = rect.width / screenSize.width;
    final scaleY = rect.height / screenSize.height;
    final transform = Matrix4.identity()
      ..translateByDouble(rect.left, rect.top, 0, 1)
      ..scaleByDouble(scaleX, scaleY, 1, 1);

    return Positioned.fill(
      child: Transform(
        alignment: Alignment.topLeft,
        transform: transform,
        child: Opacity(
          opacity: opacity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              boxShadow: shadow,
            ),
            child: ClipRRect(borderRadius: borderRadius, child: child),
          ),
        ),
      ),
    );
  }
}

class _PredictiveBackGestureSnapshot extends StatefulWidget {
  const _PredictiveBackGestureSnapshot({
    required this.route,
    required this.active,
    required this.child,
  });

  final PageRoute<dynamic> route;
  final bool active;
  final Widget child;

  @override
  State<_PredictiveBackGestureSnapshot> createState() =>
      _PredictiveBackGestureSnapshotState();
}

class _PredictiveBackGestureSnapshotState
    extends State<_PredictiveBackGestureSnapshot> {
  final SnapshotController _controller = SnapshotController();
  NavigatorState? _navigator;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bindNavigator();
  }

  @override
  void didUpdateWidget(covariant _PredictiveBackGestureSnapshot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.route != widget.route) {
      _bindNavigator();
    } else if (oldWidget.active != widget.active) {
      _syncSnapshotting();
    }
  }

  void _bindNavigator() {
    final navigator = widget.route.navigator;
    if (identical(navigator, _navigator)) {
      _syncSnapshotting();
      return;
    }

    _navigator?.userGestureInProgressNotifier.removeListener(_syncSnapshotting);
    _navigator = navigator;
    _navigator?.userGestureInProgressNotifier.addListener(_syncSnapshotting);
    _syncSnapshotting();
  }

  void _syncSnapshotting() {
    _controller.allowSnapshotting =
        widget.active ||
        (_navigator?.userGestureInProgressNotifier.value ?? false);
  }

  @override
  void dispose() {
    _navigator?.userGestureInProgressNotifier.removeListener(_syncSnapshotting);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SnapshotWidget(
      controller: _controller,
      mode: SnapshotMode.permissive,
      child: widget.child,
    );
  }
}
