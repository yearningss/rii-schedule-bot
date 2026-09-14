// Виджет карточки учебной пары по стандарту Material 3
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/theme.dart';

class ParaCard extends StatelessWidget {
  final ParaItem item;
  final ParaTime timeInfo;
  final bool isOngoing;
  final bool isNext;
  final bool isCompleted;
  final int activeSubgroup;

  const ParaCard({
    super.key,
    required this.item,
    required this.timeInfo,
    this.isOngoing = false,
    this.isNext = false,
    this.isCompleted = false,
    this.activeSubgroup = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final scheduleColors = context.scheduleColors;

    Color cardBg = colorScheme.surface;
    Color borderColor = colorScheme.outlineVariant;
    double borderWidth = 1.0;

    if (isOngoing) {
      cardBg = scheduleColors.ongoingContainer.withOpacity(0.18);
      borderColor = scheduleColors.ongoing;
      borderWidth = 1.8;
    } else if (isNext) {
      cardBg = colorScheme.surfaceContainer;
      borderColor = scheduleColors.next;
      borderWidth = 1.5;
    } else if (isCompleted) {
      cardBg = colorScheme.surfaceContainerLow.withOpacity(0.6);
      borderColor = colorScheme.outlineVariant.withOpacity(0.5);
    }

    final accessibilityLabel = _buildAccessibilityLabel();

    return Semantics(
      label: accessibilityLabel,
      container: true,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: AppShape.roundedLg,
          border: Border.all(
            color: borderColor,
            width: borderWidth,
          ),
          boxShadow: [
            if (isOngoing || isNext)
              BoxShadow(
                color: (isOngoing ? scheduleColors.ongoing : scheduleColors.next)
                    .withOpacity(0.12),
                blurRadius: 10,
                offset: const Offset(0, 3),
              )
            else
              BoxShadow(
                color: colorScheme.shadow.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Padding(
          padding: AppSpacing.cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Шапка пары: номер, время и статус
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        '${item.paraNum} пара',
                        style: AppTypography.titleSmall.copyWith(
                          color: isCompleted
                              ? colorScheme.onSurfaceVariant.withOpacity(0.6)
                              : colorScheme.onSurface,
                        ),
                      ),
                      AppSpacing.gapW8,
                      Text(
                        '${timeInfo.startStr} - ${timeInfo.endStr}',
                        style: AppTypography.bodySmall.copyWith(
                          color: isCompleted
                              ? colorScheme.onSurfaceVariant.withOpacity(0.5)
                              : colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  if (isOngoing)
                    _buildBadge(
                      text: 'Идет сейчас',
                      bg: scheduleColors.ongoingContainer,
                      textColor: scheduleColors.onOngoingContainer,
                    )
                  else if (isNext)
                    _buildBadge(
                      text: 'Следующая',
                      bg: scheduleColors.nextContainer,
                      textColor: scheduleColors.onNextContainer,
                    )
                  else if (isCompleted)
                    _buildBadge(
                      text: 'Завершена',
                      bg: colorScheme.surfaceContainerHighest.withOpacity(0.6),
                      textColor: colorScheme.onSurfaceVariant.withOpacity(0.7),
                    ),
                ],
              ),
              AppSpacing.gapH12,

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
                  Padding(
                    padding: AppSpacing.verticalSm,
                    child: Divider(
                      height: 1,
                      color: colorScheme.outlineVariant,
                    ),
                  ),
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
      ),
    );
  }

  String _buildAccessibilityLabel() {
    final statusText = isOngoing
        ? ', идет сейчас'
        : isNext
            ? ', следующая пара'
            : isCompleted
                ? ', завершена'
                : '';
    final timeText = '${item.paraNum} пара, время с ${timeInfo.startStr} до ${timeInfo.endStr}$statusText. ';

    if (item.isDouble) {
      final s1 = item.subj1 != null ? '1 подгруппа: ${item.subj1}, ауд. ${item.aud1 ?? "не указана"}. ' : '';
      final s2 = item.subj2 != null ? '2 подгруппа: ${item.subj2}, ауд. ${item.aud2 ?? "не указана"}.' : '';
      return '$timeText$s1$s2';
    } else {
      final subject = item.subj1 ?? 'Предмет не указан';
      final aud = item.aud1 != null ? ', аудитория ${item.aud1}' : '';
      final teacher = item.teacher1 != null ? ', преподаватель ${item.teacher1}' : '';
      return '$timeText$subject$aud$teacher';
    }
  }

  Widget _buildBadge({
    required String text,
    required Color bg,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppShape.roundedSm,
      ),
      child: Text(
        text,
        style: AppTypography.labelSmall.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
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
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xxs,
          ),
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer,
            borderRadius: AppShape.roundedXs,
          ),
          child: Text(
            title,
            style: AppTypography.labelSmall.copyWith(
              color: colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        AppSpacing.gapH4,
        _buildSubjectContent(
          context,
          subject: subject,
          type: type,
          aud: aud,
          teacher: teacher,
          post: post,
        ),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final scheduleColors = context.scheduleColors;

    final typeBadge = _resolveTypeBadge(type, scheduleColors, colorScheme);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                subject ?? 'Предмет',
                style: AppTypography.titleMedium.copyWith(
                  color: isCompleted
                      ? colorScheme.onSurface.withOpacity(0.65)
                      : colorScheme.onSurface,
                ),
              ),
            ),
            if (typeBadge != null) ...[
              AppSpacing.gapW8,
              typeBadge,
            ],
          ],
        ),
        AppSpacing.gapH8,
        Row(
          children: [
            if (aud != null && aud.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.tertiaryContainer,
                  borderRadius: AppShape.roundedSm,
                ),
                child: Text(
                  'ауд. $aud',
                  style: AppTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
              AppSpacing.gapW8,
            ],
            if (teacher != null && teacher.isNotEmpty)
              Expanded(
                child: Text(
                  '$teacher ${post != null && post.isNotEmpty ? '($post)' : ''}',
                  style: AppTypography.bodySmall.copyWith(
                    color: isCompleted
                        ? colorScheme.onSurfaceVariant.withOpacity(0.5)
                        : colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget? _resolveTypeBadge(
    String? type,
    AppScheduleColors scheduleColors,
    ColorScheme colorScheme,
  ) {
    if (type == null || type.trim().isEmpty) return null;

    final lower = type.toLowerCase();
    Color bg;
    Color fg;

    if (lower.contains('лек')) {
      bg = scheduleColors.lectureContainer;
      fg = scheduleColors.onLectureContainer;
    } else if (lower.contains('прак')) {
      bg = scheduleColors.practiceContainer;
      fg = scheduleColors.onPracticeContainer;
    } else if (lower.contains('лаб')) {
      bg = scheduleColors.labContainer;
      fg = scheduleColors.onLabContainer;
    } else if (lower.contains('экз') || lower.contains('зач') || lower.contains('конс')) {
      bg = scheduleColors.examContainer;
      fg = scheduleColors.onExamContainer;
    } else {
      bg = colorScheme.surfaceContainerHighest;
      fg = colorScheme.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppShape.roundedSm,
      ),
      child: Text(
        type,
        style: AppTypography.labelSmall.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
