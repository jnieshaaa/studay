import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../common/gradient_card.dart';

class AnswerExplanationBox extends StatelessWidget {
  final bool isCorrect;
  final String explanation;
  final String? reference;

  const AnswerExplanationBox({
    super.key,
    required this.isCorrect,
    required this.explanation,
    this.reference,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GradientCard(
      borderColor: isCorrect
          ? AppColors.success.withValues(alpha: 0.5)
          : AppColors.error.withValues(alpha: 0.5),
      backgroundColor: isCorrect
          ? AppColors.success.withValues(alpha: isDark ? 0.12 : 0.06)
          : AppColors.error.withValues(alpha: isDark ? 0.12 : 0.06),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCorrect ? Icons.check_circle : Icons.error_outline,
                color: isCorrect ? AppColors.success : AppColors.error,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isCorrect ? 'Correct Answer!' : 'Incorrect',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isCorrect ? AppColors.success : AppColors.error,
                ),
              ),
            ],
          ),
          if (explanation.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              explanation,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
          ],
          if (reference != null && reference!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.menu_book, size: 14, color: AppColors.secondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Reference: $reference',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
