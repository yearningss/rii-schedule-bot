// Сервис синхронизации данных виджета рабочего стола Android/iOS
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class WidgetService {
  static const MethodChannel _channel = MethodChannel('com.yearnings.rii/widget');
  static const String _keyWidgetScheduleJson = 'widget_schedule_json';

  // Обновление данных виджета в SharedPreferences и вызов нативного обновления
  static Future<void> updateWidgetData({
    required UserProfile profile,
    Map<String, dynamic>? scheduleJson,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (profile.groupName != null) {
        await prefs.setString('group_name', profile.groupName!);
      }
      if (profile.groupId != null) {
        await prefs.setInt('group_id', profile.groupId!);
      }
      await prefs.setInt('subgroup', profile.subgroup);

      final jsonStr = scheduleJson != null ? jsonEncode(scheduleJson) : '';
      if (jsonStr.isNotEmpty) {
        await prefs.setString(_keyWidgetScheduleJson, jsonStr);
      }

      // Вызов нативного метода обновления виджета (Android и iOS)
      await _channel.invokeMethod('updateWidget', {
        'group_name': profile.groupName ?? 'РИИ',
        'group_id': profile.groupId ?? 0,
        'subgroup': profile.subgroup,
        'widget_schedule_json': jsonStr.isNotEmpty ? jsonStr : (prefs.getString(_keyWidgetScheduleJson) ?? ''),
      });
    } catch (_) {}
  }
}
