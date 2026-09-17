// Сервис авторизации через Яндекс ID
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import 'api_service.dart';
import 'storage_service.dart';

class YandexAuthService {
  static const MethodChannel _channel = MethodChannel('com.yearnings.rii/yandex_auth');
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

      // 1. Запрашиваем информацию о пользователе напрямую у Яндекс API
      final yandexUser = await _fetchYandexUserInfo(token);
      if (yandexUser == null) return null;

      final yandexId = yandexUser['id']?.toString() ?? '';
      final firstName = yandexUser['first_name']?.toString() ?? '';
      final lastName = yandexUser['last_name']?.toString() ?? '';
      final displayName = yandexUser['display_name']?.toString() ?? '$firstName $lastName'.trim();
      final email = yandexUser['default_email']?.toString() ?? '';
      final avatarId = yandexUser['default_avatar_id']?.toString();

      String avatarUrl = '';
      if (avatarId != null && avatarId.isNotEmpty && avatarId != '0/0-0') {
        avatarUrl = 'https://avatars.yandex.net/get-yapic/$avatarId/islands-200';
      }

      // 2. Регистрируем / подтверждаем пользователя на нашем бэкенде
      String? backendAuthToken;
      try {
        final authRes = await api.authWithYandex(
          token: token,
          yandexId: yandexId,
          firstName: firstName,
          lastName: lastName,
          displayName: displayName,
          email: email,
          avatarUrl: avatarUrl,
        );
        backendAuthToken = authRes['auth_token'] as String?;
      } catch (_) {}

      final profile = UserProfile(
        authToken: backendAuthToken ?? 'yandex_$token',
        userId: int.tryParse(yandexId) ?? (yandexId.hashCode.abs()),
        firstName: firstName.isNotEmpty ? firstName : displayName,
        lastName: lastName,
        username: email.isNotEmpty ? email : displayName,
        avatarUrl: avatarUrl,
      );

      await storage.saveUserProfile(profile);
      return profile;
    } catch (_) {
      return null;
    }
  }

  // Запрос публичных данных пользователя из сервиса Яндекс Паспорт
  static Future<Map<String, dynamic>?> _fetchYandexUserInfo(String oauthToken) async {
    try {
      final uri = Uri.parse('https://login.yandex.ru/info?format=json');
      final res = await http.get(
        uri,
        headers: {
          'Authorization': 'OAuth $oauthToken',
        },
      ).timeout(const Duration(seconds: 7));

      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }
}
