import 'dart:async';
import '../models/event.dart';

/// Coalesces high-frequency touch motion deltas into fixed-rate MoveEvents (~60-120 Hz).
class MoveCoalescer {
  MoveCoalescer({
    this.tickInterval = const Duration(milliseconds: 16), // ~60 Hz
    void Function(MoveEvent)? onEvent,
  }) : _onEvent = onEvent {
    _startTimer();
  }

  final Duration tickInterval;
  final void Function(MoveEvent)? _onEvent;

  final _streamController = StreamController<MoveEvent>.broadcast();
  Stream<MoveEvent> get stream => _streamController.stream;

  Timer? _timer;
  double _accumDx = 0.0;
  double _accumDy = 0.0;
  bool _isDisposed = false;

  void _startTimer() {
    _timer = Timer.periodic(tickInterval, (_) => _tick());
  }

  /// Adds a motion delta to be coalesced.
  void addDelta(double dx, double dy) {
    if (_isDisposed) return;
    _accumDx += dx;
    _accumDy += dy;
  }

  void _tick() {
    if (_accumDx != 0.0 || _accumDy != 0.0) {
      final event = MoveEvent(dx: _accumDx, dy: _accumDy);
      _accumDx = 0.0;
      _accumDy = 0.0;
      _onEvent?.call(event);
      if (!_streamController.isClosed) {
        _streamController.add(event);
      }
    }
  }

  /// Immediately flushes any pending deltas.
  void flush() {
    _tick();
  }

  void dispose() {
    _isDisposed = true;
    _timer?.cancel();
    _timer = null;
    flush();
    _streamController.close();
  }
}
