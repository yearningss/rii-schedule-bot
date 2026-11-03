// Сервис авторизации через Яндекс ID
import 'dart:io';
import 'package:flutter/services.dart';
import '../models/models.dart';
import 'api_service.dart';
import 'storage_service.dart';

class YandexAuthService {
  static const MethodChannel _channel =
      MethodChannel('com.yearnings.rii/yandex_auth');
  static const String clientId = '4cae7d5a54a142c2906bf93a43203467';

  // Проверка доступности нативного входа через Яндекс
  static bool get isSupported => Platform.isAndroid;

  // Запуск процесса входа через Яндекс ID
  static Future<UserProfile?> signIn({
    required StorageService storage,
    required ApiService api,
  }) async {
    if (!Platform.isAndroid) return null;

    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('login');
      if (res == null) return null;

      final status = res['status'] as String?;
      if (status != 'success') return null;

      final token = res['token'] as String?;
      if (token == null || token.isEmpty) return null;

      final verified = await api.authWithYandex(token: token);
      final authToken = verified['auth_token'] as String?;
      final user = verified['user'] as Map<String, dynamic>?;
      if (authToken == null || authToken.isEmpty || user == null) return null;
      final profile = UserProfile(
        authToken: authToken,
        userId: user['user_id'] as int,
        firstName: user['first_name'] as String?,
        lastName: user['last_name'] as String?,
        username: user['username'] as String?,
        avatarUrl: user['avatar_url'] as String?,
        groupId: user['group_id'] as int?,
        groupName: user['group_name'] as String?,
        subgroup: user['subgroup'] as int? ?? 0,
      );

      await storage.saveUserProfile(profile);
      return profile;
    } catch (_) {
      return null;
    }
  }
}
