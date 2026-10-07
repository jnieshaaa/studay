import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/question_model.dart';
import '../common/custom_badge.dart';
import '../common/gradient_card.dart';

class QuestionCard extends StatelessWidget {
  final Question question;
  final int questionIndex;
  final int totalQuestions;
  final bool isBookmarked;
  final VoidCallback? onBookmarkToggle;

  const QuestionCard({
    super.key,
    required this.question,
    required this.questionIndex,
    required this.totalQuestions,
    this.isBookmarked = false,
    this.onBookmarkToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GradientCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Index + Badges wrapped flexibly
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Q ${questionIndex + 1}/$totalQuestions',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    CustomBadge.questionType(question.questionType),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              // Bookmark action
              IconButton(
                icon: Icon(
                  isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  color: isBookmarked
                      ? AppColors.accent
                      : (isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight),
                ),
                onPressed: onBookmarkToggle,
                tooltip: isBookmarked ? 'Remove Star' : 'Star for review',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            question.questionText,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              height: 1.45,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
        ],
      ),
    );
  }
}
