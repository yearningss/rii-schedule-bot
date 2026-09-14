import 'package:flutter/material.dart';

/// Дизайн-токены типографики по спецификации Material 3.
class AppTypography {
  AppTypography._();

  // Display стили для крупных заголовков
  static const TextStyle displayLarge = TextStyle(
    fontSize: 57.0,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.25,
    height: 1.12,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 45.0,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.0,
    height: 1.16,
  );

  static const TextStyle displaySmall = TextStyle(
    fontSize: 36.0,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.0,
    height: 1.22,
  );

  // Headline стили
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 32.0,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.0,
    height: 1.25,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 28.0,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.0,
    height: 1.29,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontSize: 24.0,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.0,
    height: 1.33,
  );

  // Title стили для карточек и заголовков секций
  static const TextStyle titleLarge = TextStyle(
    fontSize: 22.0,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.0,
    height: 1.27,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.15,
    height: 1.5,
  );

  static const TextStyle titleSmall = TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.43,
  );

  // Body стили для основного содержимого
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.5,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
    height: 1.43,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12.0,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    height: 1.33,
  );

  // Label стили для кнопок, чипов, подписей и бейджей
  static const TextStyle labelLarge = TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.43,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12.0,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.33,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 11.0,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.45,
  );

  /// Генерация TextTheme на основе заданной цветовой схемы
  static TextTheme createTextTheme(ColorScheme colors) {
    return TextTheme(
      displayLarge: displayLarge.copyWith(color: colors.onSurface),
      displayMedium: displayMedium.copyWith(color: colors.onSurface),
      displaySmall: displaySmall.copyWith(color: colors.onSurface),
      headlineLarge: headlineLarge.copyWith(color: colors.onSurface),
      headlineMedium: headlineMedium.copyWith(color: colors.onSurface),
      headlineSmall: headlineSmall.copyWith(color: colors.onSurface),
      titleLarge: titleLarge.copyWith(color: colors.onSurface),
      titleMedium: titleMedium.copyWith(color: colors.onSurface),
      titleSmall: titleSmall.copyWith(color: colors.onSurface),
      bodyLarge: bodyLarge.copyWith(color: colors.onSurface),
      bodyMedium: bodyMedium.copyWith(color: colors.onSurface),
      bodySmall: bodySmall.copyWith(color: colors.onSurfaceVariant),
      labelLarge: labelLarge.copyWith(color: colors.onSurface),
      labelMedium: labelMedium.copyWith(color: colors.onSurfaceVariant),
      labelSmall: labelSmall.copyWith(color: colors.onSurfaceVariant),
    );
  }
}
