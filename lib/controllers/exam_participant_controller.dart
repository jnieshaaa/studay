import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../models/exam_model.dart';
import '../models/exam_participant_model.dart';
import '../models/question_model.dart';
import '../core/utils/code_generator.dart';
import 'providers.dart';

class ExamParticipantPlayState {
  final Exam exam;
  final ExamParticipant participant;
  final int currentIndex;
  final Map<String, String> selectedChoices; // questionId -> choiceId
  final Map<String, Map<String, String>> matchingAnswers; // questionId -> {left: right}
  final String? activeMatchingLeft;
  final bool isSubmitting;
  final ExamParticipant? submissionResult;
  final List<ExamResponse> lastResponses;
  final String? errorMessage;

  const ExamParticipantPlayState({
    required this.exam,
    required this.participant,
    this.currentIndex = 0,
    this.selectedChoices = const {},
    this.matchingAnswers = const {},
    this.activeMatchingLeft,
    this.isSubmitting = false,
    this.submissionResult,
    this.lastResponses = const [],
    this.errorMessage,
  });

  Question? get currentQuestion =>
      currentIndex < exam.questions.length ? exam.questions[currentIndex] : null;

  bool get isLastQuestion => currentIndex == exam.questions.length - 1;

  ExamParticipantPlayState copyWith({
    Exam? exam,
    ExamParticipant? participant,
    int? currentIndex,
    Map<String, String>? selectedChoices,
    Map<String, Map<String, String>>? matchingAnswers,
    String? activeMatchingLeft,
    bool clearActiveMatchingLeft = false,
    bool? isSubmitting,
    ExamParticipant? submissionResult,
    List<ExamResponse>? lastResponses,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ExamParticipantPlayState(
      exam: exam ?? this.exam,
      participant: participant ?? this.participant,
      currentIndex: currentIndex ?? this.currentIndex,
      selectedChoices: selectedChoices ?? this.selectedChoices,
      matchingAnswers: matchingAnswers ?? this.matchingAnswers,
      activeMatchingLeft: clearActiveMatchingLeft
          ? null
          : (activeMatchingLeft ?? this.activeMatchingLeft),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submissionResult: submissionResult ?? this.submissionResult,
      lastResponses: lastResponses ?? this.lastResponses,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class ExamParticipantController extends StateNotifier<ExamParticipantPlayState> {
  final Ref _ref;

  ExamParticipantController(this._ref, Exam exam, ExamParticipant participant)
      : super(ExamParticipantPlayState(
          exam: _prepareExam(exam),
          participant: participant,
        ));

  static Exam _prepareExam(Exam original) {
    // Partition questions strictly by sectionOrder so question types are always separate
    final preparedQuestions = <Question>[];

    for (final type in original.sectionOrder) {
      var sectionQuestions = original.questions
          .where((q) => q.questionType == type)
          .toList();

      // If questionOrder is shuffled, shuffle strictly WITHIN this section
      if (original.questionOrder == QuestionOrder.shuffled) {
        sectionQuestions.shuffle();
      }

      preparedQuestions.addAll(sectionQuestions);
    }

    // Include any questions whose type wasn't in sectionOrder (safeguard)
    for (final q in original.questions) {
      if (!original.sectionOrder.contains(q.questionType)) {
        preparedQuestions.add(q);
      }
    }

    // Shuffle multiple choice choices if choiceOrder == ChoiceOrder.shuffled
    final finalQuestions = preparedQuestions.map((q) {
      if (original.choiceOrder == ChoiceOrder.shuffled &&
          q.questionType == QuestionType.multipleChoice) {
        final shuffledChoices = List<QuestionChoice>.from(q.choices)..shuffle();
        return q.copyWith(choices: shuffledChoices);
      }
      return q;
    }).toList();

    return original.copyWith(questions: finalQuestions);
  }

  void selectChoice(String questionId, String choiceId) {
    final updated = Map<String, String>.from(state.selectedChoices);
    updated[questionId] = choiceId;
    state = state.copyWith(selectedChoices: updated);
  }

  void selectMatchingLeft(String leftText) {
    state = state.copyWith(activeMatchingLeft: leftText);
  }

  void connectMatchingRight(String questionId, String rightText) {
    final left = state.activeMatchingLeft;
    if (left == null) return;

    final currentPairs = Map<String, String>.from(
      state.matchingAnswers[questionId] ?? {},
    );
    // Remove if right was already paired
    currentPairs.removeWhere((k, v) => v == rightText);
    currentPairs[left] = rightText;

    final updatedAll = Map<String, Map<String, String>>.from(state.matchingAnswers);
    updatedAll[questionId] = currentPairs;

    state = state.copyWith(
      matchingAnswers: updatedAll,
      clearActiveMatchingLeft: true,
    );
  }

  void removeMatchingPair(String questionId, String leftText) {
    final currentPairs = Map<String, String>.from(
      state.matchingAnswers[questionId] ?? {},
    );
    currentPairs.remove(leftText);

    final updatedAll = Map<String, Map<String, String>>.from(state.matchingAnswers);
    updatedAll[questionId] = currentPairs;

    state = state.copyWith(matchingAnswers: updatedAll);
  }

  void nextQuestion() {
    if (!state.isLastQuestion) {
      state = state.copyWith(
        currentIndex: state.currentIndex + 1,
        clearActiveMatchingLeft: true,
      );
    }
  }

  void previousQuestion() {
    if (state.currentIndex > 0) {
      state = state.copyWith(
        currentIndex: state.currentIndex - 1,
        clearActiveMatchingLeft: true,
      );
    }
  }

  Future<ExamParticipant?> submitExam() async {
    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      final examService = _ref.read(examServiceProvider);
      final responses = <ExamResponse>[];

      for (final q in state.exam.questions) {
        bool isCorrect = false;
        String? choiceId = state.selectedChoices[q.id];
        Map<String, String> matching = state.matchingAnswers[q.id] ?? {};

        if (q.questionType == QuestionType.matching) {
          if (matching.length == q.matchingPairs.length) {
            isCorrect = q.matchingPairs.every(
              (pair) => matching[pair.leftText] == pair.rightText,
            );
          }
        } else {
          final choice = q.choices.where((c) => c.id == choiceId).firstOrNull;
          isCorrect = choice?.isCorrect ?? false;
        }

        responses.add(ExamResponse(
          id: CodeGenerator.generateId('resp'),
          participantId: state.participant.id,
          questionId: q.id,
          selectedChoiceId: choiceId,
          matchingResponse: matching,
          isCorrect: isCorrect,
          timeSpent: 0,
        ));
      }

      final result = examService.submitResponses(
        examId: state.exam.id,
        participantId: state.participant.id,
        responses: responses,
      );

      state = state.copyWith(
        isSubmitting: false,
        submissionResult: result,
        lastResponses: responses,
      );
      return result;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Submission error: $e',
      );
      return null;
    }
  }
}

class ExamParticipantParam {
  final Exam exam;
  final ExamParticipant participant;
  const ExamParticipantParam(this.exam, this.participant);
}

final examParticipantControllerProvider = StateNotifierProvider.autoDispose
    .family<ExamParticipantController, ExamParticipantPlayState, ExamParticipantParam>(
        (ref, param) {
  return ExamParticipantController(ref, param.exam, param.participant);
});
