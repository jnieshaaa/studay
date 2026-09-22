import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/exam_participant_model.dart';

class HardestQuestionTile extends StatelessWidget {
  final int index;
  final HardestQuestionStat stat;

  const HardestQuestionTile({
    super.key,
    required this.index,
    required this.stat,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accuracyPercent = stat.accuracy.toInt();

    // Color based on difficulty: red (< 50%), orange (< 70%), amber (>= 70%)
    Color barColor;
    if (accuracyPercent < 50) {
      barColor = AppColors.primary;
    } else if (accuracyPercent < 70) {
      barColor = AppColors.secondary;
    } else {
      barColor = AppColors.accent;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: barColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: barColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Q$index',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: barColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$accuracyPercent% correct',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: barColor,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${stat.correctCount}/${stat.totalAttempts} correct',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              stat.questionText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: stat.accuracy / 100.0,
                minHeight: 5,
                backgroundColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
