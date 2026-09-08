// Сервис взаимодействия с REST API бэкенда РИИ
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class ApiService {
  static const String baseUrl = 'https://rii-bot.yearnings.ru';

  // Загрузка списка всех групп института
  Future<List<GroupItem>> getGroups() async {
    final res = await http.get(Uri.parse('$baseUrl/api/groups'));
    if (res.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));
      return data.map((json) => GroupItem.fromJson(json)).toList();
    }
    throw Exception('Не удалось загрузить список групп (код ${res.statusCode})');
  }

  // Загрузка расписания конкретной группы
  Future<Map<String, dynamic>> getSchedule(int groupId) async {
    final res = await http.get(Uri.parse('$baseUrl/api/schedule?group_id=$groupId'));
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    }
    throw Exception('Не удалось загрузить расписание (код ${res.statusCode})');
  }

  // Инициализация сессии авторизации через Telegram
  Future<Map<String, dynamic>> createAuthSession() async {
    final res = await http.post(Uri.parse('$baseUrl/api/app/auth/session'));
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    }
    throw Exception('Ошибка создания сессии авторизации');
  }

  // Проверка статуса авторизации сессии (poll)
  Future<Map<String, dynamic>> checkAuthSession(String sessionToken) async {
    final res = await http.get(Uri.parse('$baseUrl/api/app/auth/check?session_token=$sessionToken'));
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    }
    throw Exception('Ошибка проверки статуса авторизации');
  }

  // Получение актуального профиля с сервера
  Future<Map<String, dynamic>?> getProfile(String authToken) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/app/profile'),
        headers: {
          'Authorization': 'Bearer $authToken',
        },
      );
      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  // Двусторонняя синхронизация профиля и параметров уведомлений пользователя
  Future<Map<String, dynamic>?> syncProfile({
    required String authToken,
    int? groupId,
    String? groupName,
    int? subgroup,
    String? avatarUrl,
    String? avatarBase64,
    bool? notificationsEnabled,
    int? notifyBeforeMins,
    bool? notifyLessonStart,
    bool? notifyBreaks,
    bool? notifyChanges,
  }) async {
    final body = <String, dynamic>{};
    if (groupId != null) body['group_id'] = groupId;
    if (groupName != null) body['group_name'] = groupName;
    if (subgroup != null) body['subgroup'] = subgroup;
    if (avatarUrl != null) body['avatar_url'] = avatarUrl;
    if (avatarBase64 != null) body['avatar_base64'] = avatarBase64;
    if (notificationsEnabled != null) body['notifications_enabled'] = notificationsEnabled ? 1 : 0;
    if (notifyBeforeMins != null) body['notify_before_mins'] = notifyBeforeMins;
    if (notifyLessonStart != null) body['notify_lesson_start'] = notifyLessonStart ? 1 : 0;
    if (notifyBreaks != null) body['notify_breaks'] = notifyBreaks ? 1 : 0;
    if (notifyChanges != null) body['notify_changes'] = notifyChanges ? 1 : 0;

    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/app/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode(body),
      );

      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  // Регистрация и синхронизация пользователя приложения в БД без необходимости входа в Telegram
  Future<Map<String, dynamic>?> syncDeviceUser({
    required String deviceId,
    String? platform,
    int? groupId,
    String? groupName,
    int? subgroup,
    bool? notificationsEnabled,
    int? notifyBeforeMins,
    bool? notifyLessonStart,
    bool? notifyBreaks,
    bool? notifyChanges,
    String? appVersion,
    String? authToken,
  }) async {
    final body = <String, dynamic>{
      'device_id': deviceId,
      'platform': platform ?? (defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android'),
    };
    if (groupId != null) body['group_id'] = groupId;
    if (groupName != null) body['group_name'] = groupName;
    if (subgroup != null) body['subgroup'] = subgroup;
    if (notificationsEnabled != null) body['notifications_enabled'] = notificationsEnabled ? 1 : 0;
    if (notifyBeforeMins != null) body['notify_before_mins'] = notifyBeforeMins;
    if (notifyLessonStart != null) body['notify_lesson_start'] = notifyLessonStart ? 1 : 0;
    if (notifyBreaks != null) body['notify_breaks'] = notifyBreaks ? 1 : 0;
    if (notifyChanges != null) body['notify_changes'] = notifyChanges ? 1 : 0;
    if (appVersion != null) body['app_version'] = appVersion;
    if (authToken != null && authToken.isNotEmpty) body['auth_token'] = authToken;

    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/app/device/sync'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  // Проверка доступности сервера и подключения к сети
  Future<bool> checkConnection() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/groups')).timeout(
        const Duration(seconds: 4),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // Проверка доступности новой версии мобильного приложения
  Future<AppUpdateInfo?> checkAppUpdate({
    int currentBuild = 1,
    String currentVersion = '1.0.0',
  }) async {
    AppUpdateInfo? serverUpdate;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final platformParam = isIOS ? '?platform=ios' : '?platform=android';
    final targetAsset = isIOS ? 'RiiSchedule.ipa' : 'RiiSchedule.apk';

    try {
      final res = await http.get(Uri.parse('$baseUrl/api/app/version$platformParam')).timeout(
        const Duration(seconds: 5),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        serverUpdate = AppUpdateInfo.fromJson(
          data,
          currentBuild: currentBuild,
          currentVersion: currentVersion,
        );
        if (serverUpdate.hasUpdate) {
          return serverUpdate;
        }
      }
    } catch (_) {}

    // Резервная проверка напрямую через GitHub Releases
    try {
      final res = await http.get(
        Uri.parse('https://api.github.com/repos/yearningss/rii-schedule-bot/releases/latest'),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final tagName = (data['tag_name'] ?? '').toString().replaceAll('v', '').trim();
        final name = (data['name'] ?? '').toString();
        final match = RegExp(r'(?:сборка|\+)\s*(\d+)', caseSensitive: false).firstMatch(name);
        final buildNum = match != null ? int.tryParse(match.group(1)!) ?? 1 : 1;
        final notes = data['body']?.toString();
        var downloadUrl = 'https://github.com/yearningss/rii-schedule-bot/releases/latest';
        if (data['assets'] is List) {
          for (final asset in data['assets']) {
            if (asset is Map && asset['name'] == targetAsset) {
              downloadUrl = asset['browser_download_url'] ?? downloadUrl;
              break;
            }
          }
        }
        final hasNewer = (buildNum > currentBuild) || (AppUpdateInfo.compareVersions(tagName, currentVersion) > 0);
        return AppUpdateInfo(
          latestVersion: tagName.isNotEmpty ? tagName : '1.0.0',
          latestBuild: buildNum,
          downloadUrl: downloadUrl,
          releaseNotes: notes,
          hasUpdate: hasNewer,
        );
      }
    } catch (_) {}

    return serverUpdate;
  }

  // Загрузка реальной истории изменений из GitHub Releases
  Future<List<Map<String, dynamic>>> getChangelog() async {
    // 1. Попытка запроса через наш бэкенд
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/app/changelog')).timeout(
        const Duration(seconds: 4),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        if (data is List && data.isNotEmpty) {
          return List<Map<String, dynamic>>.from(
            data.map((e) => Map<String, dynamic>.from(e as Map)),
          );
        }
      }
    } catch (_) {}

    // 2. Резервный запрос напрямую к GitHub Releases API
    try {
      final res = await http.get(
        Uri.parse('https://api.github.com/repos/yearningss/rii-schedule-bot/releases'),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        if (data is List) {
          final list = <Map<String, dynamic>>[];
          for (final item in data) {
            if (item is! Map) continue;
            final assetsList = <Map<String, dynamic>>[];
            if (item['assets'] is List) {
              for (final a in item['assets']) {
                if (a is Map) {
                  assetsList.add({
                    'name': a['name'],
                    'size': a['size'] ?? 0,
                    'download_url': a['browser_download_url'],
                  });
                }
              }
            }
            list.add({
              'tag_name': (item['tag_name'] ?? '').toString().replaceAll('v', '').trim(),
              'name': item['name'] ?? '',
              'published_at': item['published_at'] ?? '',
              'body': item['body'] ?? '',
              'html_url': item['html_url'] ?? '',
              'assets': assetsList,
            });
          }
          if (list.isNotEmpty) return list;
        }
      }
    } catch (_) {}

    return [];
  }
}
