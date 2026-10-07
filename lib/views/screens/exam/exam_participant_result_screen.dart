import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../models/exam_model.dart';
import '../../../models/exam_participant_model.dart';
import '../../../models/question_model.dart';
import '../../../controllers/providers.dart';
import '../../components/common/gradient_card.dart';
import '../../components/common/custom_button.dart';

enum QuestionReviewFilter { all, correct, incorrect }

class ExamResultParam {
  final Exam exam;
  final ExamParticipant participant;
  final List<ExamResponse> responses;
  const ExamResultParam(this.exam, this.participant, {this.responses = const []});
}

class ExamParticipantResultScreen extends ConsumerStatefulWidget {
  final ExamResultParam param;

  const ExamParticipantResultScreen({super.key, required this.param});

  @override
  ConsumerState<ExamParticipantResultScreen> createState() =>
      _ExamParticipantResultScreenState();
}

class _ExamParticipantResultScreenState
    extends ConsumerState<ExamParticipantResultScreen> {
  QuestionReviewFilter _filter = QuestionReviewFilter.all;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final exam = widget.param.exam;
    final participant = widget.param.participant;
    final showMode = exam.showAnswers;

    // Get responses from param or lookup from service
    final responses = widget.param.responses.isNotEmpty
        ? widget.param.responses
        : ref
            .watch(examServiceProvider)
            .getResponsesForParticipant(exam.id, participant.id);

    final responsesMap = {for (final r in responses) r.questionId: r};

    final total = participant.totalQuestions > 0
        ? participant.totalQuestions
        : exam.questions.length;
    final score = participant.score;
    final incorrectCount = (total - score).clamp(0, total);
    final percent = participant.percentage.toInt();

    String ratingMessage;
    Color ratingColor;
    if (percent >= 80) {
      ratingMessage = '🎉 Outstanding Performance!';
      ratingColor = AppColors.success;
    } else if (percent >= 60) {
      ratingMessage = '👍 Good Job! Passing Score';
      ratingColor = AppColors.accent;
    } else {
      ratingMessage = '💪 Keep Practicing & Review Mistakes';
      ratingColor = AppColors.primary;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exam Results', style: TextStyle(fontWeight: FontWeight.w800)),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: ResponsiveContainer(
          maxWidth: 700,
          child: Column(
            children: [
              // Header Checkmark
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.primaryGradient,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 16),
              const Text(
                'Exam Submitted Successfully!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Great job, ${participant.nickname}. Here is your result breakdown.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 24),

              // Mode 1: Maker set ShowAnswersMode.immediately (Default)
              if (showMode == ShowAnswersMode.immediately) ...[
                // Score Summary Card
                GradientCard(
                  padding: const EdgeInsets.all(22),
                  borderColor: ratingColor.withValues(alpha: 0.5),
                  child: Column(
                    children: [
                      Text(
                        ratingMessage,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: ratingColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$score',
                            style: TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.w900,
                              color: ratingColor,
                            ),
                          ),
                          Text(
                            ' / $total',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$percent% accuracy',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 16),
                      // Stats Row
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem(
                              icon: Icons.check_circle_outline,
                              color: AppColors.success,
                              label: 'Correct',
                              value: '$score',
                            ),
                            Container(width: 1, height: 24, color: isDark ? Colors.white12 : Colors.black12),
                            _buildStatItem(
                              icon: Icons.cancel_outlined,
                              color: AppColors.error,
                              label: 'Incorrect',
                              value: '$incorrectCount',
                            ),
                            Container(width: 1, height: 24, color: isDark ? Colors.white12 : Colors.black12),
                            _buildStatItem(
                              icon: Icons.assignment_outlined,
                              color: AppColors.secondary,
                              label: 'Total Qs',
                              value: '$total',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Question Breakdown Section Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Question Breakdown',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Review which questions you got right & wrong.',
                          style: TextStyle(fontSize: 11.5, color: Colors.grey),
                        ),
                      ],
                    ),
                    // Filter Chips
                    Row(
                      children: [
                        _buildFilterChip('All ($total)', QuestionReviewFilter.all),
                        const SizedBox(width: 6),
                        _buildFilterChip('✓ Correct ($score)', QuestionReviewFilter.correct,
                            activeColor: AppColors.success),
                        const SizedBox(width: 6),
                        _buildFilterChip('✗ Wrong ($incorrectCount)', QuestionReviewFilter.incorrect,
                            activeColor: AppColors.error),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Questions Review List
                ...exam.questions.asMap().entries.map((entry) {
                  final qIdx = entry.key;
                  final q = entry.value;
                  final resp = responsesMap[q.id];
                  final isCorrect = resp?.isCorrect ?? false;

                  // Filter check
                  if (_filter == QuestionReviewFilter.correct && !isCorrect) {
                    return const SizedBox.shrink();
                  }
                  if (_filter == QuestionReviewFilter.incorrect && isCorrect) {
                    return const SizedBox.shrink();
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: GradientCard(
                      padding: const EdgeInsets.all(16),
                      borderColor: isCorrect
                          ? AppColors.success.withValues(alpha: 0.45)
                          : AppColors.error.withValues(alpha: 0.45),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Card Header: Question index, Part, and Status Badge
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Question ${qIdx + 1} • ${q.questionType.label}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isCorrect
                                      ? AppColors.success.withValues(alpha: 0.15)
                                      : AppColors.error.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isCorrect
                                        ? AppColors.success.withValues(alpha: 0.4)
                                        : AppColors.error.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isCorrect ? Icons.check_circle : Icons.cancel,
                                      size: 13,
                                      color: isCorrect ? AppColors.success : AppColors.error,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isCorrect ? 'Correct (+${q.points} pt)' : 'Incorrect (0 pts)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: isCorrect ? AppColors.success : AppColors.error,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Question Text
                          Text(
                            q.questionText,
                            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 12),

                          // Answers Breakdown: Multiple Choice & True/False
                          if (q.questionType != QuestionType.matching) ...[
                            if (resp?.selectedChoiceId == null)
                              Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.info_outline, size: 14, color: AppColors.error),
                                    SizedBox(width: 6),
                                    Text(
                                      'No answer was selected for this question.',
                                      style: TextStyle(fontSize: 11.5, color: AppColors.error),
                                    ),
                                  ],
                                ),
                              ),
                            ...q.choices.asMap().entries.map((choiceEntry) {
                              final cIdx = choiceEntry.key;
                              final c = choiceEntry.value;
                              final isUserChoice = resp?.selectedChoiceId == c.id;
                              final isCorrectChoice = c.isCorrect;
                              final letter = String.fromCharCode(65 + cIdx);

                              Color? bgColor;
                              Border? border;
                              Widget statusBadge = const SizedBox.shrink();

                              if (isUserChoice && isCorrectChoice) {
                                // User picked the correct answer
                                bgColor = AppColors.success.withValues(alpha: 0.14);
                                border = Border.all(color: AppColors.success, width: 1.5);
                                statusBadge = _buildAnswerTag('✓ Your Answer (Correct)', AppColors.success);
                              } else if (isUserChoice && !isCorrectChoice) {
                                // User picked wrong answer
                                bgColor = AppColors.error.withValues(alpha: 0.14);
                                border = Border.all(color: AppColors.error, width: 1.5);
                                statusBadge = _buildAnswerTag('✗ Your Answer', AppColors.error);
                              } else if (!isUserChoice && isCorrectChoice) {
                                // The actual correct answer (which user missed)
                                bgColor = AppColors.success.withValues(alpha: 0.08);
                                border = Border.all(color: AppColors.success.withValues(alpha: 0.7), width: 1.2);
                                statusBadge = _buildAnswerTag('✓ Correct Answer', AppColors.success);
                              } else {
                                // Neutral option
                                bgColor = isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02);
                                border = Border.all(color: isDark ? Colors.white10 : Colors.black12);
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: bgColor,
                                  borderRadius: BorderRadius.circular(8),
                                  border: border,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 22,
                                      height: 22,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: isCorrectChoice
                                            ? AppColors.success.withValues(alpha: 0.2)
                                            : (isUserChoice ? AppColors.error.withValues(alpha: 0.2) : Colors.transparent),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        letter,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: isCorrectChoice
                                              ? AppColors.success
                                              : (isUserChoice ? AppColors.error : (isDark ? Colors.white70 : Colors.black87)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        c.choiceText,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: (isUserChoice || isCorrectChoice)
                                              ? FontWeight.w700
                                              : FontWeight.w400,
                                        ),
                                      ),
                                    ),
                                    statusBadge,
                                  ],
                                ),
                              );
                            }),
                          ] else ...[
                            // Matching Type Answers Breakdown
                            ...q.matchingPairs.map((pair) {
                              final userMatch = resp?.matchingResponse[pair.leftText];
                              final isPairCorrect = userMatch == pair.rightText;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isPairCorrect
                                      ? AppColors.success.withValues(alpha: 0.08)
                                      : AppColors.error.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isPairCorrect
                                        ? AppColors.success.withValues(alpha: 0.4)
                                        : AppColors.error.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          isPairCorrect ? Icons.check_circle : Icons.cancel,
                                          size: 14,
                                          color: isPairCorrect ? AppColors.success : AppColors.error,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            '${pair.leftText} ➔ ${userMatch ?? "Unanswered"}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: isPairCorrect ? AppColors.success : AppColors.error,
                                            ),
                                          ),
                                        ),
                                        _buildAnswerTag(
                                          isPairCorrect ? 'Matched' : 'Incorrect',
                                          isPairCorrect ? AppColors.success : AppColors.error,
                                        ),
                                      ],
                                    ),
                                    if (!isPairCorrect) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        '✓ Correct Match: ${pair.leftText} ➔ ${pair.rightText}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.success,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }),
                          ],

                          // Explanation Box (if creator added an explanation)
                          if (q.explanation.trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1B1B26) : const Color(0xFFF6F6FD),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark ? Colors.white12 : Colors.black12,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.lightbulb_outline, size: 14, color: AppColors.secondary),
                                      SizedBox(width: 4),
                                      Text(
                                        'Explanation',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.secondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    q.explanation.trim(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      height: 1.35,
                                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
              ] else if (showMode == ShowAnswersMode.afterClose) ...[
                // Mode 2: ShowAnswersMode.afterClose
                GradientCard(
                  padding: const EdgeInsets.all(20),
                  borderColor: AppColors.accent.withValues(alpha: 0.4),
                  child: Column(
                    children: [
                      const Icon(Icons.lock_clock, size: 36, color: AppColors.accent),
                      const SizedBox(height: 10),
                      const Text(
                        'Scores & Answers Released After Exam Closes',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Per the exam creator\'s settings, the answer key and per-question score breakdown will be revealed once submissions close.',
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
                // Mode 3: ShowAnswersMode.never
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
                      const SizedBox(height: 6),
                      Text(
                        'The creator has configured this exam for administrator-only scoring. Your responses have been securely delivered.',
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
              const SizedBox(height: 28),

              // Return Home Button
              CustomButton(
                text: 'Return Home',
                variant: ButtonVariant.primaryGradient,
                width: double.infinity,
                onPressed: () => context.go('/'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, QuestionReviewFilter filter, {Color? activeColor}) {
    final isSelected = _filter == filter;
    final color = activeColor ?? AppColors.secondary;

    return InkWell(
      onTap: () => setState(() => _filter = filter),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.grey.withValues(alpha: 0.3),
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
            color: isSelected ? color : null,
          ),
        ),
      ),
    );
  }

  Widget _buildAnswerTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
