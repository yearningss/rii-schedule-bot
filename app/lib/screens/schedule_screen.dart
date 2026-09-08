// Главный экран расписания занятий
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
            title: 'Доступно обновление РИИ',
            message: 'Вышла новая версия v${update.latestVersion} (сборка ${update.latestBuild}). Нажмите для скачивания.',
          );
        }

        final lastPrompted = widget.storage.prefs.getInt('last_prompted_update_build') ?? 0;
        if (mounted && isStartup && update.latestBuild > lastPrompted) {
          await widget.storage.prefs.setInt('last_prompted_update_build', update.latestBuild);
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Доступна новая версия приложения (v${update.latestVersion})'),
              duration: const Duration(seconds: 8),
              action: SnackBarAction(
                label: 'Обновить',
                onPressed: () => _openUpdateUrl(update.downloadUrl),
              ),
            ),
          );
        }
      }
    } catch (_) {}
  }

  // Проверка расписания на сегодня и отправка системных уведомлений о парах и переменах
  Future<void> _checkScheduleNotifications() async {
    if (_scheduleJson == null) return;
    final notifSettings = widget.storage.getNotificationSettings();
    if (!notifSettings.enabled) return;

    final rTime = _getRubtsovskTime();
    final realWeekday = rTime.weekday;
    if (realWeekday > 6) return; // Воскресенье: занятий нет

    final siteWeek = int.tryParse(_scheduleJson!['weekNumber']?.toString() ?? '1') ?? 1;
    final scheduleData = _scheduleJson!['scheduleData'];
    if (scheduleData is! Map) return;

    final weekData = scheduleData[siteWeek.toString()];
    if (weekData is! Map) return;

    final dayData = weekData[realWeekday.toString()];
    if (dayData is! Map || dayData.isEmpty) return;

    final paraTimes = _scheduleJson!['paraTimes'];
    final paraTimesMap = paraTimes is Map ? paraTimes : {};

    final curMins = rTime.hour * 60 + rTime.minute;
    final todayStr = '${rTime.year}_${rTime.month}_${rTime.day}';

    final sortedParaNums = dayData.keys
        .map((k) => int.tryParse(k.toString()))
        .where((k) => k != null)
        .cast<int>()
        .toList()..sort();

    final userSubgroup = _profile.subgroup;

    for (int i = 0; i < sortedParaNums.length; i++) {
      final pNum = sortedParaNums[i];
      final pData = dayData[pNum.toString()];
      if (pData is! Map) continue;

      final timeStr = paraTimesMap[pNum.toString()]?.toString();
      final pTime = ParaTime.parse(timeStr, pNum);

      String subjText = '';
      String audText = '';
      if (pData['isDouble'] == true) {
        if (userSubgroup == 2 && pData['subj2'] != null) {
          subjText = pData['subj2'].toString();
          audText = pData['aud2'] != null ? ' (ауд. ${pData['aud2']})' : '';
        } else {
          subjText = pData['subj1']?.toString() ?? pData['subj2']?.toString() ?? 'Пара';
          final a = userSubgroup == 2 ? pData['aud2'] : pData['aud1'];
          audText = a != null ? ' (ауд. $a)' : '';
        }
      } else {
        subjText = pData['subj1']?.toString() ?? 'Пара';
        if (pData['aud1'] != null && pData['aud1'].toString().isNotEmpty) {
          audText = ' (ауд. ${pData['aud1']})';
        }
      }

      // 1. Точное системное планирование напоминаний на текущий день
      try {
        final startMinUtc = DateTime.utc(
          rTime.year,
          rTime.month,
          rTime.day,
          pTime.startMinutes ~/ 60,
          pTime.startMinutes % 60,
        ).subtract(const Duration(hours: 7));

        final endMinUtc = DateTime.utc(
          rTime.year,
          rTime.month,
          rTime.day,
          pTime.endMinutes ~/ 60,
          pTime.endMinutes % 60,
        ).subtract(const Duration(hours: 7));

        final nowUtc = DateTime.now().toUtc();

        // А. Системное напоминание до начала пары
        if (notifSettings.beforeMins > 0) {
          final targetBeforeUtc = startMinUtc.subtract(Duration(minutes: notifSettings.beforeMins));
          if (targetBeforeUtc.isAfter(nowUtc)) {
            final schedKey = 'sched_${todayStr}_p${pNum}_before_${notifSettings.beforeMins}';
            if (widget.storage.prefs.getBool(schedKey) != true) {
              await widget.storage.prefs.setBool(schedKey, true);
              await NotificationService.scheduleNotification(
                id: pNum * 10 + 1,
                title: 'Скоро пара: $subjText',
                message: 'Через ${notifSettings.beforeMins} мин (${pTime.startStr}) начнется $pNum пара$audText.',
                scheduledDate: targetBeforeUtc.toLocal(),
              );
            }
          }
        }

        // Б. Системный звонок на пару
        if (notifSettings.lessonStart && startMinUtc.isAfter(nowUtc)) {
          final schedKey = 'sched_${todayStr}_p${pNum}_start';
          if (widget.storage.prefs.getBool(schedKey) != true) {
            await widget.storage.prefs.setBool(schedKey, true);
            await NotificationService.scheduleNotification(
              id: pNum * 10 + 2,
              title: 'Началась $pNum пара',
              message: '$subjText$audText (${pTime.startStr} - ${pTime.endStr}).',
              scheduledDate: startMinUtc.toLocal(),
            );
          }
        }

        // В. Системное оповещение о перемене / окончании занятий
        if (notifSettings.breaks && endMinUtc.isAfter(nowUtc)) {
          final schedKey = 'sched_${todayStr}_p${pNum}_break';
          if (widget.storage.prefs.getBool(schedKey) != true) {
            await widget.storage.prefs.setBool(schedKey, true);
            String breakTitle = 'Занятия завершены';
            String breakMsg = 'Закончилась $pNum пара. На сегодня занятий больше нет.';

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
              breakTitle = 'Перемена $breakLen мин';
              breakMsg = 'Закончилась $pNum пара. Следующая: $nextPNum пара в ${nextPTime.startStr} ($nextSubj).';
            }

            await NotificationService.scheduleNotification(
              id: pNum * 10 + 3,
              title: breakTitle,
              message: breakMsg,
              scheduledDate: endMinUtc.toLocal(),
            );
          }
        }
      } catch (_) {}

      // 2. Оперативное уведомление прямо сейчас (динамический расчет точных минут без задержки)
      if (notifSettings.beforeMins > 0) {
        final minsLeft = pTime.startMinutes - curMins;
        if (minsLeft > 0 && minsLeft <= notifSettings.beforeMins) {
          final sentKey = 'notif_sent_${todayStr}_p${pNum}_before';
          if (widget.storage.prefs.getBool(sentKey) != true) {
            await widget.storage.prefs.setBool(sentKey, true);
            await NotificationService.showNotification(
              title: 'Скоро пара: $subjText',
              message: 'Через $minsLeft мин (${pTime.startStr}) начнется $pNum пара$audText.',
            );
          }
        }
      }

      // 3. Оперативное оповещение о начале пары
      if (notifSettings.lessonStart) {
        if (curMins >= pTime.startMinutes && curMins < (pTime.startMinutes + 5)) {
          final sentKey = 'notif_sent_${todayStr}_p${pNum}_start';
          if (widget.storage.prefs.getBool(sentKey) != true) {
            await widget.storage.prefs.setBool(sentKey, true);
            await NotificationService.showNotification(
              title: 'Началась $pNum пара',
              message: '$subjText$audText (${pTime.startStr} - ${pTime.endStr}).',
            );
          }
        }
      }

      // 4. Оперативное оповещение об окончании пары и начале перемены
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
      final notif = widget.storage.getNotificationSettings();
      final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
      await widget.api.syncDeviceUser(
        deviceId: deviceId,
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
    final realWeekday = rTime.weekday; // 1 = Monday .. 6 = Saturday, 7 = Sunday

    setState(() {
      _scheduleJson = data;
      _isLoading = false;
      if (!_userSelectedManually) {
        if (realWeekday > 6) {
          // Воскресенье: открываем расписание на понедельник следующей учебной недели
          _selectedDay = 1;
          _selectedWeek = (siteWeek == 1) ? 2 : 1;
        } else {
          _selectedDay = realWeekday;
          _selectedWeek = siteWeek;
        }
      }
    });

    WidgetService.updateWidgetData(profile: _profile, scheduleJson: data);
    _checkScheduleNotifications();
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

    WidgetService.updateWidgetData(profile: _profile, scheduleJson: _scheduleJson);
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
        elevation: 0,
        title: InkWell(
          onTap: _changeGroup,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _profile.groupName ?? 'Выбрать группу',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
              ],
            ),
          ),
        ),
        actions: [
          // Переключатель недели I / II
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E232D) : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                _buildWeekBtn(1, 'I нед'),
                _buildWeekBtn(2, 'II нед'),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.access_time_rounded),
            tooltip: 'Звонки',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const BellsScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Настройки и профиль',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(storage: widget.storage, api: widget.api),
                ),
              );
              if (mounted) {
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
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Полоса выбора дней недели
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (idx) {
                final dayNum = idx + 1;
                final isSelected = _selectedDay == dayNum;
                final isCurrentRealDay = (realWeekday == dayNum);

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: InkWell(
                      onTap: () => setState(() {
                        _selectedDay = dayNum;
                        _userSelectedManually = true;
                      }),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF2563EB)
                              : (isDark ? const Color(0xFF1E232D) : Colors.white),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF2563EB)
                                : (isDark ? const Color(0xFF2C3340) : const Color(0xFFE2E8F0)),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              _dayNames[idx],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isSelected
                                    ? Colors.white
                                    : (isDark ? Colors.grey[300] : Colors.grey[800]),
                              ),
                            ),
                            if (isCurrentRealDay) ...[
                              const SizedBox(height: 3),
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected ? Colors.white : const Color(0xFF2563EB),
                                ),
                              ),
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

          // Предупреждение об офлайн-режиме работы
          if (_isOffline)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.14),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.wifi_off_rounded, size: 18, color: Color(0xFFD97706)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Офлайн-режим: отображается сохраненное расписание. Для обновления подключитесь к сети.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFD97706),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _fetchFreshSchedule,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Повторить', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

          // Плашка статуса для сегодняшнего дня или выходных
          if (isToday)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2563EB),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _calculateLiveStatus(dayMap, paraTimes),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (isSunday && _selectedDay == 1)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.weekend_rounded, size: 18, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Сегодня воскресенье (выходной) • Показан понедельник (${_selectedWeek == 2 ? 'II' : 'I'} нед)',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (isSaturday && _selectedDay == 6 && sortedKeys.isEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_available_rounded, size: 18, color: Color(0xFFD97706)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Сегодня суббота • По расписанию пар нет (выходной день)',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFD97706),
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
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.event_busy_rounded, size: 54, color: Colors.grey[400]),
                                    const SizedBox(height: 12),
                                    Text(
                                      _selectedDay == 6
                                          ? 'В субботу занятий нет (выходной)'
                                          : 'В этот день занятий нет',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    if (_selectedDay == 6) ...[
                                      const SizedBox(height: 12),
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          setState(() {
                                            _selectedDay = 1;
                                            _selectedWeek = (_selectedWeek == 1) ? 2 : 1;
                                            _userSelectedManually = true;
                                          });
                                        },
                                        icon: const Icon(Icons.calendar_today_rounded, size: 16),
                                        label: const Text('Открыть понедельник'),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchFreshSchedule,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(top: 6, bottom: 16),
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

          // Переключатель подгруппы внизу с учетом безопасного отступа iOS и Android
          Container(
            color: isDark ? const Color(0xFF1E232D) : Colors.white,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: isDark ? const Color(0xFF2C3340) : const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    _buildSubgroupBtn(0, 'Все подгруппы'),
                    const SizedBox(width: 8),
                    _buildSubgroupBtn(1, '1 п/г'),
                    const SizedBox(width: 8),
                    _buildSubgroupBtn(2, '2 п/г'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekBtn(int week, String label) {
    final isActive = _selectedWeek == week;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedWeek = week;
        _userSelectedManually = true;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF2563EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey[600],
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildSubgroupBtn(int sg, String title) {
    final isSelected = _profile.subgroup == sg;
    return Expanded(
      child: InkWell(
        onTap: () => _setSubgroup(sg),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFF2563EB) : Colors.grey.withOpacity(0.3),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.grey[300] : Colors.grey[700]),
            ),
          ),
        ),
      ),
    );
  }
}
