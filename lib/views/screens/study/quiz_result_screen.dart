import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../models/quiz_session_model.dart';
import '../../../models/question_model.dart';
import '../../../controllers/study_controller.dart';
import '../../components/common/gradient_card.dart';
import '../../components/common/custom_button.dart';
import '../../components/common/stat_card.dart';

class QuizResultScreen extends ConsumerWidget {
  final QuizSession session;

  const QuizResultScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final score = session.score;
    final total = session.totalQuestions;
    final percent = session.percentage.toInt();
    final incorrectCount = total - score;

    String ratingMessage;
    Color ratingColor;
    if (percent >= 80) {
      ratingMessage = 'Outstanding Performance!';
      ratingColor = AppColors.success;
    } else if (percent >= 60) {
      ratingMessage = 'Good Job! Room for improvement.';
      ratingColor = AppColors.accent;
    } else {
      ratingMessage = 'Keep practicing! Review weak spots.';
      ratingColor = AppColors.primary;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Results', style: TextStyle(fontWeight: FontWeight.w800)),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: ResponsiveContainer(
          child: Column(
          children: [
            // Score Banner
            GradientCard(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              borderColor: ratingColor.withValues(alpha: 0.5),
              child: Column(
                children: [
                  // Circular Percentage Graphic
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.primaryGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$percent%',
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '$score / $total',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    ratingMessage,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: ratingColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    session.mode.title,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Performance Stat Tiles
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: 'Correct',
                    value: '$score',
                    icon: Icons.check_circle_outline,
                    accentColor: AppColors.success,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    title: 'Missed',
                    value: '$incorrectCount',
                    icon: Icons.highlight_off,
                    accentColor: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Quick Actions
            if (incorrectCount > 0) ...[
              CustomButton(
                text: 'Retry Missed Questions ($incorrectCount)',
                icon: Icons.replay,
                variant: ButtonVariant.primaryGradient,
                width: double.infinity,
                onPressed: () {
                  final retrySession = ref
                      .read(studyControllerProvider.notifier)
                      .buildQuizSession(mode: StudyMode.mistakesReview);
                  context.pushReplacement('/study/quiz', extra: retrySession);
                },
              ),
              const SizedBox(height: 12),
            ],

            CustomButton(
              text: 'Return to Study Mode',
              icon: Icons.arrow_back,
              variant: ButtonVariant.outline,
              width: double.infinity,
              onPressed: () => context.go('/study'),
            ),
            const SizedBox(height: 28),

            // Detailed Question Review Breakdown
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'QUESTION BREAKDOWN & EXPLANATIONS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
            ),
            const SizedBox(height: 14),

            ...session.questions.asMap().entries.map((entry) {
              final idx = entry.key;
              final q = entry.value;
              final ans = session.answers[q.id];
              final isCorrect = ans?.isCorrect ?? false;

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: GradientCard(
                  padding: const EdgeInsets.all(16),
                  borderColor: isCorrect
                      ? AppColors.success.withValues(alpha: 0.4)
                      : AppColors.error.withValues(alpha: 0.4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isCorrect
                                  ? AppColors.success.withValues(alpha: 0.15)
                                  : AppColors.error.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Q${idx + 1} • ${isCorrect ? 'Correct' : 'Incorrect'}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: isCorrect ? AppColors.success : AppColors.error,
                              ),
                            ),
                          ),
                          Icon(
                            isCorrect ? Icons.check_circle : Icons.cancel,
                            size: 18,
                            color: isCorrect ? AppColors.success : AppColors.error,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        q.questionText,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      if (q.questionType != QuestionType.matching) ...[
                        const SizedBox(height: 8),
                        ...q.choices.map((c) {
                          final isUserChoice = ans?.selectedChoiceId == c.id;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Icon(
                                  c.isCorrect
                                      ? Icons.check
                                      : (isUserChoice ? Icons.close : Icons.circle_outlined),
                                  size: 14,
                                  color: c.isCorrect
                                      ? AppColors.success
                                      : (isUserChoice ? AppColors.error : Colors.grey),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    c.choiceText,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: c.isCorrect ? FontWeight.w700 : FontWeight.w400,
                                      color: c.isCorrect
                                          ? AppColors.success
                                          : (isUserChoice ? AppColors.error : null),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                      if (q.explanation.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            q.explanation,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    ),
  );
  }
}
