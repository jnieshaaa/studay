class QuestionProgress {
  final String questionId;
  final int attempts;
  final int correctCount;
  final int wrongCount;
  final bool isBookmarked;
  final DateTime lastAnsweredAt;

  const QuestionProgress({
    required this.questionId,
    this.attempts = 0,
    this.correctCount = 0,
    this.wrongCount = 0,
    this.isBookmarked = false,
    required this.lastAnsweredAt,
  });

  double get accuracy =>
      attempts > 0 ? (correctCount / attempts) * 100 : 0.0;
  bool get isWeak => attempts >= 1 && accuracy < 65.0;

  QuestionProgress copyWith({
    String? questionId,
    int? attempts,
    int? correctCount,
    int? wrongCount,
    bool? isBookmarked,
    DateTime? lastAnsweredAt,
  }) {
    return QuestionProgress(
      questionId: questionId ?? this.questionId,
      attempts: attempts ?? this.attempts,
      correctCount: correctCount ?? this.correctCount,
      wrongCount: wrongCount ?? this.wrongCount,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      lastAnsweredAt: lastAnsweredAt ?? this.lastAnsweredAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'question_id': questionId,
        'attempts': attempts,
        'correct_count': correctCount,
        'wrong_count': wrongCount,
        'is_bookmarked': isBookmarked,
        'last_answered_at': lastAnsweredAt.toIso8601String(),
      };

  factory QuestionProgress.fromJson(Map<String, dynamic> json) =>
      QuestionProgress(
        questionId: json['question_id'] as String,
        attempts: json['attempts'] as int? ?? 0,
        correctCount: json['correct_count'] as int? ?? 0,
        wrongCount: json['wrong_count'] as int? ?? 0,
        isBookmarked: json['is_bookmarked'] as bool? ?? false,
        lastAnsweredAt: DateTime.tryParse(json['last_answered_at'] as String? ?? '') ??
            DateTime.now(),
      );
}

class SubjectPerformance {
  final String subjectId;
  final String subjectName;
  final int totalQuestions;
  final int answeredCount;
  final int correctCount;
  final int weakQuestionsCount;

  const SubjectPerformance({
    required this.subjectId,
    required this.subjectName,
    required this.totalQuestions,
    this.answeredCount = 0,
    this.correctCount = 0,
    this.weakQuestionsCount = 0,
  });

  double get accuracy =>
      answeredCount > 0 ? (correctCount / answeredCount) * 100 : 0.0;
}
