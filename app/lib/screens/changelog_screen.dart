import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class ReleaseModel {
  final String tag;
  final String title;
  final String publishedAt;
  final String rawBody;
  final String htmlUrl;
  final List<ReleaseAsset> assets;
  final bool isCurrent;

  const ReleaseModel({
    required this.tag,
    required this.title,
    required this.publishedAt,
    required this.rawBody,
    required this.htmlUrl,
    required this.assets,
    this.isCurrent = false,
  });

  factory ReleaseModel.fromJson(Map<String, dynamic> json, {String currentVersion = '1.0.3'}) {
    final tag = (json['tag_name'] ?? '').toString().replaceAll('v', '').trim();
    final title = json['name']?.toString() ?? 'Версия $tag';
    final published = json['published_at']?.toString() ?? '';
    final body = json['body']?.toString() ?? '';
    final html = json['html_url']?.toString() ?? 'https://github.com/yearningss/rii-schedule-bot/releases';

    final assetsList = <ReleaseAsset>[];
    if (json['assets'] is List) {
      for (final a in json['assets']) {
        if (a is Map) {
          assetsList.add(ReleaseAsset(
            name: a['name']?.toString() ?? 'Файл',
            sizeBytes: (a['size'] is num) ? (a['size'] as num).toInt() : 0,
            downloadUrl: a['download_url']?.toString() ?? '',
          ));
        }
      }
    }

    final isCur = tag.isNotEmpty && tag == currentVersion;

    return ReleaseModel(
      tag: tag,
      title: title,
      publishedAt: published,
      rawBody: body,
      htmlUrl: html,
      assets: assetsList,
      isCurrent: isCur,
    );
  }
}

class ReleaseAsset {
  final String name;
  final int sizeBytes;
  final String downloadUrl;

  const ReleaseAsset({
    required this.name,
    required this.sizeBytes,
    required this.downloadUrl,
  });

  String get formattedSize {
    if (sizeBytes <= 0) return '';
    final mb = sizeBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} МБ';
  }
}

class ChangelogScreen extends StatefulWidget {
  final ApiService? api;

  const ChangelogScreen({super.key, this.api});

  @override
  State<ChangelogScreen> createState() => _ChangelogScreenState();
}

class _ChangelogScreenState extends State<ChangelogScreen> {
  late final ApiService _api;
  bool _isLoading = true;
  String? _errorMessage;
  List<ReleaseModel> _releases = [];
  bool _isFromCache = false;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? ApiService();
    _loadReleases();
  }

  Future<void> _loadReleases({bool isRefresh = false}) async {
    if (!isRefresh && _releases.isEmpty) {
      final cached = await _getCachedReleases();
      if (cached.isNotEmpty) {
        if (mounted) {
          setState(() {
            _releases = cached;
            _isLoading = false;
            _isFromCache = true;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _releases = _fallbackHistory();
            _isLoading = false;
            _isFromCache = true;
          });
        }
      }
    } else if (isRefresh) {
      setState(() {
        _errorMessage = null;
      });
    }

    try {
      final rawList = await _api.getChangelog();
      if (rawList.isNotEmpty) {
        final parsed = rawList
            .map((item) => ReleaseModel.fromJson(item, currentVersion: AppInfo.versionName))
            .toList();

        await _saveCachedReleases(rawList);

        if (mounted) {
          setState(() {
            _releases = parsed;
            _isLoading = false;
            _isFromCache = false;
            _errorMessage = null;
          });
        }
        return;
      }
    } catch (_) {}

    // Если сеть недоступна и список еще не заполнен
    if (mounted && _releases.isEmpty) {
      setState(() {
        _releases = _fallbackHistory();
        _isLoading = false;
        _isFromCache = true;
        _errorMessage = null;
      });
    }
  }

  Future<List<ReleaseModel>> _getCachedReleases() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('cached_changelog_list');
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded
              .map((item) => ReleaseModel.fromJson(Map<String, dynamic>.from(item as Map), currentVersion: AppInfo.versionName))
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }

  Future<void> _saveCachedReleases(List<Map<String, dynamic>> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_changelog_list', jsonEncode(list));
    } catch (_) {}
  }

  List<ReleaseModel> _fallbackHistory() {
    return [
      ReleaseModel(
        tag: '1.0.17',
        title: 'Релиз v1.0.17 (сборка 18)',
        publishedAt: '2026-09-08T09:30:00Z',
        isCurrent: true,
        htmlUrl: 'https://github.com/yearningss/rii-schedule-bot/releases/tag/v1.0.17',
        rawBody: '''* Динамическая смена темы и иконки по сезонам и праздникам: День города Рубцовска (10 - 20 сентября), День машиностроителя/АТЗ (21 - 30 сентября), Золотая осень, С Новым Годом, День студента (Татьянин день), 23 февраля, 8 марта, День Победы, Выпускной и День молодежи, весна, лето.
* Интерактивный выбор темы оформления и иконки в Настройках приложения: авторежим по календарю Рубцовска (UTC+7) или выбор любого из 12 праздничных стилей.
* Динамический favicon и значок веб-версии Telegram Mini App в зависимости от активного сезона и праздника.
* Команда /pic в Telegram-боте для просмотра актуальной сезонной иконки и инструкций по установке аватарки через @BotFather.''',
        assets: [
          const ReleaseAsset(
            name: 'RiiSchedule.apk',
            sizeBytes: 56500000,
            downloadUrl: 'https://github.com/yearningss/rii-schedule-bot/releases/download/v1.0.17/RiiSchedule.apk',
          ),
          const ReleaseAsset(
            name: 'RiiSchedule.ipa',
            sizeBytes: 8380000,
            downloadUrl: 'https://github.com/yearningss/rii-schedule-bot/releases/download/v1.0.17/RiiSchedule.ipa',
          ),
        ],
      ),
      ReleaseModel(
        tag: '1.0.16',
        title: 'Релиз v1.0.16 (сборка 17)',
        publishedAt: '2026-09-08T07:15:00Z',
        isCurrent: false,
        htmlUrl: 'https://github.com/yearningss/rii-schedule-bot/releases/tag/v1.0.16',
        rawBody: '''* Время в виджете рабочего стола обновляется в реальном времени каждую минуту (WidgetKit поминутный таймлайн на iOS и точный AlarmManager в Android).
* Устранена задержка отправки уведомлений: прямое системное планирование напоминаний о парах и переменах через точные системные будильники ОС.
* Динамический расчет оставшихся минут в тексте уведомлений без нестыковок и ложных таймингов.
* Расширен выбор времени напоминания до начала пары (5, 10, 15, 20, 30, 45, 60 минут).
* Автоматический учет и синхронизация пользователей мобильного приложения в базе данных SQLite без обязательной авторизации в Telegram.''',
        assets: [
          const ReleaseAsset(
            name: 'RiiSchedule.apk',
            sizeBytes: 56350000,
            downloadUrl: 'https://github.com/yearningss/rii-schedule-bot/releases/download/v1.0.16/RiiSchedule.apk',
          ),
          const ReleaseAsset(
            name: 'RiiSchedule.ipa',
            sizeBytes: 8360000,
            downloadUrl: 'https://github.com/yearningss/rii-schedule-bot/releases/download/v1.0.16/RiiSchedule.ipa',
          ),
        ],
      ),
      ReleaseModel(
        tag: '1.0.15',
        title: 'Релиз v1.0.15 (сборка 16)',
        publishedAt: '2026-09-07T09:20:00Z',
        isCurrent: false,
        htmlUrl: 'https://github.com/yearningss/rii-schedule-bot/releases/tag/v1.0.15',
        rawBody: '''* Модульная организация экрана настроек: параметры разделены по 6 удобным категориям.
* Интерактивные карточки-кнопки категорий (Оформление, Уведомления, Обновления, Учебный профиль, Сеть, Справка).
* Плавное раскрытие подкнопок при нажатии на категорию без визуального нагромождения экрана.
* Быстрые бейджи статуса для каждой категории настроек.
* Кнопка быстрого сворачивания и разворачивания всех категорий одновременно.''',
        assets: [
          const ReleaseAsset(
            name: 'RiiSchedule.apk',
            sizeBytes: 56210000,
            downloadUrl: 'https://github.com/yearningss/rii-schedule-bot/releases/download/v1.0.15/RiiSchedule.apk',
          ),
          const ReleaseAsset(
            name: 'RiiSchedule.ipa',
            sizeBytes: 8350000,
            downloadUrl: 'https://github.com/yearningss/rii-schedule-bot/releases/download/v1.0.15/RiiSchedule.ipa',
          ),
        ],
      ),
      ReleaseModel(
        tag: '1.0.14',
        title: 'Релиз v1.0.14 (сборка 15)',
        publishedAt: '2026-09-07T08:45:00Z',
        isCurrent: false,
        htmlUrl: 'https://github.com/yearningss/rii-schedule-bot/releases/tag/v1.0.14',
        rawBody: '''* Полноценная система системных push-уведомлений о парах, переменах и начале занятий на смартфоне.
* Высокоприоритетный канал уведомлений Android со всплывающими баннерами, звуком и вибрацией.
* В Настройки добавлена кнопка мгновенной проверки уведомлений (тестовое уведомление) и открытие системных параметров.
* В Telegram-бот добавлена кнопка 'Скачать приложение' в главное меню и команда /download для прямой загрузки приложения на Android и iOS.
* Информация о мобильном приложении добавлена в справку и команду /about Telegram-бота.''',
        assets: [
          const ReleaseAsset(
            name: 'RiiSchedule.apk',
            sizeBytes: 56060000,
            downloadUrl: 'https://github.com/yearningss/rii-schedule-bot/releases/download/v1.0.14/RiiSchedule.apk',
          ),
          const ReleaseAsset(
            name: 'RiiSchedule.ipa',
            sizeBytes: 8350000,
            downloadUrl: 'https://github.com/yearningss/rii-schedule-bot/releases/download/v1.0.14/RiiSchedule.ipa',
          ),
        ],
      ),
      ReleaseModel(
        tag: '1.0.13',
        title: 'Релиз v1.0.13 (сборка 14)',
        publishedAt: '2026-09-07T08:00:00Z',
        isCurrent: false,
        htmlUrl: 'https://github.com/yearningss/rii-schedule-bot/releases/tag/v1.0.13',
        rawBody: '''* Исправлена критическая ошибка обработки дней недели в Telegram-боте: полностью восстановлена работа команд /today, /tomorrow и кнопок 'Сегодня', 'Завтра'.
* Восстановлена работа интерактивных кнопок дней недели (Пн-Сб, переключение недели, обновление расписания).
* Добавлена новая команда /now ('Сейчас') с оперативным расчетом текущей пары, времени до конца и информации о переменах.
* Добавлены интерактивные кнопки навигации по неделям для полного расписания.
* Добавлена нечувствительность к регистру ввода и поддержка русскоязычных псевдонимов команд.
* Добавлена кнопка отмены при выборе группы и предотвращены сбои при удалении сообщений в Telegram.''',
        assets: [
          const ReleaseAsset(
            name: 'RiiSchedule.apk',
            sizeBytes: 56060000,
            downloadUrl: 'https://github.com/yearningss/rii-schedule-bot/releases/download/v1.0.13/RiiSchedule.apk',
          ),
          const ReleaseAsset(
            name: 'RiiSchedule.ipa',
            sizeBytes: 8350000,
            downloadUrl: 'https://github.com/yearningss/rii-schedule-bot/releases/download/v1.0.13/RiiSchedule.ipa',
          ),
        ],
      ),
      ReleaseModel(
        tag: '1.0.12',
        title: 'Релиз v1.0.12 (сборка 13)',
        publishedAt: '2026-09-06T09:10:00Z',
        isCurrent: false,
        htmlUrl: 'https://github.com/yearningss/rii-schedule-bot/releases/tag/v1.0.12',
        rawBody: '''* Фоновая проверка обновлений каждые 15 минут: периодическая проверка новых версий и отправка системных уведомлений.
* Очистка интерфейса шапки расписания: удалена лишняя плашка статуса возле номера учебной группы для исключения наложений.
* Полная история изменений: гарантированное отображение всех версий приложения от v1.0.1 до актуальной с локальным кэшированием для офлайн-режима.
* Добавлен переключатель фоновой проверки обновлений в расширенные настройки уведомлений.''',
        assets: [
          const ReleaseAsset(
            name: 'RiiSchedule.apk',
            sizeBytes: 56050000,
            downloadUrl: 'https://github.com/yearningss/rii-schedule-bot/releases/download/v1.0.12/RiiSchedule.apk',
          ),
          const ReleaseAsset(
            name: 'RiiSchedule.ipa',
            sizeBytes: 8350000,
            downloadUrl: 'https://github.com/yearningss/rii-schedule-bot/releases/download/v1.0.12/RiiSchedule.ipa',
          ),
        ],
      ),
      ReleaseModel(
        tag: '1.0.11',
        title: 'Релиз v1.0.11 (сборка 12)',
        publishedAt: '2026-09-06T08:50:00Z',
        isCurrent: false,
        htmlUrl: 'https://github.com/yearningss/rii-schedule-bot/releases/tag/v1.0.11',
        rawBody: '''* Интеллектуальный офлайн-режим: при отсутствии интернет-соединения при запуске отображается локально сохраненное расписание с понятным уведомлением.
* Отображение сетевого режима в Настройках: статус онлайн/офлайн с индикатором и кнопкой мгновенной проверки соединения.
* Расширенная настройка уведомлений: выбор времени напоминания до пары (5, 10, 15, 30 минут), оповещения о начале пары, переменах и изменениях в расписании.
* Полноценная синхронизация параметров уведомлений с Telegram-ботом и сервером РИИ.
* Добавлена возможность обновления расписания жестом свайпа (pull-to-refresh) на пустых экранах выходных дней.''',
        assets: [
          const ReleaseAsset(
            name: 'RiiSchedule.apk',
            sizeBytes: 55750000,
            downloadUrl: 'https://github.com/yearningss/rii-schedule-bot/releases/download/v1.0.11/RiiSchedule.apk',
          ),
          const ReleaseAsset(
            name: 'RiiSchedule.ipa',
            sizeBytes: 8290000,
            downloadUrl: 'https://github.com/yearningss/rii-schedule-bot/releases/download/v1.0.11/RiiSchedule.ipa',
          ),
        ],
      ),
      ReleaseModel(
        tag: '1.0.10',
        title: 'Релиз v1.0.10 (сборка 11)',
        publishedAt: '2026-09-06T07:25:00Z',
        isCurrent: false,
        htmlUrl: 'https://github.com/yearningss/rii-schedule-bot/releases/tag/v1.0.10',
        rawBody: '''* Документирование кодовой базы: все комментарии в исходном коде переведены и стандартизированы на русском языке.
* Подтверждена стабильная работа нативного виджета расписания для iOS (WidgetKit) и Android (RemoteViews).
* Фиксация обновлений манифеста схем и оптимизация управления памятью.''',
        assets: [
          const ReleaseAsset(
            name: 'RiiSchedule.apk',
            sizeBytes: 55712671,
            downloadUrl: 'https://github.com/yearningss/rii-schedule-bot/releases/download/v1.0.10/RiiSchedule.apk',
          ),
          const ReleaseAsset(
            name: 'RiiSchedule.ipa',
            sizeBytes: 8284792,
            downloadUrl: 'https://github.com/yearningss/rii-schedule-bot/releases/download/v1.0.10/RiiSchedule.ipa',
          ),
        ],
      ),
      ReleaseModel(
        tag: '1.0.9',
        title: 'Релиз v1.0.9 (сборка 10)',
        publishedAt: '2026-09-06T07:20:00Z',
        isCurrent: false,
        htmlUrl: 'https://github.com/yearningss/rii-schedule-bot/releases/tag/v1.0.9',
        rawBody: '''* Исправлен критический баг сопоставления структуры данных в нативном виджете iOS (WidgetKit): восстановлено чтение расписания по номеру недели и дня.
* Добавлена поддержка фона виджетов для iOS 17 и новее с использованием containerBackground.
* В Info.plist добавлен белый список схем LSApplicationQueriesSchemes для бесперебойного открытия приложения Telegram.
* Повышена отказоустойчивость авторизации: прямой вызов launchUrl с автоматическим резервным переходом в браузер.
* Устранена утечка памяти контроллера поиска (TextEditingController.dispose) на экране выбора учебной группы.''',
        assets: [
          const ReleaseAsset(
            name: 'RiiSchedule.apk',
            sizeBytes: 55597479,
            downloadUrl: 'https://github.com/yearningss/rii-schedule-bot/releases/download/v1.0.9/RiiSchedule.apk',
          ),
          const ReleaseAsset(
            name: 'RiiSchedule.ipa',
            sizeBytes: 8196388,
            downloadUrl: 'https://github.com/yearningss/rii-schedule-bot/releases/download/v1.0.9/RiiSchedule.ipa',
          ),
        ],
      ),
      ReleaseModel(
        tag: '1.0.8',
        title: 'Релиз v1.0.8 (сборка 9)',
        publishedAt: '2026-09-06T07:10:00Z',
        isCurrent: false,
        htmlUrl: 'https://github.com/yearningss/rii-schedule-bot/releases/tag/v1.0.8',
        rawBody: '''* Устранена циклическая зависимость фаз сборки Xcode (Cycle inside Runner) при интеграции виджета WidgetKit.
* Порядок фаз сборки Runner скорректирован: встраивание расширения Embed App Extensions перенесено перед скриптом Thin Binary.
* Нативный виджет расписания для iOS (WidgetKit и SwiftUI) с поддержкой форматов systemSmall и systemMedium.''',
        assets: [
          const ReleaseAsset(
            name: 'RiiSchedule.apk',
            sizeBytes: 55597479,
            downloadUrl: 'https://github.com/yearningss/rii-schedule-bot/releases/download/v1.0.8/RiiSchedule.apk',
          ),
          const ReleaseAsset(
            name: 'RiiSchedule.ipa',
            sizeBytes: 8196388,
            downloadUrl: 'https://github.com/yearningss/rii-schedule-bot/releases/download/v1.0.8/RiiSchedule.ipa',
          ),
        ],
      ),
      ReleaseModel(
        tag: '1.0.7',
        title: 'Релиз v1.0.7 (сборка 8)',
        publishedAt: '2026-09-06T07:00:00Z',
        isCurrent: false,
        htmlUrl: 'https://github.com/yearningss/rii-schedule-bot/releases/tag/v1.0.7',
        rawBody: '''* Устранена ошибка компиляции нативного виджета iOS в Swift (заменен вызов TimelineProviderContext на вспомогательный метод defaultPlaceholder).
* Оптимизирована публикация релизов в GitHub Actions: описание релиза теперь формируется через единый файл release_body.md с параметром body_path.
* Нативный виджет расписания для iOS (WidgetKit и SwiftUI) с поддержкой форматов systemSmall и systemMedium.''',
        assets: [
          const ReleaseAsset(
            name: 'RiiSchedule.apk',
            sizeBytes: 55597479,
            downloadUrl: 'https://github.com/yearningss/rii-schedule-bot/releases/download/v1.0.7/RiiSchedule.apk',
          ),
          const ReleaseAsset(
            name: 'RiiSchedule.ipa',
            sizeBytes: 8196388,
            downloadUrl: 'https://github.com/yearningss/rii-schedule-bot/releases/download/v1.0.7/RiiSchedule.ipa',
          ),
        ],
      ),
      ReleaseModel(
        tag: '1.0.6',
        title: 'Релиз v1.0.6 (сборка 7)',
        publishedAt: '2026-09-06T06:50:00Z',
        isCurrent: false,
        htmlUrl: 'https://github.com/yearningss/rii-schedule-bot/releases/tag/v1.0.6',
        rawBody: '''* Внедрен нативный виджет расписания для рабочего стола iOS (WidgetKit и SwiftUI).
* Поддержка компактного (systemSmall) и расширенного (systemMedium) форматов виджета.
* Синхронизация расписания между Flutter-приложением и расширением виджета через App Groups.
* Автоматическая генерация описания изменений (Changelog) в GitHub Actions для каждого релиза.''',
        assets: [
          const ReleaseAsset(
            name: 'RiiSchedule.apk',
            sizeBytes: 55597479,
            downloadUrl: 'https://github.com/yearningss/rii-schedule-bot/releases/download/v1.0.6/RiiSchedule.apk',
          ),
          const ReleaseAsset(
            name: 'RiiSchedule.ipa',
            sizeBytes: 8196388,
            downloadUrl: 'https://github.com/yearningss/rii-schedule-bot/releases/download/v1.0.6/RiiSchedule.ipa',
          ),
        ],
      ),
      ReleaseModel(
        tag: '1.0.5',
        title: 'Релиз v1.0.5 (сборка 6)',
        publishedAt: '2026-09-06T06:30:00Z',
        isCurrent: false,
        htmlUrl: 'https://github.com/yearningss/rii-schedule-bot/releases/tag/v1.0.5',
        rawBody: '''* Исправлен отступ безопасной зоны (SafeArea) снизу экрана: переключатель подгрупп теперь корректно приподнят над системной полосой жестов iOS (Home Bar) и панелью Android.
* Устранены ошибки компиляции Flutter и добавлена поддержка сборки пакета iOS IPA без цифровой подписи.
* Оптимизирована работа диалогов обновления и проверки дистрибутивов.''',
        assets: [
          const ReleaseAsset(
            name: 'RiiSchedule.apk',
            sizeBytes: 55597479,
            downloadUrl: 'https://github.com/yearningss/rii-schedule-bot/releases/download/v1.0.5/RiiSchedule.apk',
          ),
          const ReleaseAsset(
            name: 'RiiSchedule.ipa',
            sizeBytes: 8196388,
            downloadUrl: 'https://github.com/yearningss/rii-schedule-bot/releases/download/v1.0.5/RiiSchedule.ipa',
          ),
        ],
      ),
      ReleaseModel(
        tag: '1.0.4',
        title: 'Релиз v1.0.4 (сборка 5)',
        publishedAt: '2026-09-06T06:10:00Z',
        isCurrent: false,
        htmlUrl: 'https://github.com/yearningss/rii-schedule-bot/releases/tag/v1.0.4',
        rawBody: '''* Автоматическое разделение загрузки обновлений: для Android скачивается APK (RiiSchedule.apk), для iOS предлагается пакет IPA (RiiSchedule.ipa).
* Устранена блокировка скачивания файлов через браузер (убран баг метода canLaunchUrl в Flutter).
* Очищено меню настроек: удалены дублирующиеся пункты, оставлен удобный и понятный интерфейс.
* Добавлена возможность принудительного повторного скачивания актуального дистрибутива в один клик.
* Обновлена среда сборки мобильных приложений (переход на actions/setup-java@v5).''',
        assets: [
          const ReleaseAsset(
            name: 'RiiSchedule.apk',
            sizeBytes: 55597479,
            downloadUrl: 'https://github.com/yearningss/rii-schedule-bot/releases/download/v1.0.4/RiiSchedule.apk',
          ),
          const ReleaseAsset(
            name: 'RiiSchedule.ipa',
            sizeBytes: 8196388,
            downloadUrl: 'https://github.com/yearningss/rii-schedule-bot/releases/download/v1.0.4/RiiSchedule.ipa',
          ),
        ],
      ),
      ReleaseModel(
        tag: '1.0.3',
        title: 'Релиз v1.0.3 (сборка 4)',
        publishedAt: '2026-09-06T05:18:11Z',
        isCurrent: false,
        htmlUrl: 'https://github.com/yearningss/rii-schedule-bot/releases/tag/v1.0.3',
        rawBody: '''* Исправлен расчет и отображение расписания в субботу и воскресенье в приложении и виджете
* В выходные виджет и приложение автоматически рассчитывают пары на понедельник следующей недели
* Запрос разрешения на отправку системных уведомлений при запуске (Android 13+)
* Унификация версий в настройках и интеграция динамического Changelog
* Официальная цифровая подпись разработчика для доверия Google Play Protect''',
        assets: [
          const ReleaseAsset(
            name: 'RiiSchedule.apk',
            sizeBytes: 55597479,
            downloadUrl: 'https://github.com/yearningss/rii-schedule-bot/releases/download/v1.0.3/RiiSchedule.apk',
          ),
        ],
      ),
      ReleaseModel(
        tag: '1.0.2',
        title: 'Релиз v1.0.2 (сборка 3)',
        publishedAt: '2026-09-05T10:21:51Z',
        htmlUrl: 'https://github.com/yearningss/rii-schedule-bot/releases/tag/v1.0.2',
        rawBody: '''* Новый фирменный скругленный логотип приложения РИИ
* Адаптивные векторные и растровые иконки высокой четкости для Android и iOS
* Оптимизация памяти сборки Gradle и отключение устаревшего Jetifier
* Подготовка графических карточек и баннеров для RuStore''',
        assets: [
          const ReleaseAsset(
            name: 'RiiSchedule.apk',
            sizeBytes: 56199315,
            downloadUrl: 'https://github.com/yearningss/rii-schedule-bot/releases/download/v1.0.2/RiiSchedule.apk',
          ),
        ],
      ),
      ReleaseModel(
        tag: '1.0.1',
        title: 'Релиз v1.0.1 (сборка 2)',
        publishedAt: '2026-09-05T09:54:18Z',
        htmlUrl: 'https://github.com/yearningss/rii-schedule-bot/releases/tag/v1.0.1',
        rawBody: '''* Нативный виджет расписания для рабочего стола Android (RemoteViews)
* Отображение текущей и следующей пары, времени перемены и аудитории
* Авторизация через Telegram-бота (@rubinst_bot) и синхронизация профиля
* Проверка обновлений приложения через сервер института''',
        assets: [
          const ReleaseAsset(
            name: 'RiiSchedule.apk',
            sizeBytes: 56199000,
            downloadUrl: 'https://github.com/yearningss/rii-schedule-bot/releases/download/v1.0.1/RiiSchedule.apk',
          ),
        ],
      ),
    ];
  }

  String _formatDate(String isoString) {
    if (isoString.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year.toString();
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$day.$month.$year, $hour:$minute';
    } catch (_) {
      return isoString;
    }
  }

  List<String> _parseBodyLines(String raw) {
    if (raw.trim().isEmpty) return ['Улучшения стабильности и исправления ошибок.'];
    final lines = raw.split('\n');
    final result = <String>[];
    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      // Пропускаем технические служебные заголовки
      if (trimmed.startsWith('### Файлы для загрузки') ||
          trimmed.startsWith('### Files') ||
          trimmed.startsWith('### Assets')) {
        break;
      }
      if (trimmed.startsWith('#')) {
        final heading = trimmed.replaceAll(RegExp(r'^#+\s*'), '');
        if (heading.isNotEmpty) result.add('__HEADING__:$heading');
        continue;
      }
      // Очищаем маркер списка
      final clean = trimmed
          .replaceAll(RegExp(r'^[\*\-\+]\s*'), '')
          .replaceAll('**', '')
          .trim();
      if (clean.isNotEmpty) {
        result.add(clean);
      }
    }
    return result.isEmpty ? ['Улучшения стабильности и исправления ошибок.'] : result;
  }

  Future<void> _launchUrl(String url) async {
    if (url.isEmpty) return;
    try {
      final uri = Uri.parse(url);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      try {
        await launchUrl(
          Uri.parse('https://github.com/yearningss/rii-schedule-bot/releases/latest'),
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E232D) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2D333F) : const Color(0xFFE2E8F0);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      appBar: AppBar(
        title: const Text('История изменений'),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Открыть GitHub',
            icon: const Icon(Icons.open_in_new_rounded),
            onPressed: () => _launchUrl('https://github.com/yearningss/rii-schedule-bot/releases'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadReleases(isRefresh: true),
        color: const Color(0xFF2563EB),
        child: _isLoading
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF2563EB)),
                    SizedBox(height: 16),
                    Text(
                      'Загрузка реальной истории с GitHub...',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              )
            : _releases.isEmpty
                ? ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
                        child: Column(
                          children: [
                            const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey),
                            const SizedBox(height: 16),
                            const Text(
                              'Не удалось загрузить историю изменений',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Проверьте подключение к интернету и повторите попытку.',
                              style: TextStyle(fontSize: 13, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed: () => _loadReleases(),
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Повторить'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: _releases.length + 1,
                    itemBuilder: (context, idx) {
                      if (idx == 0) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF19202C) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _isFromCache ? Icons.storage_rounded : Icons.check_circle_outline_rounded,
                                size: 18,
                                color: _isFromCache ? Colors.amber : const Color(0xFF10B981),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _isFromCache
                                      ? 'Офлайн-режим (встроенная история). Потяните вниз для обновления.'
                                      : 'Данные синхронизированы в реальном времени с GitHub Releases.',
                                  style: TextStyle(fontSize: 12, color: subColor),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final item = _releases[idx - 1];
                      final lines = _parseBodyLines(item.rawBody);
                      final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
                      final targetExt = isIOS ? '.ipa' : '.apk';
                      final targetLabel = isIOS ? 'IPA' : 'APK';
                      ReleaseAsset? releaseAsset;
                      for (final a in item.assets) {
                        if (a.name.endsWith(targetExt) && !a.name.contains('debug')) {
                          releaseAsset = a;
                          break;
                        }
                      }
                      if (releaseAsset == null && item.assets.isNotEmpty) {
                        for (final a in item.assets) {
                          if (a.name.endsWith(targetExt)) {
                            releaseAsset = a;
                            break;
                          }
                        }
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: item.isCurrent ? const Color(0xFF2563EB) : borderColor,
                            width: item.isCurrent ? 1.5 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: item.isCurrent
                                          ? const Color(0xFF2563EB)
                                          : (isDark ? const Color(0xFF2D333F) : const Color(0xFFE2E8F0)),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'v${item.tag}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: item.isCurrent
                                            ? Colors.white
                                            : (isDark ? Colors.white : const Color(0xFF1E293B)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (item.isCurrent)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981).withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'Установлена',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF10B981),
                                        ),
                                      ),
                                    ),
                                  const Spacer(),
                                  if (item.publishedAt.isNotEmpty)
                                    Text(
                                      _formatDate(item.publishedAt),
                                      style: TextStyle(fontSize: 12, color: subColor),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                item.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ...lines.map((line) {
                                if (line.startsWith('__HEADING__:')) {
                                  final h = line.replaceFirst('__HEADING__:', '');
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                                    child: Text(
                                      h,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                  );
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        margin: const EdgeInsets.only(top: 6, right: 8),
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: item.isCurrent
                                              ? const Color(0xFF2563EB)
                                              : subColor,
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          line,
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            height: 1.35,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              if (releaseAsset != null) ...[
                                const SizedBox(height: 12),
                                const Divider(height: 1),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _launchUrl(releaseAsset!.downloadUrl),
                                        icon: const Icon(Icons.download_rounded, size: 18),
                                        label: Text(
                                          releaseAsset!.formattedSize.isNotEmpty
                                              ? 'Скачать $targetLabel (${releaseAsset!.formattedSize})'
                                              : 'Скачать $targetLabel',
                                          style: const TextStyle(fontSize: 12.5),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      tooltip: 'Смотреть релиз на GitHub',
                                      icon: const Icon(Icons.launch_rounded, size: 18),
                                      onPressed: () => _launchUrl(item.htmlUrl),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
