// Экран расписания звонков института
import 'package:flutter/material.dart';

class BellsScreen extends StatelessWidget {
  const BellsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
        title: const Text('Расписание звонков', style: TextStyle(fontWeight: FontWeight.bold)),
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
              color: isDark ? const Color(0xFF1E232D) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF2C3340) : const Color(0xFFE2E8F0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    b['num']!,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2563EB),
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
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        b['break']!,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
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
