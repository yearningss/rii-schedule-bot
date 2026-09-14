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
    final isDark = theme.brightness == Brightness.dark;

    Color borderColor = Colors.transparent;
    Color cardBg = isDark ? const Color(0xFF1E232D) : Colors.white;

    if (isOngoing) {
      borderColor = const Color(0xFF2563EB);
      cardBg = isDark ? const Color(0xFF19253B) : const Color(0xFFEFF6FF);
    } else if (isNext) {
      borderColor = const Color(0xFF10B981);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor != Colors.transparent ? borderColor : (isDark ? const Color(0xFF2C3340) : const Color(0xFFE2E8F0)),
          width: isOngoing || isNext ? 1.8 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
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
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${timeInfo.startStr} - ${timeInfo.endStr}',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                if (isOngoing)
                  _buildBadge('Идет сейчас', const Color(0xFF2563EB), Colors.white)
                else if (isNext)
                  _buildBadge('Следующая', const Color(0xFF10B981), Colors.white)
                else if (isCompleted)
                  _buildBadge('Завершена', Colors.grey[600]!, Colors.grey[300]!),
              ],
            ),
            const SizedBox(height: 10),

            // Контент пары
            if (item.isDouble) ...[
              if ((activeSubgroup == 0 || activeSubgroup == 1) && (item.subj1 != null || item.aud1 != null))
                _buildSubgroupSection(
                  context,
                  title: '1 подгруппа',
                  subject: item.subj1,
                  type: item.type1,
                  aud: item.aud1,
                  teacher: item.teacher1,
                  post: item.teachPost1,
                ),
              if (activeSubgroup == 0 && (item.subj1 != null) && (item.subj2 != null))
                const Divider(height: 16),
              if ((activeSubgroup == 0 || activeSubgroup == 2) && (item.subj2 != null || item.aud2 != null))
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
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(color: textCol, fontSize: 11, fontWeight: FontWeight.w600),
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
            color: const Color(0xFF2563EB).withOpacity(0.12),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            title,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
          ),
        ),
        const SizedBox(height: 4),
        _buildSubjectContent(context, subject: subject, type: type, aud: aud, teacher: teacher, post: post),
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
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            if (type != null && type.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2B3240) : const Color(0xFFE2E8F0),
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
                  color: const Color(0xFF10B981).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'ауд. $aud',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF059669),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (teacher != null && teacher.isNotEmpty)
              Expanded(
                child: Text(
                  '$teacher ${post != null && post.isNotEmpty ? '($post)' : ''}',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
