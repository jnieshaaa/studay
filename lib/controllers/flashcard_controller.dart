import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../models/question_model.dart';
import 'study_controller.dart';

class FlashcardState {
  final List<Question> deck;
  final int currentIndex;
  final bool isFlipped;
  final int knownCount;
  final int learningCount;
  final bool isCompleted;

  const FlashcardState({
    required this.deck,
    this.currentIndex = 0,
    this.isFlipped = false,
    this.knownCount = 0,
    this.learningCount = 0,
    this.isCompleted = false,
  });

  Question? get currentCard =>
      currentIndex < deck.length ? deck[currentIndex] : null;

  FlashcardState copyWith({
    List<Question>? deck,
    int? currentIndex,
    bool? isFlipped,
    int? knownCount,
    int? learningCount,
    bool? isCompleted,
  }) {
    return FlashcardState(
      deck: deck ?? this.deck,
      currentIndex: currentIndex ?? this.currentIndex,
      isFlipped: isFlipped ?? this.isFlipped,
      knownCount: knownCount ?? this.knownCount,
      learningCount: learningCount ?? this.learningCount,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class FlashcardController extends StateNotifier<FlashcardState> {
  final Ref _ref;

  FlashcardController(this._ref, List<Question> questions)
      : super(FlashcardState(deck: questions));

  void flip() {
    state = state.copyWith(isFlipped: !state.isFlipped);
  }

  void markKnown() {
    final card = state.currentCard;
    if (card != null) {
      _ref.read(studyControllerProvider.notifier).recordAnswerResult(
            questionId: card.id,
            isCorrect: true,
          );
    }
    _nextCard(isKnown: true);
  }

  void markStillLearning() {
    final card = state.currentCard;
    if (card != null) {
      _ref.read(studyControllerProvider.notifier).recordAnswerResult(
            questionId: card.id,
            isCorrect: false,
          );
    }
    _nextCard(isKnown: false);
  }

  void _nextCard({required bool isKnown}) {
    final nextIdx = state.currentIndex + 1;
    final isDone = nextIdx >= state.deck.length;

    state = state.copyWith(
      currentIndex: nextIdx,
      isFlipped: false,
      knownCount: state.knownCount + (isKnown ? 1 : 0),
      learningCount: state.learningCount + (!isKnown ? 1 : 0),
      isCompleted: isDone,
    );
  }

  void reset() {
    state = state.copyWith(
      currentIndex: 0,
      isFlipped: false,
      knownCount: 0,
      learningCount: 0,
      isCompleted: false,
    );
  }
}

final flashcardControllerProvider = StateNotifierProvider.autoDispose
    .family<FlashcardController, FlashcardState, List<Question>>((ref, questions) {
  return FlashcardController(ref, questions);
});
