import 'package:flutter/material.dart';

import '../core/theme/app_theme_extension.dart';

class AnimatedBackground extends StatelessWidget {
  const AnimatedBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final decor = context.decor;

    return Container(
      decoration: BoxDecoration(gradient: decor.backgroundGradient),
    );
  }
}
