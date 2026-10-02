// Экран расписания звонков института
import 'package:flutter/material.dart';

class BellsScreen extends StatelessWidget {
  const BellsScreen({super.key});

  @override
  Widget build(BuildContext context) {

    final bells = [
      {'num': '1', 'time': '08:30 - 10:00', 'break': 'Перемена 10 минут'},
      {
        'num': '2',
        'time': '10:10 - 11:40',
        'break': 'Обеденный перерыв 30 минут'
      },
      {'num': '3', 'time': '12:10 - 13:40', 'break': 'Перемена 10 минут'},
      {'num': '4', 'time': '13:50 - 15:20', 'break': 'Перемена 10 минут'},
      {'num': '5', 'time': '15:30 - 17:00', 'break': 'Перемена 10 минут'},
      {'num': '6', 'time': '17:10 - 18:40', 'break': 'Окончание занятий'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Расписание звонков',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: bells.length,
        itemBuilder: (context, idx) {
          final b = bells[idx];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    b['num']!,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b['time']!,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        b['break']!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
