import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_theme_extension.dart';

class AnimatedBackground extends StatefulWidget {
  const AnimatedBackground({super.key});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final decor = context.decor;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return Container(
          decoration: BoxDecoration(gradient: decor.backgroundGradient),
          child: Stack(
            children: [
              _FloatingOrb(
                color: decor.orbColor1,
                size: 280,
                offset: Offset(
                  math.sin(t * 2 * math.pi) * 40,
                  math.cos(t * 2 * math.pi) * 30 - 60,
                ),
                alignment: Alignment.topRight,
              ),
              _FloatingOrb(
                color: decor.orbColor2,
                size: 220,
                offset: Offset(
                  math.cos(t * 2 * math.pi + 1) * 50,
                  math.sin(t * 2 * math.pi + 1) * 40 + 80,
                ),
                alignment: Alignment.bottomLeft,
              ),
              _FloatingOrb(
                color: decor.glowColor.withValues(alpha: 0.15),
                size: 160,
                offset: Offset(
                  math.sin(t * 2 * math.pi + 2) * 30,
                  math.cos(t * 2 * math.pi + 2) * 20,
                ),
                alignment: Alignment.center,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FloatingOrb extends StatelessWidget {
  const _FloatingOrb({
    required this.color,
    required this.size,
    required this.offset,
    required this.alignment,
  });

  final Color color;
  final double size;
  final Offset offset;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Transform.translate(
        offset: offset,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color, color.withValues(alpha: 0)],
            ),
          ),
        ),
      ),
    );
  }
}
