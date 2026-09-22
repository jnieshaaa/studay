import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/exam_participant_model.dart';

class LeaderboardTile extends StatelessWidget {
  final int rank;
  final ExamParticipant participant;

  const LeaderboardTile({
    super.key,
    required this.rank,
    required this.participant,
  });

  Color _getRankColor() {
    switch (rank) {
      case 1:
        return AppColors.highlight; // Gold
      case 2:
        return const Color(0xFFC0C0C0); // Silver
      case 3:
        return AppColors.tertiary; // Bronze
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSubmitted = participant.status == ParticipantStatus.submitted;
    final rankColor = _getRankColor();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: rank <= 3
                ? rankColor.withValues(alpha: 0.5)
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: rank <= 3 ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Rank Badge
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: rank <= 3 ? rankColor.withValues(alpha: 0.2) : Colors.transparent,
              ),
              alignment: Alignment.center,
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: rank <= 3 ? rankColor : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Nickname & Status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    participant.nickname,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                  ),
                  Text(
                    isSubmitted ? 'Completed' : 'Taking exam...',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isSubmitted
                          ? AppColors.success
                          : (isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight),
                    ),
                  ),
                ],
              ),
            ),
            // Score
            if (isSubmitted)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${participant.score}/${participant.totalQuestions}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              )
            else
              const Icon(Icons.hourglass_top, size: 18, color: AppColors.accent),
          ],
        ),
      ),
    );
  }
}
