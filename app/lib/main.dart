// Главная точка входа Flutter приложения
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/api_service.dart';
import 'services/storage_service.dart';
import 'services/season_icon_service.dart';
import 'screens/auth_screen.dart';
import 'screens/schedule_screen.dart';
import 'theme/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Настройка прозрачного статус-бара
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  final storage = await StorageService.init();
  final api = ApiService();

  // Применить сезонную иконку на рабочем столе (автоматически по дате или по настройке)
  final rTime = DateTime.now().toUtc().add(const Duration(hours: 7));
  final theme = SeasonIconService.getEffectiveTheme(storage.getSeasonIconPreference(), rTime);
  await SeasonIconService.applyLauncherIcon(theme);

  runApp(RiiScheduleApp(storage: storage, api: api));
}

class RiiScheduleApp extends StatelessWidget {
  final StorageService storage;
  final ApiService api;

  const RiiScheduleApp({
    super.key,
    required this.storage,
    required this.api,
  });

  @override
  Widget build(BuildContext context) {
    final userProfile = storage.getUserProfile();
    final hasGroup = userProfile.groupId != null;

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: storage.themeModeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'РИИ Расписание',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          home: hasGroup
              ? ScheduleScreen(storage: storage, api: api)
              : AuthScreen(storage: storage, api: api),
        );
      },
    );
  }
}
