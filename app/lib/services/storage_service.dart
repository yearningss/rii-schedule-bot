// Сервис локального хранения настроек и офлайн-кэша
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class StorageService {
  static const String _keyAuthToken = 'auth_token';
  static const String _keyUserId = 'user_id';
  static const String _keyGroupId = 'group_id';
  static const String _keyGroupName = 'group_name';
  static const String _keySubgroup = 'subgroup';
  static const String _keyFirstName = 'first_name';
  static const String _keyLastName = 'last_name';
  static const String _keyUsername = 'username';
  static const String _keyAvatarUrl = 'avatar_url';
  static const String _keyCustomAvatar = 'custom_avatar';
  static const String _keyThemeMode = 'theme_mode';
  static const String _keySeasonIcon = 'season_icon_preference';
  static const String _keyScheduleCache = 'schedule_cache_';
  static const String _keyGroupsCache = 'groups_cache';
  static const String _keyDeviceId = 'device_id';

  final SharedPreferences prefs;
  late final ValueNotifier<ThemeMode> themeModeNotifier;

  StorageService(this.prefs) {
    themeModeNotifier = ValueNotifier<ThemeMode>(getThemeMode());
  }

  static Future<StorageService> init() async {
    final sp = await SharedPreferences.getInstance();
    return StorageService(sp);
  }

  // Получение или создание постоянного уникального идентификатора устройства
  String getDeviceId() {
    String? id = prefs.getString(_keyDeviceId);
    if (id == null || id.isEmpty) {
      final ts = DateTime.now().microsecondsSinceEpoch.toString();
      final salt = (100000 + (DateTime.now().millisecond * 899)).toString();
      id = 'dev_${ts}_$salt';
      prefs.setString(_keyDeviceId, id);
    }
    return id;
  }

  ThemeMode getThemeMode() {
    final val = prefs.getString(_keyThemeMode);
    if (val == 'dark') return ThemeMode.dark;
    if (val == 'light') return ThemeMode.light;
    return ThemeMode.system;
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    String val = 'system';
    if (mode == ThemeMode.dark) val = 'dark';
    if (mode == ThemeMode.light) val = 'light';
    await prefs.setString(_keyThemeMode, val);
    themeModeNotifier.value = mode;
  }

  String getSeasonIconPreference() {
    return prefs.getString(_keySeasonIcon) ?? 'auto';
  }

  Future<void> saveSeasonIconPreference(String id) async {
    await prefs.setString(_keySeasonIcon, id);
  }

  UserProfile getUserProfile() {
    final token = prefs.getString(_keyAuthToken);
    final userId = prefs.getInt(_keyUserId);
    final groupId = prefs.getInt(_keyGroupId);
    final groupName = prefs.getString(_keyGroupName);
    final subgroup = prefs.getInt(_keySubgroup) ?? 0;
    final firstName = prefs.getString(_keyFirstName);
    final lastName = prefs.getString(_keyLastName);
    final username = prefs.getString(_keyUsername);
    final avatarUrl = prefs.getString(_keyAvatarUrl);
    final customAvatar = prefs.getString(_keyCustomAvatar);

    return UserProfile(
      authToken: token,
      userId: userId,
      groupId: groupId,
      groupName: groupName,
      subgroup: subgroup,
      firstName: firstName,
      lastName: lastName,
      username: username,
      avatarUrl: avatarUrl,
      customAvatar: customAvatar,
    );
  }

  Future<void> saveUserProfile(UserProfile profile) async {
    if (profile.authToken != null) {
      await prefs.setString(_keyAuthToken, profile.authToken!);
    }
    if (profile.userId != null) {
      await prefs.setInt(_keyUserId, profile.userId!);
    }
    if (profile.groupId != null) {
      await prefs.setInt(_keyGroupId, profile.groupId!);
    }
    if (profile.groupName != null) {
      await prefs.setString(_keyGroupName, profile.groupName!);
    }
    if (profile.firstName != null) {
      await prefs.setString(_keyFirstName, profile.firstName!);
    }
    if (profile.lastName != null) {
      await prefs.setString(_keyLastName, profile.lastName!);
    }
    if (profile.username != null) {
      await prefs.setString(_keyUsername, profile.username!);
    }
    if (profile.avatarUrl != null) {
      await prefs.setString(_keyAvatarUrl, profile.avatarUrl!);
    }
    if (profile.customAvatar != null) {
      await prefs.setString(_keyCustomAvatar, profile.customAvatar!);
    }
    await prefs.setInt(_keySubgroup, profile.subgroup);
  }

  Future<void> saveCustomAvatar(String avatar) async {
    await prefs.setString(_keyCustomAvatar, avatar);
  }

  Future<void> saveSubgroup(int subgroup) async {
    await prefs.setInt(_keySubgroup, subgroup);
  }

  // Получение параметров уведомлений из локальной памяти
  NotificationSettings getNotificationSettings() {
    return NotificationSettings(
      enabled: prefs.getBool('notifications_enabled') ?? true,
      beforeMins: prefs.getInt('notify_before_mins') ?? 10,
      lessonStart: prefs.getBool('notify_lesson_start') ?? true,
      breaks: prefs.getBool('notify_breaks') ?? true,
      changes: prefs.getBool('notify_changes') ?? true,
      bgUpdateCheck: prefs.getBool('notify_bg_update_check') ?? true,
    );
  }

  // Сохранение параметров уведомлений в локальную память
  Future<void> saveNotificationSettings(NotificationSettings settings) async {
    await prefs.setBool('notifications_enabled', settings.enabled);
    await prefs.setInt('notify_before_mins', settings.beforeMins);
    await prefs.setBool('notify_lesson_start', settings.lessonStart);
    await prefs.setBool('notify_breaks', settings.breaks);
    await prefs.setBool('notify_changes', settings.changes);
    await prefs.setBool('notify_bg_update_check', settings.bgUpdateCheck);
  }

  // Кэширование истории изменений для постоянного офлайн-доступа
  List<Map<String, dynamic>>? getChangelogCache() {
    final raw = prefs.getString('changelog_cache_json');
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return List<Map<String, dynamic>>.from(
          decoded.map((e) => Map<String, dynamic>.from(e as Map)),
        );
      }
    } catch (_) {}
    return null;
  }

  Future<void> saveChangelogCache(List<Map<String, dynamic>> list) async {
    try {
      await prefs.setString('changelog_cache_json', jsonEncode(list));
    } catch (_) {}
  }

  Future<void> clearAuth() async {
    await prefs.remove(_keyAuthToken);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyFirstName);
    await prefs.remove(_keyLastName);
    await prefs.remove(_keyUsername);
    await prefs.remove(_keyAvatarUrl);
    await prefs.remove(_keyCustomAvatar);
  }

  // Офлайн-кэширование расписания
  Future<void> saveScheduleCache(int groupId, Map<String, dynamic> data) async {
    await prefs.setString('$_keyScheduleCache$groupId', jsonEncode(data));
  }

  Map<String, dynamic>? getScheduleCache(int groupId) {
    final str = prefs.getString('$_keyScheduleCache$groupId');
    if (str == null) return null;
    try {
      return jsonDecode(str) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // Офлайн-кэширование списка групп
  Future<void> saveGroupsCache(List<GroupItem> groups) async {
    final list = groups.map((g) => g.toJson()).toList();
    await prefs.setString(_keyGroupsCache, jsonEncode(list));
  }

  List<GroupItem>? getGroupsCache() {
    final str = prefs.getString(_keyGroupsCache);
    if (str == null) return null;
    try {
      final list = jsonDecode(str) as List<dynamic>;
      return list.map((item) => GroupItem.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return null;
    }
  }
}
