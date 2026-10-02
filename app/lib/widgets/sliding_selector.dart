import 'package:flutter/material.dart';

/// Общая скользящая плашка для выбора недели и подгруппы на всех платформах.
class SlidingSelector extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const SlidingSelector({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 380);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: LayoutBuilder(builder: (context, constraints) {
          final width = constraints.maxWidth / labels.length;
          return Stack(
            children: [
              Positioned.fill(
                child: AnimatedAlign(
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  alignment: AlignmentDirectional(
                    -1 + 2 * selectedIndex / (labels.length - 1),
                    0,
                  ),
                  child: SizedBox(
                    width: width,
                    height: double.infinity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.secondaryContainer,
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: List.generate(labels.length, (index) {
                  final selected = selectedIndex == index;
                  return Expanded(
                    child: Semantics(
                      selected: selected,
                      child: TextButton(
                        onPressed: () => onSelected(index),
                        style: TextButton.styleFrom(
                          foregroundColor: selected
                              ? colors.onSecondaryContainer
                              : colors.onSurfaceVariant,
                          minimumSize: const Size(0, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: Text(labels[index], textAlign: TextAlign.center),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        }),
      ),
    );
  }
}
