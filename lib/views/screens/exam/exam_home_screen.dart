import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../controllers/providers.dart';
import '../../../controllers/auth_controller.dart';
import '../../components/common/gradient_card.dart';
import '../../components/common/custom_button.dart';

class ExamHomeScreen extends ConsumerWidget {
  const ExamHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final examService = ref.watch(examServiceProvider);
    final sampleExam = examService.getExamByCode('4F9K2Q');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exam Mode', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SingleChildScrollView(
        child: ResponsiveContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Minimalist Intro Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161620) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark ? const Color(0xFF28283A) : const Color(0xFFE4E4EC),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E2A) : const Color(0xFFF0F0F5),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDark ? const Color(0xFF28283A) : const Color(0xFFE4E4EC),
                        ),
                      ),
                      child: const Text(
                        'HOST & JOIN EXAMS WITH CODES',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.secondary,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'No Sign-Up Required For Joiners',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? const Color(0xFFF3F3F7) : const Color(0xFF1B1B24),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Makers create exams and generate a 6-character code. Participants take it at their own pace.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFF8E8EA2) : const Color(0xFF707084),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Main Choices: Join vs Create
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 500;
                  final joinCard = GradientCard(
                    onTap: () => context.push('/exam/join'),
                    padding: const EdgeInsets.all(18),
                    borderColor: AppColors.secondary.withValues(alpha: 0.4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.login, color: AppColors.secondary, size: 24),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Join Exam',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Enter 6-char code & nickname to take an exam.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  );

                  final createCard = GradientCard(
                    onTap: () {
                      final authState = ref.read(authControllerProvider);
                      if (!authState.isAuthenticated) {
                        context.push('/login', extra: '/exam/maker');
                      } else {
                        context.push('/exam/maker');
                      }
                    },
                    padding: const EdgeInsets.all(18),
                    borderColor: AppColors.accent.withValues(alpha: 0.4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.add_task, color: AppColors.accent, size: 24),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Create Exam',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Build MCQ, True/False, and Matching quizzes.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  );

                  if (isNarrow) {
                    return Column(
                      children: [
                        joinCard,
                        const SizedBox(height: 14),
                        createCard,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: joinCard),
                      const SizedBox(width: 14),
                      Expanded(child: createCard),
                    ],
                  );
                },
              ),
              const SizedBox(height: 28),

              // Pre-Seeded Sample Exam from Proposal v2 Section 7 & 8
              if (sampleExam != null) ...[
                Text(
                  'FEATURED DEMO EXAM (FROM PROPOSAL V2)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 12),
                GradientCard(
                  padding: const EdgeInsets.all(18),
                  borderColor: AppColors.secondary.withValues(alpha: 0.5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.secondary.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              'CODE: ${sampleExam.code}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: AppColors.secondary,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'ACTIVE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        sampleExam.title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sampleExam.description,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 450;
                          final joinBtn = CustomButton(
                            text: 'Join as Participant',
                            icon: Icons.play_arrow,
                            variant: ButtonVariant.primaryGradient,
                            height: 42,
                            onPressed: () {
                              context.push('/exam/join', extra: sampleExam.code);
                            },
                          );

                          final dashBtn = OutlinedButton(
                            onPressed: () {
                              context.push('/exam/dashboard/${sampleExam.id}');
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.secondary),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            ),
                            child: const Text(
                              'Maker Dashboard',
                              style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.w700),
                            ),
                          );

                          if (isNarrow) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                joinBtn,
                                const SizedBox(height: 10),
                                dashBtn,
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(child: joinBtn),
                              const SizedBox(width: 10),
                              dashBtn,
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
