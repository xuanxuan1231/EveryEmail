import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

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

  static const PredictiveBackPageTransitionsBuilder _delegate =
      PredictiveBackPageTransitionsBuilder();

  @override
  Duration get transitionDuration => _delegate.transitionDuration;

  @override
  Duration get reverseTransitionDuration => _delegate.reverseTransitionDuration;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return PredictiveBackPageTransitionsBuilder(
      fallbackColor: fallbackColor,
    ).buildTransitions<T>(
      route,
      context,
      animation,
      secondaryAnimation,
      _PredictiveBackGestureSnapshot(route: route, child: child),
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
