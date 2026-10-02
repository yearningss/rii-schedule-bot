import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rii_schedule/services/api_service.dart';
import 'package:rii_schedule/services/storage_service.dart';
import 'package:rii_schedule/screens/auth_screen.dart';
import 'package:rii_schedule/screens/group_picker_screen.dart';
import 'package:rii_schedule/screens/schedule_screen.dart';
import 'package:rii_schedule/models/models.dart';
import 'package:rii_schedule/theme/app_theme.dart';
import 'package:rii_schedule/widgets/para_card.dart';
import 'package:rii_schedule/screens/bells_screen.dart';

void main() {
  testWidgets('Экран входа помещается на коротком экране, поиск групп работает',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.init();
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.create(Brightness.light),
        home: AuthScreen(storage: storage, api: FakeApi())));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.create(Brightness.dark),
        home: GroupPickerScreen(storage: storage, api: FakeApi())));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ивт61');
    await tester.pump();
    expect(find.text('ИВТ-61'), findsOneWidget);
    expect(find.text('Э-21'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Главный экран: выбор недели, подгруппы и сохранение настроек', (tester) async {
    SharedPreferences.setMockInitialValues({'group_id': 1, 'group_name': 'ИВТ-61', 'notifications_enabled': false});
    final storage = await StorageService.init();
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.create(Brightness.dark),
      home: ScheduleScreen(storage: storage, api: FakeApi())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Пн'));
    await tester.pump();
    expect(find.text('Физика'), findsOneWidget);
    await tester.tap(find.text('II нед'));
    await tester.pump();
    expect(find.text('Физика'), findsOneWidget);
    await tester.tap(find.text('1 п/г'));
    await tester.pumpAndSettle();
    expect(find.text('Физика'), findsNothing);
    expect(storage.getUserProfile().subgroup, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  for (final brightness in Brightness.values) {
    for (final width in [320.0, 840.0]) {
      testWidgets('Фильтрация подгрупп и нажатие на преподавателя: $brightness / $width',
          (tester) async {
        tester.view.physicalSize = Size(width, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        String? tapped;
        Widget card(int subgroup) => MaterialApp(
              theme: AppTheme.create(brightness),
              home: Scaffold(
                  body: SingleChildScrollView(
                      child: ParaCard(
                item: ParaItem(
                    paraNum: 1,
                    isDouble: true,
                    subj1: 'Математический анализ и дифференциальные уравнения',
                    subj2: 'Физика',
                    aud1: '211',
                    aud2: '312',
                    teacher1: 'Иванов Иван Иванович',
                    teacher2: 'Петров Пётр Петрович'),
                timeInfo: ParaTime.parse(null, 1),
                activeSubgroup: subgroup,
                isOngoing: true,
                onTeacherTap: (teacher, _) => tapped = teacher,
              ))),
            );
        await tester.pumpWidget(card(0));
        expect(find.text('Физика'), findsOneWidget);
        expect(find.text('Идёт сейчас'), findsOneWidget);
        await tester.tap(find.text('Иванов Иван Иванович'));
        expect(tapped, 'Иванов Иван Иванович');
        await tester.pumpWidget(card(1));
        expect(find.text('Физика'), findsNothing);
        expect(find.text('ауд. 211'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
    testWidgets('Расписание звонков с увеличенным текстом: $brightness', (tester) async {
      tester.view.physicalSize = const Size(320, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.create(brightness),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!),
          home: BellsScreen()));
      expect(find.text('08:30 - 10:00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

class FakeApi extends ApiService {
  @override
  Future<AppUpdateInfo?> checkAppUpdate({int currentBuild = 1, String currentVersion = '1.0.0'}) async => null;

  @override
  Future<Map<String, dynamic>> getSchedule(int groupId) async {
    final Map<String, dynamic> day = {'1': {'isDouble': true, 'subj1': 'Математика', 'subj2': 'Физика'}};
    final week = {for (var d = 1; d <= 6; d++) '$d': day};
    return {'weekNumber': 1, 'scheduleData': {'1': week, '2': week}, 'paraTimes': <String, dynamic>{}};
  }

  @override
  Future<Map<String, dynamic>?> syncDeviceUser({required String deviceId,
    String? clientUserId, String? platform, int? groupId, String? groupName,
    int? subgroup, bool? notificationsEnabled, int? notifyBeforeMins,
    bool? notifyLessonStart, bool? notifyBreaks, bool? notifyChanges,
    String? appVersion, String? authToken}) async => null;

  @override
  Future<List<GroupItem>> getGroups() async => [
        GroupItem(id: 1, name: 'ИВТ-61', course: 1),
        GroupItem(id: 2, name: 'Э-21', course: 2),
      ];
}
