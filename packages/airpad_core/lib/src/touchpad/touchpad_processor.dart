import 'dart:async';
import 'dart:math';

import '../models/event.dart';
import 'move_coalescer.dart';

class _TouchPoint {
  _TouchPoint({
    required this.id,
    required this.startX,
    required this.startY,
    required this.time,
  })  : currentX = startX,
        currentY = startY;

  final int id;
  final double startX;
  final double startY;
  final DateTime time;
  double currentX;
  double currentY;

  double get totalDisplacement =>
      sqrt(pow(currentX - startX, 2) + pow(currentY - startY, 2));
}

/// Gesture recognizer and processor converting multi-touch raw pointer events
/// into Airpad protocol events (move, scroll, clicks, drag).
class TouchpadProcessor {
  TouchpadProcessor({
    this.sensitivity = 1.0,
    this.naturalScroll = true,
    this.accelerationEnabled = true,
    this.moveSlop = 6.0,
    this.tapThreshold = const Duration(milliseconds: 250),
    this.doubleTapInterval = const Duration(milliseconds: 250),
    void Function(AirpadEvent)? onEvent,
  }) : _onEvent = onEvent {
    _coalescer = MoveCoalescer(
      onEvent: (move) => _emitEvent(move),
    );
  }

  double sensitivity;
  bool naturalScroll;
  bool accelerationEnabled;
  final double moveSlop;
  final Duration tapThreshold;
  final Duration doubleTapInterval;
  final void Function(AirpadEvent)? _onEvent;

  late final MoveCoalescer _coalescer;
  final Map<int, _TouchPoint> _activeTouches = {};
  int _maxFingersSeen = 0;
  bool _isDragging = false;
  DateTime? _lastTapTime;
  double _lastTapX = 0.0;
  double _lastTapY = 0.0;

  final _eventController = StreamController<AirpadEvent>.broadcast();
  Stream<AirpadEvent> get onEvent => _eventController.stream;

  bool get isDragging => _isDragging;
  int get activePointerCount => _activeTouches.length;

  /// Call when a touch pointer touches down.
  void onPointerDown(int pointerId, double x, double y) {
    final now = DateTime.now();
    _activeTouches[pointerId] = _TouchPoint(
      id: pointerId,
      startX: x,
      startY: y,
      time: now,
    );

    if (_activeTouches.length > _maxFingersSeen) {
      _maxFingersSeen = _activeTouches.length;
    }

    // Check tap-then-hold drag gesture (or second tap of a double tap)
    if (_activeTouches.length == 1 && _lastTapTime != null) {
      final elapsed = now.difference(_lastTapTime!);
      final distFromLastTap =
          sqrt(pow(x - _lastTapX, 2) + pow(y - _lastTapY, 2));

      if (elapsed <= doubleTapInterval && distFromLastTap <= 30.0) {
        _isDragging = true;
        _emitEvent(const ButtonEvent(
          button: MouseButton.left,
          state: ButtonState.down,
        ));
      }
    }
  }

  /// Call when a touch pointer moves.
  void onPointerMove(
    int pointerId,
    double x,
    double y,
    double deltaX,
    double deltaY,
  ) {
    final point = _activeTouches[pointerId];
    if (point == null) return;

    point.currentX = x;
    point.currentY = y;

    if (_activeTouches.length == 1) {
      // 1 Finger move / drag
      final speed = sqrt(deltaX * deltaX + deltaY * deltaY);
      final accel = accelerationEnabled
          ? (1.0 + (speed / 12.0).clamp(0.0, 2.5))
          : 1.0;

      final finalDx = deltaX * sensitivity * accel;
      final finalDy = deltaY * sensitivity * accel;

      _coalescer.addDelta(finalDx, finalDy);
    } else if (_activeTouches.length == 2) {
      // 2 Finger scroll
      final scrollMultiplier = naturalScroll ? 1.0 : -1.0;
      final event = ScrollEvent(
        dx: deltaX * sensitivity,
        dy: deltaY * sensitivity * scrollMultiplier,
      );
      _emitEvent(event);
    }
  }

  /// Call when a touch pointer lifts up.
  void onPointerUp(int pointerId, double x, double y) {
    final point = _activeTouches.remove(pointerId);
    if (point == null) return;

    point.currentX = x;
    point.currentY = y;
    final now = DateTime.now();
    final wasDragging = _isDragging;

    // End drag if finger lifted
    if (_isDragging && _activeTouches.isEmpty) {
      _isDragging = false;
      _coalescer.flush();
      _emitEvent(const ButtonEvent(
        button: MouseButton.left,
        state: ButtonState.up,
      ));
    }

    // Process tap gestures when last finger lifts up
    if (_activeTouches.isEmpty) {
      _coalescer.flush();
      final duration = now.difference(point.time);

      if (point.totalDisplacement <= moveSlop && duration <= tapThreshold) {
        if (_maxFingersSeen == 1) {
          if (wasDragging ||
              (_lastTapTime != null && now.difference(_lastTapTime!) <= doubleTapInterval)) {
            _emitEvent(const ClickEvent(button: MouseButton.left, count: 2));
            _lastTapTime = null;
          } else {
            _lastTapTime = now;
            _lastTapX = x;
            _lastTapY = y;
            _emitEvent(const ClickEvent(button: MouseButton.left, count: 1));
          }
        } else if (_maxFingersSeen == 2) {
          // Two finger tap -> Right click
          _emitEvent(const ClickEvent(button: MouseButton.right, count: 1));
          _lastTapTime = null;
        } else if (_maxFingersSeen == 3) {
          // Three finger tap -> Middle click
          _emitEvent(const ClickEvent(button: MouseButton.middle, count: 1));
          _lastTapTime = null;
        }
      } else if (wasDragging) {
        _lastTapTime = null;
      }
      _maxFingersSeen = 0;
    }
  }

  /// Call on pointer cancel or touch surface lost.
  void onPointerCancel(int pointerId) {
    _activeTouches.remove(pointerId);
    if (_isDragging && _activeTouches.isEmpty) {
      _isDragging = false;
      _emitEvent(const ButtonEvent(
        button: MouseButton.left,
        state: ButtonState.up,
      ));
    }
    if (_activeTouches.isEmpty) {
      _coalescer.flush();
      _maxFingersSeen = 0;
    }
  }

  /// Cancels all touches and ensures any held buttons are released.
  void reset() {
    if (_isDragging) {
      _isDragging = false;
      _emitEvent(const ButtonEvent(
        button: MouseButton.left,
        state: ButtonState.up,
      ));
    }
    _activeTouches.clear();
    _maxFingersSeen = 0;
    _lastTapTime = null;
  }

  void _emitEvent(AirpadEvent event) {
    _onEvent?.call(event);
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  void dispose() {
    reset();
    _coalescer.dispose();
    _eventController.close();
  }
}
