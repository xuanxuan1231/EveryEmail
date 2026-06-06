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

  String? get activeId => _activeId;

  void registerTarget(
    String id,
    GlobalKey key, {
    WidgetBuilder? previewBuilder,
    BorderRadius? borderRadius,
  }) {
    final existing = _targets[id];
    if (existing != null && existing.key == key) {
      existing
        ..previewBuilder = previewBuilder
        ..borderRadius = borderRadius;
      return;
    }

    _targets[id] = _SharedElementTargetEntry(
      key: key,
      previewBuilder: previewBuilder,
      borderRadius: borderRadius,
    );
  }

  void unregisterTarget(String id, GlobalKey key) {
    if (_targets[id]?.key == key) {
      _targets.remove(id);
    }
  }

  void setActive({required String id, WidgetBuilder? previewBuilder}) {
    _activeId = id;
    _activePreviewBuilder = previewBuilder;
  }

  void clearActive(String id) {
    if (_activeId == id) {
      _activeId = null;
      _activePreviewBuilder = null;
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

class _SharedElementTargetEntry {
  _SharedElementTargetEntry({
    required this.key,
    this.previewBuilder,
    this.borderRadius,
  });

  final GlobalKey key;
  WidgetBuilder? previewBuilder;
  BorderRadius? borderRadius;
  Rect? lastRect;
}

class PredictiveBackSharedElementTarget extends StatefulWidget {
  const PredictiveBackSharedElementTarget({
    required this.id,
    required this.child,
    this.previewBuilder,
    this.borderRadius,
    super.key,
  });

  final String id;
  final Widget child;
  final WidgetBuilder? previewBuilder;
  final BorderRadius? borderRadius;

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
