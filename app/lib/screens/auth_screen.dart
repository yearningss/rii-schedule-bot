// Экран авторизации через Telegram и выбора группы
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import 'group_picker_screen.dart';
import 'schedule_screen.dart';
import '../services/season_icon_service.dart';
import '../services/yandex_auth_service.dart';

class AuthScreen extends StatefulWidget {
  final StorageService storage;
  final ApiService api;

  const AuthScreen({
    super.key,
    required this.storage,
    required this.api,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isWaitingConfirmation = false;
  bool _isYandexLoading = false;
  Timer? _pollTimer;
  String? _sessionToken;

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _startTelegramAuth() async {
    setState(() => _isWaitingConfirmation = true);

    try {
      final sessionData = await widget.api.createAuthSession();
      _sessionToken = sessionData['session_token'] as String;
      final deepLink = sessionData['deep_link'] as String;
      final authUrl = sessionData['auth_url'] as String;

      // Открываем Telegram приложение напрямую (или браузер при отсутствии приложения)
      final uri = Uri.parse(deepLink);
      try {
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!launched) {
          await launchUrl(Uri.parse(authUrl), mode: LaunchMode.externalApplication);
        }
      } catch (_) {
        try {
          await launchUrl(Uri.parse(authUrl), mode: LaunchMode.externalApplication);
        } catch (_) {}
      }

      // Запускаем фоновый опрос сервера на подтверждение
      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
        if (!mounted || _sessionToken == null) {
          timer.cancel();
          return;
        }
        try {
          final res = await widget.api.checkAuthSession(_sessionToken!);
          final status = res['status'] as String?;

          if (status == 'confirmed') {
            timer.cancel();
            final authToken = res['auth_token'] as String?;
            final userMap = res['user'] as Map<String, dynamic>?;

            final profile = UserProfile(
              authToken: authToken,
              userId: userMap?['user_id'],
              groupId: userMap?['group_id'],
              groupName: userMap?['group_name'],
              subgroup: userMap?['subgroup'] ?? 0,
              firstName: userMap?['first_name'],
              lastName: userMap?['last_name'],
              username: userMap?['username'],
              avatarUrl: userMap?['avatar_url'],
            );

            await widget.storage.saveUserProfile(profile);

            try {
              final deviceId = widget.storage.getDeviceId();
              final clientUserId = widget.storage.getClientUserId();
              final notif = widget.storage.getNotificationSettings();
              await widget.api.syncDeviceUser(
                deviceId: deviceId,
                clientUserId: clientUserId,
                authToken: authToken,
                groupId: profile.groupId,
                groupName: profile.groupName,
                subgroup: profile.subgroup,
                notificationsEnabled: notif.enabled,
                notifyBeforeMins: notif.beforeMins,
                notifyLessonStart: notif.lessonStart,
                notifyBreaks: notif.breaks,
                notifyChanges: notif.changes,
                appVersion: AppInfo.versionName,
              );
            } catch (_) {}

            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => ScheduleScreen(storage: widget.storage, api: widget.api),
                ),
              );
            }
          } else if (status == 'expired') {
            timer.cancel();
            if (mounted) {
              setState(() => _isWaitingConfirmation = false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Время ожидания входа истекло. Попробуйте снова.')),
              );
            }
          }
        } catch (_) {}
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isWaitingConfirmation = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка подключения к серверу. Попробуйте позже.')),
        );
      }
    }
  }

  Future<void> _startYandexAuth() async {
    setState(() => _isYandexLoading = true);
    try {
      final profile = await YandexAuthService.signIn(
        storage: widget.storage,
        api: widget.api,
      );

      if (profile != null && mounted) {
        if (profile.groupId == null) {
          final selected = await Navigator.push<GroupItem>(
            context,
            MaterialPageRoute(
              builder: (_) => GroupPickerScreen(storage: widget.storage, api: widget.api),
            ),
          );
          if (selected != null && mounted) {
            final updated = profile.copyWith(
              groupId: selected.id,
              groupName: selected.name,
            );
            await widget.storage.saveUserProfile(updated);
          }
        }

        try {
          final currentProfile = widget.storage.getUserProfile();
          final deviceId = widget.storage.getDeviceId();
          final clientUserId = widget.storage.getClientUserId();
          final notif = widget.storage.getNotificationSettings();
          await widget.api.syncDeviceUser(
            deviceId: deviceId,
            clientUserId: clientUserId,
            authToken: currentProfile.authToken,
            groupId: currentProfile.groupId,
            groupName: currentProfile.groupName,
            subgroup: currentProfile.subgroup,
            notificationsEnabled: notif.enabled,
            notifyBeforeMins: notif.beforeMins,
            notifyLessonStart: notif.lessonStart,
            notifyBreaks: notif.breaks,
            notifyChanges: notif.changes,
            appVersion: AppInfo.versionName,
          );
        } catch (_) {}

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ScheduleScreen(storage: widget.storage, api: widget.api),
            ),
          );
        }
      } else if (mounted) {
        setState(() => _isYandexLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isYandexLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось войти через Яндекс ID. Попробуйте снова.')),
        );
      }
    }
  }

  Future<void> _selectGroupManually() async {
    final selected = await Navigator.push<GroupItem>(
      context,
      MaterialPageRoute(
        builder: (_) => GroupPickerScreen(storage: widget.storage, api: widget.api),
      ),
    );

    if (selected != null && mounted) {
      final profile = widget.storage.getUserProfile().copyWith(
            groupId: selected.id,
            groupName: selected.name,
          );
      await widget.storage.saveUserProfile(profile);

      try {
        final deviceId = widget.storage.getDeviceId();
        final clientUserId = widget.storage.getClientUserId();
        final notif = widget.storage.getNotificationSettings();
        await widget.api.syncDeviceUser(
          deviceId: deviceId,
          clientUserId: clientUserId,
          groupId: selected.id,
          groupName: selected.name,
          subgroup: profile.subgroup,
          notificationsEnabled: notif.enabled,
          notifyBeforeMins: notif.beforeMins,
          notifyLessonStart: notif.lessonStart,
          notifyBreaks: notif.breaks,
          notifyChanges: notif.changes,
          appVersion: AppInfo.versionName,
        );
      } catch (_) {}

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ScheduleScreen(storage: widget.storage, api: widget.api),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final rTime = DateTime.now().toUtc().add(const Duration(hours: 7));
    final effectiveTheme = SeasonIconService.getEffectiveTheme(widget.storage.getSeasonIconPreference(), rTime);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Логотип приложения
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Image.asset(
                  effectiveTheme.assetPath,
                  width: 110,
                  height: 110,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'РИИ Расписание',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Рубцовский индустриальный институт',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),

              const Spacer(),

              // Состояние ожидания подтверждения в Telegram
              if (_isWaitingConfirmation) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text(
                  'Ожидание подтверждения в Telegram...',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  'Нажмите «Подтвердить вход» в диалоге с ботом @rubinst_bot',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () {
                    _pollTimer?.cancel();
                    setState(() => _isWaitingConfirmation = false);
                  },
                  child: const Text('Отмена'),
                ),
              ] else ...[
                // Кнопка входа через Telegram в 1 клик
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _startTelegramAuth,
                    icon: const Icon(Icons.send_rounded, color: Colors.white),
                    label: const Text(
                      'Войти через Telegram',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Кнопка входа через Яндекс ID
                if (YandexAuthService.isSupported) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isYandexLoading ? null : _startYandexAuth,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF262626) : Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _isYandexLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFC3F1D),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: const Text(
                                    'Я',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      height: 1.1,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'Войти с Яндекс ID',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Кнопка продолжить без авторизации
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: TextButton(
                    onPressed: _selectGroupManually,
                    child: Text(
                      'Выбрать группу без привязки',
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
