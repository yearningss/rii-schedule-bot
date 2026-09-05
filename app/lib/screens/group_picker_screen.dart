// Экран выбора учебной группы с поиском
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Группируем по курсам
    final Map<int, List<GroupItem>> byCourse = {};
    for (var g in _filteredGroups) {
      byCourse.putIfAbsent(g.course, () => []).add(g);
    }
    final sortedCourses = byCourse.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Выбор группы', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Поле поиска
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: _filterGroups,
              decoration: InputDecoration(
                hintText: 'Поиск группы (например: ИВТ-61)...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filterGroups('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark ? const Color(0xFF1E232D) : const Color(0xFFF1F5F9),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Список групп
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredGroups.isEmpty
                    ? Center(
                        child: Text(
                          'Группы не найдены',
                          style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                        ),
                      )
                    : ListView.builder(
                        itemCount: sortedCourses.length,
                        padding: const EdgeInsets.only(bottom: 24),
                        itemBuilder: (context, idx) {
                          final course = sortedCourses[idx];
                          final groups = byCourse[course]!;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                                child: Text(
                                  '$course КУРС',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.1,
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: groups.map((g) {
                                    return ActionChip(
                                      label: Text(g.name),
                                      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                                      backgroundColor: isDark ? const Color(0xFF1E232D) : Colors.white,
                                      side: BorderSide(
                                        color: isDark ? const Color(0xFF2C3340) : const Color(0xFFE2E8F0),
                                      ),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
