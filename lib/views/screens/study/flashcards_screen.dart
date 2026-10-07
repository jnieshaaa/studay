import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../models/question_model.dart';
import '../../../controllers/flashcard_controller.dart';
import '../../components/common/gradient_card.dart';
import '../../components/common/custom_button.dart';

class FlashcardsScreen extends ConsumerWidget {
  final List<Question> questions;

  const FlashcardsScreen({super.key, required this.questions});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(flashcardControllerProvider(questions));
    final controller = ref.read(flashcardControllerProvider(questions).notifier);

    if (questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Flashcards')),
        body: const Center(child: Text('No questions available for flashcards.')),
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
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 32),
              CustomButton(
                text: 'Study Deck Again',
                icon: Icons.replay,
                variant: ButtonVariant.primaryGradient,
                width: double.infinity,
                onPressed: controller.reset,
              ),
              const SizedBox(height: 12),
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
        ? card.matchingPairs.map((p) => '${p.leftText} ➔ ${p.rightText}').join('\n')
        : (card.choices.where((c) => c.isCorrect).firstOrNull?.choiceText ?? 'See explanation');

    final displayText = state.isFlipped ? correctAnswer : card.questionText;
    final isCodeOrMultiline = displayText.contains('\n') ||
        displayText.contains('{') ||
        displayText.contains('class ') ||
        displayText.contains('function ') ||
        displayText.contains('=>');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flashcards Focus', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          if (state.currentIndex > 0)
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 18),
              tooltip: 'Previous Card',
              onPressed: controller.previousCard,
            ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(left: 8, right: 16),
              child: Text(
                '${state.currentIndex + 1}/${state.deck.length}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
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
                  backgroundColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.secondary),
                ),
              ),
              const SizedBox(height: 20),

              // Interactive 3D Flip Card
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
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: (state.isFlipped ? AppColors.secondary : AppColors.primary)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              state.isFlipped ? 'ANSWER / BACK' : 'QUESTION / FRONT',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: state.isFlipped ? AppColors.secondary : AppColors.primary,
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
                                    textAlign: isCodeOrMultiline ? TextAlign.left : TextAlign.center,
                                    style: TextStyle(
                                      fontSize: isCodeOrMultiline ? 15 : 18,
                                      fontFamily: isCodeOrMultiline ? 'monospace' : null,
                                      fontWeight: isCodeOrMultiline ? FontWeight.w600 : FontWeight.w700,
                                      height: 1.45,
                                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (state.isFlipped && card.explanation.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                card.explanation,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
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
                                color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Tap card to flip',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
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
                      onPressed: controller.markStillLearning,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: CustomButton(
                      text: 'Got It!',
                      icon: Icons.check,
                      variant: ButtonVariant.accent,
                      onPressed: controller.markKnown,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
