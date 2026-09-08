// Сервис динамических сезонных и праздничных иконок приложения РИИ
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SeasonThemeItem {
  final String id;
  final String title;
  final String subtitle;
  final String assetPath;
  final String webIconName;
  final Color accentColor;
  // Суффикс activity-alias для Android (например 'NewYear' -> '.MainActivityNewYear')
  final String? androidAlias;
  // Имя alternate icon для iOS (например 'AppIcon-NewYear')
  final String? iosIconName;

  const SeasonThemeItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.assetPath,
    required this.webIconName,
    required this.accentColor,
    this.androidAlias,
    this.iosIconName,
  });
}

class SeasonIconService {
  // Список всех доступных тем оформления иконки
  static const List<SeasonThemeItem> allThemes = [
    SeasonThemeItem(
      id: 'default',
      title: 'Классический РИИ',
      subtitle: 'Стандартный фирменный стиль института',
      assetPath: 'assets/icons/logo_app.png',
      webIconName: 'logo_app.png',
      accentColor: Color(0xFF2563EB),
      androidAlias: '.MainActivityDefault',
      iosIconName: null,
    ),
    SeasonThemeItem(
      id: 'city_day',
      title: 'День города Рубцовска',
      subtitle: '10 - 20 сентября (основан в 1892 г.)',
      assetPath: 'assets/icons/logo_app_dengoroda.png',
      webIconName: 'logo_app_dengoroda.png',
      accentColor: Color(0xFF059669),
      androidAlias: '.MainActivityCityDay',
      iosIconName: 'AppIcon-CityDay',
    ),
    SeasonThemeItem(
      id: 'machinist_day',
      title: 'День машиностроителя (АТЗ)',
      subtitle: '21 - 30 сентября (проф. праздник РИИ)',
      assetPath: 'assets/icons/logo_app_ATZ.png',
      webIconName: 'logo_app_ATZ.png',
      accentColor: Color(0xFF1E3A8A),
      androidAlias: '.MainActivityMachinistDay',
      iosIconName: 'AppIcon-MachinistDay',
    ),
    SeasonThemeItem(
      id: 'autumn',
      title: 'Золотая осень',
      subtitle: 'Октябрь - ноябрь',
      assetPath: 'assets/icons/logo_app_osen.png',
      webIconName: 'logo_app_osen.png',
      accentColor: Color(0xFFD97706),
      androidAlias: '.MainActivityAutumn',
      iosIconName: 'AppIcon-Autumn',
    ),
    SeasonThemeItem(
      id: 'new_year',
      title: 'С Новым Годом!',
      subtitle: '20 декабря - 10 января',
      assetPath: 'assets/icons/logo_app_zima.png',
      webIconName: 'logo_app_zima.png',
      accentColor: Color(0xFF0284C7),
      androidAlias: '.MainActivityNewYear',
      iosIconName: 'AppIcon-NewYear',
    ),
    SeasonThemeItem(
      id: 'student_day',
      title: 'День студента',
      subtitle: '25 января (Татьянин день)',
      assetPath: 'assets/icons/logo_app_denisydenta.png',
      webIconName: 'logo_app_denisydenta.png',
      accentColor: Color(0xFF7C3AED),
      androidAlias: '.MainActivityStudentDay',
      iosIconName: 'AppIcon-StudentDay',
    ),
    SeasonThemeItem(
      id: 'defender_day',
      title: 'День защитника Отечества',
      subtitle: '21 - 24 февраля (23 февраля)',
      assetPath: 'assets/icons/logo_app_23fevrala.png',
      webIconName: 'logo_app_23fevrala.png',
      accentColor: Color(0xFF15803D),
      androidAlias: '.MainActivityDefenderDay',
      iosIconName: 'AppIcon-DefenderDay',
    ),
    SeasonThemeItem(
      id: 'women_day',
      title: 'Международный женский день',
      subtitle: '7 - 9 марта (8 марта)',
      assetPath: 'assets/icons/logo_app_8marta.png',
      webIconName: 'logo_app_8marta.png',
      accentColor: Color(0xFFDB2777),
      androidAlias: '.MainActivityWomenDay',
      iosIconName: 'AppIcon-WomenDay',
    ),
    SeasonThemeItem(
      id: 'spring',
      title: 'Весенний сезон',
      subtitle: 'Март - апрель',
      assetPath: 'assets/icons/logo_app_vesna.png',
      webIconName: 'logo_app_vesna.png',
      accentColor: Color(0xFF10B981),
      androidAlias: '.MainActivitySpring',
      iosIconName: 'AppIcon-Spring',
    ),
    SeasonThemeItem(
      id: 'victory_day',
      title: 'День Победы',
      subtitle: '1 - 10 мая (9 мая)',
      assetPath: 'assets/icons/logo_app_denpobed.png',
      webIconName: 'logo_app_denpobed.png',
      accentColor: Color(0xFFB91C1C),
      androidAlias: '.MainActivityVictoryDay',
      iosIconName: 'AppIcon-VictoryDay',
    ),
    SeasonThemeItem(
      id: 'graduation',
      title: 'Выпускной и День молодежи',
      subtitle: '20 - 30 июня',
      assetPath: 'assets/icons/logo_app_vipsk.png',
      webIconName: 'logo_app_vipsk.png',
      accentColor: Color(0xFF6366F1),
      androidAlias: '.MainActivityGraduation',
      iosIconName: 'AppIcon-Graduation',
    ),
    SeasonThemeItem(
      id: 'summer',
      title: 'Летний сезон',
      subtitle: 'Июнь - август',
      assetPath: 'assets/icons/logo_app_leto.png',
      webIconName: 'logo_app_leto.png',
      accentColor: Color(0xFFEAB308),
      androidAlias: '.MainActivitySummer',
      iosIconName: 'AppIcon-Summer',
    ),
  ];

  // MethodChannel для нативной смены иконки лаунчера
  static const MethodChannel _channel = MethodChannel('com.yearnings.rii/launcher_icon');

  // Применить иконку лаунчера на рабочем столе телефона.
  // Вызывать при старте приложения и при ручной смене темы в настройках.
  static Future<void> applyLauncherIcon(SeasonThemeItem theme) async {
    try {
      await _channel.invokeMethod('setIcon', {
        'androidAlias': theme.androidAlias,
        'iosIconName': theme.iosIconName,
      });
    } catch (_) {
      // Игнорируем ошибки платформы: иконка - не критичный функционал
    }
  }

  // Определение актуальной темы по времени Рубцовска (UTC+7)
  static SeasonThemeItem resolveAutoSeason(DateTime rubtsovskTime) {
    final m = rubtsovskTime.month;
    final d = rubtsovskTime.day;

    // 1. Точечные праздники с фиксированными датами
    // Новый год и каникулы: 20 декабря - 10 января
    if ((m == 12 && d >= 20) || (m == 1 && d <= 10)) {
      return getThemeById('new_year');
    }
    // День студента (Татьянин день): 25 января
    if (m == 1 && d == 25) {
      return getThemeById('student_day');
    }
    // День защитника Отечества (23 февраля): 21 - 24 февраля
    if (m == 2 && d >= 21 && d <= 24) {
      return getThemeById('defender_day');
    }
    // Международный женский день (8 марта): 7 - 9 марта
    if (m == 3 && d >= 7 && d <= 9) {
      return getThemeById('women_day');
    }
    // День Победы: 1 - 10 мая
    if (m == 5 && d <= 10) {
      return getThemeById('victory_day');
    }
    // Выпускной и День молодежи: 20 - 30 июня
    if (m == 6 && d >= 20) {
      return getThemeById('graduation');
    }
    // День города Рубцовска (основан в 1892 г.): 10 - 20 сентября
    if (m == 9 && d >= 10 && d <= 20) {
      return getThemeById('city_day');
    }
    // День машиностроителя (проф. праздник РИИ и АТЗ): 21 - 30 сентября
    if (m == 9 && d >= 21 && d <= 30) {
      return getThemeById('machinist_day');
    }

    // 2. Сезонные темы
    // Весна: март - май
    if (m == 3 || m == 4 || m == 5) {
      return getThemeById('spring');
    }
    // Лето: июнь - август
    if (m == 6 || m == 7 || m == 8) {
      return getThemeById('summer');
    }
    // Золотая осень: октябрь - ноябрь
    if (m == 10 || m == 11) {
      return getThemeById('autumn');
    }

    // По умолчанию - классический фирменный логотип
    return getThemeById('default');
  }

  static SeasonThemeItem getThemeById(String id) {
    return allThemes.firstWhere(
      (t) => t.id == id,
      orElse: () => allThemes.first,
    );
  }

  // Получение эффективной темы (с учетом пользовательской настройки auto / конкретный id)
  static SeasonThemeItem getEffectiveTheme(String? prefId, DateTime rubtsovskTime) {
    if (prefId == null || prefId.isEmpty || prefId == 'auto') {
      return resolveAutoSeason(rubtsovskTime);
    }
    return getThemeById(prefId);
  }
}
