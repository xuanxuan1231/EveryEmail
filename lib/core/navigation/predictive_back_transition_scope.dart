import 'package:flutter/widgets.dart';

/// Exposes the custom Android predictive-back transition state to route
/// descendants that need to avoid expensive platform-view rendering.
class PredictiveBackTransitionScope extends InheritedWidget {
  const PredictiveBackTransitionScope({
    required this.active,
    required this.committing,
    required super.child,
    super.key,
  });

  final bool active;
  final bool committing;

  static bool isActive(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<PredictiveBackTransitionScope>()
            ?.active ??
        false;
  }

  static bool isCommitting(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<PredictiveBackTransitionScope>()
            ?.committing ??
        false;
  }

  @override
  bool updateShouldNotify(PredictiveBackTransitionScope oldWidget) {
    return active != oldWidget.active || committing != oldWidget.committing;
  }
}
