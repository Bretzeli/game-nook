import 'package:flutter/material.dart';

enum AppButtonStyle {
  filled,
  soft,
  outlined,
}

@immutable
class AppDecor extends ThemeExtension<AppDecor> {
  const AppDecor({
    required this.backgroundGradientStart,
    required this.backgroundGradientEnd,
    required this.cardColor,
    required this.cardBorderColor,
    required this.cardBorderWidth,
    required this.cardBorderRadius,
    required this.accentColor,
    required this.accentSecondary,
    required this.glowColor,
    required this.navBarColor,
    required this.navBarBorderColor,
    required this.buttonStyle,
    required this.buttonBorderRadius,
    required this.subtleTextColor,
    required this.orbColor1,
    required this.orbColor2,
    required this.cardHoverGlow,
  });

  final Color backgroundGradientStart;
  final Color backgroundGradientEnd;
  final Color cardColor;
  final Color cardBorderColor;
  final double cardBorderWidth;
  final double cardBorderRadius;
  final Color accentColor;
  final Color accentSecondary;
  final Color glowColor;
  final Color navBarColor;
  final Color navBarBorderColor;
  final AppButtonStyle buttonStyle;
  final double buttonBorderRadius;
  final Color subtleTextColor;
  final Color orbColor1;
  final Color orbColor2;
  final Color cardHoverGlow;

  LinearGradient get backgroundGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [backgroundGradientStart, backgroundGradientEnd],
      );

  BorderRadius get cardRadius => BorderRadius.circular(cardBorderRadius);

  BorderRadius get buttonRadius => BorderRadius.circular(buttonBorderRadius);

  Color get subtleNavBorder => navBarBorderColor.withValues(alpha: 0.22);

  @override
  AppDecor copyWith({
    Color? backgroundGradientStart,
    Color? backgroundGradientEnd,
    Color? cardColor,
    Color? cardBorderColor,
    double? cardBorderWidth,
    double? cardBorderRadius,
    Color? accentColor,
    Color? accentSecondary,
    Color? glowColor,
    Color? navBarColor,
    Color? navBarBorderColor,
    AppButtonStyle? buttonStyle,
    double? buttonBorderRadius,
    Color? subtleTextColor,
    Color? orbColor1,
    Color? orbColor2,
    Color? cardHoverGlow,
  }) {
    return AppDecor(
      backgroundGradientStart:
          backgroundGradientStart ?? this.backgroundGradientStart,
      backgroundGradientEnd:
          backgroundGradientEnd ?? this.backgroundGradientEnd,
      cardColor: cardColor ?? this.cardColor,
      cardBorderColor: cardBorderColor ?? this.cardBorderColor,
      cardBorderWidth: cardBorderWidth ?? this.cardBorderWidth,
      cardBorderRadius: cardBorderRadius ?? this.cardBorderRadius,
      accentColor: accentColor ?? this.accentColor,
      accentSecondary: accentSecondary ?? this.accentSecondary,
      glowColor: glowColor ?? this.glowColor,
      navBarColor: navBarColor ?? this.navBarColor,
      navBarBorderColor: navBarBorderColor ?? this.navBarBorderColor,
      buttonStyle: buttonStyle ?? this.buttonStyle,
      buttonBorderRadius: buttonBorderRadius ?? this.buttonBorderRadius,
      subtleTextColor: subtleTextColor ?? this.subtleTextColor,
      orbColor1: orbColor1 ?? this.orbColor1,
      orbColor2: orbColor2 ?? this.orbColor2,
      cardHoverGlow: cardHoverGlow ?? this.cardHoverGlow,
    );
  }

  @override
  AppDecor lerp(ThemeExtension<AppDecor>? other, double t) {
    if (other is! AppDecor) return this;
    return AppDecor(
      backgroundGradientStart: Color.lerp(
        backgroundGradientStart,
        other.backgroundGradientStart,
        t,
      )!,
      backgroundGradientEnd: Color.lerp(
        backgroundGradientEnd,
        other.backgroundGradientEnd,
        t,
      )!,
      cardColor: Color.lerp(cardColor, other.cardColor, t)!,
      cardBorderColor: Color.lerp(cardBorderColor, other.cardBorderColor, t)!,
      cardBorderWidth: cardBorderWidth + (other.cardBorderWidth - cardBorderWidth) * t,
      cardBorderRadius:
          cardBorderRadius + (other.cardBorderRadius - cardBorderRadius) * t,
      accentColor: Color.lerp(accentColor, other.accentColor, t)!,
      accentSecondary: Color.lerp(accentSecondary, other.accentSecondary, t)!,
      glowColor: Color.lerp(glowColor, other.glowColor, t)!,
      navBarColor: Color.lerp(navBarColor, other.navBarColor, t)!,
      navBarBorderColor:
          Color.lerp(navBarBorderColor, other.navBarBorderColor, t)!,
      buttonStyle: t < 0.5 ? buttonStyle : other.buttonStyle,
      buttonBorderRadius:
          buttonBorderRadius + (other.buttonBorderRadius - buttonBorderRadius) * t,
      subtleTextColor: Color.lerp(subtleTextColor, other.subtleTextColor, t)!,
      orbColor1: Color.lerp(orbColor1, other.orbColor1, t)!,
      orbColor2: Color.lerp(orbColor2, other.orbColor2, t)!,
      cardHoverGlow: Color.lerp(cardHoverGlow, other.cardHoverGlow, t)!,
    );
  }
}

extension AppDecorContext on BuildContext {
  AppDecor get decor => Theme.of(this).extension<AppDecor>()!;
}
