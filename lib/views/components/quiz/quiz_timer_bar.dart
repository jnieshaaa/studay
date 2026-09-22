import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class QuizTimerBar extends StatelessWidget {
  final int remainingSeconds;
  final int totalSeconds;
  final int currentIndex;
  final int totalQuestions;

  const QuizTimerBar({
    super.key,
    required this.remainingSeconds,
    required this.totalSeconds,
    required this.currentIndex,
    required this.totalQuestions,
  });

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final questionProgress = totalQuestions > 0 ? (currentIndex + 1) / totalQuestions : 0.0;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Question counter
            Text(
              'Question ${currentIndex + 1} of $totalQuestions',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            // Timer countdown if active
            if (totalSeconds > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: remainingSeconds < 30
                      ? AppColors.error.withValues(alpha: 0.15)
                      : AppColors.secondary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 15,
                      color: remainingSeconds < 30 ? AppColors.error : AppColors.secondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatTime(remainingSeconds),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: remainingSeconds < 30 ? AppColors.error : AppColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        // Progress bar with warm gradient
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 6,
            child: LinearProgressIndicator(
              value: questionProgress,
              backgroundColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.secondary),
            ),
          ),
        ),
      ],
    );
  }
}
