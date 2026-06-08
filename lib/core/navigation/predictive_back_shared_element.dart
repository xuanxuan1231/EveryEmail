import 'package:flutter/material.dart';

/// Registry for predictive-back shared-element targets.
///
/// This intentionally does not use Flutter's [Hero]. Android predictive back
/// updates the page route while the gesture is in progress, but Hero flights can
/// still be deferred until the pop is committed. This registry lets the page
/// transition builder draw a compact preview directly from the live gesture
/// progress.
class PredictiveBackSharedElementRegistry {
  PredictiveBackSharedElementRegistry._();

  static final PredictiveBackSharedElementRegistry instance =
      PredictiveBackSharedElementRegistry._();

  final Map<String, _SharedElementTargetEntry> _targets = {};

  String? _activeId;
  WidgetBuilder? _activePreviewBuilder;
  Color? _activeSourceBackgroundColor;
  Route<dynamic>? _activeOwnerRoute;

  String? get activeId => _activeId;

  /// The route that registered the current active target, if any. The page
  /// transition only collapses a popping route into the active target when that
  /// route IS this owner (or the owner is null). This stops a child route — e.g.
  /// a license-detail page pushed onto `LicensePage`'s nested navigator — from
  /// wrongly collapsing into a target owned by an ancestor route that is still
  /// the current GoRouter page.
  Route<dynamic>? get activeOwnerRoute => _activeOwnerRoute;

  void registerTarget(
    String id,
    GlobalKey key, {
    WidgetBuilder? previewBuilder,
    BorderRadius? borderRadius,
    Color? backgroundColor,
  }) {
    final existing = _targets[id];
    if (existing != null && existing.key == key) {
      existing
        ..previewBuilder = previewBuilder
        ..borderRadius = borderRadius
        ..backgroundColor = backgroundColor;
      return;
    }

    _targets[id] = _SharedElementTargetEntry(
      key: key,
      previewBuilder: previewBuilder,
      borderRadius: borderRadius,
      backgroundColor: backgroundColor,
    );
  }

  void unregisterTarget(String id, GlobalKey key) {
    if (_targets[id]?.key == key) {
      _targets.remove(id);
    }
  }

  void setActive({
    required String id,
    WidgetBuilder? previewBuilder,
    Color? sourceBackgroundColor,
    Route<dynamic>? ownerRoute,
  }) {
    _activeId = id;
    _activePreviewBuilder = previewBuilder;
    _activeSourceBackgroundColor = sourceBackgroundColor;
    _activeOwnerRoute = ownerRoute;
  }

  void clearActive(String id) {
    if (_activeId == id) {
      _activeId = null;
      _activePreviewBuilder = null;
      _activeSourceBackgroundColor = null;
      _activeOwnerRoute = null;
    }
  }

  Rect? activeTargetRect() {
    final id = _activeId;
    if (id == null) return null;
    final entry = _targets[id];
    if (entry == null) return null;
    return _currentRectForEntry(entry) ?? entry.lastRect;
  }

  BorderRadius? activeTargetBorderRadius() {
    final id = _activeId;
    if (id == null) return null;
    return _targets[id]?.borderRadius;
  }

  Color? activeTargetBackgroundColor() {
    final id = _activeId;
    if (id == null) return null;
    return _targets[id]?.backgroundColor;
  }

  Color? activeSourceBackgroundColor() {
    final id = _activeId;
    if (id == null) return null;
    return _activeSourceBackgroundColor;
  }

  Widget? buildActivePreview(BuildContext context) {
    final id = _activeId;
    final targetPreviewBuilder = id == null
        ? null
        : _targets[id]?.previewBuilder;
    return (targetPreviewBuilder ?? _activePreviewBuilder)?.call(context);
  }

  void updateTargetRect(String id, GlobalKey key) {
    final entry = _targets[id];
    if (entry == null || entry.key != key) return;
    _currentRectForEntry(entry);
  }

  Rect? _currentRectForEntry(_SharedElementTargetEntry entry) {
    final rect = _rectForKey(entry.key);
    if (rect != null) {
      entry.lastRect = rect;
    }
    return rect;
  }

  Rect? _rectForKey(GlobalKey? key) {
    final context = key?.currentContext;
    if (context == null || !_debugContextIsActive(context)) return null;

    final RenderObject? renderObject;
    try {
      renderObject = context.findRenderObject();
    } on FlutterError {
      return null;
    }

    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize) {
      return null;
    }

    final topLeft = renderObject.localToGlobal(Offset.zero);
    final rect = topLeft & renderObject.size;
    return rect.isFinite ? rect : null;
  }

  bool _debugContextIsActive(BuildContext context) {
    var isActive = true;
    assert(() {
      if (context is Element && !context.debugIsActive) {
        isActive = false;
      }
      return true;
    }());
    return isActive;
  }
}

/// Marks the enclosing route as the destination of a shared-element
/// predictive-back transition.
///
/// While this route is the top-most one it keeps [id] registered as the
/// registry's active return target, so a predictive-back gesture collapses the
/// page into the matching [PredictiveBackSharedElementTarget] (the "button" the
/// page was opened from) instead of the default page slide. The target — which
/// is still mounted on the route below — supplies the preview and geometry, so
/// most callers only need to pass [id]. [previewBuilder] and
/// [sourceBackgroundColor] are optional fallbacks used when the target does not
/// register its own.
///
/// The id is released whenever another route is pushed on top (the secondary
/// animation leaves [AnimationStatus.dismissed]), so popping an intermediate
/// page does not collapse it into this page's target.
class PredictiveBackReturnTarget extends StatefulWidget {
  const PredictiveBackReturnTarget({
    required this.id,
    required this.child,
    this.previewBuilder,
    this.sourceBackgroundColor,
    super.key,
  });

  final String id;
  final Widget child;
  final WidgetBuilder? previewBuilder;
  final Color? sourceBackgroundColor;

  @override
  State<PredictiveBackReturnTarget> createState() =>
      _PredictiveBackReturnTargetState();
}

class _PredictiveBackReturnTargetState
    extends State<PredictiveBackReturnTarget> {
  ModalRoute<dynamic>? _route;
  Animation<double>? _secondaryAnimation;
  bool _isActive = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
    final secondary = _route?.secondaryAnimation;
    if (!identical(secondary, _secondaryAnimation)) {
      _secondaryAnimation?.removeStatusListener(_handleSecondaryStatus);
      _secondaryAnimation = secondary;
      _secondaryAnimation?.addStatusListener(_handleSecondaryStatus);
    }
    _syncActive();
  }

  @override
  void didUpdateWidget(covariant PredictiveBackReturnTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id && _isActive) {
      PredictiveBackSharedElementRegistry.instance.clearActive(oldWidget.id);
      _isActive = false;
    }
    _syncActive();
  }

  @override
  void dispose() {
    _secondaryAnimation?.removeStatusListener(_handleSecondaryStatus);
    if (_isActive) {
      PredictiveBackSharedElementRegistry.instance.clearActive(widget.id);
    }
    super.dispose();
  }

  void _handleSecondaryStatus(AnimationStatus status) => _syncActive();

  /// Active only while this route is the current (top-most) one. We key off
  /// [ModalRoute.isCurrent] rather than the secondary animation so nested
  /// convergence works: when a return-target page (e.g. the About page) itself
  /// pushes another convergence child (the licenses page), the covered parent
  /// stops being current the instant the child is pushed and releases its id,
  /// so the child's id wins the registry's single active slot instead of the
  /// parent leaking its target into the child's back transition. The secondary
  /// animation is still listened to as an extra re-evaluation trigger during
  /// push/pop, but it no longer decides activeness.
  bool get _shouldBeActive {
    final route = _route;
    return route == null || route.isCurrent;
  }

  void _syncActive() {
    final registry = PredictiveBackSharedElementRegistry.instance;
    if (_shouldBeActive) {
      registry.setActive(
        id: widget.id,
        previewBuilder: widget.previewBuilder,
        sourceBackgroundColor: widget.sourceBackgroundColor,
        ownerRoute: _route,
      );
      _isActive = true;
    } else if (_isActive) {
      registry.clearActive(widget.id);
      _isActive = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _SharedElementTargetEntry {
  _SharedElementTargetEntry({
    required this.key,
    this.previewBuilder,
    this.borderRadius,
    this.backgroundColor,
  });

  final GlobalKey key;
  WidgetBuilder? previewBuilder;
  BorderRadius? borderRadius;
  Color? backgroundColor;
  Rect? lastRect;
}

class PredictiveBackSharedElementTarget extends StatefulWidget {
  const PredictiveBackSharedElementTarget({
    required this.id,
    required this.child,
    this.previewBuilder,
    this.borderRadius,
    this.backgroundColor,
    super.key,
  });

  final String id;
  final Widget child;
  final WidgetBuilder? previewBuilder;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;

  @override
  State<PredictiveBackSharedElementTarget> createState() =>
      _PredictiveBackSharedElementTargetState();
}

class _PredictiveBackSharedElementTargetState
    extends State<PredictiveBackSharedElementTarget> {
  final GlobalKey _key = GlobalKey();
  bool _geometrySyncScheduled = false;

  @override
  void initState() {
    super.initState();
    _registerTarget();
    _scheduleGeometrySync();
  }

  @override
  void didUpdateWidget(covariant PredictiveBackSharedElementTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      PredictiveBackSharedElementRegistry.instance.unregisterTarget(
        oldWidget.id,
        _key,
      );
    }
    _registerTarget();
    _scheduleGeometrySync();
  }

  @override
  void activate() {
    super.activate();
    _registerTarget();
    _scheduleGeometrySync();
  }

  @override
  void deactivate() {
    _syncGeometry();
    super.deactivate();
  }

  void _registerTarget() {
    PredictiveBackSharedElementRegistry.instance.registerTarget(
      widget.id,
      _key,
      previewBuilder: widget.previewBuilder,
      borderRadius: widget.borderRadius,
      backgroundColor: widget.backgroundColor,
    );
  }

  void _scheduleGeometrySync() {
    if (_geometrySyncScheduled) return;
    _geometrySyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _geometrySyncScheduled = false;
      if (!mounted) return;
      _syncGeometry();
    });
  }

  void _syncGeometry() {
    PredictiveBackSharedElementRegistry.instance.updateTargetRect(
      widget.id,
      _key,
    );
  }

  @override
  void dispose() {
    PredictiveBackSharedElementRegistry.instance.unregisterTarget(
      widget.id,
      _key,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _scheduleGeometrySync();
    return KeyedSubtree(key: _key, child: widget.child);
  }
}
