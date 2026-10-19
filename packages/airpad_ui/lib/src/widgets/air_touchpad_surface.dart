import 'package:airpad_core/airpad_core.dart';
import 'package:flutter/material.dart';
import '../theme/air_theme.dart';

/// Touchpad surface widget with visual touch ring indicators following active fingers.
class AirTouchpadSurface extends StatefulWidget {
  const AirTouchpadSurface({
    super.key,
    required this.processor,
  });

  final TouchpadProcessor processor;

  @override
  State<AirTouchpadSurface> createState() => _AirTouchpadSurfaceState();
}

class _AirTouchpadSurfaceState extends State<AirTouchpadSurface> {
  final Map<int, Offset> _touchLocations = {};

  void _onPointerDown(PointerDownEvent event) {
    setState(() {
      _touchLocations[event.pointer] = event.localPosition;
    });
    widget.processor.onPointerDown(
      event.pointer,
      event.localPosition.dx,
      event.localPosition.dy,
    );
  }

  void _onPointerMove(PointerMoveEvent event) {
    setState(() {
      _touchLocations[event.pointer] = event.localPosition;
    });
    widget.processor.onPointerMove(
      event.pointer,
      event.localPosition.dx,
      event.localPosition.dy,
      event.delta.dx,
      event.delta.dy,
    );
  }

  void _onPointerUp(PointerUpEvent event) {
    setState(() {
      _touchLocations.remove(event.pointer);
    });
    widget.processor.onPointerUp(
      event.pointer,
      event.localPosition.dx,
      event.localPosition.dy,
    );
  }

  void _onPointerCancel(PointerCancelEvent event) {
    setState(() {
      _touchLocations.remove(event.pointer);
    });
    widget.processor.onPointerCancel(event.pointer);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: Container(
        decoration: BoxDecoration(
          color: AirTheme.black,
          borderRadius: BorderRadius.circular(AirpadTokens.cornerRadius),
          border: Border.all(
            color: AirTheme.gray700,
            width: AirpadTokens.borderWidth,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AirpadTokens.cornerRadius),
          child: CustomPaint(
            painter: _TouchFeedbackPainter(
              touchLocations: _touchLocations.values.toList(),
              isDragging: widget.processor.isDragging,
            ),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _TouchFeedbackPainter extends CustomPainter {
  const _TouchFeedbackPainter({
    required this.touchLocations,
    required this.isDragging,
  });

  final List<Offset> touchLocations;
  final bool isDragging;

  @override
  void paint(Canvas canvas, Size size) {
    // Optional subtle grid lines or center mark
    final centerPaint = Paint()
      ..color = AirTheme.gray700
      ..strokeWidth = 1.0;

    // Small subtle center crosshair
    const markSize = 8.0;
    final cx = size.width / 2;
    final cy = size.height / 2;
    canvas.drawLine(Offset(cx - markSize, cy), Offset(cx + markSize, cy), centerPaint);
    canvas.drawLine(Offset(cx, cy - markSize), Offset(cx, cy + markSize), centerPaint);

    // Active touch rings (Section 8.4)
    final ringPaint = Paint()
      ..color = AirTheme.white
      ..style = isDragging ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final radius = isDragging ? 16.0 : 24.0;
    for (final pos in touchLocations) {
      canvas.drawCircle(pos, radius, ringPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TouchFeedbackPainter oldDelegate) {
    return oldDelegate.touchLocations != touchLocations ||
        oldDelegate.isDragging != isDragging;
  }
}
