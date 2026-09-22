import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/question_model.dart';

class CustomBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool isSmall;

  const CustomBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.isSmall = false,
  });

  factory CustomBadge.difficulty(Difficulty difficulty) {
    switch (difficulty) {
      case Difficulty.easy:
        return CustomBadge(
          label: 'Easy',
          color: AppColors.highlight,
          icon: Icons.bolt,
        );
      case Difficulty.medium:
        return CustomBadge(
          label: 'Medium',
          color: AppColors.accent,
          icon: Icons.trending_up,
        );
      case Difficulty.hard:
        return CustomBadge(
          label: 'Hard',
          color: AppColors.primary,
          icon: Icons.local_fire_department,
        );
    }
  }

  factory CustomBadge.questionType(QuestionType type) {
    switch (type) {
      case QuestionType.multipleChoice:
        return CustomBadge(
          label: 'Multiple Choice',
          color: AppColors.secondary,
          icon: Icons.check_circle_outline,
        );
      case QuestionType.trueFalse:
        return CustomBadge(
          label: 'True / False',
          color: AppColors.tertiary,
          icon: Icons.rule,
        );
      case QuestionType.matching:
        return CustomBadge(
          label: 'Matching',
          color: AppColors.accent,
          icon: Icons.sync_alt,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 8 : 12,
        vertical: isSmall ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: isSmall ? 13 : 15,
              color: color,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: isSmall ? 11 : 12.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
