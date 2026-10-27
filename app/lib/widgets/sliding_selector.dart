import 'package:flutter/material.dart';

/// РћР±С‰Р°СЏ СЃРєРѕР»СЊР·СЏС‰Р°СЏ РїР»Р°С€РєР° РґР»СЏ РІС‹Р±РѕСЂР° РЅРµРґРµР»Рё Рё РїРѕРґРіСЂСѓРїРїС‹ РЅР° РІСЃРµС… РїР»Р°С‚С„РѕСЂРјР°С….
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
        borderRadius: BorderRadius.circular(20),
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
                  curve: Curves.easeOutBack,
                  alignment: AlignmentDirectional(
                    -1 + 2 * selectedIndex / (labels.length - 1),
                    0,
                  ),
                  child: SizedBox(
                    width: width,
                    height: double.infinity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
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
                              ? colors.onPrimaryContainer
                              : colors.onSurfaceVariant,
                          minimumSize: const Size(0, 48),
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
