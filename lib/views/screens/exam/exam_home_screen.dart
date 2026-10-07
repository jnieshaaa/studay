import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../controllers/providers.dart';
import '../../../controllers/auth_controller.dart';
import '../../../models/exam_model.dart';
import '../../components/common/gradient_card.dart';
import '../../components/common/custom_button.dart';

class ExamHomeScreen extends ConsumerWidget {
  const ExamHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final examService = ref.watch(examServiceProvider);
    final publishedExams = examService.allExams
        .where((e) => e.status == ExamStatus.published)
        .toList();

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

              // Main Choices: Join vs Create in one row
              Row(
                children: [
                  Expanded(
                    child: GradientCard(
                      onTap: () => context.push('/exam/join'),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                      borderColor: AppColors.secondary.withValues(alpha: 0.4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.login, color: AppColors.secondary, size: 22),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Join Exam',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GradientCard(
                      onTap: () {
                        final authState = ref.read(authControllerProvider);
                        if (!authState.isAuthenticated) {
                          context.push('/login', extra: '/exam/maker');
                        } else {
                          context.push('/exam/maker');
                        }
                      },
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                      borderColor: AppColors.accent.withValues(alpha: 0.4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.add_task, color: AppColors.accent, size: 22),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Create Exam',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Active / Published Exams
              if (publishedExams.isNotEmpty) ...[
                Text(
                  'ACTIVE EXAMS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 12),
                ...publishedExams.take(3).map((exam) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GradientCard(
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
                                  'CODE: ${exam.code}',
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
                                child: Text(
                                  exam.effectiveSubject,
                                  style: const TextStyle(
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
                            exam.title,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                          if (exam.description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              exam.description,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
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
                                  context.push('/exam/join', extra: exam.code);
                                },
                              );

                              final dashBtn = OutlinedButton(
                                onPressed: () {
                                  context.push('/exam/dashboard/${exam.id}');
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
                  );
                }),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
