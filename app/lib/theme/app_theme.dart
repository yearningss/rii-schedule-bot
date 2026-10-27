import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Общая тема Material 3 для всех экранов.
abstract final class AppTheme {
  static const seed = Color(0xFF386A52);
  static const small = 12.0;
  static const large = 28.0;
  static const sheet = 32.0;

  static ThemeData create(Brightness brightness) {
    final colors =
        ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    final base = ThemeData(
        useMaterial3: true, colorScheme: colors, fontFamily: 'RobotoFlex');
    return base.copyWith(
      scaffoldBackgroundColor: colors.surface,
      splashFactory: InkSparkle.splashFactory,
      iconTheme: IconThemeData(color: colors.onSurfaceVariant, size: 24),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
        linearTrackColor: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(small),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: colors.surfaceContainerHigh,
        selectedColor: colors.secondaryContainer,
        side: BorderSide.none,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(small)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceContainerHigh,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(sheet)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(small)),
      ),
      textTheme: base.textTheme.copyWith(
        displaySmall: base.textTheme.displaySmall
            ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -1),
        headlineMedium: base.textTheme.headlineMedium
            ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5),
        headlineSmall:
            base.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        labelLarge:
            base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        titleLarge:
            base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium:
            base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        surfaceTintColor: colors.surfaceTint,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        systemOverlayStyle: brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: colors.surfaceContainerLow,
        elevation: 0,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(large)),
      ),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: const StadiumBorder(),
      )),
      elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        elevation: 0,
        minimumSize: const Size(48, 48),
        shape: const StadiumBorder(),
      )),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: const StadiumBorder(),
      )),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainerHighest,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(small)),
        contentPadding: const EdgeInsets.all(16),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surfaceContainerLow,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(sheet)),
        ),
      ),
      dividerTheme:
          DividerThemeData(color: colors.outlineVariant, thickness: 1),
      listTileTheme: const ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 8)),
    );
  }
}
