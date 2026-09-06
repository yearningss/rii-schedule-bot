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
}
