// Главный экран расписания занятий по стандарту Material 3
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/widget_service.dart';
import '../widgets/para_card.dart';
import 'bells_screen.dart';
import 'group_picker_screen.dart';
import 'settings_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/notification_service.dart';
import '../theme/theme.dart';

class ScheduleScreen extends StatefulWidget {
  final StorageService storage;
  final ApiService api;

  const ScheduleScreen({
    super.key,
    required this.storage,
    required this.api,
  });

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> with WidgetsBindingObserver {
  late UserProfile _profile;
  Map<String, dynamic>? _scheduleJson;
  bool _isLoading = true;
  bool _isOffline = false;

  int _selectedWeek = 1;
  int _selectedDay = 1;
  int _navIndex = 0;
  bool _userSelectedManually = false;
  Timer? _statusTimer;
  Timer? _bgUpdateTimer;

  final List<String> _dayNames = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _profile = widget.storage.getUserProfile();

    // Первичная инициализация дня и недели на основе текущего времени
    final rTime = _getRubtsovskTime();
    final realWeekday = rTime.weekday; // 1=Пн .. 6=Сб, 7=Вс
    if (realWeekday > 6) {
      // Воскресенье: настраиваемся на понедельник
      _selectedDay = 1;
      _selectedWeek = 1;
    } else {
      _selectedDay = realWeekday;
      _selectedWeek = 1;
    }

    _initSchedule();

    // Обновляем статус времени и проверяем расписание каждую минуту
    _statusTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {});
        _checkScheduleNotifications();
      }
    });

    // Фоновая проверка обновлений каждые 15 минут
    _bgUpdateTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      _checkPeriodicUpdate();
    });

    // Фоновая тихая проверка обновлений и запрос разрешения на уведомления
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPeriodicUpdate(isStartup: true);
      NotificationService.requestPermission();
      _checkScheduleNotifications();
      _syncDeviceProfile();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkScheduleNotifications();
      _syncDeviceProfile();
      final lastCheck = widget.storage.prefs.getInt('last_bg_update_check_time') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      // Если прошло 15 минут или более с последней проверки
      if (now - lastCheck >= 15 * 60 * 1000) {
        _checkPeriodicUpdate();
      }
    }
  }

  // Фоновая периодическая проверка обновлений каждые 15 минут с отправкой системного уведомления
  Future<void> _checkPeriodicUpdate({bool isStartup = false}) async {
    final notifSettings = widget.storage.getNotificationSettings();
    if (!notifSettings.bgUpdateCheck) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    await widget.storage.prefs.setInt('last_bg_update_check_time', now);

    try {
      final update = await widget.api.checkAppUpdate(
        currentBuild: AppInfo.versionCode,
        currentVersion: AppInfo.versionName,
      );

      if (update != null && update.hasUpdate) {
        final lastNotified = widget.storage.prefs.getInt('last_notified_update_build') ?? 0;
        if (update.latestBuild > lastNotified) {
          await widget.storage.prefs.setInt('last_notified_update_build', update.latestBuild);

          // Отправка системного push-уведомления
          await NotificationService.showNotification(
            title: 'Доступно обновление ${update.latestVersion}',
            message: 'Нажмите для загрузки новой версии приложения РИИ Расписание.',
          );
        }

        // Показ диалога обновления при запуске
        if (isStartup && mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(
                'Доступно обновление ${update.latestVersion}',
                style: AppTypography.titleLarge,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Вышла новая версия приложения: ${update.latestVersion} (сборка ${update.latestBuild}).',
                    style: AppTypography.bodyMedium,
                  ),
                  if (update.changelog != null && update.changelog!.isNotEmpty) ...[
                    AppSpacing.gapH12,
                    Text(
                      'Что нового:',
                      style: AppTypography.labelLarge,
                    ),
                    AppSpacing.gapH4,
                    Text(
                      update.changelog!,
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Позже'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    if (update.downloadUrl != null) {
                      _openUpdateUrl(update.downloadUrl!);
                    }
                  },
                  child: const Text('Обновить'),
                ),
              ],
            ),
          );
        }
      }
    } catch (_) {}
  }

  // Проверка расписания для отправки локальных уведомлений
  Future<void> _checkScheduleNotifications() async {
    final notifSettings = widget.storage.getNotificationSettings();
    if (!notifSettings.enabled) return;

    if (_scheduleJson == null) return;
    final rTime = _getRubtsovskTime();
    final realWeekday = rTime.weekday;
    if (realWeekday > 6) return;

    final siteWeek = int.tryParse(_scheduleJson?['weekNumber']?.toString() ?? '1') ?? 1;
    final scheduleMap = _scheduleJson?['scheduleData'] as Map<String, dynamic>?;
    final weekMap = scheduleMap?[siteWeek.toString()] as Map<String, dynamic>?;
    final dayData = weekMap?[realWeekday.toString()] as Map<String, dynamic>?;
    final paraTimesMap = _scheduleJson?['paraTimes'] as Map<String, dynamic>?;

    if (dayData == null || paraTimesMap == null) return;

    final curMins = rTime.hour * 60 + rTime.minute;
    final todayStr = '${rTime.year}_${rTime.month}_${rTime.day}';
    final userSubgroup = _profile.subgroup;

    final sortedParaNums = dayData.keys.map((k) => int.tryParse(k) ?? 0).where((n) => n > 0).toList()..sort();
    if (sortedParaNums.isEmpty) return;

    for (int i = 0; i < sortedParaNums.length; i++) {
      final pNum = sortedParaNums[i];
      final pData = dayData[pNum.toString()];
      if (pData is! Map) continue;

      if (pData['isDouble'] == true) {
        if (userSubgroup == 1 && pData['subj1'] == null) continue;
        if (userSubgroup == 2 && pData['subj2'] == null) continue;
      } else {
        if (pData['subj1'] == null) continue;
      }

      final timeStr = paraTimesMap[pNum.toString()]?.toString();
      final pTime = ParaTime.parse(timeStr, pNum);

      String subjName = 'Занятие';
      String audName = '';
      if (pData['isDouble'] == true && userSubgroup == 2) {
        subjName = pData['subj2']?.toString() ?? 'Занятие';
        audName = pData['aud2']?.toString() ?? '';
      } else {
        subjName = pData['subj1']?.toString() ?? 'Занятие';
        audName = pData['aud1']?.toString() ?? '';
      }
      final audStr = audName.isNotEmpty ? ' (ауд. $audName)' : '';

      // 1. Уведомление до начала пары
      if (notifSettings.beforeMins > 0) {
        final targetMins = pTime.startMinutes - notifSettings.beforeMins;
        if (curMins >= targetMins && curMins < pTime.startMinutes) {
          final sentKey = 'notif_sent_${todayStr}_p${pNum}_before';
          if (widget.storage.prefs.getBool(sentKey) != true) {
            await widget.storage.prefs.setBool(sentKey, true);
            await NotificationService.showNotification(
              title: 'Через ${notifSettings.beforeMins} мин: $pNum пара',
              message: '$subjName$audStr начнется в ${pTime.startStr}.',
            );
          }
        }
      }

      // 2. Уведомление в момент начала пары
      if (notifSettings.lessonStart) {
        if (curMins >= pTime.startMinutes && curMins < (pTime.startMinutes + 5)) {
          final sentKey = 'notif_sent_${todayStr}_p${pNum}_start';
          if (widget.storage.prefs.getBool(sentKey) != true) {
            await widget.storage.prefs.setBool(sentKey, true);
            await NotificationService.showNotification(
              title: 'Началась $pNum пара: $subjName',
              message: 'Аудитория: ${audName.isNotEmpty ? audName : "не указана"}. Окончание в ${pTime.endStr}.',
            );
          }
        }
      }

      // 3. Оперативное оповещение об окончании пары и начале перемены
      if (notifSettings.breaks) {
        if (curMins >= pTime.endMinutes && curMins < (pTime.endMinutes + 5)) {
          final sentKey = 'notif_sent_${todayStr}_p${pNum}_break';
          if (widget.storage.prefs.getBool(sentKey) != true) {
            await widget.storage.prefs.setBool(sentKey, true);

            if (i + 1 < sortedParaNums.length) {
              final nextPNum = sortedParaNums[i + 1];
              final nextPData = dayData[nextPNum.toString()];
              final nextTimeStr = paraTimesMap[nextPNum.toString()]?.toString();
              final nextPTime = ParaTime.parse(nextTimeStr, nextPNum);
              final breakLen = (nextPTime.startMinutes - pTime.endMinutes).clamp(0, 180);

              String nextSubj = 'следующая пара';
              if (nextPData is Map) {
                if (nextPData['isDouble'] == true && userSubgroup == 2 && nextPData['subj2'] != null) {
                  nextSubj = nextPData['subj2'].toString();
                } else if (nextPData['subj1'] != null) {
                  nextSubj = nextPData['subj1'].toString();
                }
              }

              await NotificationService.showNotification(
                title: 'Перемена $breakLen мин',
                message: 'Закончилась $pNum пара. Следующая: $nextPNum пара в ${nextPTime.startStr} ($nextSubj).',
              );
            } else {
              await NotificationService.showNotification(
                title: 'Занятия завершены',
                message: 'Закончилась $pNum пара. На сегодня занятий больше нет.',
              );
            }
          }
        }
      }
    }
  }

  Future<void> _openUpdateUrl(String url) async {
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
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _statusTimer?.cancel();
    _bgUpdateTimer?.cancel();
    super.dispose();
  }

  DateTime _getRubtsovskTime() {
    final now = DateTime.now().toUtc();
    return now.add(const Duration(hours: 7));
  }

  Future<void> _syncDeviceProfile() async {
    try {
      final deviceId = widget.storage.getDeviceId();
      final clientUserId = widget.storage.getClientUserId();
      final notif = widget.storage.getNotificationSettings();
      final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
      await widget.api.syncDeviceUser(
        deviceId: deviceId,
        clientUserId: clientUserId,
        platform: isIOS ? 'ios' : 'android',
        groupId: _profile.groupId,
        groupName: _profile.groupName,
        subgroup: _profile.subgroup,
        notificationsEnabled: notif.enabled,
        notifyBeforeMins: notif.beforeMins,
        notifyLessonStart: notif.lessonStart,
        notifyBreaks: notif.breaks,
        notifyChanges: notif.changes,
        appVersion: AppInfo.versionName,
        authToken: _profile.authToken,
      );
    } catch (_) {}
  }

  Future<void> _initSchedule() async {
    if (_profile.groupId == null) return;

    // Сначала читаем кэш для мгновенной отрисовки без задержки
    final cached = widget.storage.getScheduleCache(_profile.groupId!);
    if (cached != null) {
      _applyScheduleData(cached, isFromCache: true);
    }

    await _fetchFreshSchedule();
  }

  Future<void> _fetchFreshSchedule({bool isInit = false}) async {
    if (_profile.groupId == null) return;

    try {
      final fresh = await widget.api.getSchedule(_profile.groupId!);
      await widget.storage.saveScheduleCache(_profile.groupId!, fresh);
      if (mounted) {
        setState(() {
          _isOffline = false;
        });
        _applyScheduleData(fresh, isFromCache: false);
      }
      _syncDeviceProfile();
    } catch (_) {
      if (mounted) {
        setState(() {
          _isOffline = true;
          if (_scheduleJson == null) {
            _isLoading = false;
          }
        });

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Офлайн-режим: отображается сохраненное расписание. Для получения актуальных данных подключитесь к интернету.',
            ),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Повторить',
              onPressed: () => _fetchFreshSchedule(),
            ),
          ),
        );
      }
    }
  }

  void _applyScheduleData(Map<String, dynamic> data, {required bool isFromCache}) {
    final siteWeek = int.tryParse(data['weekNumber']?.toString() ?? '1') ?? 1;
    final rTime = _getRubtsovskTime();
    final realWeekday = rTime.weekday; // 1=Пн .. 6=Сб, 7=Вс

    setState(() {
      _scheduleJson = data;
      _isLoading = false;

      if (!_userSelectedManually) {
        if (realWeekday > 6) {
          _selectedDay = 1;
          _selectedWeek = (siteWeek == 1) ? 2 : 1;
        } else {
          _selectedDay = realWeekday;
          _selectedWeek = siteWeek;
        }
      }
    });

    WidgetService.updateWidgetData(profile: _profile, scheduleJson: data);
  }

  Future<void> _changeGroup() async {
    final selected = await Navigator.push<GroupItem>(
      context,
      MaterialPageRoute(
        builder: (_) => GroupPickerScreen(storage: widget.storage, api: widget.api),
      ),
    );

    if (selected != null && selected.id != _profile.groupId) {
      setState(() {
        _profile = _profile.copyWith(groupId: selected.id, groupName: selected.name);
        _isLoading = true;
      });
      await widget.storage.saveUserProfile(_profile);

      // Фоновая синхронизация с ботом при наличии авторизации
      if (_profile.authToken != null) {
        widget.api.syncProfile(
          authToken: _profile.authToken!,
          groupId: selected.id,
          groupName: selected.name,
        );
      }
      _syncDeviceProfile();

      WidgetService.updateWidgetData(profile: _profile);
      await _fetchFreshSchedule();
    }
  }

  void _setSubgroup(int sg) {
    setState(() {
      _profile = _profile.copyWith(subgroup: sg);
    });
    widget.storage.saveSubgroup(sg);

    if (_profile.authToken != null) {
      widget.api.syncProfile(
        authToken: _profile.authToken!,
        subgroup: sg,
      );
    }
    _syncDeviceProfile();

    WidgetService.updateWidgetData(profile: _profile, scheduleJson: _scheduleJson);
  }

  void _onNavDestinationSelected(int index) {
    if (_navIndex == index) return;
    setState(() {
      _navIndex = index;
    });

    // При возврате на экран расписания проверяем синхронизацию профиля
    if (index == 0) {
      final updated = widget.storage.getUserProfile();
      if (updated.groupId != _profile.groupId || updated.subgroup != _profile.subgroup) {
        setState(() {
          _profile = updated;
          _isLoading = true;
        });
        _initSchedule();
      } else {
        setState(() {
          _profile = updated;
        });
      }
    }
  }

  String _calculateLiveStatus(Map<String, dynamic> dayMap, Map<String, dynamic> paraTimes) {
    final rTime = _getRubtsovskTime();
    final curMins = rTime.hour * 60 + rTime.minute;

    final sortedKeys = dayMap.keys.map((k) => int.tryParse(k) ?? 0).where((n) => n > 0).toList()..sort();
    if (sortedKeys.isEmpty) return 'Пар на сегодня нет';

    ParaTime? ongoing;
    int? ongoingNum;
    ParaTime? next;
    int? nextNum;

    for (var pNum in sortedKeys) {
      final t = ParaTime.parse(paraTimes[pNum.toString()], pNum);
      if (t.startMinutes <= curMins && curMins <= t.endMinutes) {
        ongoing = t;
        ongoingNum = pNum;
        break;
      } else if (curMins < t.startMinutes && next == null) {
        next = t;
        nextNum = pNum;
      }
    }

    if (ongoing != null) {
      final rem = ongoing.endMinutes - curMins;
      return 'Идет $ongoingNum пара (до ${ongoing.endStr}, осталось $rem мин)';
    } else if (next != null) {
      final firstNum = sortedKeys.first;
      final firstTime = ParaTime.parse(paraTimes[firstNum.toString()], firstNum);
      if (curMins < firstTime.startMinutes) {
        final rem = firstTime.startMinutes - curMins;
        return 'Занятия не начались. $firstNum пара в ${firstTime.startStr} (через $rem мин)';
      } else {
        final rem = next.startMinutes - curMins;
        return 'Перемена (до ${next.startStr}, осталось $rem мин). След: $nextNum пара';
      }
    } else {
      return 'Все пары на сегодня завершены';
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth >= 640;

        if (isWideScreen) {
          // Планшетный и десктопный режим с боковой панелью NavigationRail
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _navIndex,
                  onDestinationSelected: _onNavDestinationSelected,
                  extended: constraints.maxWidth >= 900,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: Icon(
                      Icons.school_rounded,
                      size: 32,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.calendar_today_outlined),
                      selectedIcon: Icon(Icons.calendar_today_rounded),
                      label: Text('Расписание'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.access_time_outlined),
                      selectedIcon: Icon(Icons.access_time_filled_rounded),
                      label: Text('Звонки'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings_rounded),
                      label: Text('Настройки'),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 860),
                      child: _buildCurrentTab(),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // Мобильный режим со стандартным M3 NavigationBar
        return Scaffold(
          body: _buildCurrentTab(),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _navIndex,
            onDestinationSelected: _onNavDestinationSelected,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.calendar_today_outlined),
                selectedIcon: Icon(Icons.calendar_today_rounded),
                label: 'Расписание',
              ),
              NavigationDestination(
                icon: Icon(Icons.access_time_outlined),
                selectedIcon: Icon(Icons.access_time_filled_rounded),
                label: 'Звонки',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings_rounded),
                label: 'Настройки',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCurrentTab() {
    switch (_navIndex) {
      case 1:
        return const BellsScreen();
      case 2:
        return SettingsScreen(storage: widget.storage, api: widget.api);
      case 0:
      default:
        return _buildScheduleView();
    }
  }

  Widget _buildScheduleView() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final scheduleColors = context.scheduleColors;

    final scheduleMap = _scheduleJson?['scheduleData'] as Map<String, dynamic>?;
    final weekMap = scheduleMap?[_selectedWeek.toString()] as Map<String, dynamic>?;
    final dayMap = weekMap?[_selectedDay.toString()] as Map<String, dynamic>? ?? {};
    final paraTimes = _scheduleJson?['paraTimes'] as Map<String, dynamic>? ?? {};

    final rTime = _getRubtsovskTime();
    final realWeekday = rTime.weekday; // 1=Пн .. 6=Сб, 7=Вс
    final siteWeek = int.tryParse(_scheduleJson?['weekNumber']?.toString() ?? '1') ?? 1;
    final isToday = (realWeekday <= 6 && _selectedWeek == siteWeek && _selectedDay == realWeekday);
    final isSunday = (realWeekday == 7);
    final isSaturday = (realWeekday == 6);

    final curMins = rTime.hour * 60 + rTime.minute;
    final sortedKeys = dayMap.keys.map((k) => int.tryParse(k) ?? 0).where((n) => n > 0).toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: _changeGroup,
          borderRadius: AppShape.roundedMd,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    _profile.groupName ?? 'Выбрать группу',
                    style: AppTypography.titleLarge.copyWith(
                      color: colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                AppSpacing.gapW4,
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 22,
                  color: colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
        actions: [
          // Переключатель недели I / II через SegmentedButton
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment<int>(
                  value: 1,
                  label: Text('I нед'),
                ),
                ButtonSegment<int>(
                  value: 2,
                  label: Text('II нед'),
                ),
              ],
              selected: {_selectedWeek},
              onSelectionChanged: (newSelection) {
                setState(() {
                  _selectedWeek = newSelection.first;
                  _userSelectedManually = true;
                });
              },
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Обновить расписание',
            onPressed: () => _fetchFreshSchedule(),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: Column(
        children: [
          // Полоса выбора дней недели (Пн-Сб)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xs,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (idx) {
                final dayNum = idx + 1;
                final isSelected = _selectedDay == dayNum;
                final isCurrentRealDay = (realWeekday == dayNum);

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
                    child: InkWell(
                      onTap: () => setState(() {
                        _selectedDay = dayNum;
                        _userSelectedManually = true;
                      }),
                      borderRadius: AppShape.roundedMd,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.surface,
                          borderRadius: AppShape.roundedMd,
                          border: Border.all(
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.outlineVariant,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: colorScheme.primary.withOpacity(0.25),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _dayNames[idx],
                              style: AppTypography.labelMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? colorScheme.onPrimary
                                    : colorScheme.onSurface,
                              ),
                            ),
                            if (isCurrentRealDay) ...[
                              AppSpacing.gapH2,
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? colorScheme.onPrimary
                                      : colorScheme.primary,
                                ),
                              ),
                            ] else ...[
                              const SizedBox(height: 7),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          // Переключатель подгруппы (Все / 1 п/г / 2 п/г)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment<int>(
                    value: 0,
                    label: Text('Все подгруппы'),
                  ),
                  ButtonSegment<int>(
                    value: 1,
                    label: Text('1 подгруппа'),
                  ),
                  ButtonSegment<int>(
                    value: 2,
                    label: Text('2 подгруппа'),
                  ),
                ],
                selected: {_profile.subgroup},
                onSelectionChanged: (newSelection) {
                  _setSubgroup(newSelection.first);
                },
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ),

          // Предупреждение об офлайн-режиме работы
          if (_isOffline)
            Container(
              margin: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xs,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer.withOpacity(0.4),
                borderRadius: AppShape.roundedMd,
                border: Border.all(
                  color: colorScheme.error.withOpacity(0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.wifi_off_rounded,
                    size: 20,
                    color: colorScheme.error,
                  ),
                  AppSpacing.gapW8,
                  Expanded(
                    child: Text(
                      'Офлайн-режим: показано сохраненное расписание.',
                      style: AppTypography.bodySmall.copyWith(
                        color: colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _fetchFreshSchedule,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            ),

          // Плашка статуса для сегодняшнего дня или выходных
          if (isToday)
            Container(
              margin: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xs,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: scheduleColors.ongoingContainer.withOpacity(0.35),
                borderRadius: AppShape.roundedMd,
                border: Border.all(
                  color: scheduleColors.ongoing.withOpacity(0.35),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: scheduleColors.ongoing,
                      shape: BoxShape.circle,
                    ),
                  ),
                  AppSpacing.gapW8,
                  Expanded(
                    child: Text(
                      _calculateLiveStatus(dayMap, paraTimes),
                      style: AppTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheduleColors.onOngoingContainer,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (isSunday && _selectedDay == 1)
            Container(
              margin: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xs,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer.withOpacity(0.5),
                borderRadius: AppShape.roundedMd,
                border: Border.all(
                  color: colorScheme.outlineVariant,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.weekend_rounded,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  AppSpacing.gapW8,
                  Expanded(
                    child: Text(
                      'Сегодня воскресенье (выходной) - Показан понедельник (${_selectedWeek == 2 ? 'II' : 'I'} нед)',
                      style: AppTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (isSaturday && _selectedDay == 6 && sortedKeys.isEmpty)
            Container(
              margin: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xs,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer.withOpacity(0.5),
                borderRadius: AppShape.roundedMd,
                border: Border.all(
                  color: colorScheme.outlineVariant,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.event_available_rounded,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  AppSpacing.gapW8,
                  Expanded(
                    child: Text(
                      'Сегодня суббота - По расписанию пар нет (выходной день)',
                      style: AppTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Список пар на выбранный день
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : sortedKeys.isEmpty
                    ? RefreshIndicator(
                        onRefresh: _fetchFreshSchedule,
                        child: LayoutBuilder(
                          builder: (context, constraints) => SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minHeight: constraints.maxHeight),
                              child: Center(
                                child: Padding(
                                  padding: AppSpacing.dialogPadding,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.event_busy_rounded,
                                        size: 56,
                                        color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                                      ),
                                      AppSpacing.gapH16,
                                      Text(
                                        _selectedDay == 6
                                            ? 'В субботу занятий нет (выходной)'
                                            : 'В этот день занятий нет',
                                        style: AppTypography.titleMedium.copyWith(
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      if (_selectedDay == 6) ...[
                                        AppSpacing.gapH12,
                                        FilledButton.tonalIcon(
                                          onPressed: () {
                                            setState(() {
                                              _selectedDay = 1;
                                              _selectedWeek = (_selectedWeek == 1) ? 2 : 1;
                                              _userSelectedManually = true;
                                            });
                                          },
                                          icon: const Icon(Icons.calendar_today_rounded, size: 18),
                                          label: const Text('Открыть понедельник'),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchFreshSchedule,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(
                            top: AppSpacing.xs,
                            bottom: AppSpacing.xxl,
                          ),
                          itemCount: sortedKeys.length,
                          itemBuilder: (context, idx) {
                            final pNum = sortedKeys[idx];
                            final itemJson = dayMap[pNum.toString()] as Map<String, dynamic>;
                            final item = ParaItem.fromJson(pNum, itemJson);
                            final timeInfo = ParaTime.parse(paraTimes[pNum.toString()], pNum);

                            bool isOngoing = false;
                            bool isNext = false;
                            bool isCompleted = false;

                            if (isToday) {
                              if (curMins > timeInfo.endMinutes) {
                                isCompleted = true;
                              } else if (timeInfo.startMinutes <= curMins && curMins <= timeInfo.endMinutes) {
                                isOngoing = true;
                              } else if (curMins < timeInfo.startMinutes &&
                                  (idx == 0 || curMins > ParaTime.parse(paraTimes[sortedKeys[idx - 1].toString()], sortedKeys[idx - 1]).endMinutes)) {
                                isNext = true;
                              }
                            }

                            return ParaCard(
                              item: item,
                              timeInfo: timeInfo,
                              isOngoing: isOngoing,
                              isNext: isNext,
                              isCompleted: isCompleted,
                              activeSubgroup: _profile.subgroup,
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
