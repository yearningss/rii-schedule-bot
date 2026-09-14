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
import '../theme/theme.dart';

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
    final colorScheme = theme.colorScheme;
    final rTime = DateTime.now().toUtc().add(const Duration(hours: 7));
    final effectiveTheme = SeasonIconService.getEffectiveTheme(widget.storage.getSeasonIconPreference(), rTime);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Логотип приложения
              ClipRRect(
                borderRadius: AppShape.roundedXl,
                child: Image.asset(
                  effectiveTheme.assetPath,
                  width: 110,
                  height: 110,
                  fit: BoxFit.cover,
                ),
              ),
              AppSpacing.gapH24,

              Text(
                'РИИ Расписание',
                style: AppTypography.headlineMedium.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
              AppSpacing.gapH4,
              Text(
                'Рубцовский индустриальный институт',
                style: AppTypography.bodyMedium.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),

              const Spacer(),

              // Состояние ожидания подтверждения в Telegram
              if (_isWaitingConfirmation) ...[
                const CircularProgressIndicator(),
                AppSpacing.gapH16,
                Text(
                  'Ожидание подтверждения в Telegram...',
                  style: AppTypography.titleMedium.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
                AppSpacing.gapH8,
                Text(
                  'Нажмите «Подтвердить вход» в диалоге с ботом @rubinst_bot',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                AppSpacing.gapH20,
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
                  child: FilledButton.icon(
                    onPressed: _startTelegramAuth,
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('Войти через Telegram'),
                  ),
                ),
                AppSpacing.gapH12,

                // Кнопка продолжить без авторизации
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: _selectGroupManually,
                    child: const Text('Выбрать группу без привязки'),
                  ),
                ),
              ],

              AppSpacing.gapH24,
            ],
          ),
        ),
      ),
    );
  }
}
