import 'package:flutter/material.dart';

/// Returns a layout scale factor based on viewport width.
/// Base design targets ~900px; scales up on larger screens.
double layoutScaleForWidth(double width) {
  if (width >= 1600) return 1.4;
  if (width >= 1200) return 1.28;
  if (width >= 900) return 1.15;
  if (width >= 600) return 1.0;
  return (width / 600).clamp(0.9, 1.0);
}

extension ResponsiveContext on BuildContext {
  double get layoutScale => layoutScaleForWidth(MediaQuery.sizeOf(this).width);

  /// Scale a layout value (padding, icon size, radius, etc.).
  double rs(double value) => value * layoutScale;
}
