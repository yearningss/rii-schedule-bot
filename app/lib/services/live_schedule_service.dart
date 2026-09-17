// Сервис управления закрепленным Live-расписанием на экране блокировки и в шторке
// Поддерживает Android Ongoing Notification с системным хронометром и iOS Live Activities
import 'dart:io';
import 'package:flutter/services.dart';
import '../models/models.dart';
import 'storage_service.dart';

class LiveScheduleService {
  static const MethodChannel _notifChannel = MethodChannel('com.yearnings.rii/notifications');
  static const MethodChannel _liveChannel = MethodChannel('com.yearnings.rii/live_activity');

  static const String _prefKeyLiveEnabled = 'live_schedule_lockscreen_enabled';

  // Проверка, включено ли живое расписание пользователем в настройках
  static bool isLiveEnabled(StorageService storage) {
    return storage.prefs.getBool(_prefKeyLiveEnabled) ?? true;
  }

  // Сохранение настройки
  static Future<void> setLiveEnabled(StorageService storage, bool enabled) async {
    await storage.prefs.setBool(_prefKeyLiveEnabled, enabled);
    if (!enabled) {
      await stopLive();
    }
  }

  // Расчет текущего состояния и отправка в нативные каналы системы
  static Future<void> syncSchedule({
    required StorageService storage,
    required Map<String, dynamic>? dayData,
    required Map<String, dynamic> paraTimesMap,
    required int userSubgroup,
    String groupName = 'РИИ',
  }) async {
    if (!isLiveEnabled(storage)) {
      await stopLive();
      return;
    }

    if (dayData == null || dayData.isEmpty) {
      await stopLive();
      return;
    }

    try {
      final nowUtc = DateTime.now().toUtc();
      final rubtsovskNow = nowUtc.add(const Duration(hours: 7));
      final curMins = rubtsovskNow.hour * 60 + rubtsovskNow.minute;

      final sortedParaNums = dayData.keys
          .map((k) => int.tryParse(k))
          .whereType<int>()
          .toList()
        ..sort();

      if (sortedParaNums.isEmpty) {
        await stopLive();
        return;
      }

      int? activeParaNum;
      ParaTime? activeParaTime;
      Map<String, dynamic>? activeParaData;

      int? nextParaNum;
      ParaTime? nextParaTime;
      Map<String, dynamic>? nextParaData;

      bool isBreak = false;
      int breakEndMins = 0;

      // 1. Проверяем, идет ли сейчас пара
      for (int i = 0; i < sortedParaNums.length; i++) {
        final pNum = sortedParaNums[i];
        final pData = dayData[pNum.toString()];
        if (pData is! Map) continue;

        final timeStr = paraTimesMap[pNum.toString()]?.toString();
        final pTime = ParaTime.parse(timeStr, pNum);

        if (curMins >= pTime.startMinutes && curMins < pTime.endMinutes) {
          activeParaNum = pNum;
          activeParaTime = pTime;
          activeParaData = Map<String, dynamic>.from(pData);

          if (i + 1 < sortedParaNums.length) {
            final nNum = sortedParaNums[i + 1];
            final nData = dayData[nNum.toString()];
            if (nData is Map) {
              nextParaNum = nNum;
              nextParaData = Map<String, dynamic>.from(nData);
              final nTimeStr = paraTimesMap[nNum.toString()]?.toString();
              nextParaTime = ParaTime.parse(nTimeStr, nNum);
            }
          }
          break;
        }
      }

      // 2. Если пара не идет, проверяем, идет ли перемена между парами
      if (activeParaNum == null) {
        for (int i = 0; i < sortedParaNums.length; i++) {
          final pNum = sortedParaNums[i];
          final timeStr = paraTimesMap[pNum.toString()]?.toString();
          final pTime = ParaTime.parse(timeStr, pNum);

          if (i == 0 && curMins < pTime.startMinutes && (pTime.startMinutes - curMins) <= 45) {
            // До начала первой пары осталось менее 45 минут
            isBreak = true;
            breakEndMins = pTime.startMinutes;
            nextParaNum = pNum;
            final nData = dayData[pNum.toString()];
            if (nData is Map) nextParaData = Map<String, dynamic>.from(nData);
            nextParaTime = pTime;
            break;
          }

          if (i + 1 < sortedParaNums.length) {
            final nNum = sortedParaNums[i + 1];
            final nTimeStr = paraTimesMap[nNum.toString()]?.toString();
            final nTime = ParaTime.parse(nTimeStr, nNum);

            if (curMins >= pTime.endMinutes && curMins < nTime.startMinutes) {
              // Идет перемена
              isBreak = true;
              breakEndMins = nTime.startMinutes;
              nextParaNum = nNum;
              final nData = dayData[nNum.toString()];
              if (nData is Map) nextParaData = Map<String, dynamic>.from(nData);
              nextParaTime = nTime;
              break;
            }
          }
        }
      }

      // 3. Формируем данные и передаем в ОС
      if (activeParaNum != null && activeParaTime != null && activeParaData != null) {
        // Идет пара
        final subj = _extractSubject(activeParaData, userSubgroup);
        final aud = _extractAud(activeParaData, userSubgroup);
        final teacher = _extractTeacher(activeParaData, userSubgroup);

        final targetEndUtc = DateTime.utc(
          rubtsovskNow.year,
          rubtsovskNow.month,
          rubtsovskNow.day,
          activeParaTime.endMinutes ~/ 60,
          activeParaTime.endMinutes % 60,
        ).subtract(const Duration(hours: 7));

        String nextInfo = '';
        if (nextParaNum != null && nextParaTime != null && nextParaData != null) {
          final nSubj = _extractSubject(nextParaData, userSubgroup);
          final nAud = _extractAud(nextParaData, userSubgroup);
          final audPart = nAud.isNotEmpty ? ' ($nAud)' : '';
          nextInfo = 'След: $nextParaNum пара в ${nextParaTime.startStr} $nSubj$audPart';
        }

        final title = '$activeParaNum пара: $subj';
        final message = [if (aud.isNotEmpty) aud, if (teacher.isNotEmpty) teacher].join(' | ');

        await _pushToNative(
          title: title,
          message: message.isNotEmpty ? message : 'Занятие идет',
          subject: subj,
          room: aud,
          teacher: teacher,
          epochEndMillis: targetEndUtc.millisecondsSinceEpoch,
          isBreak: false,
          nextParaText: nextInfo,
          groupName: groupName,
        );
      } else if (isBreak && nextParaNum != null && nextParaTime != null && nextParaData != null) {
        // Идет перемена
        final nSubj = _extractSubject(nextParaData, userSubgroup);
        final nAud = _extractAud(nextParaData, userSubgroup);

        final targetEndUtc = DateTime.utc(
          rubtsovskNow.year,
          rubtsovskNow.month,
          rubtsovskNow.day,
          breakEndMins ~/ 60,
          breakEndMins % 60,
        ).subtract(const Duration(hours: 7));

        final minsLeft = (breakEndMins - curMins).clamp(1, 120);
        final title = 'Перемена ($minsLeft мин)';
        final message = 'Следующая: $nextParaNum пара в ${nextParaTime.startStr}';
        final nextInfo = '$nSubj${nAud.isNotEmpty ? " (Ауд. $nAud)" : ""}';

        await _pushToNative(
          title: title,
          message: message,
          subject: nSubj,
          room: nAud.isNotEmpty ? 'Ауд. $nAud' : '',
          teacher: '',
          epochEndMillis: targetEndUtc.millisecondsSinceEpoch,
          isBreak: true,
          nextParaText: nextInfo,
          groupName: groupName,
        );
      } else {
        // Пар сейчас нет или учебный день завершен
        await stopLive();
      }
    } catch (_) {}
  }

  // Остановка закрепленного уведомления / Live Activity
  static Future<void> stopLive() async {
    try {
      if (Platform.isAndroid) {
        await _notifChannel.invokeMethod('stopLiveNotification');
      } else if (Platform.isIOS) {
        await _liveChannel.invokeMethod('stopLive');
      }
    } catch (_) {}
  }

  static Future<void> _pushToNative({
    required String title,
    required String message,
    required String subject,
    required String room,
    required String teacher,
    required int epochEndMillis,
    required bool isBreak,
    required String nextParaText,
    required String groupName,
  }) async {
    try {
      if (Platform.isAndroid) {
        await _notifChannel.invokeMethod('startOrUpdateLiveNotification', {
          'title': title,
          'message': message,
          'epochEndMillis': epochEndMillis,
          'isBreak': isBreak,
          'nextParaText': nextParaText,
        });
      } else if (Platform.isIOS) {
        await _liveChannel.invokeMethod('startOrUpdateLive', {
          'title': title,
          'subject': subject,
          'room': room,
          'teacher': teacher,
          'endTimeEpoch': epochEndMillis.toDouble(),
          'isBreak': isBreak,
          'nextPara': nextParaText,
          'groupName': groupName,
        });
      }
    } catch (_) {}
  }

  static String _extractSubject(Map<String, dynamic> pData, int userSubgroup) {
    if (pData['isDouble'] == true && userSubgroup == 2 && pData['subj2'] != null) {
      return pData['subj2'].toString();
    }
    return pData['subj1']?.toString() ?? 'Пара';
  }

  static String _extractAud(Map<String, dynamic> pData, int userSubgroup) {
    if (pData['isDouble'] == true && userSubgroup == 2 && pData['aud2'] != null) {
      final a = pData['aud2'].toString();
      return a.isNotEmpty ? 'Ауд. $a' : '';
    }
    final a = pData['aud1']?.toString() ?? '';
    return a.isNotEmpty ? 'Ауд. $a' : '';
  }

  static String _extractTeacher(Map<String, dynamic> pData, int userSubgroup) {
    if (pData['isDouble'] == true && userSubgroup == 2 && pData['teacher2'] != null) {
      return pData['teacher2'].toString();
    }
    return pData['teacher1']?.toString() ?? '';
  }
}
