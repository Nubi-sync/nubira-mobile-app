import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Authentic Zigza Dual-Ring Counter-Rotating Loading Spinner
/// Matches the web app's signature loading indicator:
/// - Outer ring: Dark Brand Blue / Obsidian spinning clockwise
/// - Inner ring: Light Cyan / Blue spinning counter-clockwise
class ZigzaDualRingSpinner extends StatefulWidget {
  final double size;
  final double strokeWidth;
  final Color? outerColor;
  final Color? innerColor;
  final Color? trackColor;

  const ZigzaDualRingSpinner({
    super.key,
    this.size = 38.0,
    this.strokeWidth = 2.4,
    this.outerColor,
    this.innerColor,
    this.trackColor,
  });

  @override
  State<ZigzaDualRingSpinner> createState() => _ZigzaDualRingSpinnerState();
}

class _ZigzaDualRingSpinnerState extends State<ZigzaDualRingSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final outer = widget.outerColor ?? const Color(0xFF1D4ED8);
    final inner = widget.innerColor ?? const Color(0xFF14C8B4);
    final track = widget.trackColor ?? outer.withValues(alpha: 0.14);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _DualRingPainter(
              progress: _controller.value,
              outerColor: outer,
              innerColor: inner,
              trackColor: track,
              strokeWidth: widget.strokeWidth,
            ),
          );
        },
      ),
    );
  }
}

class _DualRingPainter extends CustomPainter {
  final double progress;
  final Color outerColor;
  final Color innerColor;
  final Color trackColor;
  final double strokeWidth;

  _DualRingPainter({
    required this.progress,
    required this.outerColor,
    required this.innerColor,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = (size.width - strokeWidth) / 2;
    final innerRadius = outerRadius * 0.58;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    // 1. Outer full track circle
    canvas.drawCircle(center, outerRadius, trackPaint);

    // 2. Inner full track circle
    final innerTrackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.85;
    canvas.drawCircle(center, innerRadius, innerTrackPaint);

    // 3. Outer spinning arc (Clockwise)
    final outerStartAngle = progress * 2 * math.pi;
    const outerSweepAngle = 1.25 * math.pi; // ~225 degrees arc
    final outerArcPaint = Paint()
      ..color = outerColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: outerRadius),
      outerStartAngle,
      outerSweepAngle,
      false,
      outerArcPaint,
    );

    // 4. Inner counter-spinning arc (Counter-clockwise, slightly different speed)
    final innerStartAngle = -progress * 2 * math.pi * 1.2;
    const innerSweepAngle = 1.15 * math.pi; // ~200 degrees arc
    final innerArcPaint = Paint()
      ..color = innerColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.85
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: innerRadius),
      innerStartAngle,
      innerSweepAngle,
      false,
      innerArcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _DualRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.outerColor != outerColor ||
        oldDelegate.innerColor != innerColor;
  }
}

