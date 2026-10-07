import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../models/subject_model.dart';
import '../models/question_model.dart';
import '../models/user_progress_model.dart';
import '../models/quiz_session_model.dart';
import '../models/exam_model.dart';
import '../services/seed_data_service.dart';
import 'providers.dart';

class StudyState {
  final List<Subject> subjects;
  final List<Topic> topics;
  final List<Question> questions;
  final Map<String, QuestionProgress> progressMap;
  final String? selectedSubjectId;
  final String? selectedTopicId;
  final bool isLoading;

  const StudyState({
    this.subjects = const [],
    this.topics = const [],
    this.questions = const [],
    this.progressMap = const {},
    this.selectedSubjectId,
    this.selectedTopicId,
    this.isLoading = false,
  });

  List<Question> get filteredQuestions {
    var list = questions;
    if (selectedSubjectId != null) {
      list = list.where((q) => q.subjectId == selectedSubjectId).toList();
    }
    if (selectedTopicId != null) {
      list = list.where((q) => q.topicId == selectedTopicId).toList();
    }
    return list;
  }

  List<Question> get bookmarkedQuestions {
    return questions.where((q) {
      final p = progressMap[q.id];
      return q.isBookmarked || (p != null && p.isBookmarked);
    }).toList();
  }

  List<Question> get weakQuestions {
    return questions.where((q) {
      final p = progressMap[q.id];
      if (p == null) return false;
      return p.isWeak || (p.wrongCount > p.correctCount);
    }).toList();
  }

  List<Question> get mistakeQuestions {
    return questions.where((q) {
      final p = progressMap[q.id];
      return p != null && p.wrongCount > 0;
    }).toList();
  }

  List<SubjectPerformance> get subjectPerformances {
    return subjects.map((subj) {
      final subjQuestions = questions.where((q) => q.subjectId == subj.id).toList();
      int totalAttempts = 0;
      int totalCorrect = 0;
      int weakCount = 0;

      for (final q in subjQuestions) {
        final p = progressMap[q.id];
        if (p != null && p.attempts > 0) {
          totalAttempts += p.attempts;
          totalCorrect += p.correctCount;
          if (p.isWeak || p.wrongCount > p.correctCount) {
            weakCount++;
          }
        }
      }

      return SubjectPerformance(
        subjectId: subj.id,
        subjectName: subj.name,
        totalQuestions: subjQuestions.length,
        answeredCount: totalAttempts,
        correctCount: totalCorrect,
        weakQuestionsCount: weakCount,
      );
    }).toList();
  }

  StudyState copyWith({
    List<Subject>? subjects,
    List<Topic>? topics,
    List<Question>? questions,
    Map<String, QuestionProgress>? progressMap,
    String? selectedSubjectId,
    String? selectedTopicId,
    bool? isLoading,
    bool clearSelectedSubject = false,
    bool clearSelectedTopic = false,
  }) {
    return StudyState(
      subjects: subjects ?? this.subjects,
      topics: topics ?? this.topics,
      questions: questions ?? this.questions,
      progressMap: progressMap ?? this.progressMap,
      selectedSubjectId: clearSelectedSubject
          ? null
          : (selectedSubjectId ?? this.selectedSubjectId),
      selectedTopicId: clearSelectedTopic
          ? null
          : (selectedTopicId ?? this.selectedTopicId),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class StudyController extends StateNotifier<StudyState> {
  final Ref _ref;

  StudyController(this._ref) : super(const StudyState(isLoading: true)) {
    loadData();
  }

  Future<void> loadData() async {
    state = state.copyWith(isLoading: true);
    final storage = _ref.read(localStorageServiceProvider);
    await storage.init();
    if (!mounted) return;

    final customSubjects = await storage.loadCustomSubjects();
    if (!mounted) return;
    final examService = _ref.read(examServiceProvider);

    // Merge custom subjects + subjects derived from allExams
    final subjectMap = <String, Subject>{};
    for (final s in customSubjects) {
      subjectMap[s.id] = s;
    }

    // Ensure all exam subjects exist in Study Mode
    for (final exam in examService.allExams) {
      final subjName = exam.effectiveSubject;
      final existingSubj = subjectMap.values.cast<Subject?>().firstWhere(
        (s) => s != null && s.name.toLowerCase() == subjName.toLowerCase(),
        orElse: () => null,
      );
      if (existingSubj == null) {
        final newSubj = Subject(
          id: 'subj_${subjName.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}',
          name: subjName,
          description: 'Subject containing ${exam.title}',
          icon: 'school',
          sortOrder: subjectMap.length + 1,
        );
        subjectMap[newSubj.id] = newSubj;
      }
    }

    final subjects = subjectMap.values.toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final topics = SeedDataService.getTopics();

    // Questions from storage + questions from all exams
    final questionsFromStorage = await storage.loadQuestions();
    if (!mounted) return;
    final questionMap = <String, Question>{};
    for (final q in questionsFromStorage) {
      questionMap[q.id] = q;
    }

    // Ingest all questions from examService.allExams
    for (final exam in examService.allExams) {
      final subjName = exam.effectiveSubject;
      final subj = subjects.firstWhere(
        (s) => s.name.toLowerCase() == subjName.toLowerCase(),
        orElse: () => subjects.isNotEmpty
            ? subjects.first
            : Subject(
                id: 'subj_${subjName.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}',
                name: subjName,
                description: '',
                icon: 'school',
                sortOrder: 1,
              ),
      );
      for (final q in exam.questions) {
        if (!questionMap.containsKey(q.id)) {
          questionMap[q.id] = q.copyWith(
            subjectId: q.subjectId.isNotEmpty ? q.subjectId : subj.id,
            topicId: q.topicId.isNotEmpty ? q.topicId : 'topic_${exam.id}',
          );
        }
      }
    }

    final allQuestions = questionMap.values.toList();
    final progress = await storage.loadProgress();
    if (!mounted) return;

    state = state.copyWith(
      subjects: subjects,
      topics: topics,
      questions: allQuestions,
      progressMap: progress,
      isLoading: false,
    );
  }

  void selectSubject(String? subjectId) {
    if (state.selectedSubjectId == subjectId) {
      state = state.copyWith(clearSelectedSubject: true, clearSelectedTopic: true);
    } else {
      state = state.copyWith(
        selectedSubjectId: subjectId,
        clearSelectedTopic: true,
      );
    }
  }

  void selectTopic(String? topicId) {
    if (state.selectedTopicId == topicId) {
      state = state.copyWith(clearSelectedTopic: true);
    } else {
      state = state.copyWith(selectedTopicId: topicId);
    }
  }

  Future<void> toggleBookmark(String questionId) async {
    final storage = _ref.read(localStorageServiceProvider);
    final updatedQuestions = state.questions.map((q) {
      if (q.id == questionId) {
        return q.copyWith(isBookmarked: !q.isBookmarked);
      }
      return q;
    }).toList();

    final existingProgress = state.progressMap[questionId];
    final updatedProgress = Map<String, QuestionProgress>.from(state.progressMap);
    if (existingProgress != null) {
      updatedProgress[questionId] = existingProgress.copyWith(
        isBookmarked: !existingProgress.isBookmarked,
      );
    } else {
      updatedProgress[questionId] = QuestionProgress(
        questionId: questionId,
        isBookmarked: true,
        lastAnsweredAt: DateTime.now(),
      );
    }

    state = state.copyWith(
      questions: updatedQuestions,
      progressMap: updatedProgress,
    );

    await storage.saveQuestions(updatedQuestions);
    await storage.saveProgress(updatedProgress);
  }

  Future<void> recordAnswerResult({
    required String questionId,
    required bool isCorrect,
  }) async {
    final storage = _ref.read(localStorageServiceProvider);
    final existing = state.progressMap[questionId];

    final updated = existing != null
        ? existing.copyWith(
            attempts: existing.attempts + 1,
            correctCount: existing.correctCount + (isCorrect ? 1 : 0),
            wrongCount: existing.wrongCount + (isCorrect ? 0 : 1),
            lastAnsweredAt: DateTime.now(),
          )
        : QuestionProgress(
            questionId: questionId,
            attempts: 1,
            correctCount: isCorrect ? 1 : 0,
            wrongCount: isCorrect ? 0 : 1,
            lastAnsweredAt: DateTime.now(),
          );

    final progressMap = Map<String, QuestionProgress>.from(state.progressMap);
    progressMap[questionId] = updated;

    state = state.copyWith(progressMap: progressMap);
    await storage.saveProgress(progressMap);
  }

  /// Builds a QuizSession tailored for the chosen StudyMode
  QuizSession buildQuizSession({
    required StudyMode mode,
    String? subjectId,
    String? topicId,
    int? maxQuestions,
  }) {
    List<Question> pool;

    switch (mode) {
      case StudyMode.mistakesReview:
        pool = state.mistakeQuestions;
        if (pool.isEmpty) pool = state.questions;
        break;
      case StudyMode.bookmarked:
        pool = state.bookmarkedQuestions;
        if (pool.isEmpty) pool = state.questions;
        break;
      case StudyMode.weakQuestions:
        pool = state.weakQuestions;
        if (pool.isEmpty) pool = state.questions;
        break;
      case StudyMode.practice:
      case StudyMode.quickQuiz:
      case StudyMode.timedQuiz:
      case StudyMode.mockExam:
        pool = List<Question>.from(state.filteredQuestions.isNotEmpty
            ? state.filteredQuestions
            : state.questions);
        break;
    }

    // Shuffle for quiz generation
    final random = Random();
    final shuffled = List<Question>.from(pool)..shuffle(random);

    int count = maxQuestions ?? shuffled.length;
    if (mode == StudyMode.quickQuiz) {
      count = min(10, shuffled.length);
    } else if (mode == StudyMode.timedQuiz) {
      count = min(20, shuffled.length);
    }
    final selectedQuestions = shuffled.take(count).map((q) {
      if (q.questionType == QuestionType.multipleChoice) {
        final shuffledChoices = List<QuestionChoice>.from(q.choices)..shuffle();
        return q.copyWith(choices: shuffledChoices);
      }
      return q;
    }).toList();
    final timeLimit = mode == StudyMode.timedQuiz ? count * 60 : 0; // 60s per question

    return QuizSession(
      id: 'quiz_${DateTime.now().millisecondsSinceEpoch}',
      mode: mode,
      subjectId: subjectId ?? state.selectedSubjectId,
      topicId: topicId ?? state.selectedTopicId,
      questions: selectedQuestions,
      timeLimitSeconds: timeLimit,
      startedAt: DateTime.now(),
    );
  }

  Future<Subject> importExamAsStudyDeck(Exam exam) async {
    final storage = _ref.read(localStorageServiceProvider);
    final subjectId = 'subj_exam_${exam.id}';

    // 1. Create or update Subject
    final newSubject = Subject(
      id: subjectId,
      name: exam.title,
      description: exam.description.isNotEmpty
          ? exam.description
          : 'Imported from Exam ${exam.code}',
      icon: 'school',
      sortOrder: state.subjects.length + 1,
    );
    await storage.saveCustomSubject(newSubject);

    // 2. Map questions to this subject
    final importedQuestions = exam.questions.map((q) {
      return q.copyWith(
        subjectId: subjectId,
        topicId: 'topic_${exam.id}',
      );
    }).toList();

    // 3. Merge with existing questions (avoid duplicate IDs)
    final existingQMap = {for (final q in state.questions) q.id: q};
    for (final q in importedQuestions) {
      existingQMap[q.id] = q;
    }
    final allQuestions = existingQMap.values.toList();
    await storage.saveQuestions(allQuestions);

    // 4. Update state and automatically select the new subject
    final updatedSubjects = [
      ...state.subjects.where((s) => s.id != subjectId),
      newSubject,
    ];

    state = state.copyWith(
      subjects: updatedSubjects,
      questions: allQuestions,
      selectedSubjectId: subjectId,
      clearSelectedTopic: true,
    );

    return newSubject;
  }

  /// Automatically syncs a newly created exam into study subjects and questions
  Future<void> syncCreatedExam(Exam exam) async {
    final storage = _ref.read(localStorageServiceProvider);
    final subjName = exam.effectiveSubject;

    Subject? targetSubject = state.subjects.cast<Subject?>().firstWhere(
      (s) => s != null && s.name.toLowerCase() == subjName.toLowerCase(),
      orElse: () => null,
    );

    final updatedSubjects = List<Subject>.from(state.subjects);
    if (targetSubject == null) {
      targetSubject = Subject(
        id: 'subj_${subjName.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}',
        name: subjName,
        description: 'Subject containing ${exam.title}',
        icon: 'school',
        sortOrder: state.subjects.length + 1,
      );
      updatedSubjects.add(targetSubject);
      await storage.saveCustomSubject(targetSubject);
    }

    final questionMap = {for (final q in state.questions) q.id: q};
    for (final q in exam.questions) {
      questionMap[q.id] = q.copyWith(
        subjectId: q.subjectId.isNotEmpty ? q.subjectId : targetSubject.id,
        topicId: q.topicId.isNotEmpty ? q.topicId : 'topic_${exam.id}',
      );
    }
    final allQuestions = questionMap.values.toList();
    await storage.saveQuestions(allQuestions);

    state = state.copyWith(
      subjects: updatedSubjects,
      questions: allQuestions,
    );
  }

  /// Builds a QuizSession directly for a specific Exam
  QuizSession buildQuizSessionForExam(Exam exam) {
    final timeLimit = (exam.durationMinutes != null && exam.durationMinutes! > 0)
        ? exam.durationMinutes! * 60
        : 0;

    return QuizSession(
      id: 'quiz_exam_${exam.id}_${DateTime.now().millisecondsSinceEpoch}',
      mode: StudyMode.practice,
      subjectId: 'subj_${exam.effectiveSubject.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}',
      questions: exam.orderedQuestions,
      timeLimitSeconds: timeLimit,
      startedAt: DateTime.now(),
    );
  }
}

final studyControllerProvider =
    StateNotifierProvider<StudyController, StudyState>((ref) {
  return StudyController(ref);
});
