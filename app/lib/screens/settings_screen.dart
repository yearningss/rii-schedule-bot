// Экран настроек приложения: профиль Telegram, смена темы, выбор группы
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import 'bells_screen.dart';
import 'group_picker_screen.dart';
import 'auth_screen.dart';

class SettingsScreen extends StatefulWidget {
  final StorageService storage;
  final ApiService api;

  const SettingsScreen({
    super.key,
    required this.storage,
    required this.api,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late UserProfile _profile;
  late ThemeMode _currentThemeMode;

  // Список встроенных иконок для выбора аватара
  static const List<Map<String, dynamic>> _presetAvatars = [
    {'id': 'school', 'name': 'Академик', 'icon': Icons.school_rounded, 'color': 0xFF2563EB},
    {'id': 'code', 'name': 'Разработчик', 'icon': Icons.terminal_rounded, 'color': 0xFF059669},
    {'id': 'engineer', 'name': 'Инженер', 'icon': Icons.precision_manufacturing_rounded, 'color': 0xFFD97706},
    {'id': 'star', 'name': 'Отличник', 'icon': Icons.star_rounded, 'color': 0xFFEAB308},
    {'id': 'book', 'name': 'Студент', 'icon': Icons.menu_book_rounded, 'color': 0xFF7C3AED},
    {'id': 'science', 'name': 'Исследователь', 'icon': Icons.biotech_rounded, 'color': 0xFF0284C7},
    {'id': 'energy', 'name': 'Энергетик', 'icon': Icons.bolt_rounded, 'color': 0xFFEA580C},
    {'id': 'person', 'name': 'Профиль', 'icon': Icons.person_rounded, 'color': 0xFF64748B},
  ];

  @override
  void initState() {
    super.initState();
    _profile = widget.storage.getUserProfile();
    _currentThemeMode = widget.storage.getThemeMode();
    _refreshProfileFromServer();
  }

  Future<void> _refreshProfileFromServer() async {
    if (_profile.authToken == null) return;
    final data = await widget.api.getProfile(_profile.authToken!);
    if (data != null && mounted) {
      setState(() {
        _profile = _profile.copyWith(
          userId: data['user_id'] is int ? data['user_id'] : int.tryParse(data['user_id']?.toString() ?? ''),
          groupId: data['group_id'] is int ? data['group_id'] : int.tryParse(data['group_id']?.toString() ?? ''),
          groupName: data['group_name'],
          subgroup: data['subgroup'] is int ? data['subgroup'] : int.tryParse(data['subgroup']?.toString() ?? '') ?? 0,
          firstName: data['first_name'],
          lastName: data['last_name'],
          username: data['username'],
          avatarUrl: data['avatar_url'],
        );
      });
      await widget.storage.saveUserProfile(_profile);
    }
  }

  Future<void> _setTheme(ThemeMode mode) async {
    setState(() => _currentThemeMode = mode);
    await widget.storage.saveThemeMode(mode);
  }

  Future<void> _setSubgroup(int sg) async {
    setState(() {
      _profile = _profile.copyWith(subgroup: sg);
    });
    await widget.storage.saveSubgroup(sg);

    if (_profile.authToken != null) {
      widget.api.syncProfile(
        authToken: _profile.authToken!,
        subgroup: sg,
      );
    }
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
      });
      await widget.storage.saveUserProfile(_profile);

      if (_profile.authToken != null) {
        widget.api.syncProfile(
          authToken: _profile.authToken!,
          groupId: selected.id,
          groupName: selected.name,
        );
      }
    }
  }

  void _openAvatarPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Выбор аватара',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Выберите значок для отображения в профиле приложения:',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: _presetAvatars.length,
                  itemBuilder: (_, idx) {
                    final item = _presetAvatars[idx];
                    final isSelected = _profile.customAvatar == item['id'];
                    final color = Color(item['color'] as int);

                    return InkWell(
                      onTap: () async {
                        final avatarId = item['id'] as String;
                        setState(() {
                          _profile = _profile.copyWith(customAvatar: avatarId);
                        });
                        await widget.storage.saveCustomAvatar(avatarId);
                        if (_profile.authToken != null) {
                          widget.api.syncProfile(
                            authToken: _profile.authToken!,
                            avatarUrl: 'custom:$avatarId',
                          );
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? color.withOpacity(0.15)
                              : (isDark ? const Color(0xFF1E232D) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? color : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: color.withOpacity(0.2),
                              child: Icon(item['icon'] as IconData, color: color, size: 24),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item['name'] as String,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvatarWidget() {
    final avatarUrl = _profile.avatarUrl;
    final customAvatar = _profile.customAvatar;

    // 1. Если задана встроенная иконка
    if (customAvatar != null && customAvatar.isNotEmpty) {
      final preset = _presetAvatars.firstWhere(
        (p) => p['id'] == customAvatar,
        orElse: () => _presetAvatars.last,
      );
      final color = Color(preset['color'] as int);
      return CircleAvatar(
        radius: 36,
        backgroundColor: color.withOpacity(0.2),
        child: Icon(preset['icon'] as IconData, color: color, size: 38),
      );
    }

    // 2. Если есть фото из Telegram
    if (avatarUrl != null && avatarUrl.isNotEmpty && !avatarUrl.startsWith('custom:')) {
      final fullUrl = avatarUrl.startsWith('http') ? avatarUrl : '${ApiService.baseUrl}$avatarUrl';
      return CircleAvatar(
        radius: 36,
        backgroundColor: const Color(0xFF2563EB).withOpacity(0.15),
        backgroundImage: NetworkImage(fullUrl),
        onBackgroundImageError: (_, __) {},
        child: null,
      );
    }

    // 3. По умолчанию инициалы или иконка
    final initials = (_profile.firstName != null && _profile.firstName!.isNotEmpty)
        ? _profile.firstName![0].toUpperCase()
        : 'Р';

    return CircleAvatar(
      radius: 36,
      backgroundColor: const Color(0xFF2563EB),
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Выход из аккаунта'),
        content: const Text('Вы действительно хотите выйти? Расписание выбранной группы останется доступным.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await widget.storage.clearAuth();
      setState(() {
        _profile = widget.storage.getUserProfile();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Вы вышли из профиля Telegram')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E232D) : Colors.white;
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Настройки',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Карточка профиля пользователя
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? const Color(0xFF2D333F) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Stack(
                      children: [
                        _buildAvatarWidget(),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: InkWell(
                            onTap: _openAvatarPicker,
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB),
                                shape: BoxShape.circle,
                                border: Border.all(color: cardBg, width: 2),
                              ),
                              child: const Icon(
                                Icons.edit_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _profile.displayName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _profile.idAndUsernameText,
                            style: TextStyle(
                              fontSize: 13,
                              color: subColor,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _profile.userId != null
                                  ? const Color(0xFF059669).withOpacity(0.12)
                                  : const Color(0xFF64748B).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _profile.userId != null ? 'Telegram привязан' : 'Без авторизации',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _profile.userId != null
                                    ? const Color(0xFF059669)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_profile.userId == null) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AuthScreen(storage: widget.storage, api: widget.api),
                          ),
                        );
                        if (mounted) {
                          setState(() {
                            _profile = widget.storage.getUserProfile();
                          });
                        }
                      },
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: const Text('Привязать Telegram аккаунт'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Секция: Тема оформления
          _buildSectionHeader('Оформление темы'),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF2D333F) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              children: [
                _buildThemeTile(
                  title: 'Светлая тема',
                  subtitle: 'Классический белый фон с синими акцентами',
                  icon: Icons.light_mode_rounded,
                  mode: ThemeMode.light,
                ),
                Divider(height: 1, color: isDark ? const Color(0xFF2D333F) : const Color(0xFFE2E8F0)),
                _buildThemeTile(
                  title: 'Тёмная тема',
                  subtitle: 'Глубокий темный фон для комфорта глаз',
                  icon: Icons.dark_mode_rounded,
                  mode: ThemeMode.dark,
                ),
                Divider(height: 1, color: isDark ? const Color(0xFF2D333F) : const Color(0xFFE2E8F0)),
                _buildThemeTile(
                  title: 'Системная тема',
                  subtitle: 'Следовать настройкам операционной системы',
                  icon: Icons.brightness_auto_rounded,
                  mode: ThemeMode.system,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Секция: Учебный профиль
          _buildSectionHeader('Учебный профиль'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF2D333F) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Текущая группа', style: TextStyle(fontSize: 12, color: subColor)),
                        const SizedBox(height: 4),
                        Text(
                          _profile.groupName ?? 'Не выбрана',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    OutlinedButton(
                      onPressed: _changeGroup,
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Сменить'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Подгруппа для фильтрации пар', style: TextStyle(fontSize: 12, color: subColor)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildSubgroupBtn(0, 'Все'),
                    const SizedBox(width: 8),
                    _buildSubgroupBtn(1, '1-я'),
                    const SizedBox(width: 8),
                    _buildSubgroupBtn(2, '2-я'),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Секция: Дополнительно
          _buildSectionHeader('Дополнительно'),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF2D333F) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.access_time_rounded, color: Color(0xFF2563EB)),
                  title: const Text('Расписание звонков'),
                  subtitle: const Text('Длительность пар и перемен в РИИ'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const BellsScreen()));
                  },
                ),
                Divider(height: 1, color: isDark ? const Color(0xFF2D333F) : const Color(0xFFE2E8F0)),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded, color: Color(0xFF64748B)),
                  title: const Text('О приложении'),
                  subtitle: const Text('РИИ Расписание v1.0.0 (Flutter)'),
                  trailing: Text('2026', style: TextStyle(color: subColor, fontSize: 13)),
                ),
                if (_profile.userId != null) ...[
                  Divider(height: 1, color: isDark ? const Color(0xFF2D333F) : const Color(0xFFE2E8F0)),
                  ListTile(
                    leading: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626)),
                    title: const Text('Выйти из Telegram аккаунта', style: TextStyle(color: Color(0xFFDC2626))),
                    onTap: _logout,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
          color: Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _buildThemeTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required ThemeMode mode,
  }) {
    final isSelected = _currentThemeMode == mode;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: isSelected
          ? const Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB))
          : null,
      onTap: () => _setTheme(mode),
    );
  }

  Widget _buildSubgroupBtn(int sg, String label) {
    final isSelected = _profile.subgroup == sg;
    return Expanded(
      child: InkWell(
        onTap: () => _setSubgroup(sg),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF2563EB)
                : (Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1E232D)
                    : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.white : null,
            ),
          ),
        ),
      ),
    );
  }
}
