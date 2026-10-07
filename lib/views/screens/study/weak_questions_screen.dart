import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../controllers/study_controller.dart';
import '../../../models/quiz_session_model.dart';
import '../../components/common/gradient_card.dart';
import '../../components/common/custom_button.dart';

class WeakQuestionsScreen extends ConsumerWidget {
  const WeakQuestionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final studyState = ref.watch(studyControllerProvider);
    final studyNotifier = ref.read(studyControllerProvider.notifier);
    final performances = studyState.subjectPerformances;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weak Questions Review', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SingleChildScrollView(
        child: ResponsiveContainer(
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Info Card
            GradientCard(
              padding: const EdgeInsets.all(20),
              borderColor: AppColors.primary.withValues(alpha: 0.4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.psychology, color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Targeted Mastery Engine',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                            Text(
                              'Prioritizes subjects and concepts you missed most',
                              style: TextStyle(fontSize: 12, color: AppColors.secondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Questions with under 65% accuracy or repeated mistakes are flagged for rapid reinforcement.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // All Weak Questions Quick Launch
            if (studyState.weakQuestions.isNotEmpty) ...[
              CustomButton(
                text: 'Launch All Weak Questions Quiz (${studyState.weakQuestions.length})',
                icon: Icons.local_fire_department,
                variant: ButtonVariant.primaryGradient,
                width: double.infinity,
                onPressed: () {
                  final session = studyNotifier.buildQuizSession(mode: StudyMode.weakQuestions);
                  context.push('/study/quiz', extra: session);
                },
              ),
              const SizedBox(height: 24),
            ],

            // Per-Subject Accuracy Breakdown
            Text(
              'YOUR PERFORMANCE BY SUBJECT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 12),

            ...performances.map((perf) {
              final accuracy = perf.accuracy.toInt();
              final isWeak = accuracy < 65;
              final statusColor = isWeak ? AppColors.primary : AppColors.success;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GradientCard(
                  padding: const EdgeInsets.all(16),
                  borderColor: isWeak
                      ? AppColors.primary.withValues(alpha: 0.4)
                      : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                if (isWeak) ...[
                                  const Icon(Icons.warning_amber_rounded,
                                      size: 18, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                ],
                                Expanded(
                                  child: Text(
                                    perf.subjectName,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$accuracy%',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${perf.correctCount}/${perf.answeredCount} answered correctly • ${perf.weakQuestionsCount} weak questions',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: perf.accuracy / 100.0,
                          minHeight: 6,
                          backgroundColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.play_arrow, size: 16),
                          label: const Text('Review Subject'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.secondary,
                            side: const BorderSide(color: AppColors.secondary),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                          onPressed: () {
                            final session = studyNotifier.buildQuizSession(
                              mode: StudyMode.weakQuestions,
                              subjectId: perf.subjectId,
                            );
                            context.push('/study/quiz', extra: session);
                          },
                        ),
                      ),
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
