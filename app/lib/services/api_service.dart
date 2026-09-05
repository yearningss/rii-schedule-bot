// Сервис взаимодействия с REST API бэкенда РИИ
import 'dart:convert';
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

  // Двусторонняя синхронизация профиля пользователя
  Future<Map<String, dynamic>?> syncProfile({
    required String authToken,
    int? groupId,
    String? groupName,
    int? subgroup,
  }) async {
    final body = <String, dynamic>{};
    if (groupId != null) body['group_id'] = groupId;
    if (groupName != null) body['group_name'] = groupName;
    if (subgroup != null) body['subgroup'] = subgroup;

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
    return null;
  }
}
