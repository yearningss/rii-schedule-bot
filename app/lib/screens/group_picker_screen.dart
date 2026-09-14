// Экран выбора учебной группы с поиском по стандарту Material 3
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../theme/theme.dart';

class GroupPickerScreen extends StatefulWidget {
  final StorageService storage;
  final ApiService api;

  const GroupPickerScreen({
    super.key,
    required this.storage,
    required this.api,
  });

  @override
  State<GroupPickerScreen> createState() => _GroupPickerScreenState();
}

class _GroupPickerScreenState extends State<GroupPickerScreen> {
  List<GroupItem> _allGroups = [];
  List<GroupItem> _filteredGroups = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    // Сначала пробуем кэш
    final cached = widget.storage.getGroupsCache();
    if (cached != null && cached.isNotEmpty) {
      setState(() {
        _allGroups = cached;
        _filteredGroups = cached;
        _isLoading = false;
      });
    }

    try {
      final fresh = await widget.api.getGroups();
      await widget.storage.saveGroupsCache(fresh);
      if (mounted) {
        setState(() {
          _allGroups = fresh;
          _filterGroups(_searchQuery);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted && _allGroups.isEmpty) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterGroups(String query) {
    _searchQuery = query.toLowerCase().replaceAll(RegExp(r'[\s\-_]'), '');
    setState(() {
      if (_searchQuery.isEmpty) {
        _filteredGroups = _allGroups;
      } else {
        _filteredGroups = _allGroups.where((g) {
          final norm = g.name.toLowerCase().replaceAll(RegExp(r'[\s\-_]'), '');
          return norm.contains(_searchQuery);
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Группируем по курсам
    final Map<int, List<GroupItem>> byCourse = {};
    for (var g in _filteredGroups) {
      byCourse.putIfAbsent(g.course, () => []).add(g);
    }
    final sortedCourses = byCourse.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Выбор группы',
          style: AppTypography.titleLarge.copyWith(
            color: colorScheme.onSurface,
          ),
        ),
      ),
      body: Column(
        children: [
          // Поле поиска группы
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _filterGroups,
              decoration: InputDecoration(
                hintText: 'Поиск группы (например: ИВТ-61)...',
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          _filterGroups('');
                        },
                      )
                    : null,
              ),
            ),
          ),

          // Список групп
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredGroups.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 48,
                              color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                            ),
                            AppSpacing.gapH12,
                            Text(
                              'Группы не найдены',
                              style: AppTypography.bodyLarge.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: sortedCourses.length,
                        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                        itemBuilder: (context, idx) {
                          final course = sortedCourses[idx];
                          final groups = byCourse[course]!;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  AppSpacing.lg,
                                  AppSpacing.lg,
                                  AppSpacing.lg,
                                  AppSpacing.sm,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: colorScheme.primary,
                                        borderRadius: AppShape.roundedXs,
                                      ),
                                    ),
                                    AppSpacing.gapW8,
                                    Text(
                                      '$course КУРС',
                                      style: AppTypography.labelMedium.copyWith(
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.1,
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.lg,
                                ),
                                child: Wrap(
                                  spacing: AppSpacing.sm,
                                  runSpacing: AppSpacing.sm,
                                  children: groups.map((g) {
                                    return ActionChip(
                                      label: Text(g.name),
                                      labelStyle: AppTypography.labelLarge.copyWith(
                                        color: colorScheme.onSurface,
                                      ),
                                      backgroundColor: colorScheme.surface,
                                      side: BorderSide(
                                        color: colorScheme.outlineVariant,
                                      ),
                                      shape: const RoundedRectangleBorder(
                                        borderRadius: AppShape.roundedSm,
                                      ),
                                      onPressed: () => Navigator.pop(context, g),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
