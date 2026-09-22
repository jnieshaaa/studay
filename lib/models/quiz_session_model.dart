import 'question_model.dart';

enum StudyMode {
  practice,
  quickQuiz,
  timedQuiz,
  mockExam,
  mistakesReview,
  bookmarked,
  weakQuestions;

  String get title {
    switch (this) {
      case StudyMode.practice:
        return 'Practice Mode';
      case StudyMode.quickQuiz:
        return 'Quick Quiz';
      case StudyMode.timedQuiz:
        return 'Timed Quiz';
      case StudyMode.mockExam:
        return 'Mock Exam';
      case StudyMode.mistakesReview:
        return 'Mistakes Review';
      case StudyMode.bookmarked:
        return 'Starred Questions';
      case StudyMode.weakQuestions:
        return 'Weak Questions Review';
    }
  }

  String get subtitle {
    switch (this) {
      case StudyMode.practice:
        return 'No timer • Instant explanations after each answer';
      case StudyMode.quickQuiz:
        return '10 random questions • Rapid 5-minute review';
      case StudyMode.timedQuiz:
        return 'Timed challenge • Test your exam pacing';
      case StudyMode.mockExam:
        return 'Full exam simulation • Answers hidden until end';
      case StudyMode.mistakesReview:
        return 'Replay questions you previously missed';
      case StudyMode.bookmarked:
        return 'Practice questions you starred for later';
      case StudyMode.weakQuestions:
        return 'Auto-targeted review of low accuracy subjects';
    }
  }
}

class QuizAnswer {
  final String questionId;
  final String? selectedChoiceId;
  /// Map of leftText -> matched rightText for Matching questions
  final Map<String, String> matchingAnswers;
  final bool isCorrect;
  final int timeSpentSeconds;

  const QuizAnswer({
    required this.questionId,
    this.selectedChoiceId,
    this.matchingAnswers = const {},
    required this.isCorrect,
    this.timeSpentSeconds = 0,
  });

  Map<String, dynamic> toJson() => {
        'question_id': questionId,
        'selected_choice_id': selectedChoiceId,
        'matching_answers': matchingAnswers,
        'is_correct': isCorrect,
        'time_spent_seconds': timeSpentSeconds,
      };

  factory QuizAnswer.fromJson(Map<String, dynamic> json) => QuizAnswer(
        questionId: json['question_id'] as String,
        selectedChoiceId: json['selected_choice_id'] as String?,
        matchingAnswers: (json['matching_answers'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, v.toString()),
            ) ??
            const {},
        isCorrect: json['is_correct'] as bool? ?? false,
        timeSpentSeconds: json['time_spent_seconds'] as int? ?? 0,
      );
}

class QuizSession {
  final String id;
  final StudyMode mode;
  final String? subjectId;
  final String? topicId;
  final List<Question> questions;
  final Map<String, QuizAnswer> answers; // questionId -> QuizAnswer
  final int timeLimitSeconds;
  final DateTime startedAt;
  final DateTime? completedAt;

  const QuizSession({
    required this.id,
    required this.mode,
    this.subjectId,
    this.topicId,
    required this.questions,
    this.answers = const {},
    this.timeLimitSeconds = 0,
    required this.startedAt,
    this.completedAt,
  });

  int get score => answers.values.where((a) => a.isCorrect).length;
  int get totalQuestions => questions.length;
  double get percentage =>
      totalQuestions > 0 ? (score / totalQuestions) * 100 : 0.0;
  bool get isCompleted => completedAt != null;

  QuizSession copyWith({
    String? id,
    StudyMode? mode,
    String? subjectId,
    String? topicId,
    List<Question>? questions,
    Map<String, QuizAnswer>? answers,
    int? timeLimitSeconds,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return QuizSession(
      id: id ?? this.id,
      mode: mode ?? this.mode,
      subjectId: subjectId ?? this.subjectId,
      topicId: topicId ?? this.topicId,
      questions: questions ?? this.questions,
      answers: answers ?? this.answers,
      timeLimitSeconds: timeLimitSeconds ?? this.timeLimitSeconds,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
