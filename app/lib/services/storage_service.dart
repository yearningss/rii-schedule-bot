// Сервис локального хранения настроек и офлайн-кэша
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class StorageService {
  static const String _keyAuthToken = 'auth_token';
  static const String _keyUserId = 'user_id';
  static const String _keyGroupId = 'group_id';
  static const String _keyGroupName = 'group_name';
  static const String _keySubgroup = 'subgroup';
  static const String _keyScheduleCache = 'schedule_cache_';
  static const String _keyGroupsCache = 'groups_cache';

  final SharedPreferences prefs;

  StorageService(this.prefs);

  static Future<StorageService> init() async {
    final sp = await SharedPreferences.getInstance();
    return StorageService(sp);
  }

  UserProfile getUserProfile() {
    final token = prefs.getString(_keyAuthToken);
    final userId = prefs.getInt(_keyUserId);
    final groupId = prefs.getInt(_keyGroupId);
    final groupName = prefs.getString(_keyGroupName);
    final subgroup = prefs.getInt(_keySubgroup) ?? 0;

    return UserProfile(
      authToken: token,
      userId: userId,
      groupId: groupId,
      groupName: groupName,
      subgroup: subgroup,
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
    await prefs.setInt(_keySubgroup, profile.subgroup);
  }

  Future<void> saveSubgroup(int subgroup) async {
    await prefs.setInt(_keySubgroup, subgroup);
  }

  Future<void> clearAuth() async {
    await prefs.remove(_keyAuthToken);
    await prefs.remove(_keyUserId);
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
