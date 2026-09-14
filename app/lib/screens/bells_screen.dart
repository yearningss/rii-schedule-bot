// Экран расписания звонков института по стандарту Material 3
import 'package:flutter/material.dart';
import '../theme/theme.dart';

class BellsScreen extends StatelessWidget {
  const BellsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final bells = [
      {'num': '1', 'time': '08:30 - 10:00', 'break': 'Перемена 10 минут'},
      {'num': '2', 'time': '10:10 - 11:40', 'break': 'Обеденный перерыв 30 минут'},
      {'num': '3', 'time': '12:10 - 13:40', 'break': 'Перемена 10 минут'},
      {'num': '4', 'time': '13:50 - 15:20', 'break': 'Перемена 10 минут'},
      {'num': '5', 'time': '15:30 - 17:00', 'break': 'Перемена 10 минут'},
      {'num': '6', 'time': '17:10 - 18:40', 'break': 'Окончание занятий'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Расписание звонков',
          style: AppTypography.titleLarge.copyWith(
            color: colorScheme.onSurface,
          ),
        ),
      ),
      body: ListView.builder(
        padding: AppSpacing.screenPadding,
        itemCount: bells.length,
        itemBuilder: (context, idx) {
          final b = bells[idx];
          final isLunch = idx == 1;

          return Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            shape: AppShape.cardShape,
            color: colorScheme.surface,
            child: Padding(
              padding: AppSpacing.cardPadding,
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isLunch
                          ? colorScheme.tertiaryContainer
                          : colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      b['num']!,
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isLunch
                            ? colorScheme.onTertiaryContainer
                            : colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  AppSpacing.gapW16,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b['time']!,
                          style: AppTypography.titleMedium.copyWith(
                            color: colorScheme.onSurface,
                          ),
                        ),
                        AppSpacing.gapH4,
                        Text(
                          b['break']!,
                          style: AppTypography.bodySmall.copyWith(
                            color: isLunch
                                ? colorScheme.tertiary
                                : colorScheme.onSurfaceVariant,
                            fontWeight: isLunch ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
