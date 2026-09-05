// Экран авторизации через Telegram и выбора группы
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import 'group_picker_screen.dart';
import 'schedule_screen.dart';

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
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(Uri.parse(authUrl), mode: LaunchMode.externalApplication);
      }

      // Запускаем фоновый опрос сервера на подтверждение
      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
        if (_sessionToken == null) return;
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
                  'assets/logo_app.png',
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
