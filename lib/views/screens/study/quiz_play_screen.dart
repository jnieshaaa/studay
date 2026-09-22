import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/quiz_session_model.dart';
import '../../../models/question_model.dart';
import '../../../controllers/quiz_controller.dart';
import '../../../controllers/study_controller.dart';
import '../../components/quiz/question_card.dart';
import '../../components/quiz/choice_option_tile.dart';
import '../../components/quiz/matching_question_widget.dart';
import '../../components/quiz/quiz_timer_bar.dart';
import '../../components/quiz/answer_explanation_box.dart';
import '../../components/common/custom_button.dart';

class QuizPlayScreen extends ConsumerWidget {
  final QuizSession session;

  const QuizPlayScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(quizControllerProvider(session));
    final controller = ref.read(quizControllerProvider(session).notifier);
    final studyState = ref.watch(studyControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Navigate to results screen when completed
    ref.listen(quizControllerProvider(session), (previous, next) {
      if (next.isCompleted) {
        context.pushReplacement('/study/result', extra: next.session);
      }
    });

    final currentQ = state.currentQuestion;
    if (currentQ == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isPractice = session.mode == StudyMode.practice;
    final isBookmarked = currentQ.isBookmarked ||
        (studyState.progressMap[currentQ.id]?.isBookmarked ?? false);

    // For practice mode explanation
    final currentAnswer = state.session.answers[currentQ.id];
    final isAnswerCorrect = currentAnswer?.isCorrect ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          session.mode.title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Exit Quiz',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Quit Session?'),
                  content: const Text('Your current quiz progress will not be completed.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Keep Going'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.pop();
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                      child: const Text('Quit'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              // Top progress & timer bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: QuizTimerBar(
                  remainingSeconds: state.remainingSeconds,
                  totalSeconds: session.timeLimitSeconds,
                  currentIndex: state.currentIndex,
                  totalQuestions: session.questions.length,
                ),
              ),

          // Scrollable Question Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Part / Section Banner (if quiz has multiple question types)
                  Builder(
                    builder: (context) {
                      final distinctTypes = session.questions.map((q) => q.questionType).toSet();
                      if (distinctTypes.length <= 1) return const SizedBox.shrink();

                      final sectionQuestions = session.questions.where((q) => q.questionType == currentQ.questionType).toList();
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
                                  currentQ.questionType.label.toUpperCase(),
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
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // Question Card
                  QuestionCard(
                    question: currentQ,
                    questionIndex: state.currentIndex,
                    totalQuestions: session.questions.length,
                    isBookmarked: isBookmarked,
                    onBookmarkToggle: () {
                      ref.read(studyControllerProvider.notifier).toggleBookmark(currentQ.id);
                    },
                  ),
                  const SizedBox(height: 18),

                  // Dynamic Answer Options based on QuestionType
                  if (currentQ.questionType == QuestionType.matching) ...[
                    MatchingQuestionWidget(
                      pairs: currentQ.matchingPairs,
                      userPairs: state.currentMatchingPairs,
                      activeLeft: state.selectedMatchingLeft,
                      isRevealed: isPractice && state.hasConfirmedAnswer,
                      onSelectLeft: controller.selectMatchingLeft,
                      onConnectRight: controller.connectMatchingRight,
                      onRemovePair: controller.removeMatchingPair,
                    ),
                  ] else ...[
                    // Multiple Choice & True/False Tiles
                    ...currentQ.choices.map((choice) {
                      final isSelected = state.selectedChoiceId == choice.id;

                      return ChoiceOptionTile(
                        text: choice.choiceText,
                        isSelected: isSelected,
                        isRevealed: isPractice && state.hasConfirmedAnswer,
                        isCorrect: choice.isCorrect,
                        onTap: () => controller.selectChoice(choice.id),
                      );
                    }),
                  ],

                  // Practice mode instant explanation reveal
                  if (isPractice && state.hasConfirmedAnswer) ...[
                    const SizedBox(height: 14),
                    AnswerExplanationBox(
                      isCorrect: isAnswerCorrect,
                      explanation: currentQ.explanation,
                      reference: currentQ.reference,
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // Bottom Action Bar
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
                      tooltip: 'Previous Question',
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: isPractice && !state.hasConfirmedAnswer
                        ? CustomButton(
                            text: 'Check Answer',
                            variant: ButtonVariant.primaryGradient,
                            onPressed: (state.selectedChoiceId != null ||
                                    state.currentMatchingPairs.isNotEmpty)
                                ? controller.confirmPracticeAnswer
                                : null,
                          )
                        : CustomButton(
                            text: state.isLastQuestion ? 'Finish Quiz' : 'Next Question',
                            icon: state.isLastQuestion ? Icons.check : Icons.arrow_forward,
                            variant: ButtonVariant.primaryGradient,
                            onPressed: controller.nextQuestion,
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
