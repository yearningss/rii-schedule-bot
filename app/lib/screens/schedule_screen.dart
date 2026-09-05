// Главный экран расписания занятий
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/widget_service.dart';
import '../widgets/para_card.dart';
import 'bells_screen.dart';
import 'group_picker_screen.dart';
import 'auth_screen.dart';
import 'settings_screen.dart';

class ScheduleScreen extends StatefulWidget {
  final StorageService storage;
  final ApiService api;

  const ScheduleScreen({
    super.key,
    required this.storage,
    required this.api,
  });

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late UserProfile _profile;
  Map<String, dynamic>? _scheduleJson;
  bool _isLoading = true;

  int _selectedWeek = 1;
  int _selectedDay = 1;
  Timer? _statusTimer;

  final List<String> _dayNames = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб'];

  @override
  void initState() {
    super.initState();
    _profile = widget.storage.getUserProfile();
    _initSchedule();

    // Обновляем статус времени каждую минуту
    _statusTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  DateTime _getRubtsovskTime() {
    final now = DateTime.now().toUtc();
    return now.add(const Duration(hours: 7));
  }

  Future<void> _initSchedule() async {
    if (_profile.groupId == null) return;

    // Сначала читаем кэш для мгновенной отрисовки без задержки
    final cached = widget.storage.getScheduleCache(_profile.groupId!);
    if (cached != null) {
      _applyScheduleData(cached, isFromCache: true);
    }

    await _fetchFreshSchedule();
  }

  Future<void> _fetchFreshSchedule() async {
    if (_profile.groupId == null) return;

    try {
      final fresh = await widget.api.getSchedule(_profile.groupId!);
      await widget.storage.saveScheduleCache(_profile.groupId!, fresh);
      if (mounted) {
        _applyScheduleData(fresh, isFromCache: false);
      }
    } catch (_) {
      if (mounted && _scheduleJson == null) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyScheduleData(Map<String, dynamic> data, {required bool isFromCache}) {
    final siteWeek = int.tryParse(data['weekNumber']?.toString() ?? '1') ?? 1;
    final rTime = _getRubtsovskTime();
    int rDay = rTime.weekday; // 1 = Monday, 7 = Sunday
    if (rDay > 6) rDay = 1;

    setState(() {
      _scheduleJson = data;
      _isLoading = false;
      if (!isFromCache) {
        _selectedWeek = siteWeek;
        _selectedDay = rDay;
      }
    });

    WidgetService.updateWidgetData(profile: _profile, scheduleJson: data);
  }

  Future<void> _changeGroup() async {
    final selected = await Navigator.push<GroupItem>(
      context,
      MaterialPageRoute(
        builder: (_) => GroupPickerScreen(storage: widget.storage, api: widget.api),
      ),
    );

    if (selected != null && mounted) {
      setState(() {
        _profile = _profile.copyWith(groupId: selected.id, groupName: selected.name);
        _isLoading = true;
      });
      await widget.storage.saveUserProfile(_profile);

      // Фоновая синхронизация с ботом при наличии авторизации
      if (_profile.authToken != null) {
        widget.api.syncProfile(
          authToken: _profile.authToken!,
          groupId: selected.id,
          groupName: selected.name,
        );
      }

      WidgetService.updateWidgetData(profile: _profile);
      await _fetchFreshSchedule();
    }
  }

  void _setSubgroup(int sg) {
    setState(() {
      _profile = _profile.copyWith(subgroup: sg);
    });
    widget.storage.saveSubgroup(sg);

    if (_profile.authToken != null) {
      widget.api.syncProfile(
        authToken: _profile.authToken!,
        subgroup: sg,
      );
    }

    WidgetService.updateWidgetData(profile: _profile, scheduleJson: _scheduleJson);
  }

  String _calculateLiveStatus(Map<String, dynamic> dayMap, Map<String, dynamic> paraTimes) {
    final rTime = _getRubtsovskTime();
    final curMins = rTime.hour * 60 + rTime.minute;

    final sortedKeys = dayMap.keys.map((k) => int.tryParse(k) ?? 0).where((n) => n > 0).toList()..sort();
    if (sortedKeys.isEmpty) return 'Пар на сегодня нет';

    ParaTime? ongoing;
    int? ongoingNum;
    ParaTime? next;
    int? nextNum;

    for (var pNum in sortedKeys) {
      final t = ParaTime.parse(paraTimes[pNum.toString()], pNum);
      if (t.startMinutes <= curMins && curMins <= t.endMinutes) {
        ongoing = t;
        ongoingNum = pNum;
        break;
      } else if (curMins < t.startMinutes && next == null) {
        next = t;
        nextNum = pNum;
      }
    }

    if (ongoing != null) {
      final rem = ongoing.endMinutes - curMins;
      return 'Идет $ongoingNum пара (до ${ongoing.endStr}, осталось $rem мин)';
    } else if (next != null) {
      final firstNum = sortedKeys.first;
      final firstTime = ParaTime.parse(paraTimes[firstNum.toString()], firstNum);
      if (curMins < firstTime.startMinutes) {
        final rem = firstTime.startMinutes - curMins;
        return 'Занятия не начались. $firstNum пара в ${firstTime.startStr} (через $rem мин)';
      } else {
        final rem = next.startMinutes - curMins;
        return 'Перемена (до ${next.startStr}, осталось $rem мин). След: $nextNum пара';
      }
    } else {
      return 'Все пары на сегодня завершены';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final scheduleMap = _scheduleJson?['scheduleData'] as Map<String, dynamic>?;
    final weekMap = scheduleMap?[_selectedWeek.toString()] as Map<String, dynamic>?;
    final dayMap = weekMap?[_selectedDay.toString()] as Map<String, dynamic>? ?? {};
    final paraTimes = _scheduleJson?['paraTimes'] as Map<String, dynamic>? ?? {};

    final rTime = _getRubtsovskTime();
    final siteWeek = int.tryParse(_scheduleJson?['weekNumber']?.toString() ?? '1') ?? 1;
    final isToday = (_selectedWeek == siteWeek && _selectedDay == (rTime.weekday > 6 ? 1 : rTime.weekday));

    final curMins = rTime.hour * 60 + rTime.minute;
    final sortedKeys = dayMap.keys.map((k) => int.tryParse(k) ?? 0).where((n) => n > 0).toList()..sort();

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: InkWell(
          onTap: _changeGroup,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _profile.groupName ?? 'Выбрать группу',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
              ],
            ),
          ),
        ),
        actions: [
          // Переключатель недели I / II
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E232D) : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                _buildWeekBtn(1, 'I нед'),
                _buildWeekBtn(2, 'II нед'),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.access_time_rounded),
            tooltip: 'Звонки',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const BellsScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Настройки и профиль',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(storage: widget.storage, api: widget.api),
                ),
              );
              if (mounted) {
                final updated = widget.storage.getUserProfile();
                if (updated.groupId != _profile.groupId || updated.subgroup != _profile.subgroup) {
                  setState(() {
                    _profile = updated;
                    _isLoading = true;
                  });
                  _initSchedule();
                } else {
                  setState(() {
                    _profile = updated;
                  });
                }
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Полоса выбора дней недели
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (idx) {
                final dayNum = idx + 1;
                final isSelected = _selectedDay == dayNum;
                final isCurrentRealDay = (rTime.weekday == dayNum);

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: InkWell(
                      onTap: () => setState(() => _selectedDay = dayNum),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF2563EB)
                              : (isDark ? const Color(0xFF1E232D) : Colors.white),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF2563EB)
                                : (isDark ? const Color(0xFF2C3340) : const Color(0xFFE2E8F0)),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              _dayNames[idx],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isSelected
                                    ? Colors.white
                                    : (isDark ? Colors.grey[300] : Colors.grey[800]),
                              ),
                            ),
                            if (isCurrentRealDay) ...[
                              const SizedBox(height: 3),
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected ? Colors.white : const Color(0xFF2563EB),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          // Плашка статуса для сегодняшнего дня
          if (isToday)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2563EB),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _calculateLiveStatus(dayMap, paraTimes),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Список пар на выбранный день
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : sortedKeys.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.event_busy_rounded, size: 54, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            const Text('В этот день занятий нет', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchFreshSchedule,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(top: 6, bottom: 16),
                          itemCount: sortedKeys.length,
                          itemBuilder: (context, idx) {
                            final pNum = sortedKeys[idx];
                            final itemJson = dayMap[pNum.toString()] as Map<String, dynamic>;
                            final item = ParaItem.fromJson(pNum, itemJson);
                            final timeInfo = ParaTime.parse(paraTimes[pNum.toString()], pNum);

                            bool isOngoing = false;
                            bool isNext = false;
                            bool isCompleted = false;

                            if (isToday) {
                              if (curMins > timeInfo.endMinutes) {
                                isCompleted = true;
                              } else if (timeInfo.startMinutes <= curMins && curMins <= timeInfo.endMinutes) {
                                isOngoing = true;
                              } else if (curMins < timeInfo.startMinutes &&
                                  (idx == 0 || curMins > ParaTime.parse(paraTimes[sortedKeys[idx - 1].toString()], sortedKeys[idx - 1]).endMinutes)) {
                                isNext = true;
                              }
                            }

                            return ParaCard(
                              item: item,
                              timeInfo: timeInfo,
                              isOngoing: isOngoing,
                              isNext: isNext,
                              isCompleted: isCompleted,
                              activeSubgroup: _profile.subgroup,
                            );
                          },
                        ),
                      ),
          ),

          // Переключатель подгруппы внизу
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E232D) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? const Color(0xFF2C3340) : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: Row(
              children: [
                _buildSubgroupBtn(0, 'Все подгруппы'),
                const SizedBox(width: 8),
                _buildSubgroupBtn(1, '1 п/г'),
                const SizedBox(width: 8),
                _buildSubgroupBtn(2, '2 п/г'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekBtn(int week, String label) {
    final isActive = _selectedWeek == week;
    return GestureDetector(
      onTap: () => setState(() => _selectedWeek = week),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF2563EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey[600],
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildSubgroupBtn(int sg, String title) {
    final isSelected = _profile.subgroup == sg;
    return Expanded(
      child: InkWell(
        onTap: () => _setSubgroup(sg),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFF2563EB) : Colors.grey.withOpacity(0.3),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.grey[300] : Colors.grey[700]),
            ),
          ),
        ),
      ),
    );
  }
}
