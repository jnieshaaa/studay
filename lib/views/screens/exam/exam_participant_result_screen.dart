import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../models/exam_model.dart';
import '../../../models/exam_participant_model.dart';
import '../../components/common/gradient_card.dart';
import '../../components/common/custom_button.dart';

class ExamResultParam {
  final Exam exam;
  final ExamParticipant participant;
  const ExamResultParam(this.exam, this.participant);
}

class ExamParticipantResultScreen extends StatelessWidget {
  final ExamResultParam param;

  const ExamParticipantResultScreen({super.key, required this.param});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final exam = param.exam;
    final participant = param.participant;
    final showMode = exam.showAnswers;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exam Submitted', style: TextStyle(fontWeight: FontWeight.w800)),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: ResponsiveContainer(
          maxWidth: 600,
          child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.primaryGradient,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 44),
            ),
            const SizedBox(height: 20),
            const Text(
              'Exam Successfully Submitted!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Thank you, ${participant.nickname}. Your responses have been recorded.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 28),

            // Result Display based on Maker's ShowAnswersMode setting
            if (showMode == ShowAnswersMode.immediately) ...[
              GradientCard(
                padding: const EdgeInsets.all(24),
                borderColor: AppColors.success.withValues(alpha: 0.5),
                child: Column(
                  children: [
                    const Text(
                      'YOUR SCORE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${participant.score} / ${participant.totalQuestions}',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${participant.percentage.toInt()}% accuracy',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ] else if (showMode == ShowAnswersMode.afterClose) ...[
              GradientCard(
                padding: const EdgeInsets.all(20),
                borderColor: AppColors.accent.withValues(alpha: 0.4),
                child: Column(
                  children: [
                    const Icon(Icons.lock_clock, size: 36, color: AppColors.accent),
                    const SizedBox(height: 10),
                    const Text(
                      'Scores Released After Exam Closes',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Per the maker\'s policy, scores and answer keys will be revealed once all submissions have closed.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              GradientCard(
                padding: const EdgeInsets.all(20),
                borderColor: AppColors.secondary.withValues(alpha: 0.4),
                child: Column(
                  children: [
                    const Icon(Icons.visibility_off, size: 36, color: AppColors.secondary),
                    const SizedBox(height: 10),
                    const Text(
                      'Maker-Only Scoring',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your results have been sent directly to the exam administrator.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),

            CustomButton(
              text: 'Return Home',
              variant: ButtonVariant.primaryGradient,
              width: double.infinity,
              onPressed: () => context.go('/'),
            ),
          ],
        ),
      ),
    ),
  );
}
}
