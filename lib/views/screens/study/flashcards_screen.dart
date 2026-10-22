import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../models/question_model.dart';
import '../../../controllers/flashcard_controller.dart';
import '../../components/common/gradient_card.dart';
import '../../components/common/custom_button.dart';

enum FlashcardStudyMode {
  review, // Classic front/back flip card
  quiz, // Type-in recall quiz with Pass and validation
}

class FlashcardArgs {
  final List<Question> questions;
  final FlashcardStudyMode mode;

  const FlashcardArgs({
    required this.questions,
    this.mode = FlashcardStudyMode.review,
  });
}

enum QuizFeedback {
  none,
  correct,
  incorrect,
  passed,
}

class FlashcardsScreen extends ConsumerStatefulWidget {
  final List<Question> questions;
  final FlashcardStudyMode initialMode;

  const FlashcardsScreen({
    super.key,
    required this.questions,
    this.initialMode = FlashcardStudyMode.review,
  });

  @override
  ConsumerState<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends ConsumerState<FlashcardsScreen> {
  late FlashcardStudyMode _mode;
  QuizFeedback _feedback = QuizFeedback.none;
  int _lastCardIndex = 0;
  String _submittedAnswer = '';

  late final TextEditingController _answerController;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _answerController = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _answerController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _resetInputState() {
    _answerController.clear();
    _submittedAnswer = '';
    setState(() {
      _feedback = QuizFeedback.none;
    });
  }

  bool _evaluateAnswer(String input, String expected) {
    String normalize(String s) => s
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ');

    final cleanInput = normalize(input);
    final cleanExpected = normalize(expected);

    if (cleanInput.isEmpty || cleanExpected.isEmpty) return false;
    if (cleanInput == cleanExpected) return true;

    // Check if input matches expected without parenthetical details
    final withoutParens =
        normalize(expected.replaceAll(RegExp(r'\(.*?\)'), ''));
    if (withoutParens.isNotEmpty && cleanInput == withoutParens) return true;

    return false;
  }

  void _submitAnswer(FlashcardController controller, String correctAnswer) {
    final typed = _answerController.text.trim();
    if (typed.isEmpty) return;

    _focusNode.unfocus();
    final isCorrect = _evaluateAnswer(typed, correctAnswer);

    setState(() {
      _submittedAnswer = typed;
      _feedback = isCorrect ? QuizFeedback.correct : QuizFeedback.incorrect;
    });
  }

  void _passQuestion(String correctAnswer) {
    _focusNode.unfocus();
    setState(() {
      _feedback = QuizFeedback.passed;
    });
  }

  void _proceedNext(FlashcardController controller, {required bool isCorrect}) {
    _resetInputState();
    if (isCorrect) {
      controller.markKnown();
    } else {
      controller.markStillLearning();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(flashcardControllerProvider(widget.questions));
    final controller =
        ref.read(flashcardControllerProvider(widget.questions).notifier);

    // If card index changed, reset input state
    if (state.currentIndex != _lastCardIndex) {
      _lastCardIndex = state.currentIndex;
      _resetInputState();
    }

    if (widget.questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Flashcards')),
        body:
            const Center(child: Text('No questions available for flashcards.')),
      );
    }

    if (state.isCompleted) {
      return Scaffold(
        appBar: AppBar(title: const Text('Deck Completed')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.primaryGradient,
                ),
                child: const Icon(Icons.star, size: 48, color: Colors.white),
              ),
              const SizedBox(height: 20),
              const Text(
                'Deck Completed!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text(
                'Mastered: ${state.knownCount} • Still Learning: ${state.learningCount}',
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 32),
              CustomButton(
                text: _mode == FlashcardStudyMode.review
                    ? 'Study Deck Again (Flip Cards)'
                    : 'Study Deck Again (Type Quiz)',
                icon: Icons.replay,
                variant: ButtonVariant.primaryGradient,
                width: double.infinity,
                onPressed: () {
                  _resetInputState();
                  controller.reset();
                },
              ),
              const SizedBox(height: 10),
              CustomButton(
                text: _mode == FlashcardStudyMode.review
                    ? 'Switch to Type-in Quiz'
                    : 'Switch to Card Flip Review',
                icon: _mode == FlashcardStudyMode.review
                    ? Icons.edit_note_rounded
                    : Icons.flip_to_back_rounded,
                variant: ButtonVariant.secondary,
                width: double.infinity,
                onPressed: () {
                  setState(() {
                    _mode = _mode == FlashcardStudyMode.review
                        ? FlashcardStudyMode.quiz
                        : FlashcardStudyMode.review;
                  });
                  _resetInputState();
                  controller.reset();
                },
              ),
              const SizedBox(height: 10),
              CustomButton(
                text: 'Return to Study',
                variant: ButtonVariant.outline,
                width: double.infinity,
                onPressed: () => context.pop(),
              ),
            ],
          ),
        ),
      );
    }

    final card = state.currentCard!;
    final correctAnswer = card.questionType == QuestionType.matching
        ? card.matchingPairs
            .map((p) => '${p.leftText} ➔ ${p.rightText}')
            .join('\n')
        : (card.choices.where((c) => c.isCorrect).firstOrNull?.choiceText ??
            'See explanation');

    final displayText = state.isFlipped ? correctAnswer : card.questionText;
    final isCodeOrMultiline = displayText.contains('\n') ||
        displayText.contains('{') ||
        displayText.contains('class ') ||
        displayText.contains('function ') ||
        displayText.contains('=>');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flashcards Focus',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.shuffle_rounded, size: 20),
            tooltip: 'Shuffle Cards',
            onPressed: () {
              _resetInputState();
              controller.shuffleDeck();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Shuffled flashcard deck randomly!'),
                  duration: Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          if (widget.questions.length > 10)
            PopupMenuButton<int>(
              icon: const Icon(Icons.tune_rounded, size: 20),
              tooltip: 'Sample Size (Random Draw)',
              onSelected: (limit) {
                _resetInputState();
                if (limit == 0) {
                  ref.invalidate(
                      flashcardControllerProvider(widget.questions));
                } else {
                  controller.sampleDeck(limit);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Practicing $limit random cards without repetition!'),
                      duration: const Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 0,
                  child: Text('All Cards'),
                ),
                ...[10, 20, 25, 50]
                    .where((n) => n < widget.questions.length)
                    .map(
                      (n) => PopupMenuItem(
                        value: n,
                        child: Text('Practice $n Random Cards'),
                      ),
                    ),
              ],
            ),
          if (state.currentIndex > 0)
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 18),
              tooltip: 'Previous Card',
              onPressed: () {
                _resetInputState();
                controller.previousCard();
              },
            ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(left: 8, right: 16),
              child: Text(
                '${state.currentIndex + 1}/${state.deck.length}',
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          maxWidth: 650,
          child: Column(
            children: [
              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (state.currentIndex + 1) / state.deck.length,
                  minHeight: 6,
                  backgroundColor:
                      isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.secondary),
                ),
              ),
              const SizedBox(height: 14),

              // Dedicated Mode Header Indicator (no switching mid-session)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF14141E) : const Color(0xFFEBEBF2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF242436) : const Color(0xFFDCDCE8),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _mode == FlashcardStudyMode.review
                          ? Icons.flip_to_back_rounded
                          : Icons.edit_note_rounded,
                      size: 16,
                      color: _mode == FlashcardStudyMode.review
                          ? AppColors.secondary
                          : AppColors.tertiary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _mode == FlashcardStudyMode.review
                          ? 'Card Flip Review'
                          : 'Type-in Quiz',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _mode == FlashcardStudyMode.review
                            ? AppColors.secondary
                            : AppColors.tertiary,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Mode 1: Review Mode (Interactive 3D Flip Card)
              if (_mode == FlashcardStudyMode.review) ...[
                Expanded(
                  child: GestureDetector(
                    onTap: controller.flip,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) {
                        return ScaleTransition(scale: animation, child: child);
                      },
                      child: GradientCard(
                        key: ValueKey(state.isFlipped),
                        padding: const EdgeInsets.all(24),
                        borderColor: state.isFlipped
                            ? AppColors.secondary.withValues(alpha: 0.6)
                            : AppColors.primary.withValues(alpha: 0.4),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: (state.isFlipped
                                        ? AppColors.secondary
                                        : AppColors.primary)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                state.isFlipped
                                    ? 'ANSWER / BACK'
                                    : 'QUESTION / FRONT',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                  color: state.isFlipped
                                      ? AppColors.secondary
                                      : AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: Center(
                                child: SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  child: Container(
                                    width: double.infinity,
                                    alignment: Alignment.center,
                                    child: Text(
                                      displayText,
                                      textAlign: isCodeOrMultiline
                                          ? TextAlign.left
                                          : TextAlign.center,
                                      style: TextStyle(
                                        fontSize: isCodeOrMultiline ? 15 : 18,
                                        fontFamily: isCodeOrMultiline
                                            ? 'monospace'
                                            : null,
                                        fontWeight: isCodeOrMultiline
                                            ? FontWeight.w600
                                            : FontWeight.w700,
                                        height: 1.45,
                                        color: isDark
                                            ? AppColors.textPrimaryDark
                                            : AppColors.textPrimaryLight,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (state.isFlipped &&
                                card.explanation.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.darkCard
                                      : AppColors.lightCard,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  card.explanation,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                    color: isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.touch_app,
                                  size: 16,
                                  color: isDark
                                      ? AppColors.textTertiaryDark
                                      : AppColors.textTertiaryLight,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Tap card to flip',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? AppColors.textTertiaryDark
                                        : AppColors.textTertiaryLight,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Rating Buttons: Still Learning vs Mastered
                Row(
                  children: [
                    Expanded(
                      child: CustomButton(
                        text: 'Still Learning',
                        icon: Icons.refresh,
                        variant: ButtonVariant.secondary,
                        onPressed: () {
                          _resetInputState();
                          controller.markStillLearning();
                        },
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: CustomButton(
                        text: 'Got It!',
                        icon: Icons.check,
                        variant: ButtonVariant.accent,
                        onPressed: () {
                          _resetInputState();
                          controller.markKnown();
                        },
                      ),
                    ),
                  ],
                ),
              ]

              // Mode 2: Type-in Quiz Mode (Type back of card, Pass button, feedback)
              else ...[
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Prompt / Front of the card
                        GradientCard(
                          padding: const EdgeInsets.all(22),
                          borderColor:
                              AppColors.tertiary.withValues(alpha: 0.4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.tertiary
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'QUESTION / PROMPT',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                    color: AppColors.tertiary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                card.questionText,
                                textAlign: isCodeOrMultiline
                                    ? TextAlign.left
                                    : TextAlign.center,
                                style: TextStyle(
                                  fontSize: isCodeOrMultiline ? 15 : 18,
                                  fontFamily:
                                      isCodeOrMultiline ? 'monospace' : null,
                                  fontWeight: isCodeOrMultiline
                                      ? FontWeight.w600
                                      : FontWeight.w700,
                                  height: 1.45,
                                  color: isDark
                                      ? AppColors.textPrimaryDark
                                      : AppColors.textPrimaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // If not yet submitted/passed: Show typing input box and action buttons
                        if (_feedback == QuizFeedback.none) ...[
                          Text(
                            'Type the answer on the back of the card:',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _answerController,
                            focusNode: _focusNode,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) =>
                                _submitAnswer(controller, correctAnswer),
                            onChanged: (_) => setState(() {}),
                            style: const TextStyle(fontSize: 15),
                            decoration: InputDecoration(
                              hintText: 'Enter answer here...',
                              prefixIcon: const Icon(Icons.edit_note,
                                  color: AppColors.tertiary),
                              suffixIcon: _answerController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        setState(() => _answerController.clear());
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: isDark
                                  ? const Color(0xFF14141E)
                                  : const Color(0xFFF4F4F8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? AppColors.darkBorder
                                      : AppColors.lightBorder,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                    color: AppColors.tertiary, width: 2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              // Pass Button: lets user proceed without an answer
                              Expanded(
                                flex: 1,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    side: BorderSide(
                                      color: isDark
                                          ? const Color(0xFF38384E)
                                          : const Color(0xFFD0D0DC),
                                      width: 1.5,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () => _passQuestion(correctAnswer),
                                  icon: const Icon(Icons.skip_next_rounded,
                                      size: 18, color: Colors.amber),
                                  label: const Text(
                                    'Pass',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: Colors.amber,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Submit / Check Answer Button
                              Expanded(
                                flex: 2,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.tertiary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 2,
                                  ),
                                  onPressed: _answerController
                                          .text.trim().isNotEmpty
                                      ? () => _submitAnswer(
                                          controller, correctAnswer)
                                      : null,
                                  icon: const Icon(Icons.check_circle_outline,
                                      size: 18),
                                  label: const Text(
                                    'Check Answer',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ]

                        // If Feedback State: Show answer comparison and proceed button
                        else ...[
                          // Feedback Card
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: _feedback == QuizFeedback.correct
                                  ? AppColors.success.withValues(alpha: 0.12)
                                  : (_feedback == QuizFeedback.incorrect
                                      ? AppColors.error.withValues(alpha: 0.12)
                                      : Colors.amber.withValues(alpha: 0.12)),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _feedback == QuizFeedback.correct
                                    ? AppColors.success.withValues(alpha: 0.5)
                                    : (_feedback == QuizFeedback.incorrect
                                        ? AppColors.error.withValues(alpha: 0.5)
                                        : Colors.amber.withValues(alpha: 0.5)),
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _feedback == QuizFeedback.correct
                                          ? Icons.check_circle
                                          : (_feedback == QuizFeedback.incorrect
                                              ? Icons.cancel
                                              : Icons.flag_outlined),
                                      color: _feedback == QuizFeedback.correct
                                          ? AppColors.success
                                          : (_feedback == QuizFeedback.incorrect
                                              ? AppColors.error
                                              : Colors.amber),
                                      size: 22,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _feedback == QuizFeedback.correct
                                          ? 'Correct! Nailed it! 🎉'
                                          : (_feedback == QuizFeedback.incorrect
                                              ? 'Incorrect ❌'
                                              : 'Passed / Skipped ⚠️'),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: _feedback ==
                                                QuizFeedback.correct
                                            ? AppColors.success
                                            : (_feedback ==
                                                    QuizFeedback.incorrect
                                                ? AppColors.error
                                                : Colors.amber),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (_feedback == QuizFeedback.incorrect) ...[
                                  Text(
                                    'Your Answer: "$_submittedAnswer"',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark
                                          ? AppColors.textSecondaryDark
                                          : AppColors.textSecondaryLight,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                ],
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Correct Answer: ',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        correctAnswer,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: _feedback ==
                                                  QuizFeedback.correct
                                              ? AppColors.success
                                              : AppColors.secondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (card.explanation.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.05)
                                          : Colors.black.withValues(alpha: 0.04),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Key Note: ${card.explanation}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                        color: isDark
                                            ? AppColors.textTertiaryDark
                                            : AppColors.textTertiaryLight,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Proceed to Next Question / Card Button
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _feedback == QuizFeedback.correct
                                  ? AppColors.success
                                  : AppColors.secondary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            onPressed: () => _proceedNext(
                              controller,
                              isCorrect: _feedback == QuizFeedback.correct,
                            ),
                            icon: const Icon(Icons.arrow_forward_rounded,
                                size: 18),
                            label: Text(
                              state.currentIndex == state.deck.length - 1
                                  ? 'Finish Deck 🏁'
                                  : 'Proceed to Next Card ➔',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
