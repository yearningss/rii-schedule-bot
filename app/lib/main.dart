// Главная точка входа Flutter приложения
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/api_service.dart';
import 'services/storage_service.dart';
import 'screens/auth_screen.dart';
import 'screens/schedule_screen.dart';

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

    return MaterialApp(
      title: 'РИИ Расписание',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: const Color(0xFF2563EB),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF0F172A),
          elevation: 0,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF2563EB),
        scaffoldBackgroundColor: const Color(0xFF11151C),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E232D),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: hasGroup
          ? ScheduleScreen(storage: storage, api: api)
          : AuthScreen(storage: storage, api: api),
    );
  }
}
