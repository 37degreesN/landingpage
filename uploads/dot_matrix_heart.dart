import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:health_timeline/core/theme/design_tokens.dart';

/// A dot-matrix heart animation with a breathing/pulsing effect.
///
/// Each dot in the grid is rendered as a small circle. Dots inside the
/// heart silhouette glow with varying opacity; dots outside are very faint.
/// A radial wave animation continuously pulses outward from the center,
/// modulating each dot's opacity and scale for a living, breathing feel.
///
/// Usage:
/// ```dart
/// const DotMatrixHeart(size: 200)
/// ```
class DotMatrixHeart extends StatefulWidget {
  /// Overall size (width & height) of the heart widget.
  final double size;

  /// Number of dots along each axis. Higher = denser grid.
  final int gridResolution;

  /// Duration of one full breathing cycle.
  final Duration breathDuration;

  /// If provided, overrides the default accent color from design tokens.
  final Color? color;

  const DotMatrixHeart({
    super.key,
    this.size = 180,
    this.gridResolution = 17,
    this.breathDuration = const Duration(milliseconds: 3000),
    this.color,
  });

  @override
  State<DotMatrixHeart> createState() => _DotMatrixHeartState();
}

class _DotMatrixHeartState extends State<DotMatrixHeart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.breathDuration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dotColor = widget.color ?? AppColors.of(context).accentPrimary;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _DotMatrixHeartPainter(
              color: dotColor,
              gridResolution: widget.gridResolution,
              phase: _controller.value,
            ),
          );
        },
      ),
    );
  }
}

/// Evaluates a heart-shaped signed distance function.
///
/// Returns a value from 0.0 (deep inside heart) to 1.0+ (outside heart).
/// The coordinate system is centered at (0,0) with x,y in [-1, 1].
double _heartSDF(double px, double py) {
  // Shift y up so the heart is better centered in the box
  final x = px;
  final y = -py + 0.3;

  // Classic algebraic heart: (x² + y² − 1)³ − x²·y³ = 0
  final x2 = x * x;
  final y2 = y * y;
  final a = x2 + y2 - 1.0;
  final value = a * a * a - x2 * y * y2;

  // Negative inside, positive outside. Normalize for smooth falloff.
  // The magic number 0.1 controls the edge softness.
  return value / 0.1;
}

class _DotMatrixHeartPainter extends CustomPainter {
  final Color color;
  final int gridResolution;
  final double phase; // 0.0 – 1.0

  _DotMatrixHeartPainter({
    required this.color,
    required this.gridResolution,
    required this.phase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final n = gridResolution;
    final cellW = size.width / n;
    final cellH = size.height / n;
    final dotRadius = math.min(cellW, cellH) * 0.28;

    final paint = Paint()..style = PaintingStyle.fill;

    // Center of the grid in normalized coords
    final cx = n / 2.0;
    final cy = n / 2.0;
    final maxDist = math.sqrt(cx * cx + cy * cy);

    for (int row = 0; row < n; row++) {
      for (int col = 0; col < n; col++) {
        // Map grid position to normalized coords [-1.1, 1.1]
        final nx = (col / (n - 1)) * 2.2 - 1.1;
        final ny = (row / (n - 1)) * 2.2 - 1.1;

        final sdf = _heartSDF(nx, ny);

        // Base opacity: dots inside the heart are bright, outside are faint.
        double baseOpacity;
        if (sdf < -0.15) {
          // Deep inside — full brightness
          baseOpacity = 0.85;
        } else if (sdf < 0.0) {
          // Near the edge — smooth gradient
          baseOpacity = 0.35 + 0.50 * (-sdf / 0.15);
        } else if (sdf < 0.15) {
          // Just outside — faint halo
          baseOpacity = 0.15 * (1.0 - sdf / 0.15);
        } else {
          // Far outside — invisible
          continue;
        }

        // Wave animation: radial pulse from center
        final distFromCenter =
            math.sqrt(math.pow(col - cx, 2) + math.pow(row - cy, 2));
        final normalizedDist = distFromCenter / maxDist;

        // Create a traveling wave that moves outward
        final wavePhase = (phase * 2 * math.pi) - (normalizedDist * math.pi * 1.5);
        final waveFactor = 0.5 + 0.5 * math.sin(wavePhase);

        // Modulate opacity and scale with the wave
        final animatedOpacity =
            (baseOpacity * (0.55 + 0.45 * waveFactor)).clamp(0.0, 1.0);
        final animatedScale = 0.7 + 0.3 * waveFactor;

        paint.color = color.withValues(alpha: animatedOpacity);

        final centerX = col * cellW + cellW / 2;
        final centerY = row * cellH + cellH / 2;

        canvas.drawCircle(
          Offset(centerX, centerY),
          dotRadius * animatedScale,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotMatrixHeartPainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.color != color ||
        oldDelegate.gridResolution != gridResolution;
  }
}
