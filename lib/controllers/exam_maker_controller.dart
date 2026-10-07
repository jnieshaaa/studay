import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../models/exam_model.dart';
import '../models/question_model.dart';
import '../core/utils/code_generator.dart';
import 'providers.dart';
import 'study_controller.dart';
import 'auth_controller.dart';

class ExamMakerState {
  final String title;
  final String subject;
  final String description;
  final List<Question> questions;
  final QuestionOrder questionOrder;
  final ChoiceOrder choiceOrder;
  final ShowAnswersMode showAnswers;
  final int maxAttempts;
  final int? durationMinutes;
  final DateTime? closesAt;
  final bool isPublishing;
  final Exam? publishedExam;
  final String? errorMessage;
  final String? editingExamId;
  final String? editingExamCode;
  final ExamStatus? editingExamStatus;
  final DateTime? editingCreatedAt;
  final List<QuestionType> sectionOrder;

  const ExamMakerState({
    this.title = '',
    this.subject = '',
    this.description = '',
    this.questions = const [],
    this.questionOrder = QuestionOrder.shuffled,
    this.choiceOrder = ChoiceOrder.shuffled,
    this.showAnswers = ShowAnswersMode.immediately,
    this.maxAttempts = 1,
    this.durationMinutes,
    this.closesAt,
    this.isPublishing = false,
    this.publishedExam,
    this.errorMessage,
    this.editingExamId,
    this.editingExamCode,
    this.editingExamStatus,
    this.editingCreatedAt,
    this.sectionOrder = Exam.defaultSectionOrder,
  });

  bool get isValid =>
      title.trim().isNotEmpty && subject.trim().isNotEmpty && questions.isNotEmpty;
  bool get isEditing => editingExamId != null;

  ExamMakerState copyWith({
    String? title,
    String? subject,
    String? description,
    List<Question>? questions,
    QuestionOrder? questionOrder,
    ChoiceOrder? choiceOrder,
    ShowAnswersMode? showAnswers,
    int? maxAttempts,
    int? durationMinutes,
    bool clearDuration = false,
    DateTime? closesAt,
    bool? isPublishing,
    Exam? publishedExam,
    String? errorMessage,
    bool clearError = false,
    String? editingExamId,
    String? editingExamCode,
    ExamStatus? editingExamStatus,
    DateTime? editingCreatedAt,
    bool clearEditing = false,
    List<QuestionType>? sectionOrder,
  }) {
    return ExamMakerState(
      title: title ?? this.title,
      subject: subject ?? this.subject,
      description: description ?? this.description,
      questions: questions ?? this.questions,
      questionOrder: questionOrder ?? this.questionOrder,
      choiceOrder: choiceOrder ?? this.choiceOrder,
      showAnswers: showAnswers ?? this.showAnswers,
      maxAttempts: maxAttempts ?? this.maxAttempts,
      durationMinutes: clearDuration ? null : (durationMinutes ?? this.durationMinutes),
      closesAt: closesAt ?? this.closesAt,
      isPublishing: isPublishing ?? this.isPublishing,
      publishedExam: publishedExam ?? this.publishedExam,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      editingExamId: clearEditing ? null : (editingExamId ?? this.editingExamId),
      editingExamCode: clearEditing ? null : (editingExamCode ?? this.editingExamCode),
      editingExamStatus: clearEditing ? null : (editingExamStatus ?? this.editingExamStatus),
      editingCreatedAt: clearEditing ? null : (editingCreatedAt ?? this.editingCreatedAt),
      sectionOrder: sectionOrder ?? this.sectionOrder,
    );
  }
}

class ExamMakerController extends StateNotifier<ExamMakerState> {
  final Ref _ref;

  ExamMakerController(this._ref) : super(const ExamMakerState());

  void initForEdit(Exam exam) {
    state = ExamMakerState(
      title: exam.title,
      subject: exam.effectiveSubject,
      description: exam.description,
      questions: List<Question>.from(exam.questions),
      questionOrder: exam.questionOrder,
      choiceOrder: exam.choiceOrder,
      showAnswers: exam.showAnswers,
      maxAttempts: exam.maxAttemptsPerParticipant,
      durationMinutes: exam.durationMinutes,
      closesAt: exam.closesAt,
      editingExamId: exam.id,
      editingExamCode: exam.code,
      editingExamStatus: exam.status,
      editingCreatedAt: exam.createdAt,
      sectionOrder: List<QuestionType>.from(exam.sectionOrder),
    );
  }

  void setTitle(String title) {
    state = state.copyWith(title: title, clearError: true);
  }

  void setSubject(String subject) {
    state = state.copyWith(subject: subject, clearError: true);
  }

  void setDescription(String description) {
    state = state.copyWith(description: description);
  }

  void addQuestion(Question question) {
    final updated = List<Question>.from(state.questions)..add(question);
    state = state.copyWith(questions: updated, clearError: true);
  }

  void addQuestions(List<Question> newQuestions) {
    if (newQuestions.isEmpty) return;
    final updated = List<Question>.from(state.questions)..addAll(newQuestions);
    state = state.copyWith(questions: updated, clearError: true);
  }

  void updateQuestion(int index, Question question) {
    if (index >= 0 && index < state.questions.length) {
      final updated = List<Question>.from(state.questions);
      updated[index] = question;
      state = state.copyWith(questions: updated, clearError: true);
    }
  }

  void removeQuestion(int index) {
    if (index >= 0 && index < state.questions.length) {
      final updated = List<Question>.from(state.questions)..removeAt(index);
      state = state.copyWith(questions: updated);
    }
  }

  void setQuestionOrder(QuestionOrder order) {
    state = state.copyWith(questionOrder: order);
  }

  void setChoiceOrder(ChoiceOrder order) {
    state = state.copyWith(choiceOrder: order);
  }

  void setShowAnswers(ShowAnswersMode mode) {
    state = state.copyWith(showAnswers: mode);
  }

  void setDurationMinutes(int? mins) {
    state = state.copyWith(durationMinutes: mins, clearDuration: mins == null || mins <= 0);
  }

  void setClosesAt(DateTime? dt) {
    state = state.copyWith(closesAt: dt);
  }

  void setSectionOrder(List<QuestionType> order) {
    state = state.copyWith(sectionOrder: List<QuestionType>.from(order));
  }

  /// Sets which question type starts first (e.g. Matching Type or True/False first)
  void setFirstSection(QuestionType type) {
    final updated = List<QuestionType>.from(state.sectionOrder);
    updated.remove(type);
    updated.insert(0, type);
    state = state.copyWith(sectionOrder: updated);
  }

  void moveSectionUp(QuestionType type) {
    final idx = state.sectionOrder.indexOf(type);
    if (idx > 0) {
      final updated = List<QuestionType>.from(state.sectionOrder);
      final item = updated.removeAt(idx);
      updated.insert(idx - 1, item);
      state = state.copyWith(sectionOrder: updated);
    }
  }

  void moveSectionDown(QuestionType type) {
    final idx = state.sectionOrder.indexOf(type);
    if (idx >= 0 && idx < state.sectionOrder.length - 1) {
      final updated = List<QuestionType>.from(state.sectionOrder);
      final item = updated.removeAt(idx);
      updated.insert(idx + 1, item);
      state = state.copyWith(sectionOrder: updated);
    }
  }

  Future<Exam?> publish() async {
    if (state.title.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'Please provide an exam title.');
      return null;
    }
    if (state.subject.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'Please provide a subject category.');
      return null;
    }
    if (state.questions.isEmpty) {
      state = state.copyWith(errorMessage: 'Please add at least one question.');
      return null;
    }

    state = state.copyWith(isPublishing: true, clearError: true);

    try {
      final examService = _ref.read(examServiceProvider);

      // Handle updating existing published exam
      if (state.isEditing) {
        final updatedExam = Exam(
          id: state.editingExamId!,
          creatorId: 'maker_local',
          title: state.title.trim(),
          subject: state.subject.trim().isNotEmpty ? state.subject.trim() : 'General Knowledge',
          description: state.description.trim(),
          code: state.editingExamCode!,
          status: state.editingExamStatus ?? ExamStatus.published,
          questionOrder: state.questionOrder,
          choiceOrder: state.choiceOrder,
          showAnswers: state.showAnswers,
          closesAt: state.closesAt,
          maxAttemptsPerParticipant: state.maxAttempts,
          durationMinutes: state.durationMinutes,
          sectionOrder: state.sectionOrder,
          questions: state.questions,
          createdAt: state.editingCreatedAt ?? DateTime.now(),
        );

        final saved = await examService.updateExam(updatedExam);

        try {
          await _ref.read(studyControllerProvider.notifier).syncCreatedExam(saved);
        } catch (_) {
          // Non-blocking sync
        }

        state = state.copyWith(
          isPublishing: false,
          publishedExam: saved,
        );
        return saved;
      }

      // Handle publishing brand new exam
      final currentUser = _ref.read(authControllerProvider).currentUser;
      final newExam = Exam(
        id: CodeGenerator.generateId('exam'),
        creatorId: currentUser?.id ?? currentUser?.name ?? 'maker_local',
        title: state.title.trim(),
        subject: state.subject.trim().isNotEmpty ? state.subject.trim() : 'General Knowledge',
        description: state.description.trim(),
        code: '', // will be generated in examService
        status: ExamStatus.published,
        questionOrder: state.questionOrder,
        choiceOrder: state.choiceOrder,
        showAnswers: state.showAnswers,
        closesAt: state.closesAt,
        maxAttemptsPerParticipant: state.maxAttempts,
        durationMinutes: state.durationMinutes,
        sectionOrder: state.sectionOrder,
        questions: state.questions,
        createdAt: DateTime.now(),
      );

      final published = await examService.publishExam(newExam);

      // Automatically sync into study controller so creator can study or take this quiz in Study Mode
      try {
        await _ref.read(studyControllerProvider.notifier).syncCreatedExam(published);
      } catch (_) {
        // Non-blocking sync
      }

      state = state.copyWith(
        isPublishing: false,
        publishedExam: published,
      );
      return published;
    } catch (e) {
      state = state.copyWith(
        isPublishing: false,
        errorMessage: 'Failed to save exam: $e',
      );
      return null;
    }
  }

  void reset() {
    state = const ExamMakerState();
  }
}

final examMakerControllerProvider =
    StateNotifierProvider<ExamMakerController, ExamMakerState>((ref) {
  return ExamMakerController(ref);
});
