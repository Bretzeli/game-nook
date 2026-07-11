import 'package:flutter/material.dart';

/// A simple worm silhouette for Wormdle game cards.
class WormIcon extends StatelessWidget {
  const WormIcon({super.key, required this.color, this.size = 28});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _WormPainter(color: color),
      ),
    );
  }
}

class _WormPainter extends CustomPainter {
  _WormPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final eyePaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;
    final segment = w * 0.22;

    // Body segments in an S-curve
    final segments = [
      Offset(w * 0.78, h * 0.35),
      Offset(w * 0.58, h * 0.55),
      Offset(w * 0.38, h * 0.42),
      Offset(w * 0.18, h * 0.58),
    ];

    for (final center in segments) {
      canvas.drawCircle(center, segment * 0.55, paint);
    }

    // Head (slightly larger)
    final head = Offset(w * 0.82, h * 0.28);
    canvas.drawCircle(head, segment * 0.62, paint);

    // Eyes
    canvas.drawCircle(
      Offset(head.dx - segment * 0.18, head.dy - segment * 0.12),
      segment * 0.12,
      eyePaint,
    );
    canvas.drawCircle(
      Offset(head.dx + segment * 0.05, head.dy - segment * 0.15),
      segment * 0.1,
      eyePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _WormPainter oldDelegate) =>
      oldDelegate.color != color;
}
