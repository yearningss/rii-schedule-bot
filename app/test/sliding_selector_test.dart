import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/widgets/sliding_selector.dart';

void main() {
  testWidgets('Плашка движется плавно и меняет направление при новом выборе',
      (tester) async {
    var selected = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(builder: (context, setState) {
          return SlidingSelector(
            labels: const ['Все', 'Первая', 'Вторая'],
            selectedIndex: selected,
            onSelected: (index) => setState(() => selected = index),
          );
        }),
      ),
    ));
    final pill = find.descendant(
      of: find.byType(AnimatedAlign),
      matching: find.byType(DecoratedBox),
    );
    final start = tester.getTopLeft(pill).dx;
    await tester.tap(find.text('Вторая'));
    await tester.pump();
    expect(tester.getTopLeft(pill).dx, start);
    await tester.pump(const Duration(milliseconds: 100));
    final middle = tester.getTopLeft(pill).dx;
    expect(middle, greaterThan(start));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(pill).dx, greaterThan(middle));
    await tester.tap(find.text('Все'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.text('Первая'));
    await tester.pumpAndSettle();
    expect(selected, 1);
    expect(tester.getTopLeft(pill).dx,
        closeTo(start + tester.getSize(pill).width, 0.01));
    expect(tester.takeException(), isNull);
  });
}
