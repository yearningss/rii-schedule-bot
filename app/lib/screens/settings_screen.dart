// Экран настроек приложения: профиль Telegram, смена темы, выбор группы
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import 'bells_screen.dart';
import 'group_picker_screen.dart';
import 'auth_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/season_icon_service.dart';
import '../services/widget_service.dart';
import '../services/notification_service.dart';
import 'changelog_screen.dart';

class SettingsScreen extends StatefulWidget {
  final StorageService storage;
  final ApiService api;

  const SettingsScreen({
    super.key,
    required this.storage,
    required this.api,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late UserProfile _profile;
  late ThemeMode _currentThemeMode;
  late NotificationSettings _notifSettings;
  late String _seasonIconPref;
  late SeasonThemeItem _currentSeasonTheme;
  bool _isCheckingUpdate = false;
  bool _isOnline = true;
  bool _isCheckingConnection = false;

  // Идентификаторы раскрытых категорий настроек
  final Set<String> _expandedCategories = {};

  void _toggleCategory(String id) {
    setState(() {
      if (_expandedCategories.contains(id)) {
        _expandedCategories.remove(id);
      } else {
        _expandedCategories.add(id);
      }
    });
  }

  void _toggleAllCategories() {
    setState(() {
      if (_expandedCategories.length >= 6) {
        _expandedCategories.clear();
      } else {
        _expandedCategories.addAll([
          'appearance',
          'notifications',
          'updates',
          'profile',
          'network',
          'help',
        ]);
      }
    });
  }

  // Список встроенных иконок для выбора аватара
  static const List<Map<String, dynamic>> _presetAvatars = [
    {'id': 'school', 'name': 'Академик', 'icon': Icons.school_rounded, 'color': 0xFF2563EB},
    {'id': 'code', 'name': 'Разработчик', 'icon': Icons.terminal_rounded, 'color': 0xFF059669},
    {'id': 'engineer', 'name': 'Инженер', 'icon': Icons.precision_manufacturing_rounded, 'color': 0xFFD97706},
    {'id': 'star', 'name': 'Отличник', 'icon': Icons.star_rounded, 'color': 0xFFEAB308},
    {'id': 'book', 'name': 'Студент', 'icon': Icons.menu_book_rounded, 'color': 0xFF7C3AED},
    {'id': 'science', 'name': 'Исследователь', 'icon': Icons.biotech_rounded, 'color': 0xFF0284C7},
    {'id': 'energy', 'name': 'Энергетик', 'icon': Icons.bolt_rounded, 'color': 0xFFEA580C},
    {'id': 'person', 'name': 'Профиль', 'icon': Icons.person_rounded, 'color': 0xFF64748B},
  ];

  @override
  void initState() {
    super.initState();
    _profile = widget.storage.getUserProfile();
    _currentThemeMode = widget.storage.getThemeMode();
    _notifSettings = widget.storage.getNotificationSettings();
    _seasonIconPref = widget.storage.getSeasonIconPreference();
    final rTime = DateTime.now().toUtc().add(const Duration(hours: 7));
    _currentSeasonTheme = SeasonIconService.getEffectiveTheme(_seasonIconPref, rTime);
    _checkNetworkConnection();
    _refreshProfileFromServer();
  }

  // Проверка статуса соединения с сервером РИИ
  Future<void> _checkNetworkConnection({bool showFeedback = false}) async {
    setState(() => _isCheckingConnection = true);
    final connected = await widget.api.checkConnection();
    if (mounted) {
      setState(() {
        _isOnline = connected;
        _isCheckingConnection = false;
      });
      if (showFeedback) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              connected
                  ? 'Соединение с сервером РИИ активно (Онлайн)'
                  : 'Нет подключения к серверу. Активен офлайн-режим',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Сохранение и двусторонняя синхронизация параметров профиля и уведомлений
  Future<void> _syncProfileToServer({NotificationSettings? notif}) async {
    try {
      final n = notif ?? _notifSettings;
      final deviceId = widget.storage.getDeviceId();
      final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

      await widget.api.syncDeviceUser(
        deviceId: deviceId,
        platform: isIOS ? 'ios' : 'android',
        groupId: _profile.groupId,
        groupName: _profile.groupName,
        subgroup: _profile.subgroup,
        notificationsEnabled: n.enabled,
        notifyBeforeMins: n.beforeMins,
        notifyLessonStart: n.lessonStart,
        notifyBreaks: n.breaks,
        notifyChanges: n.changes,
        appVersion: AppInfo.versionName,
        authToken: _profile.authToken,
      );

      if (_profile.authToken != null) {
        await widget.api.syncProfile(
          authToken: _profile.authToken!,
          groupId: _profile.groupId,
          groupName: _profile.groupName,
          subgroup: _profile.subgroup,
          notificationsEnabled: n.enabled,
          notifyBeforeMins: n.beforeMins,
          notifyLessonStart: n.lessonStart,
          notifyBreaks: n.breaks,
          notifyChanges: n.changes,
        );
      }
    } catch (_) {}
  }

  // Сохранение и синхронизация параметров уведомлений
  Future<void> _updateNotificationSettings(NotificationSettings newSettings) async {
    setState(() {
      _notifSettings = newSettings;
    });
    await widget.storage.saveNotificationSettings(newSettings);

    if (newSettings.enabled) {
      await NotificationService.requestPermission();
    }

    await _syncProfileToServer(notif: newSettings);
  }

  Future<void> _refreshProfileFromServer() async {
    if (_profile.authToken == null) return;
    final data = await widget.api.getProfile(_profile.authToken!);
    if (data != null && mounted) {
      setState(() {
        _profile = _profile.copyWith(
          userId: data['user_id'] is int ? data['user_id'] : int.tryParse(data['user_id']?.toString() ?? ''),
          groupId: data['group_id'] is int ? data['group_id'] : int.tryParse(data['group_id']?.toString() ?? ''),
          groupName: data['group_name'],
          subgroup: data['subgroup'] is int ? data['subgroup'] : int.tryParse(data['subgroup']?.toString() ?? '') ?? 0,
          firstName: data['first_name'],
          lastName: data['last_name'],
          username: data['username'],
          avatarUrl: data['avatar_url'],
        );
        if (data.containsKey('notifications_enabled')) {
          _notifSettings = _notifSettings.copyWith(
            enabled: (data['notifications_enabled'] == 1 || data['notifications_enabled'] == true),
            beforeMins: data['notify_before_mins'] is int
                ? data['notify_before_mins']
                : int.tryParse(data['notify_before_mins']?.toString() ?? '') ?? _notifSettings.beforeMins,
            lessonStart: data['notify_lesson_start'] == null
                ? _notifSettings.lessonStart
                : (data['notify_lesson_start'] == 1 || data['notify_lesson_start'] == true),
            breaks: data['notify_breaks'] == null
                ? _notifSettings.breaks
                : (data['notify_breaks'] == 1 || data['notify_breaks'] == true),
            changes: data['notify_changes'] == null
                ? _notifSettings.changes
                : (data['notify_changes'] == 1 || data['notify_changes'] == true),
          );
        }
      });
      await widget.storage.saveUserProfile(_profile);
      await widget.storage.saveNotificationSettings(_notifSettings);
    }
  }

  // Отправка тестового уведомления для проверки разрешений и звука
  Future<void> _sendTestNotification() async {
    await NotificationService.requestPermission();
    final granted = await NotificationService.checkPermission();
    if (!granted) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Уведомления отключены'),
            content: const Text(
              'В системе телефона отключены разрешения для приложения РИИ Расписание. Откройте настройки телефона и разрешите уведомления.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  NotificationService.openNotificationSettings();
                },
                child: const Text('Настройки'),
              ),
            ],
          ),
        );
      }
      return;
    }

    await NotificationService.showNotification(
      title: 'Тестовое уведомление РИИ',
      message: 'Уведомления работают отлично! Вы будете получать напоминания о парах и переменах.',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Тестовое уведомление отправлено. Проверьте шторку уведомлений.'),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _setTheme(ThemeMode mode) async {
    setState(() => _currentThemeMode = mode);
    await widget.storage.saveThemeMode(mode);
  }

  Future<void> _setSubgroup(int sg) async {
    setState(() {
      _profile = _profile.copyWith(subgroup: sg);
    });
    await widget.storage.saveSubgroup(sg);
    await _syncProfileToServer();
    WidgetService.updateWidgetData(profile: _profile);
  }

  Future<void> _changeGroup() async {
    final selected = await Navigator.push<GroupItem>(
      context,
      MaterialPageRoute(
        builder: (_) => GroupPickerScreen(storage: widget.storage, api: widget.api),
      ),
    );

    if (selected != null && mounted) {
      setState(() {
        _profile = _profile.copyWith(groupId: selected.id, groupName: selected.name);
      });
      await widget.storage.saveUserProfile(_profile);
      await _syncProfileToServer();
      WidgetService.updateWidgetData(profile: _profile);
    }
  }

  // Проверка актуальности версии приложения
  Future<void> _openDownloadUrl(String url) async {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final extName = isIOS ? 'IPA (для iOS)' : 'APK (для Android)';
    try {
      final uri = Uri.parse(url);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Открыта страница скачивания $extName в браузере...')),
        );
      }
    } catch (_) {
      try {
        await launchUrl(
          Uri.parse('https://github.com/yearningss/rii-schedule-bot/releases/latest'),
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Не удалось открыть браузер для загрузки $extName')),
          );
        }
      }
    }
  }

  Future<void> _checkForUpdate() async {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final extName = isIOS ? 'IPA' : 'APK';
    final fallbackPackage = isIOS ? 'RiiSchedule.ipa' : 'RiiSchedule.apk';

    setState(() => _isCheckingUpdate = true);
    try {
      final update = await widget.api.checkAppUpdate(
        currentBuild: AppInfo.versionCode,
        currentVersion: AppInfo.versionName,
      );
      if (!mounted) return;
      setState(() => _isCheckingUpdate = false);

      if (update != null && update.hasUpdate) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Доступно обновление v${update.latestVersion}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Вышла новая версия приложения РИИ АлтГТУ.\n\nЧто нового:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Text(
                  update.releaseNotes ?? 'Исправления ошибок и улучшения производительности.',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Позже'),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.download_rounded, size: 18),
                onPressed: () {
                  Navigator.pop(ctx);
                  _openDownloadUrl(update.downloadUrl);
                },
                label: Text('Скачать $extName'),
              ),
            ],
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Обновлений нет'),
            content: Text('У вас установлена самая актуальная версия приложения (${AppInfo.fullVersionText}).'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangelogScreen()));
                },
                child: const Text('Что нового'),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.download_rounded, size: 16),
                onPressed: () {
                  Navigator.pop(ctx);
                  final downloadUrl = (update?.downloadUrl.isNotEmpty == true)
                      ? update!.downloadUrl
                      : 'https://github.com/yearningss/rii-schedule-bot/releases/latest/download/$fallbackPackage';
                  _openDownloadUrl(downloadUrl);
                },
                label: Text('Скачать $extName заново'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Понятно'),
              ),
            ],
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isCheckingUpdate = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось связаться с сервером для проверки обновлений')),
        );
      }
    }
  }

  void _openAvatarPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Выбор аватара',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Выберите значок для отображения в профиле приложения:',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: _presetAvatars.length,
                  itemBuilder: (_, idx) {
                    final item = _presetAvatars[idx];
                    final isSelected = _profile.customAvatar == item['id'];
                    final color = Color(item['color'] as int);

                    return InkWell(
                      onTap: () async {
                        final avatarId = item['id'] as String;
                        setState(() {
                          _profile = _profile.copyWith(customAvatar: avatarId);
                        });
                        await widget.storage.saveCustomAvatar(avatarId);
                        if (_profile.authToken != null) {
                          widget.api.syncProfile(
                            authToken: _profile.authToken!,
                            avatarUrl: 'custom:$avatarId',
                          );
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? color.withOpacity(0.15)
                              : (isDark ? const Color(0xFF1E232D) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? color : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: color.withOpacity(0.2),
                              child: Icon(item['icon'] as IconData, color: color, size: 24),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item['name'] as String,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openSeasonIconPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
        final rTime = DateTime.now().toUtc().add(const Duration(hours: 7));
        final autoTheme = SeasonIconService.resolveAutoSeason(rTime);

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.78,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Иконка приложения',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'Выберите тему оформления и иконку. В авторежиме стиль переключается по календарю Рубцовска.',
                        style: TextStyle(fontSize: 13, color: subColor),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          // Опция автоматического переключения
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: _seasonIconPref == 'auto'
                                    ? const Color(0xFF2563EB)
                                    : (isDark ? const Color(0xFF2D333F) : const Color(0xFFE2E8F0)),
                                width: _seasonIconPref == 'auto' ? 2 : 1,
                              ),
                            ),
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF2563EB)),
                            ),
                            title: const Text(
                              'Авто (по календарю)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            subtitle: Text(
                              'Сейчас активно: ${autoTheme.title}',
                              style: TextStyle(fontSize: 13, color: subColor),
                            ),
                            trailing: _seasonIconPref == 'auto'
                                ? const Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB))
                                : null,
                            onTap: () async {
                              await widget.storage.saveSeasonIconPreference('auto');
                              await SeasonIconService.applyLauncherIcon(autoTheme);
                              if (mounted) {
                                setState(() {
                                  _seasonIconPref = 'auto';
                                  _currentSeasonTheme = autoTheme;
                                });
                              }
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                          ),
                          const SizedBox(height: 14),
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 8),
                            child: Text(
                              'ВСЕ 12 СТИЛЕЙ ОФОРМЛЕНИЯ',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                                color: subColor,
                              ),
                            ),
                          ),
                          ...SeasonIconService.allThemes.map((themeItem) {
                            final isSelected = _seasonIconPref == themeItem.id;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E232D) : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? themeItem.accentColor
                                      : (isDark ? const Color(0xFF2D333F) : const Color(0xFFE2E8F0)),
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.asset(
                                    themeItem.assetPath,
                                    width: 44,
                                    height: 44,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                title: Text(
                                  themeItem.title,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                ),
                                subtitle: Text(
                                  themeItem.subtitle,
                                  style: TextStyle(fontSize: 12, color: subColor),
                                ),
                                trailing: isSelected
                                    ? Icon(Icons.check_circle_rounded, color: themeItem.accentColor)
                                    : null,
                                onTap: () async {
                                  await widget.storage.saveSeasonIconPreference(themeItem.id);
                                  await SeasonIconService.applyLauncherIcon(themeItem);
                                  if (mounted) {
                                    setState(() {
                                      _seasonIconPref = themeItem.id;
                                      _currentSeasonTheme = themeItem;
                                    });
                                  }
                                  if (ctx.mounted) Navigator.pop(ctx);
                                },
                              ),
                            );
                          }),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAvatarWidget() {
    final avatarUrl = _profile.avatarUrl;
    final customAvatar = _profile.customAvatar;

    // 1. Если задана встроенная иконка
    if (customAvatar != null && customAvatar.isNotEmpty) {
      final preset = _presetAvatars.firstWhere(
        (p) => p['id'] == customAvatar,
        orElse: () => _presetAvatars.last,
      );
      final color = Color(preset['color'] as int);
      return CircleAvatar(
        radius: 36,
        backgroundColor: color.withOpacity(0.2),
        child: Icon(preset['icon'] as IconData, color: color, size: 38),
      );
    }

    // 2. Если есть фото из Telegram
    if (avatarUrl != null && avatarUrl.isNotEmpty && !avatarUrl.startsWith('custom:')) {
      final fullUrl = avatarUrl.startsWith('http') ? avatarUrl : '${ApiService.baseUrl}$avatarUrl';
      return CircleAvatar(
        radius: 36,
        backgroundColor: const Color(0xFF2563EB).withOpacity(0.15),
        backgroundImage: NetworkImage(fullUrl),
        onBackgroundImageError: (_, __) {},
        child: null,
      );
    }

    // 3. По умолчанию инициалы или иконка
    final initials = (_profile.firstName != null && _profile.firstName!.isNotEmpty)
        ? _profile.firstName![0].toUpperCase()
        : 'Р';

    return CircleAvatar(
      radius: 36,
      backgroundColor: const Color(0xFF2563EB),
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Выход из аккаунта'),
        content: const Text('Вы действительно хотите выйти? Расписание выбранной группы останется доступным.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await widget.storage.clearAuth();
      setState(() {
        _profile = widget.storage.getUserProfile();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Вы вышли из профиля Telegram')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E232D) : Colors.white;
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Настройки',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Карточка профиля пользователя
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? const Color(0xFF2D333F) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Stack(
                      children: [
                        _buildAvatarWidget(),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: InkWell(
                            onTap: _openAvatarPicker,
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB),
                                shape: BoxShape.circle,
                                border: Border.all(color: cardBg, width: 2),
                              ),
                              child: const Icon(
                                Icons.edit_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _profile.displayName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _profile.idAndUsernameText,
                            style: TextStyle(
                              fontSize: 13,
                              color: subColor,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _profile.userId != null
                                  ? const Color(0xFF059669).withOpacity(0.12)
                                  : const Color(0xFF64748B).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _profile.userId != null ? 'Telegram привязан' : 'Без авторизации',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _profile.userId != null
                                    ? const Color(0xFF059669)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_profile.userId == null) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AuthScreen(storage: widget.storage, api: widget.api),
                          ),
                        );
                        if (mounted) {
                          setState(() {
                            _profile = widget.storage.getUserProfile();
                          });
                        }
                      },
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: const Text('Привязать Telegram аккаунт'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Заголовок секции категорий с возможностью развернуть/свернуть всё
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 4, bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'КАТЕГОРИИ НАСТРОЕК',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: subColor,
                  ),
                ),
                TextButton(
                  onPressed: _toggleAllCategories,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    _expandedCategories.length >= 6 ? 'Свернуть все' : 'Развернуть все',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          // 1. Категория: Оформление
          _buildCategoryCard(
            id: 'appearance',
            title: 'Оформление',
            subtitle: 'Светлая и тёмная темы, значок аватара',
            icon: Icons.palette_rounded,
            iconColor: const Color(0xFF6366F1),
            badgeText: _currentThemeMode == ThemeMode.dark
                ? 'Тёмная'
                : (_currentThemeMode == ThemeMode.light ? 'Светлая' : 'Системная'),
            badgeColor: const Color(0xFF6366F1),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Text(
                  'Тема приложения:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: subColor),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _buildThemeChoiceBtn(
                      title: 'Светлая',
                      icon: Icons.light_mode_rounded,
                      mode: ThemeMode.light,
                    ),
                    const SizedBox(width: 8),
                    _buildThemeChoiceBtn(
                      title: 'Тёмная',
                      icon: Icons.dark_mode_rounded,
                      mode: ThemeMode.dark,
                    ),
                    const SizedBox(width: 8),
                    _buildThemeChoiceBtn(
                      title: 'Авто',
                      icon: Icons.brightness_auto_rounded,
                      mode: ThemeMode.system,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: isDark ? const Color(0xFF2D333F) : const Color(0xFFE2E8F0)),
              ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    _currentSeasonTheme.assetPath,
                    width: 34,
                    height: 34,
                    fit: BoxFit.cover,
                  ),
                ),
                title: const Text('Сезонная иконка и стиль', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  _seasonIconPref == 'auto'
                      ? 'Авто: ${_currentSeasonTheme.title}'
                      : _currentSeasonTheme.title,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _openSeasonIconPicker,
              ),
              Divider(height: 1, color: isDark ? const Color(0xFF2D333F) : const Color(0xFFE2E8F0)),
              ListTile(
                leading: const Icon(Icons.account_circle_rounded, color: Color(0xFF6366F1)),
                title: const Text('Сменить значок профиля', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Выбрать значок академической специальности'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _openAvatarPicker,
              ),
            ],
          ),

          // 2. Категория: Уведомления
          _buildCategoryCard(
            id: 'notifications',
            title: 'Уведомления',
            subtitle: 'Напоминания о парах, звонках и переменах',
            icon: Icons.notifications_active_rounded,
            iconColor: const Color(0xFF2563EB),
            badgeText: _notifSettings.enabled ? 'Вкл (${_notifSettings.beforeMins} мин)' : 'Выкл',
            badgeColor: _notifSettings.enabled ? const Color(0xFF059669) : const Color(0xFF64748B),
            children: [
              SwitchListTile(
                value: _notifSettings.enabled,
                onChanged: (val) {
                  _updateNotificationSettings(_notifSettings.copyWith(enabled: val));
                },
                secondary: const Icon(Icons.notifications_active_rounded, color: Color(0xFF2563EB)),
                title: const Text('Уведомления о занятиях', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Получать напоминания о парах и изменениях'),
              ),
              if (_notifSettings.enabled) ...[
                Divider(height: 1, color: isDark ? const Color(0xFF2D333F) : const Color(0xFFE2E8F0)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Напоминать до начала пары:',
                            style: TextStyle(fontSize: 13, color: subColor, fontWeight: FontWeight.w500),
                          ),
                          Text(
                            '${_notifSettings.beforeMins} минут',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [5, 10, 15, 20, 30, 45, 60].map((mins) {
                          final isSel = _notifSettings.beforeMins == mins;
                          return InkWell(
                            onTap: () {
                              _updateNotificationSettings(_notifSettings.copyWith(beforeMins: mins));
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSel
                                    ? const Color(0xFF2563EB)
                                    : (isDark ? const Color(0xFF1E232D) : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSel ? const Color(0xFF2563EB) : Colors.transparent,
                                ),
                              ),
                              child: Text(
                                '$mins мин',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                  color: isSel ? Colors.white : (isDark ? Colors.grey[300] : Colors.grey[800]),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: isDark ? const Color(0xFF2D333F) : const Color(0xFFE2E8F0)),
                SwitchListTile(
                  value: _notifSettings.lessonStart,
                  onChanged: (val) {
                    _updateNotificationSettings(_notifSettings.copyWith(lessonStart: val));
                  },
                  secondary: const Icon(Icons.alarm_on_rounded, color: Color(0xFF059669)),
                  title: const Text('Звонок на пару'),
                  subtitle: const Text('Оповещение в момент начала занятия'),
                ),
                Divider(height: 1, color: isDark ? const Color(0xFF2D333F) : const Color(0xFFE2E8F0)),
                SwitchListTile(
                  value: _notifSettings.breaks,
                  onChanged: (val) {
                    _updateNotificationSettings(_notifSettings.copyWith(breaks: val));
                  },
                  secondary: const Icon(Icons.coffee_rounded, color: Color(0xFFD97706)),
                  title: const Text('Оповещения о переменах'),
                  subtitle: const Text('Оповещение о завершении пары и времени перемены'),
                ),
                Divider(height: 1, color: isDark ? const Color(0xFF2D333F) : const Color(0xFFE2E8F0)),
                SwitchListTile(
                  value: _notifSettings.changes,
                  onChanged: (val) {
                    _updateNotificationSettings(_notifSettings.copyWith(changes: val));
                  },
                  secondary: const Icon(Icons.sync_problem_rounded, color: Color(0xFF8B5CF6)),
                  title: const Text('Изменения и замены'),
                  subtitle: const Text('Оповещение при публикации нового расписания'),
                ),
                Divider(height: 1, color: isDark ? const Color(0xFF2D333F) : const Color(0xFFE2E8F0)),
                ListTile(
                  leading: const Icon(Icons.mark_email_read_rounded, color: Color(0xFF059669)),
                  title: const Text('Отправить тестовое уведомление', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Проверить всплывающие баннеры и звук на телефоне'),
                  trailing: const Icon(Icons.send_rounded, size: 20),
                  onTap: _sendTestNotification,
                ),
                Divider(height: 1, color: isDark ? const Color(0xFF2D333F) : const Color(0xFFE2E8F0)),
                ListTile(
                  leading: const Icon(Icons.app_settings_alt_rounded, color: Color(0xFF6366F1)),
                  title: const Text('Системные настройки уведомлений', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Открыть параметры разрешений и звука в Android / iOS'),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                  onTap: () => NotificationService.openNotificationSettings(),
                ),
              ],
            ],
          ),

          // 3. Категория: Обновления
          _buildCategoryCard(
            id: 'updates',
            title: 'Обновления',
            subtitle: 'Проверка новой версии, история и автообновление',
            icon: Icons.system_update_rounded,
            iconColor: const Color(0xFF059669),
            badgeText: 'v${AppInfo.versionName}',
            badgeColor: const Color(0xFF059669),
            children: [
              ListTile(
                leading: const Icon(Icons.refresh_rounded, color: Color(0xFF059669)),
                title: const Text('Проверить обновления', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(_isCheckingUpdate ? 'Проверка...' : 'Текущая версия: ${AppInfo.fullVersionText}'),
                trailing: _isCheckingUpdate
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right_rounded),
                onTap: _isCheckingUpdate ? null : _checkForUpdate,
              ),
              Divider(height: 1, color: isDark ? const Color(0xFF2D333F) : const Color(0xFFE2E8F0)),
              SwitchListTile(
                value: _notifSettings.bgUpdateCheck,
                onChanged: (val) {
                  _updateNotificationSettings(_notifSettings.copyWith(bgUpdateCheck: val));
                },
                secondary: const Icon(Icons.update_rounded, color: Color(0xFF0284C7)),
                title: const Text('Фоновая проверка каждые 15 минут'),
                subtitle: const Text('Автоматически проверять наличие новой версии и присылать уведомление'),
              ),
              Divider(height: 1, color: isDark ? const Color(0xFF2D333F) : const Color(0xFFE2E8F0)),
              ListTile(
                leading: const Icon(Icons.history_rounded, color: Color(0xFF8B5CF6)),
                title: const Text('История изменений', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Список всех релизов с GitHub и описание новшеств'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangelogScreen()));
                },
              ),
              Divider(height: 1, color: isDark ? const Color(0xFF2D333F) : const Color(0xFFE2E8F0)),
              ListTile(
                leading: const Icon(Icons.download_rounded, color: Color(0xFF2563EB)),
                title: const Text('Скачать установочный файл заново', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Прямая загрузка APK для Android или IPA для iOS'),
                trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                onTap: () {
                  final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
                  final package = isIOS ? 'RiiSchedule.ipa' : 'RiiSchedule.apk';
                  _openDownloadUrl('https://github.com/yearningss/rii-schedule-bot/releases/latest/download/$package');
                },
              ),
            ],
          ),

          // 4. Категория: Учебный профиль
          _buildCategoryCard(
            id: 'profile',
            title: 'Учебный профиль',
            subtitle: 'Выбор учебной группы и фильтра подгруппы',
            icon: Icons.school_rounded,
            iconColor: const Color(0xFFEA580C),
            badgeText: _profile.groupName ?? 'Не выбрана',
            badgeColor: const Color(0xFFEA580C),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Текущая учебная группа:', style: TextStyle(fontSize: 12, color: subColor)),
                          const SizedBox(height: 4),
                          Text(
                            _profile.groupName ?? 'Группа не выбрана',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _changeGroup,
                      icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                      label: const Text('Сменить'),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: isDark ? const Color(0xFF2D333F) : const Color(0xFFE2E8F0)),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Подгруппа для фильтрации расписания:', style: TextStyle(fontSize: 12, color: subColor)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildSubgroupBtn(0, 'Все'),
                        const SizedBox(width: 8),
                        _buildSubgroupBtn(1, '1-я подгруппа'),
                        const SizedBox(width: 8),
                        _buildSubgroupBtn(2, '2-я подгруппа'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // 5. Категория: Сеть и режим работы
          _buildCategoryCard(
            id: 'network',
            title: 'Сеть и режим работы',
            subtitle: 'Связь с сервером РИИ и офлайн-кэш',
            icon: _isOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
            iconColor: _isOnline ? const Color(0xFF059669) : const Color(0xFFD97706),
            badgeText: _isOnline ? 'Онлайн' : 'Офлайн',
            badgeColor: _isOnline ? const Color(0xFF059669) : const Color(0xFFD97706),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: (_isOnline ? const Color(0xFF059669) : const Color(0xFFD97706)).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _isOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                        color: _isOnline ? const Color(0xFF059669) : const Color(0xFFD97706),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isOnline ? 'Онлайн-режим' : 'Офлайн-режим',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: _isOnline ? const Color(0xFF059669) : const Color(0xFFD97706),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _isOnline
                                ? 'Связь с сервером активна, расписание синхронизировано'
                                : 'Связь отсутствует, отображается сохраненный кэш',
                            style: TextStyle(fontSize: 12, color: subColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: isDark ? const Color(0xFF2D333F) : const Color(0xFFE2E8F0)),
              ListTile(
                leading: const Icon(Icons.wifi_tethering_rounded, color: Color(0xFF0284C7)),
                title: const Text('Проверить соединение с сервером', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Отправить запрос проверки доступности API РИИ'),
                trailing: _isCheckingConnection
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
                onTap: _isCheckingConnection ? null : () => _checkNetworkConnection(showFeedback: true),
              ),
            ],
          ),

          // 6. Категория: Справка и аккаунт
          _buildCategoryCard(
            id: 'help',
            title: 'Справка и аккаунт',
            subtitle: 'Звонки, разрешения ОС и привязка к Telegram',
            icon: Icons.help_outline_rounded,
            iconColor: const Color(0xFF64748B),
            badgeText: _profile.userId != null ? 'TG привязан' : 'Справка',
            badgeColor: const Color(0xFF64748B),
            children: [
              ListTile(
                leading: const Icon(Icons.access_time_rounded, color: Color(0xFF2563EB)),
                title: const Text('Расписание звонков', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Длительность пар и перемен в РИИ'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const BellsScreen()));
                },
              ),
              Divider(height: 1, color: isDark ? const Color(0xFF2D333F) : const Color(0xFFE2E8F0)),
              ListTile(
                leading: const Icon(Icons.verified_user_rounded, color: Color(0xFF059669)),
                title: const Text('Системные разрешения', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Проверить разрешение на показ уведомлений в ОС'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  final granted = await NotificationService.requestPermission();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(granted
                            ? 'Уведомления разрешены системой'
                            : 'Запрос отправлен. Убедитесь, что уведомления включены в настройках системы'),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                },
              ),
              Divider(height: 1, color: isDark ? const Color(0xFF2D333F) : const Color(0xFFE2E8F0)),
              if (_profile.userId == null)
                ListTile(
                  leading: const Icon(Icons.send_rounded, color: Color(0xFF2563EB)),
                  title: const Text('Привязать Telegram аккаунт', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Синхронизация профиля и уведомлений с ботом'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AuthScreen(storage: widget.storage, api: widget.api),
                      ),
                    );
                    if (mounted) {
                      setState(() {
                        _profile = widget.storage.getUserProfile();
                      });
                    }
                  },
                )
              else
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626)),
                  title: const Text('Выйти из Telegram аккаунта', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w600)),
                  subtitle: const Text('Отвязать текущий профиль Telegram от приложения'),
                  onTap: _logout,
                ),
            ],
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCategoryCard({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required String badgeText,
    required Color badgeColor,
    required List<Widget> children,
  }) {
    final isExpanded = _expandedCategories.contains(id);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E232D) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2D333F) : const Color(0xFFE2E8F0);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isExpanded ? iconColor.withOpacity(0.55) : borderColor,
          width: isExpanded ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Кнопка категории
          InkWell(
            onTap: () => _toggleCategory(id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: iconColor, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(fontSize: 12, color: subColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: badgeColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: subColor,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Подкнопки категории
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Divider(height: 1, color: borderColor),
                ...children,
              ],
            ),
            crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeChoiceBtn({
    required String title,
    required IconData icon,
    required ThemeMode mode,
  }) {
    final isSelected = _currentThemeMode == mode;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: InkWell(
        onTap: () => _setTheme(mode),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF6366F1)
                : (isDark ? const Color(0xFF1E232D) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFF6366F1) : (isDark ? const Color(0xFF2D333F) : const Color(0xFFE2E8F0)),
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : Colors.grey[700]),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : Colors.grey[700]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubgroupBtn(int sg, String label) {
    final isSelected = _profile.subgroup == sg;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: InkWell(
        onTap: () => _setSubgroup(sg),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF2563EB)
                : (isDark
                    ? const Color(0xFF1E232D)
                    : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF2D333F) : const Color(0xFFE2E8F0)),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.white : null,
            ),
          ),
        ),
      ),
    );
  }
}
