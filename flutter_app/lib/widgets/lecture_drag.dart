import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/lecture.dart';
import '../theme/app_theme.dart';
import 'lecture_card.dart' show hexColor;

/// What is being dragged: the lecture and where the drag began.
@immutable
class LectureDragData {
  const LectureDragData({
    required this.lectureId,
    required this.fromSemesterId,
    required this.season,
  });

  final String lectureId;

  /// `null` for the parking lot.
  final String? fromSemesterId;

  /// 'winter', 'summer' or 'both' - for the turnus hint while hovering.
  final String season;
}

/// A drop target: a semester, or the parking lot ([LectureDragController.parkingLot]).
typedef DropTargetId = String;

/// Runs a lecture drag across the semester list.
///
/// Flutter's [DragTarget]s only re-evaluate what is under the pointer when
/// the pointer moves. While the list auto-scrolls under a resting finger
/// they would keep the section the finger *was* over, and the drop would
/// land in a semester that has long scrolled away. So the target is
/// worked out here, from the pointer position, on every move and every
/// auto-scroll step, and the drop happens on pointer-up.
class LectureDragController extends ChangeNotifier {
  LectureDragController({required this.onDrop});

  /// Key of the parking lot among the drop targets.
  static const DropTargetId parkingLot = '__parking_lot__';

  /// Called with the drag and the target it was released over. Not called
  /// when released over nothing or over the section it came from.
  final void Function(LectureDragData data, DropTargetId target) onDrop;

  final Map<DropTargetId, GlobalKey> _targets = {};
  ScrollController? _scroll;
  GlobalKey? _viewport;

  LectureDragData? _active;
  Offset? _pointer;
  DropTargetId? _hovered;
  Timer? _scrollTimer;
  double _scrollStep = 0;

  /// Pixels from the list's top or bottom edge where auto-scroll kicks in.
  static const double edge = 72;

  /// Fastest auto-scroll, in pixels per 16 ms frame.
  static const double maxStep = 20;

  LectureDragData? get active => _active;

  /// The target under the pointer, if dropping there would move the lecture.
  DropTargetId? get hovered => _hovered;

  bool get isDragging => _active != null;

  void attachList(ScrollController scroll, GlobalKey viewport) {
    _scroll = scroll;
    _viewport = viewport;
  }

  void registerTarget(DropTargetId id, GlobalKey key) => _targets[id] = key;

  void unregisterTarget(DropTargetId id, GlobalKey key) {
    if (identical(_targets[id], key)) _targets.remove(id);
  }

  void start(LectureDragData data) {
    _active = data;
    _pointer = null;
    _setHovered(null);
    notifyListeners();
  }

  void update(Offset globalPointer) {
    if (_active == null) return;
    _pointer = globalPointer;
    _setHovered(_targetAt(globalPointer));
    _updateAutoScroll(globalPointer);
  }

  /// How far a release may be from the last drag position and still count
  /// as the dragging finger lifting (and not a second finger).
  static const double releaseSlop = 24;

  /// The finger or button was released: drop on whatever is under it.
  void release(Offset globalPointer) {
    final data = _active;
    if (data == null) return;
    final last = _pointer;
    if (last != null && (last - globalPointer).distance > releaseSlop) {
      return; // Another finger lifted; the drag goes on.
    }
    final target = _targetAt(globalPointer);
    _finish();
    if (target != null) onDrop(data, target);
  }

  /// The drag ended without a drop (cancelled, or already released).
  void cancel() {
    if (_active == null) return;
    _finish();
  }

  void _finish() {
    _active = null;
    _pointer = null;
    _hovered = null;
    _stopAutoScroll();
    notifyListeners();
  }

  void _setHovered(DropTargetId? id) {
    if (id == _hovered) return;
    _hovered = id;
    notifyListeners();
  }

  /// The target under [globalPointer], or `null` over no target or over the
  /// section the drag came from (dropping there would change nothing).
  DropTargetId? _targetAt(Offset globalPointer) {
    final data = _active;
    if (data == null) return null;
    final viewport = _box(_viewport);
    if (viewport != null && !_rectOf(viewport).contains(globalPointer)) {
      return null;
    }
    for (final entry in _targets.entries) {
      final box = _box(entry.value);
      if (box == null || !_rectOf(box).contains(globalPointer)) continue;
      final source = data.fromSemesterId ?? parkingLot;
      return entry.key == source ? null : entry.key;
    }
    return null;
  }

  void _updateAutoScroll(Offset globalPointer) {
    final viewport = _box(_viewport);
    if (viewport == null) return;
    final local = viewport.globalToLocal(globalPointer);
    final height = viewport.size.height;
    double step = 0;
    if (local.dy < edge) {
      step = -maxStep * (1 - local.dy.clamp(0.0, edge) / edge);
    } else if (local.dy > height - edge) {
      step = maxStep * (1 - (height - local.dy).clamp(0.0, edge) / edge);
    }
    _scrollStep = step;
    if (step == 0) {
      _stopAutoScroll();
    } else {
      _scrollTimer ??= Timer.periodic(
        const Duration(milliseconds: 16),
        (_) => _tick(),
      );
    }
  }

  void _tick() {
    final scroll = _scroll;
    if (_active == null || scroll == null || !scroll.hasClients) {
      _stopAutoScroll();
      return;
    }
    final position = scroll.position;
    final next = (position.pixels + _scrollStep).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (next == position.pixels) return;
    position.jumpTo(next);
    // The list moved under a resting pointer: what is under it now?
    final pointer = _pointer;
    if (pointer != null) _setHovered(_targetAt(pointer));
  }

  void _stopAutoScroll() {
    _scrollTimer?.cancel();
    _scrollTimer = null;
    _scrollStep = 0;
  }

  static RenderBox? _box(GlobalKey? key) {
    final object = key?.currentContext?.findRenderObject();
    return object is RenderBox && object.attached && object.hasSize
        ? object
        : null;
  }

  static Rect _rectOf(RenderBox box) =>
      box.localToGlobal(Offset.zero) & box.size;

  @override
  void dispose() {
    _stopAutoScroll();
    super.dispose();
  }
}

/// Hands the [LectureDragController] down the plan.
class LectureDragScope extends InheritedNotifier<LectureDragController> {
  const LectureDragScope({
    super.key,
    required LectureDragController controller,
    required super.child,
  }) : super(notifier: controller);

  static LectureDragController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LectureDragScope>()?.notifier;
}

/// Whether drags start right away (mouse) or after a long press (touch).
/// Overridable in tests.
@visibleForTesting
bool? debugDragWithMouse;

bool get _dragWithMouse =>
    debugDragWithMouse ??
    (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS));

/// Makes a lecture card draggable. On the desktop the drag starts with the
/// mouse right away; on touch screens after a long press, so it does not
/// fight with scrolling.
class DraggableLecture extends StatelessWidget {
  const DraggableLecture({
    super.key,
    required this.lecture,
    required this.child,
  });

  final Lecture lecture;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final controller = LectureDragScope.maybeOf(context);
    if (controller == null) return child;

    final data = LectureDragData(
      lectureId: lecture.id,
      fromSemesterId: lecture.semesterId,
      season: lecture.season,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final feedback = _DragFeedback(
          lecture: lecture,
          width: constraints.maxWidth.clamp(200.0, 420.0),
        );
        final dimmed = Opacity(opacity: 0.35, child: child);
        void started() => controller.start(data);
        void moved(DragUpdateDetails d) => controller.update(d.globalPosition);
        // The drop itself happens on pointer-up (see LectureDragListener);
        // this only cleans up when the drag ends any other way.
        void ended(DraggableDetails _) => controller.cancel();

        return _dragWithMouse
            ? Draggable<LectureDragData>(
                data: data,
                feedback: feedback,
                childWhenDragging: dimmed,
                onDragStarted: started,
                onDragUpdate: moved,
                onDragEnd: ended,
                child: child,
              )
            : LongPressDraggable<LectureDragData>(
                data: data,
                feedback: feedback,
                childWhenDragging: dimmed,
                onDragStarted: started,
                onDragUpdate: moved,
                onDragEnd: ended,
                child: child,
              );
      },
    );
  }
}

/// Catches the release of a lecture drag over the whole plan. Pointer
/// events reach this listener before the drag gesture ends, so the drop is
/// decided from the real release point.
class LectureDragListener extends StatelessWidget {
  const LectureDragListener({
    super.key,
    required this.controller,
    required this.child,
  });

  final LectureDragController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerUp: (e) => controller.release(e.position),
    onPointerCancel: (_) => controller.cancel(),
    child: child,
  );
}

/// The card that follows the pointer: name, ECTS and the lecture colour.
class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.lecture, required this.width});

  final Lecture lecture;
  final double width;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Material(
      elevation: 8,
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 28,
                decoration: BoxDecoration(
                  color: hexColor(lecture.color),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  lecture.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ),
              Text(
                '${lecture.ects} ECTS',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// How a drop target looks while a lecture hovers over it.
enum DropHighlight {
  /// Dropping here moves the lecture.
  ok,

  /// Dropping here works, but the lecture's turnus does not match the
  /// semester (a hint, as everywhere in StudiPlan, not a block).
  turnusMismatch,
}

/// Wraps a semester or the parking lot as a drop target: registers it with
/// the [LectureDragController], frames it while a lecture hovers, and opens
/// it when a lecture rests on it while collapsed.
class LectureDropZone extends StatefulWidget {
  const LectureDropZone({
    super.key,
    required this.id,
    required this.builder,
    this.season,
    this.collapsed = false,
    this.onExpand,
    this.margin = EdgeInsets.zero,
  });

  final DropTargetId id;

  /// The semester's season ('winter'/'summer'); `null` for the parking lot.
  final String? season;

  final bool collapsed;

  /// Opens the section; called after [expandDelay] of hovering while
  /// [collapsed].
  final VoidCallback? onExpand;

  final EdgeInsets margin;

  final Widget Function(BuildContext context, DropHighlight? highlight) builder;

  static const Duration expandDelay = Duration(milliseconds: 600);

  @override
  State<LectureDropZone> createState() => _LectureDropZoneState();
}

class _LectureDropZoneState extends State<LectureDropZone> {
  final GlobalKey _key = GlobalKey();
  LectureDragController? _controller;
  Timer? _expandTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = LectureDragScope.maybeOf(context);
    if (!identical(controller, _controller)) {
      _controller?.unregisterTarget(widget.id, _key);
      _controller = controller;
      _controller?.registerTarget(widget.id, _key);
    }
    _syncExpandTimer();
  }

  @override
  void didUpdateWidget(LectureDropZone oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _controller?.unregisterTarget(oldWidget.id, _key);
      _controller?.registerTarget(widget.id, _key);
    }
    _syncExpandTimer();
  }

  bool get _hovered => _controller?.hovered == widget.id;

  void _syncExpandTimer() {
    if (_hovered && widget.collapsed && widget.onExpand != null) {
      _expandTimer ??= Timer(LectureDropZone.expandDelay, () {
        _expandTimer = null;
        if (mounted && _hovered && widget.collapsed) widget.onExpand?.call();
      });
    } else {
      _expandTimer?.cancel();
      _expandTimer = null;
    }
  }

  @override
  void dispose() {
    _expandTimer?.cancel();
    _controller?.unregisterTarget(widget.id, _key);
    super.dispose();
  }

  DropHighlight? get _highlight {
    final data = _controller?.active;
    if (data == null || !_hovered) return null;
    final season = widget.season;
    if (season != null && data.season != 'both' && data.season != season) {
      return DropHighlight.turnusMismatch;
    }
    return DropHighlight.ok;
  }

  @override
  Widget build(BuildContext context) {
    final highlight = _highlight;
    final color = switch (highlight) {
      DropHighlight.ok => context.cs.primary,
      DropHighlight.turnusMismatch => context.tone(Colors.orange),
      null => Colors.transparent,
    };
    return Padding(
      padding: widget.margin,
      child: AnimatedContainer(
        key: _key,
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color, width: 2),
          color: highlight == null ? null : color.withValues(alpha: 0.06),
        ),
        child: widget.builder(context, highlight),
      ),
    );
  }
}

/// The small label a hovered drop target shows in its header.
class DropHint extends StatelessWidget {
  const DropHint(this.highlight, {super.key});

  final DropHighlight highlight;

  @override
  Widget build(BuildContext context) {
    final mismatch = highlight == DropHighlight.turnusMismatch;
    final color = mismatch ? context.tone(Colors.orange) : context.cs.primary;
    return Container(
      key: const ValueKey('drop-hint'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        mismatch ? 'Ablegen · Turnus passt nicht' : 'Hier ablegen',
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
