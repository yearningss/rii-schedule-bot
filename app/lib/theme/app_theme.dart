import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_shape.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Фабрика конфигурации тем оформления Material 3 для приложения.
class AppTheme {
  AppTheme._();

  /// Светлая тема оформления.
  static ThemeData get light => _buildTheme(
        colors: AppColors.lightColorScheme,
        scheduleColors: AppScheduleColors.light,
      );

  /// Темная тема оформления.
  static ThemeData get dark => _buildTheme(
        colors: AppColors.darkColorScheme,
        scheduleColors: AppScheduleColors.dark,
      );

  static ThemeData _buildTheme({
    required ColorScheme colors,
    required AppScheduleColors scheduleColors,
  }) {
    final textTheme = AppTypography.createTextTheme(colors);
    final isDark = colors.brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: colors.brightness,
      colorScheme: colors,
      scaffoldBackgroundColor: colors.surfaceContainerLow,
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[
        scheduleColors,
      ],
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        backgroundColor: colors.surfaceContainerLow,
        foregroundColor: colors.onSurface,
        surfaceTintColor: colors.surfaceTint,
        titleTextStyle: AppTypography.titleLarge.copyWith(
          color: colors.onSurface,
        ),
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: colors.surfaceContainer,
                systemNavigationBarIconBrightness: Brightness.light,
              )
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: colors.surfaceContainer,
                systemNavigationBarIconBrightness: Brightness.dark,
              ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: AppShape.cardShape,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: AppShape.buttonShape,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: AppSpacing.md,
          ),
          textStyle: AppTypography.labelLarge,
          minimumSize: const Size(48, 48),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 1,
          shape: AppShape.buttonShape,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: AppSpacing.md,
          ),
          textStyle: AppTypography.labelLarge,
          minimumSize: const Size(48, 48),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: AppShape.buttonShape,
          side: BorderSide(color: colors.outlineVariant),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: AppSpacing.md,
          ),
          textStyle: AppTypography.labelLarge,
          minimumSize: const Size(48, 48),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: AppShape.buttonShape,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          textStyle: AppTypography.labelLarge,
          minimumSize: const Size(48, 40),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: AppShape.chipShape,
        side: BorderSide(color: colors.outlineVariant),
        backgroundColor: colors.surfaceContainer,
        selectedColor: colors.secondaryContainer,
        labelStyle: AppTypography.labelMedium.copyWith(
          color: colors.onSurface,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 68,
        backgroundColor: colors.surfaceContainer,
        indicatorColor: colors.secondaryContainer,
        surfaceTintColor: colors.surfaceTint,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          final isSelected = states.contains(MaterialState.selected);
          return AppTypography.labelSmall.copyWith(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? colors.onSurface : colors.onSurfaceVariant,
          );
        }),
        iconTheme: MaterialStateProperty.resolveWith((states) {
          final isSelected = states.contains(MaterialState.selected);
          return IconThemeData(
            color: isSelected
                ? colors.onSecondaryContainer
                : colors.onSurfaceVariant,
            size: 24,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colors.surfaceContainer,
        indicatorColor: colors.secondaryContainer,
        labelType: NavigationRailLabelType.all,
        selectedLabelTextStyle: AppTypography.labelSmall.copyWith(
          fontWeight: FontWeight.w600,
          color: colors.onSurface,
        ),
        unselectedLabelTextStyle: AppTypography.labelSmall.copyWith(
          color: colors.onSurfaceVariant,
        ),
        selectedIconTheme: IconThemeData(
          color: colors.onSecondaryContainer,
          size: 24,
        ),
        unselectedIconTheme: IconThemeData(
          color: colors.onSurfaceVariant,
          size: 24,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: MaterialStateProperty.all(
            const RoundedRectangleBorder(
              borderRadius: AppShape.roundedMd,
            ),
          ),
          textStyle: MaterialStateProperty.all(
            AppTypography.labelMedium,
          ),
          side: MaterialStateProperty.resolveWith(
            (states) => BorderSide(color: colors.outlineVariant),
          ),
          backgroundColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return colors.secondaryContainer;
            }
            return colors.surfaceContainerLow;
          }),
          foregroundColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return colors.onSecondaryContainer;
            }
            return colors.onSurfaceVariant;
          }),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainer,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        border: const OutlineInputBorder(
          borderRadius: AppShape.roundedMd,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppShape.roundedMd,
          borderSide: BorderSide(color: colors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppShape.roundedMd,
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppShape.roundedMd,
          borderSide: BorderSide(color: colors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppShape.roundedMd,
          borderSide: BorderSide(color: colors.error, width: 2),
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(
          color: colors.onSurfaceVariant.withOpacity(0.7),
        ),
      ),
      dialogTheme: DialogThemeData(
        elevation: 0,
        backgroundColor: colors.surfaceContainerHigh,
        shape: AppShape.dialogShape,
        titleTextStyle: AppTypography.headlineSmall.copyWith(
          color: colors.onSurface,
        ),
        contentTextStyle: AppTypography.bodyMedium.copyWith(
          color: colors.onSurfaceVariant,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        elevation: 0,
        backgroundColor: colors.surfaceContainerLow,
        modalBackgroundColor: colors.surfaceContainerLow,
        shape: AppShape.bottomSheetShape,
        dragHandleColor: colors.outlineVariant,
        showDragHandle: true,
      ),
      dividerTheme: DividerThemeData(
        color: colors.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.inverseSurface,
        contentTextStyle: AppTypography.bodyMedium.copyWith(
          color: colors.onInverseSurface,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: AppShape.roundedSm,
        ),
      ),
    );
  }
}
