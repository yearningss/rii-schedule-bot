// Сервис управления уведомлениями и проверки разрешений (Android 13+)
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
}
