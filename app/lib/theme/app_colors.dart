import 'package:flutter/material.dart';

/// Цветовые токены Material 3 для светлой и темной тем оформления.
class AppColors {
  AppColors._();

  // Основной брендовый синий цвет (seed)
  static const Color brandPrimary = Color(0xFF1D4ED8);
  static const Color brandPrimaryLight = Color(0xFF2563EB);
  static const Color brandPrimaryDark = Color(0xFF1E40AF);

  // Светлая схема Material 3
  static const ColorScheme lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF1D4ED8),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFDBEAFE),
    onPrimaryContainer: Color(0xFF1E3A8A),
    secondary: Color(0xFF475569),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFE2E8F0),
    onSecondaryContainer: Color(0xFF0F172A),
    tertiary: Color(0xFF0D9488),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFCCFBF1),
    onTertiaryContainer: Color(0xFF115E59),
    error: Color(0xFFDC2626),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFEE2E2),
    onErrorContainer: Color(0xFF991B1B),
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF0F172A),
    onSurfaceVariant: Color(0xFF64748B),
    outline: Color(0xFFCBD5E1),
    outlineVariant: Color(0xFFE2E8F0),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF1E293B),
    onInverseSurface: Color(0xFFF8FAFC),
    inversePrimary: Color(0xFF93C5FD),
    surfaceTint: Color(0xFF1D4ED8),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF8FAFC),
    surfaceContainer: Color(0xFFF1F5F9),
    surfaceContainerHigh: Color(0xFFE2E8F0),
    surfaceContainerHighest: Color(0xFFCBD5E1),
  );

  // Темная схема Material 3
  static const ColorScheme darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF93C5FD),
    onPrimary: Color(0xFF0F172A),
    primaryContainer: Color(0xFF1E3A8A),
    onPrimaryContainer: Color(0xFFDBEAFE),
    secondary: Color(0xFF94A3B8),
    onSecondary: Color(0xFF0F172A),
    secondaryContainer: Color(0xFF334155),
    onSecondaryContainer: Color(0xFFE2E8F0),
    tertiary: Color(0xFF5EEAD4),
    onTertiary: Color(0xFF042F2E),
    tertiaryContainer: Color(0xFF115E59),
    onTertiaryContainer: Color(0xFFCCFBF1),
    error: Color(0xFFF87171),
    onError: Color(0xFF450A0A),
    errorContainer: Color(0xFF7F1D1D),
    onErrorContainer: Color(0xFFFEE2E2),
    surface: Color(0xFF0B0F19),
    onSurface: Color(0xFFF1F5F9),
    onSurfaceVariant: Color(0xFF94A3B8),
    outline: Color(0xFF334155),
    outlineVariant: Color(0xFF1E293B),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFE2E8F0),
    onInverseSurface: Color(0xFF0F172A),
    inversePrimary: Color(0xFF1D4ED8),
    surfaceTint: Color(0xFF93C5FD),
    surfaceContainerLowest: Color(0xFF06090E),
    surfaceContainerLow: Color(0xFF0F1420),
    surfaceContainer: Color(0xFF161D2B),
    surfaceContainerHigh: Color(0xFF1E2638),
    surfaceContainerHighest: Color(0xFF273145),
  );
}

/// Семантические цвета для расписания занятий (статусы пар и типы занятий).
@immutable
class AppScheduleColors extends ThemeExtension<AppScheduleColors> {
  final Color ongoing;
  final Color ongoingContainer;
  final Color onOngoingContainer;
  final Color next;
  final Color nextContainer;
  final Color onNextContainer;
  final Color completed;
  final Color lecture;
  final Color lectureContainer;
  final Color onLectureContainer;
  final Color practice;
  final Color practiceContainer;
  final Color onPracticeContainer;
  final Color lab;
  final Color labContainer;
  final Color onLabContainer;
  final Color exam;
  final Color examContainer;
  final Color onExamContainer;

  const AppScheduleColors({
    required this.ongoing,
    required this.ongoingContainer,
    required this.onOngoingContainer,
    required this.next,
    required this.nextContainer,
    required this.onNextContainer,
    required this.completed,
    required this.lecture,
    required this.lectureContainer,
    required this.onLectureContainer,
    required this.practice,
    required this.practiceContainer,
    required this.onPracticeContainer,
    required this.lab,
    required this.labContainer,
    required this.onLabContainer,
    required this.exam,
    required this.examContainer,
    required this.onExamContainer,
  });

  static const light = AppScheduleColors(
    ongoing: Color(0xFF059669),
    ongoingContainer: Color(0xFFD1FAE5),
    onOngoingContainer: Color(0xFF065F46),
    next: Color(0xFF2563EB),
    nextContainer: Color(0xFFDBEAFE),
    onNextContainer: Color(0xFF1E3A8A),
    completed: Color(0xFF94A3B8),
    lecture: Color(0xFF2563EB),
    lectureContainer: Color(0xFFDBEAFE),
    onLectureContainer: Color(0xFF1E3A8A),
    practice: Color(0xFF059669),
    practiceContainer: Color(0xFFD1FAE5),
    onPracticeContainer: Color(0xFF065F46),
    lab: Color(0xFFD97706),
    labContainer: Color(0xFFFEF3C7),
    onLabContainer: Color(0xFF92400E),
    exam: Color(0xFF7C3AED),
    examContainer: Color(0xFFEDE9FE),
    onExamContainer: Color(0xFF5B21B6),
  );

  static const dark = AppScheduleColors(
    ongoing: Color(0xFF34D399),
    ongoingContainer: Color(0xFF064E3B),
    onOngoingContainer: Color(0xFFA7F3D0),
    next: Color(0xFF60A5FA),
    nextContainer: Color(0xFF1E3A8A),
    onNextContainer: Color(0xFFDBEAFE),
    completed: Color(0xFF64748B),
    lecture: Color(0xFF60A5FA),
    lectureContainer: Color(0xFF1E3A8A),
    onLectureContainer: Color(0xFFDBEAFE),
    practice: Color(0xFF34D399),
    practiceContainer: Color(0xFF064E3B),
    onPracticeContainer: Color(0xFFA7F3D0),
    lab: Color(0xFFFBBF24),
    labContainer: Color(0xFF78350F),
    onLabContainer: Color(0xFFFDE68A),
    exam: Color(0xFFA78BFA),
    examContainer: Color(0xFF4C1D95),
    onExamContainer: Color(0xFFDDD6FE),
  );

  @override
  AppScheduleColors copyWith({
    Color? ongoing,
    Color? ongoingContainer,
    Color? onOngoingContainer,
    Color? next,
    Color? nextContainer,
    Color? onNextContainer,
    Color? completed,
    Color? lecture,
    Color? lectureContainer,
    Color? onLectureContainer,
    Color? practice,
    Color? practiceContainer,
    Color? onPracticeContainer,
    Color? lab,
    Color? labContainer,
    Color? onLabContainer,
    Color? exam,
    Color? examContainer,
    Color? onExamContainer,
  }) {
    return AppScheduleColors(
      ongoing: ongoing ?? this.ongoing,
      ongoingContainer: ongoingContainer ?? this.ongoingContainer,
      onOngoingContainer: onOngoingContainer ?? this.onOngoingContainer,
      next: next ?? this.next,
      nextContainer: nextContainer ?? this.nextContainer,
      onNextContainer: onNextContainer ?? this.onNextContainer,
      completed: completed ?? this.completed,
      lecture: lecture ?? this.lecture,
      lectureContainer: lectureContainer ?? this.lectureContainer,
      onLectureContainer: onLectureContainer ?? this.onLectureContainer,
      practice: practice ?? this.practice,
      practiceContainer: practiceContainer ?? this.practiceContainer,
      onPracticeContainer: onPracticeContainer ?? this.onPracticeContainer,
      lab: lab ?? this.lab,
      labContainer: labContainer ?? this.labContainer,
      onLabContainer: onLabContainer ?? this.onLabContainer,
      exam: exam ?? this.exam,
      examContainer: examContainer ?? this.examContainer,
      onExamContainer: onExamContainer ?? this.onExamContainer,
    );
  }

  @override
  AppScheduleColors lerp(ThemeExtension<AppScheduleColors>? other, double t) {
    if (other is! AppScheduleColors) {
      return this;
    }
    return AppScheduleColors(
      ongoing: Color.lerp(ongoing, other.ongoing, t) ?? ongoing,
      ongoingContainer: Color.lerp(ongoingContainer, other.ongoingContainer, t) ?? ongoingContainer,
      onOngoingContainer: Color.lerp(onOngoingContainer, other.onOngoingContainer, t) ?? onOngoingContainer,
      next: Color.lerp(next, other.next, t) ?? next,
      nextContainer: Color.lerp(nextContainer, other.nextContainer, t) ?? nextContainer,
      onNextContainer: Color.lerp(onNextContainer, other.onNextContainer, t) ?? onNextContainer,
      completed: Color.lerp(completed, other.completed, t) ?? completed,
      lecture: Color.lerp(lecture, other.lecture, t) ?? lecture,
      lectureContainer: Color.lerp(lectureContainer, other.lectureContainer, t) ?? lectureContainer,
      onLectureContainer: Color.lerp(onLectureContainer, other.onLectureContainer, t) ?? onLectureContainer,
      practice: Color.lerp(practice, other.practice, t) ?? practice,
      practiceContainer: Color.lerp(practiceContainer, other.practiceContainer, t) ?? practiceContainer,
      onPracticeContainer: Color.lerp(onPracticeContainer, other.onPracticeContainer, t) ?? onPracticeContainer,
      lab: Color.lerp(lab, other.lab, t) ?? lab,
      labContainer: Color.lerp(labContainer, other.labContainer, t) ?? labContainer,
      onLabContainer: Color.lerp(onLabContainer, other.onLabContainer, t) ?? onLabContainer,
      exam: Color.lerp(exam, other.exam, t) ?? exam,
      examContainer: Color.lerp(examContainer, other.examContainer, t) ?? examContainer,
      onExamContainer: Color.lerp(onExamContainer, other.onExamContainer, t) ?? onExamContainer,
    );
  }
}

/// Утилитное расширение для быстрого доступа к семантическим цветам из BuildContext.
extension AppScheduleColorsContext on BuildContext {
  AppScheduleColors get scheduleColors =>
      Theme.of(this).extension<AppScheduleColors>() ?? AppScheduleColors.light;
}
