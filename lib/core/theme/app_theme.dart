import 'dart:math' as math;
import 'dart:ui' show clampDouble, lerpDouble;

import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PredictiveBackEvent, SwipeEdge;

import '../navigation/predictive_back_shared_element.dart';
import '../../data/settings/app_font_settings.dart';
import 'expressive_colors.dart';
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
    final snapshotChild = _PredictiveBackGestureSnapshot(
      route: route,
      child: child,
    );

    return _ShadowedPredictiveBackGestureDetector(
      route: route,
      builder: (context, phase, startBackEvent, currentBackEvent) {
        if (route.popGestureInProgress) {
          return _ShadowedPredictiveBackSharedElementPageTransition(
            animation: animation,
            phase: phase,
            secondaryAnimation: secondaryAnimation,
            startBackEvent: startBackEvent,
            currentBackEvent: currentBackEvent,
            child: snapshotChild,
          );
        }

        return FadeForwardsPageTransitionsBuilder(
          backgroundColor: fallbackColor,
        ).buildTransitions(
          route,
          context,
          animation,
          secondaryAnimation,
          snapshotChild,
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
    );

enum _ShadowedPredictiveBackPhase { idle, start, update, commit, cancel }

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
  _ShadowedPredictiveBackPhase _phase = _ShadowedPredictiveBackPhase.idle;
  PredictiveBackEvent? _startBackEvent;
  PredictiveBackEvent? _currentBackEvent;

  bool get _isEnabled =>
      widget.route.isCurrent && widget.route.popGestureEnabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
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
    _syncGesture(
      phase: _ShadowedPredictiveBackPhase.cancel,
      startBackEvent: null,
      currentBackEvent: null,
    );
    widget.route.handleCancelBackGesture();
  }

  @override
  void handleCommitBackGesture() {
    _syncGesture(
      phase: _ShadowedPredictiveBackPhase.commit,
      startBackEvent: null,
      currentBackEvent: null,
    );
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
    final effectivePhase = widget.route.popGestureInProgress
        ? _phase
        : _ShadowedPredictiveBackPhase.idle;
    return widget.builder(
      context,
      effectivePhase,
      _startBackEvent,
      _currentBackEvent,
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
    required this.child,
  });

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final _ShadowedPredictiveBackPhase phase;
  final PredictiveBackEvent? startBackEvent;
  final PredictiveBackEvent? currentBackEvent;
  final Widget child;

  @override
  State<_ShadowedPredictiveBackSharedElementPageTransition> createState() =>
      _ShadowedPredictiveBackSharedElementPageTransitionState();
}

class _ShadowedPredictiveBackSharedElementPageTransitionState
    extends State<_ShadowedPredictiveBackSharedElementPageTransition> {
  static const double _minScale = 0.90;
  static const double _divisionFactor = 20;
  static const double _margin = 8;
  static const double _yPositionFactor = 0.1;
  static const int _commitMilliseconds = 400;
  static const curve = Curves.easeInOutCubicEmphasized;
  static const _commitInterval = Interval(
    0,
    _commitMilliseconds /
        FadeForwardsPageTransitionsBuilder.kTransitionMilliseconds,
    curve: curve,
  );
  static const double _deviceBorderRadius = 32;
  static const double _sharedElementStart = 0.50;
  static const double _sharedElementPageFadeEnd = 0.72;
  static const double _sharedElementContentFadeStart = 0.18;
  static const double _sharedElementContentFadeEnd = 0.44;
  static const double _fallbackCardRadius = 24;

  final _borderRadiusTween = Tween<double>(begin: 0, end: _deviceBorderRadius);
  final _opacityTween = Tween<double>(begin: 1, end: 0);
  final _scaleTween = Tween<double>(begin: 1, end: _minScale);
  final _commitAnimation = ProxyAnimation();
  final _bounceAnimation = ProxyAnimation();
  final _animation = ProxyAnimation();

  CurvedAnimation? _curvedAnimation;
  CurvedAnimation? _curvedAnimationReversed;
  late Animation<Offset> _positionAnimation;
  double _lastBounceAnimationValue = 0;
  Offset _lastDrag = Offset.zero;
  double _commitStartSharedElementProgress = 0;
  Offset _commitStartSharedElementOffset = Offset.zero;
  Offset _lastSharedElementOffset = Offset.zero;
  String? _cachedSharedElementId;
  Widget? _cachedSharedElementPreview;
  bool _sharedElementPreviewResolved = false;

  @override
  void initState() {
    super.initState();
    _updateCurvedAnimations();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateAnimations(MediaQuery.sizeOf(context));
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
      _commitStartSharedElementProgress = clampDouble(
        _lastBounceAnimationValue,
        0,
        1,
      );
      _commitStartSharedElementOffset = _lastSharedElementOffset;
      _updateAnimations(MediaQuery.sizeOf(context));
    }
  }

  @override
  void dispose() {
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenSize = _transitionSize(
          constraints,
          MediaQuery.sizeOf(context),
        );

        return AnimatedBuilder(
          animation: widget.animation,
          child: widget.child,
          builder: (context, child) {
            final rawBackProgress = clampDouble(_bounceAnimation.value, 0, 1);
            if (widget.phase != _ShadowedPredictiveBackPhase.commit) {
              _lastBounceAnimationValue = rawBackProgress;
            }

            final registry = PredictiveBackSharedElementRegistry.instance;
            final targetRect = _localTargetRect(
              context,
              registry.activeTargetRect(),
            );
            final preview = _activeSharedElementPreview(registry, context);
            final hasSharedElement =
                preview != null &&
                targetRect != null &&
                _isUsableSharedElementRect(targetRect, screenSize);

            final sharedElementProgress = _sharedElementProgress(
              rawBackProgress,
            );
            final pageBackProgress = hasSharedElement
                ? clampDouble(sharedElementProgress, 0, _sharedElementStart)
                : rawBackProgress;
            final pageScale = _scaleTween.transform(pageBackProgress);
            final pageOffset = _pageOffset(
              screenSize,
              pageBackProgress,
              hasSharedElement,
            );
            final pageOpacity =
                _opacityTween.evaluate(_commitAnimation) *
                (hasSharedElement
                    ? _sharedElementPageOpacity(sharedElementProgress)
                    : 1);
            final pageBorderRadius = _pageBorderRadius(
              context,
              pageBackProgress,
            );
            final pageRect = _pageRectForTransform(
              screenSize,
              pageScale,
              pageOffset,
            );
            final pageShadowProgress = hasSharedElement
                ? clampDouble(sharedElementProgress, 0, 1)
                : rawBackProgress;

            return SizedBox(
              width: screenSize.width,
              height: screenSize.height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: Transform.scale(
                      scale: pageScale,
                      child: Transform.translate(
                        offset: pageOffset,
                        child: Opacity(
                          opacity: pageOpacity,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: pageBorderRadius,
                              boxShadow: _pageShadow(pageShadowProgress),
                            ),
                            child: ClipRRect(
                              borderRadius: pageBorderRadius,
                              child: child,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (hasSharedElement)
                    _SharedElementOverlay(
                      progress: sharedElementProgress,
                      sourceRect: pageRect,
                      targetRect: targetRect,
                      sourceBorderRadius: _sharedElementSourceBorderRadius,
                      targetBorderRadius:
                          registry.activeTargetBorderRadius() ??
                          BorderRadius.circular(_fallbackCardRadius),
                      sourceColor: Theme.of(context).colorScheme.surface,
                      targetColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      shadow: _pageShadow(sharedElementProgress),
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

  BorderRadiusGeometry get _sharedElementSourceBorderRadius =>
      BorderRadius.circular(_borderRadiusTween.transform(_sharedElementStart));

  double _sharedElementProgress(double rawBackProgress) {
    if (widget.phase != _ShadowedPredictiveBackPhase.commit) {
      return rawBackProgress;
    }

    return lerpDouble(
      _commitStartSharedElementProgress,
      1,
      clampDouble(_animation.value, 0, 1),
    )!;
  }

  double _sharedElementPageOpacity(double progress) {
    final fadeProgress = clampDouble(
      (progress - _sharedElementStart) /
          (_sharedElementPageFadeEnd - _sharedElementStart),
      0,
      1,
    );
    return 1 - Curves.easeInCubic.transform(fadeProgress);
  }

  BorderRadiusGeometry _pageBorderRadius(
    BuildContext context,
    double pageBackProgress,
  ) {
    return MediaQuery.displayCornerRadiiOf(context) ??
        BorderRadius.circular(_borderRadiusTween.transform(pageBackProgress));
  }

  Offset _pageOffset(
    Size screenSize,
    double pageBackProgress,
    bool hasSharedElement,
  ) {
    if (!hasSharedElement) {
      return switch (widget.phase) {
        _ShadowedPredictiveBackPhase.commit => _positionAnimation.value,
        _ => _lastDrag = Offset(
          _positionAnimation.value.dx,
          _getYShiftPosition(screenSize.height),
        ),
      };
    }

    if (widget.phase == _ShadowedPredictiveBackPhase.commit) {
      return _commitStartSharedElementOffset;
    }

    return _lastSharedElementOffset = _gestureOffsetForBackProgress(
      screenSize,
      pageBackProgress,
    );
  }

  Offset _gestureOffsetForBackProgress(Size screenSize, double backProgress) {
    final xShift = (screenSize.width / _divisionFactor) - _margin;
    final direction = switch (widget.currentBackEvent?.swipeEdge) {
      SwipeEdge.right => -1.0,
      SwipeEdge.left || null => 1.0,
    };
    return Offset(
      direction * xShift * backProgress,
      _getYShiftPosition(screenSize.height),
    );
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

  Widget? _activeSharedElementPreview(
    PredictiveBackSharedElementRegistry registry,
    BuildContext context,
  ) {
    final activeId = registry.activeId;
    if (activeId == null) {
      _clearSharedElementPreviewCache();
      return null;
    }

    if (_cachedSharedElementId != activeId) {
      _cachedSharedElementId = activeId;
      _cachedSharedElementPreview = null;
      _sharedElementPreviewResolved = false;
    }

    if (!_sharedElementPreviewResolved) {
      _cachedSharedElementPreview = registry.buildActivePreview(context);
      _sharedElementPreviewResolved = true;
    }

    return _cachedSharedElementPreview;
  }

  void _clearSharedElementPreviewCache() {
    _cachedSharedElementId = null;
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
      clampDouble(rawT / 0.20, 0, 1),
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

class _PredictiveBackGestureSnapshot extends StatefulWidget {
  const _PredictiveBackGestureSnapshot({
    required this.route,
    required this.child,
  });

  final PageRoute<dynamic> route;
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
        _navigator?.userGestureInProgressNotifier.value ?? false;
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
