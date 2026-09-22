import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/question_model.dart';
import '../../../controllers/exam_participant_controller.dart';
import '../../components/quiz/question_card.dart';
import '../../components/quiz/choice_option_tile.dart';
import '../../components/quiz/matching_question_widget.dart';
import '../../components/common/custom_button.dart';
import 'exam_participant_result_screen.dart';

class ExamPlayScreen extends ConsumerStatefulWidget {
  final ExamParticipantParam param;

  const ExamPlayScreen({super.key, required this.param});

  @override
  ConsumerState<ExamPlayScreen> createState() => _ExamPlayScreenState();
}

class _ExamPlayScreenState extends ConsumerState<ExamPlayScreen> {
  Timer? _timer;
  int _remainingSeconds = 0;
  bool _timerExpired = false;

  @override
  void initState() {
    super.initState();
    final durationMins = widget.param.exam.durationMinutes;
    if (durationMins != null && durationMins > 0) {
      _remainingSeconds = durationMins * 60;
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (_remainingSeconds > 1) {
          if (mounted) {
            setState(() {
              _remainingSeconds--;
            });
          }
        } else {
          t.cancel();
          _onTimeExpired();
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onTimeExpired() async {
    if (_timerExpired) return;
    _timerExpired = true;
    final controller = ref.read(examParticipantControllerProvider(widget.param).notifier);
    final result = await controller.submitExam();
    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Time is up! Exam has been automatically submitted.'),
          backgroundColor: AppColors.error,
        ),
      );
      context.pushReplacement(
        '/exam/result',
        extra: ExamResultParam(widget.param.exam, result),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(examParticipantControllerProvider(widget.param));
    final controller = ref.read(examParticipantControllerProvider(widget.param).notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final currentQ = state.currentQuestion;
    if (currentQ == null) {
      return const Scaffold(body: Center(child: Text('No questions found.')));
    }

    final selectedChoiceId = state.selectedChoices[currentQ.id];
    final currentMatching = state.matchingAnswers[currentQ.id] ?? {};

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(state.exam.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            Text(
              'Participant: ${state.participant.nickname}',
              style: const TextStyle(fontSize: 12, color: AppColors.secondary),
            ),
          ],
        ),
        actions: [
          if (widget.param.exam.durationMinutes != null && widget.param.exam.durationMinutes! > 0)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _remainingSeconds < 60
                    ? AppColors.error.withValues(alpha: 0.15)
                    : AppColors.secondary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _remainingSeconds < 60 ? AppColors.error : AppColors.secondary,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 16,
                    color: _remainingSeconds < 60 ? AppColors.error : AppColors.secondary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${(_remainingSeconds ~/ 60).toString().padLeft(2, '0')}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: _remainingSeconds < 60 ? AppColors.error : AppColors.secondary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
          // Progress Indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Question ${state.currentIndex + 1} of ${state.exam.questions.length}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'CODE: ${state.exam.code}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (state.currentIndex + 1) / state.exam.questions.length,
              minHeight: 5,
              backgroundColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.secondary),
            ),
          ),

          // Question Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Part / Section Banner
                  Builder(
                    builder: (context) {
                      final exam = state.exam;
                      final partNum = exam.getPartNumber(currentQ.questionType);
                      final sectionQuestions = exam.questions.where((q) => q.questionType == currentQ.questionType).toList();
                      final indexInSection = sectionQuestions.indexOf(currentQ) + 1;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.secondary.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.layers_outlined, size: 16, color: AppColors.secondary),
                                const SizedBox(width: 8),
                                Text(
                                  'PART $partNum: ${currentQ.questionType.label.toUpperCase()}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                    color: AppColors.secondary,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Question $indexInSection of ${sectionQuestions.length}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  QuestionCard(
                    question: currentQ,
                    questionIndex: state.currentIndex,
                    totalQuestions: state.exam.questions.length,
                  ),
                  const SizedBox(height: 18),

                  if (currentQ.questionType == QuestionType.matching) ...[
                    MatchingQuestionWidget(
                      pairs: currentQ.matchingPairs,
                      userPairs: currentMatching,
                      activeLeft: state.activeMatchingLeft,
                      onSelectLeft: controller.selectMatchingLeft,
                      onConnectRight: (right) =>
                          controller.connectMatchingRight(currentQ.id, right),
                      onRemovePair: (left) =>
                          controller.removeMatchingPair(currentQ.id, left),
                    ),
                  ] else ...[
                    ...currentQ.choices.map((choice) {
                      final isSelected = selectedChoiceId == choice.id;

                      return ChoiceOptionTile(
                        text: choice.choiceText,
                        isSelected: isSelected,
                        onTap: () => controller.selectChoice(currentQ.id, choice.id),
                      );
                    }),
                  ],
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),

          // Bottom Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              border: Border(
                top: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  if (state.currentIndex > 0) ...[
                    IconButton.outlined(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: controller.previousQuestion,
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: CustomButton(
                      text: state.isLastQuestion ? 'Submit Exam' : 'Next Question',
                      icon: state.isLastQuestion ? Icons.check_circle : Icons.arrow_forward,
                      isLoading: state.isSubmitting,
                      variant: ButtonVariant.primaryGradient,
                      onPressed: () async {
                        if (state.isLastQuestion) {
                          final result = await controller.submitExam();
                          if (result != null && context.mounted) {
                            context.pushReplacement(
                              '/exam/result',
                              extra: ExamResultParam(state.exam, result),
                            );
                          }
                        } else {
                          controller.nextQuestion();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  ),
);
  }
}
