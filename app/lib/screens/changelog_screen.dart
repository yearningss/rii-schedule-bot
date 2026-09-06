// Экран истории обновлений и списка изменений (Changelog)
import 'package:flutter/material.dart';
import '../models/models.dart';

class ChangelogItem {
  final String version;
  final int build;
  final String date;
  final bool isCurrent;
  final List<String> changes;

  const ChangelogItem({
    required this.version,
    required this.build,
    required this.date,
    this.isCurrent = false,
    required this.changes,
  });
}

class ChangelogScreen extends StatelessWidget {
  const ChangelogScreen({super.key});

  static const List<ChangelogItem> history = [
    ChangelogItem(
      version: '1.0.3',
      build: 4,
      date: 'Сентябрь 2026',
      isCurrent: true,
      changes: [
        'Исправлен расчет и отображение расписания в субботу и воскресенье: приложение и виджет теперь корректно учитывают выходные и отображают пары на понедельник следующей недели.',
        'Виджет рабочего стола: в воскресенье и свободную субботу показывает время первой пары и план на понедельник вместо пустого экрана.',
        'Уведомления: добавлен автоматический запрос системного разрешения на отправку уведомлений при первом запуске приложения (Android 13+).',
        'Настройки: устранена рассинхронизация версий, добавлен полноценный интерактивный список изменений (Changelog).',
        'Безопасность и установка: настроен собственный сертификат подписи разработчика (Keystore) для доверия со стороны Google Play Protect.',
      ],
    ),
    ChangelogItem(
      version: '1.0.2',
      build: 3,
      date: 'Сентябрь 2026',
      changes: [
        'Обновлен логотип приложения: стильный скругленный значок РИИ в едином дизайне с иконками рабочего стола.',
        'Сгенерированы адаптивные иконки высокой четкости для всех плотностей экранов Android и iOS.',
        'Подготовлены графические материалы и карточки для публикации в RuStore.',
      ],
    ),
    ChangelogItem(
      version: '1.0.1',
      build: 2,
      date: 'Сентябрь 2026',
      changes: [
        'Нативный виджет расписания для рабочего стола: текущая пара, аудитория, время перемены и следующая пара.',
        'Авторизация через Telegram-бота: синхронизация выбранной группы, подгруппы и профиля.',
        'Проверка обновлений приложения через сервер с возможностью скачивания прямо из настроек.',
      ],
    ),
    ChangelogItem(
      version: '1.0.0',
      build: 1,
      date: 'Август 2026',
      changes: [
        'Первый релиз официального мобильного приложения РИИ Расписание на Flutter.',
        'Просмотр расписания занятий по учебным неделям (I / II) и дням недели (Пн-Сб).',
        'Интерактивное расписание звонков и длительности перемен института.',
        'Выбор и поиск учебных групп, фильтрация по подгруппам, светлая и темная темы оформления.',
        'Полная поддержка офлайн-режима с сохранением локального кэша.',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E232D) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2D333F) : const Color(0xFFE2E8F0);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      appBar: AppBar(
        title: const Text('История изменений'),
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: history.length,
        itemBuilder: (context, idx) {
          final item = history[idx];
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: item.isCurrent ? const Color(0xFF2563EB) : borderColor,
                width: item.isCurrent ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Версия ',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (item.isCurrent)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Текущая',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ),
                        ],
                      ),
                      Text(
                        item.date,
                        style: TextStyle(fontSize: 12, color: subColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Сборка ',
                    style: TextStyle(fontSize: 12, color: subColor, fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 12),
                  ...item.changes.map((ch) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 6, right: 8),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: item.isCurrent ? const Color(0xFF2563EB) : subColor,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            ch,
                            style: const TextStyle(fontSize: 13.5, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
