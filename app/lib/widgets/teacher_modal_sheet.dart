// Модальные окна сведений о преподавателе и каталога преподавателей
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../services/api_service.dart';

// Модальное окно профиля преподавателя
class TeacherModalSheet extends StatefulWidget {
  final String teacher;
  final String? post;
  final ApiService api;

  const TeacherModalSheet({
    super.key,
    required this.teacher,
    this.post,
    required this.api,
  });

  @override
  State<TeacherModalSheet> createState() => _TeacherModalSheetState();
}

class _TeacherModalSheetState extends State<TeacherModalSheet> {
  late final Future<TeacherInfo?> _teacherFuture;
  TeacherInfo? _loadedInfo;

  @override
  void initState() {
    super.initState();
    _teacherFuture = widget.api.getTeacherInfo(widget.teacher, post: widget.post);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E232D) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Верхняя закрепленная плашка с полосой свайпа и кнопкой закрытия
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 8, 4),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[700] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Закрыть',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Прокручиваемый блок данных о преподавателе
            Flexible(
              child: FutureBuilder<TeacherInfo?>(
                future: _teacherFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48.0),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Text(
                              'Загрузка сведений о преподавателе...',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final info = snapshot.data ?? TeacherInfo(
                    fullName: widget.teacher,
                    post: widget.post ?? 'Преподаватель',
                    profileUrl: 'https://www.rubinst.ru/structure',
                  );
                  _loadedInfo = info;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(40),
                              child: Container(
                                width: 76,
                                height: 76,
                                color: isDark ? const Color(0xFF2B3240) : const Color(0xFFF1F5F9),
                                child: info.photoUrl.isNotEmpty
                                    ? Image.network(
                                        info.photoUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Icon(
                                          Icons.person,
                                          size: 40,
                                          color: isDark ? Colors.grey[500] : Colors.grey[400],
                                        ),
                                      )
                                    : Icon(
                                        Icons.person,
                                        size: 40,
                                        color: isDark ? Colors.grey[500] : Colors.grey[400],
                                      ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    info.fullName.isNotEmpty ? info.fullName : widget.teacher,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (info.post.isNotEmpty)
                                    Text(
                                      info.post,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                                      ),
                                    ),
                                  if (info.department.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2563EB).withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        info.department,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF2563EB),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const Divider(height: 1),
                        const SizedBox(height: 14),
                        if (info.room.isNotEmpty)
                          _buildDetailRow(
                            Icons.meeting_room_outlined,
                            'Аудитория',
                            info.room,
                            isDark,
                          ),
                        if (info.degree.isNotEmpty || info.title.isNotEmpty)
                          _buildDetailRow(
                            Icons.school_outlined,
                            'Степень и звание',
                            [info.degree, info.title].where((s) => s.isNotEmpty).join(', '),
                            isDark,
                          ),
                        if (info.phones.isNotEmpty)
                          ...info.phones.map((p) => _buildDetailRow(
                                Icons.phone_outlined,
                                'Телефон',
                                p['display'] ?? '',
                                isDark,
                                onTap: (p['dial']?.isNotEmpty ?? false)
                                    ? () => launchUrl(Uri.parse('tel:${p['dial']}'))
                                    : null,
                              ))
                        else if (info.phone.isNotEmpty)
                          _buildDetailRow(
                            Icons.phone_outlined,
                            'Телефон',
                            info.phone,
                            isDark,
                            onTap: () => launchUrl(Uri.parse('tel:${info.dialPhone}')),
                          ),
                        if (info.email.isNotEmpty)
                          _buildDetailRow(
                            Icons.email_outlined,
                            'Email',
                            info.email,
                            isDark,
                            onTap: () {
                              final first = info.email.split(RegExp(r'\s+')).first;
                              launchUrl(Uri.parse('mailto:$first'));
                            },
                          ),
                        if (info.disciplines.isNotEmpty)
                          _buildDetailRow(
                            Icons.menu_book_outlined,
                            'Дисциплины',
                            info.disciplines,
                            isDark,
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Закрепленные кнопки управления внизу
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF2B3240) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Закрыть'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final url = (_loadedInfo?.profileUrl.isNotEmpty ?? false)
                            ? _loadedInfo!.profileUrl
                            : 'https://www.rubinst.ru/structure';
                        launchUrl(
                          Uri.parse(url),
                          mode: LaunchMode.externalApplication,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                      label: const Text('На сайте РИИ', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value,
    bool isDark, {
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: const Color(0xFF2563EB)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: onTap != null
                            ? const Color(0xFF2563EB)
                            : (isDark ? Colors.white : Colors.black87),
                        decoration: onTap != null ? TextDecoration.underline : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Модальное окно каталога всех преподавателей РИИ с поиском
class TeachersCatalogSheet extends StatefulWidget {
  final ApiService api;
  final void Function(String teacher, String? post) onTeacherSelected;

  const TeachersCatalogSheet({
    super.key,
    required this.api,
    required this.onTeacherSelected,
  });

  @override
  State<TeachersCatalogSheet> createState() => _TeachersCatalogSheetState();
}

class _TeachersCatalogSheetState extends State<TeachersCatalogSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<TeacherInfo> _allTeachers = [];
  List<TeacherInfo> _filteredTeachers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTeachers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTeachers() async {
    final list = await widget.api.getTeachersList();
    if (mounted) {
      setState(() {
        _allTeachers = list;
        _filteredTeachers = list;
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredTeachers = _allTeachers;
      } else {
        _filteredTeachers = _allTeachers.where((t) {
          return t.fullName.toLowerCase().contains(q) ||
              t.shortName.toLowerCase().contains(q) ||
              t.department.toLowerCase().contains(q) ||
              t.post.toLowerCase().contains(q) ||
              t.disciplines.toLowerCase().contains(q);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.88,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E232D) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Шапка со свайп-ручкой и закрытием
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 8, 4),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[700] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Закрыть',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.people_alt_rounded, color: Color(0xFF2563EB), size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Преподаватели РИИ (${_allTeachers.length})',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            // Поле поиска
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Поиск по ФИО, кафедре, предмету...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchCtrl.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF28303F) : const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ),
            const Divider(height: 1),
            // Список преподавателей
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredTeachers.isEmpty
                      ? Center(
                          child: Text(
                            'Преподаватели не найдены',
                            style: TextStyle(
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _filteredTeachers.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, idx) {
                            final t = _filteredTeachers[idx];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: Container(
                                  width: 46,
                                  height: 46,
                                  color: isDark ? const Color(0xFF2B3240) : const Color(0xFFF1F5F9),
                                  child: t.photoUrl.isNotEmpty
                                      ? Image.network(
                                          t.photoUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Icon(
                                            Icons.person,
                                            color: isDark ? Colors.grey[500] : Colors.grey[400],
                                          ),
                                        )
                                      : Icon(
                                          Icons.person,
                                          color: isDark ? Colors.grey[500] : Colors.grey[400],
                                        ),
                                ),
                              ),
                              title: Text(
                                t.fullName.isNotEmpty ? t.fullName : t.shortName,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (t.post.isNotEmpty)
                                    Text(
                                      t.post,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                                      ),
                                    ),
                                  if (t.department.isNotEmpty)
                                    Text(
                                      t.department,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFF2563EB),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                              onTap: () => widget.onTeacherSelected(t.fullName, t.post),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
