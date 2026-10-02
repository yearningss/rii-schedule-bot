// Виджет карточки учебной пары
import 'package:flutter/material.dart';
import '../models/models.dart';

class ParaCard extends StatelessWidget {
  final ParaItem item;
  final ParaTime timeInfo;
  final bool isOngoing;
  final bool isNext;
  final bool isCompleted;
  final int activeSubgroup;
  final void Function(String teacher, String? post)? onTeacherTap;

  const ParaCard({
    super.key,
    required this.item,
    required this.timeInfo,
    this.isOngoing = false,
    this.isNext = false,
    this.isCompleted = false,
    this.activeSubgroup = 0,
    this.onTeacherTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final borderColor = isOngoing
        ? colors.primary
        : isNext
            ? colors.tertiary
            : colors.outlineVariant;
    final cardBg =
        isOngoing ? colors.primaryContainer : colors.surfaceContainerLow;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: borderColor,
          width: isOngoing || isNext ? 1.8 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Шапка пары: номер, время и статус
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${item.paraNum} пара',
                      style:
                          const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${timeInfo.startStr} - ${timeInfo.endStr}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                if (isOngoing)
                  _buildBadge('Идёт сейчас', colors.primary, colors.onPrimary)
                else if (isNext)
                  _buildBadge('Следующая', colors.tertiaryContainer,
                      colors.onTertiaryContainer)
                else if (isCompleted)
                  _buildBadge('Завершена', colors.surfaceContainerHighest,
                      colors.onSurfaceVariant),
              ],
            ),
            const SizedBox(height: 10),

            // Контент пары
            if (item.isDouble) ...[
              if ((activeSubgroup == 0 || activeSubgroup == 1) &&
                  (item.subj1 != null || item.aud1 != null))
                _buildSubgroupSection(
                  context,
                  title: '1 подгруппа',
                  subject: item.subj1,
                  type: item.type1,
                  aud: item.aud1,
                  teacher: item.teacher1,
                  post: item.teachPost1,
                ),
              if (activeSubgroup == 0 &&
                  (item.subj1 != null) &&
                  (item.subj2 != null))
                const Divider(height: 16),
              if ((activeSubgroup == 0 || activeSubgroup == 2) &&
                  (item.subj2 != null || item.aud2 != null))
                _buildSubgroupSection(
                  context,
                  title: '2 подгруппа',
                  subject: item.subj2,
                  type: item.type2,
                  aud: item.aud2,
                  teacher: item.teacher2,
                  post: item.teachPost2,
                ),
            ] else ...[
              _buildSubjectContent(
                context,
                subject: item.subj1,
                type: item.type1,
                aud: item.aud1,
                teacher: item.teacher1,
                post: item.teachPost1,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color bg, Color textCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        text,
        style: TextStyle(
            color: textCol, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildSubgroupSection(
    BuildContext context, {
    required String title,
    String? subject,
    String? type,
    String? aud,
    String? teacher,
    String? post,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            title,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSecondaryContainer),
          ),
        ),
        const SizedBox(height: 4),
        _buildSubjectContent(context,
            subject: subject,
            type: type,
            aud: aud,
            teacher: teacher,
            post: post),
      ],
    );
  }

  Widget _buildSubjectContent(
    BuildContext context, {
    String? subject,
    String? type,
    String? aud,
    String? teacher,
    String? post,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                subject ?? 'Предмет',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (type != null && type.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  type,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            if (aud != null && aud.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'ауд. $aud',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (teacher != null && teacher.isNotEmpty)
              Expanded(
                child: InkWell(
                  onTap: onTeacherTap != null
                      ? () => onTeacherTap!(teacher, post)
                      : null,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_rounded,
                          size: 14,
                          color: Theme.of(context).colorScheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            '$teacher${post != null && post.isNotEmpty ? ' ($post)' : ''}',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSecondaryContainer,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 14,
                          color: Theme.of(context).colorScheme.onSecondaryContainer,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
