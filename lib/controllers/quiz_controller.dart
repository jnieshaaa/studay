import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../models/quiz_session_model.dart';
import '../models/question_model.dart';
import 'study_controller.dart';
import 'providers.dart';

class QuizPlayState {
  final QuizSession session;
  final int currentIndex;
  final String? selectedChoiceId;
  final Map<String, String> currentMatchingPairs; // leftText -> rightText
  final String? selectedMatchingLeft;
  final bool hasConfirmedAnswer; // for practice mode instant explanation
  final int remainingSeconds;
  final bool isCompleted;

  const QuizPlayState({
    required this.session,
    this.currentIndex = 0,
    this.selectedChoiceId,
    this.currentMatchingPairs = const {},
    this.selectedMatchingLeft,
    this.hasConfirmedAnswer = false,
    this.remainingSeconds = 0,
    this.isCompleted = false,
  });

  Question? get currentQuestion =>
      currentIndex < session.questions.length ? session.questions[currentIndex] : null;

  bool get isLastQuestion => currentIndex == session.questions.length - 1;

  QuizPlayState copyWith({
    QuizSession? session,
    int? currentIndex,
    String? selectedChoiceId,
    bool clearChoice = false,
    Map<String, String>? currentMatchingPairs,
    String? selectedMatchingLeft,
    bool clearMatchingLeft = false,
    bool? hasConfirmedAnswer,
    int? remainingSeconds,
    bool? isCompleted,
  }) {
    return QuizPlayState(
      session: session ?? this.session,
      currentIndex: currentIndex ?? this.currentIndex,
      selectedChoiceId: clearChoice ? null : (selectedChoiceId ?? this.selectedChoiceId),
      currentMatchingPairs: currentMatchingPairs ?? this.currentMatchingPairs,
      selectedMatchingLeft: clearMatchingLeft ? null : (selectedMatchingLeft ?? this.selectedMatchingLeft),
      hasConfirmedAnswer: hasConfirmedAnswer ?? this.hasConfirmedAnswer,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class QuizController extends StateNotifier<QuizPlayState> {
  final Ref _ref;
  Timer? _timer;

  QuizController(this._ref, QuizSession session)
      : super(QuizPlayState(
          session: session,
          remainingSeconds: session.timeLimitSeconds,
        )) {
    if (session.timeLimitSeconds > 0) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.remainingSeconds <= 1) {
        timer.cancel();
        submitQuiz();
      } else {
        state = state.copyWith(remainingSeconds: state.remainingSeconds - 1);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void selectChoice(String choiceId) {
    if (state.hasConfirmedAnswer && state.session.mode == StudyMode.practice) return;
    state = state.copyWith(selectedChoiceId: choiceId);
  }

  void selectMatchingLeft(String leftText) {
    if (state.hasConfirmedAnswer && state.session.mode == StudyMode.practice) return;
    state = state.copyWith(selectedMatchingLeft: leftText);
  }

  void connectMatchingRight(String rightText) {
    if (state.hasConfirmedAnswer && state.session.mode == StudyMode.practice) return;
    final left = state.selectedMatchingLeft;
    if (left == null) return;

    final updatedPairs = Map<String, String>.from(state.currentMatchingPairs);
    // Remove if right was already paired with someone else
    updatedPairs.removeWhere((k, v) => v == rightText);
    updatedPairs[left] = rightText;

    state = state.copyWith(
      currentMatchingPairs: updatedPairs,
      clearMatchingLeft: true,
    );
  }

  void removeMatchingPair(String leftText) {
    if (state.hasConfirmedAnswer && state.session.mode == StudyMode.practice) return;
    final updatedPairs = Map<String, String>.from(state.currentMatchingPairs);
    updatedPairs.remove(leftText);
    state = state.copyWith(currentMatchingPairs: updatedPairs);
  }

  /// In practice mode, check answer and display instant explanation
  void confirmPracticeAnswer() {
    final q = state.currentQuestion;
    if (q == null) return;

    bool isCorrect = false;
    if (q.questionType == QuestionType.matching) {
      isCorrect = _gradeMatching(q, state.currentMatchingPairs);
    } else {
      final choice = q.choices.where((c) => c.id == state.selectedChoiceId).firstOrNull;
      isCorrect = choice?.isCorrect ?? false;
    }

    // Save answer into session answers
    final updatedAnswers = Map<String, QuizAnswer>.from(state.session.answers);
    updatedAnswers[q.id] = QuizAnswer(
      questionId: q.id,
      selectedChoiceId: state.selectedChoiceId,
      matchingAnswers: state.currentMatchingPairs,
      isCorrect: isCorrect,
    );

    _ref.read(studyControllerProvider.notifier).recordAnswerResult(
          questionId: q.id,
          isCorrect: isCorrect,
        );

    state = state.copyWith(
      session: state.session.copyWith(answers: updatedAnswers),
      hasConfirmedAnswer: true,
    );
  }

  bool _gradeMatching(Question q, Map<String, String> userPairs) {
    if (userPairs.length != q.matchingPairs.length) return false;
    for (final pair in q.matchingPairs) {
      if (userPairs[pair.leftText] != pair.rightText) return false;
    }
    return true;
  }

  void nextQuestion() {
    final q = state.currentQuestion;
    if (q == null) return;

    // Record answer if not yet recorded (non-practice or user clicked next)
    if (!state.session.answers.containsKey(q.id)) {
      bool isCorrect = false;
      if (q.questionType == QuestionType.matching) {
        isCorrect = _gradeMatching(q, state.currentMatchingPairs);
      } else {
        final choice = q.choices.where((c) => c.id == state.selectedChoiceId).firstOrNull;
        isCorrect = choice?.isCorrect ?? false;
      }

      final updatedAnswers = Map<String, QuizAnswer>.from(state.session.answers);
      updatedAnswers[q.id] = QuizAnswer(
        questionId: q.id,
        selectedChoiceId: state.selectedChoiceId,
        matchingAnswers: state.currentMatchingPairs,
        isCorrect: isCorrect,
      );

      _ref.read(studyControllerProvider.notifier).recordAnswerResult(
            questionId: q.id,
            isCorrect: isCorrect,
          );

      state = state.copyWith(
        session: state.session.copyWith(answers: updatedAnswers),
      );
    }

    if (state.isLastQuestion) {
      submitQuiz();
    } else {
      final nextIdx = state.currentIndex + 1;
      final nextQ = state.session.questions[nextIdx];
      final existingAnswer = state.session.answers[nextQ.id];

      state = state.copyWith(
        currentIndex: nextIdx,
        selectedChoiceId: existingAnswer?.selectedChoiceId,
        clearChoice: existingAnswer?.selectedChoiceId == null,
        currentMatchingPairs: existingAnswer?.matchingAnswers ?? {},
        clearMatchingLeft: true,
        hasConfirmedAnswer: existingAnswer != null,
      );
    }
  }

  void previousQuestion() {
    if (state.currentIndex > 0) {
      final prevIdx = state.currentIndex - 1;
      final prevQ = state.session.questions[prevIdx];
      final existingAnswer = state.session.answers[prevQ.id];

      state = state.copyWith(
        currentIndex: prevIdx,
        selectedChoiceId: existingAnswer?.selectedChoiceId,
        clearChoice: existingAnswer?.selectedChoiceId == null,
        currentMatchingPairs: existingAnswer?.matchingAnswers ?? {},
        clearMatchingLeft: true,
        hasConfirmedAnswer: existingAnswer != null,
      );
    }
  }

  Future<void> submitQuiz() async {
    _timer?.cancel();
    final q = state.currentQuestion;
    if (q != null && !state.session.answers.containsKey(q.id)) {
      bool isCorrect = false;
      if (q.questionType == QuestionType.matching) {
        isCorrect = _gradeMatching(q, state.currentMatchingPairs);
      } else {
        final choice = q.choices.where((c) => c.id == state.selectedChoiceId).firstOrNull;
        isCorrect = choice?.isCorrect ?? false;
      }

      final updatedAnswers = Map<String, QuizAnswer>.from(state.session.answers);
      updatedAnswers[q.id] = QuizAnswer(
        questionId: q.id,
        selectedChoiceId: state.selectedChoiceId,
        matchingAnswers: state.currentMatchingPairs,
        isCorrect: isCorrect,
      );

      _ref.read(studyControllerProvider.notifier).recordAnswerResult(
            questionId: q.id,
            isCorrect: isCorrect,
          );

      state = state.copyWith(
        session: state.session.copyWith(
          answers: updatedAnswers,
          completedAt: DateTime.now(),
        ),
        isCompleted: true,
      );
    } else {
      state = state.copyWith(
        session: state.session.copyWith(completedAt: DateTime.now()),
        isCompleted: true,
      );
    }

    final storage = _ref.read(localStorageServiceProvider);
    await storage.recordQuizSession(state.session);
  }
}

final quizControllerProvider = StateNotifierProvider.autoDispose
    .family<QuizController, QuizPlayState, QuizSession>((ref, session) {
  return QuizController(ref, session);
});
