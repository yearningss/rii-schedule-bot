// Сервис управления уведомлениями, проверки разрешений и открытия настроек
import 'package:flutter/services.dart';

class NotificationService {
  static const MethodChannel _channel = MethodChannel('com.yearnings.rii/notifications');

  // Проверка статуса разрешения уведомлений
  static Future<bool> checkPermission() async {
    try {
      final res = await _channel.invokeMethod<bool>('checkPermission');
      return res ?? true;
    } catch (_) {
      return true;
    }
  }

  // Запрос системного диалога разрешения отправки уведомлений
  static Future<bool> requestPermission() async {
    try {
      final res = await _channel.invokeMethod<bool>('requestPermission');
      return res ?? true;
    } catch (_) {
      return true;
    }
  }

  // Открытие системных настроек уведомлений приложения
  static Future<bool> openNotificationSettings() async {
    try {
      final res = await _channel.invokeMethod<bool>('openNotificationSettings');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  // Отправка системного всплывающего уведомления
  static Future<void> showNotification({
    required String title,
    required String message,
  }) async {
    try {
      await _channel.invokeMethod('showNotification', {
        'title': title,
        'message': message,
      });
    } catch (_) {}
  }

  // Точное системное планирование уведомления без задержек через AlarmManager / UNUserNotificationCenter
  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String message,
    required DateTime scheduledDate,
  }) async {
    try {
      await _channel.invokeMethod('scheduleNotification', {
        'id': id,
        'title': title,
        'message': message,
        'epochMillis': scheduledDate.millisecondsSinceEpoch,
      });
    } catch (_) {}
  }
}
