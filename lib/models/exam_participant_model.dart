enum ParticipantStatus { inProgress, submitted }

class ExamParticipant {
  final String id;
  final String examId;
  final String nickname;
  final String deviceToken;
  final DateTime joinedAt;
  final DateTime? submittedAt;
  final int score;
  final int totalQuestions;
  final ParticipantStatus status;

  const ExamParticipant({
    required this.id,
    required this.examId,
    required this.nickname,
    required this.deviceToken,
    required this.joinedAt,
    this.submittedAt,
    this.score = 0,
    this.totalQuestions = 0,
    this.status = ParticipantStatus.inProgress,
  });

  double get percentage =>
      totalQuestions > 0 ? (score / totalQuestions) * 100 : 0.0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'exam_id': examId,
        'nickname': nickname,
        'device_token': deviceToken,
        'joined_at': joinedAt.toIso8601String(),
        'submitted_at': submittedAt?.toIso8601String(),
        'score': score,
        'total_questions': totalQuestions,
        'status': status.name,
      };

  factory ExamParticipant.fromJson(Map<String, dynamic> json) =>
      ExamParticipant(
        id: json['id'] as String,
        examId: json['exam_id'] as String,
        nickname: json['nickname'] as String,
        deviceToken: json['device_token'] as String,
        joinedAt: DateTime.tryParse(json['joined_at'] as String? ?? '') ??
            DateTime.now(),
        submittedAt: json['submitted_at'] != null
            ? DateTime.tryParse(json['submitted_at'] as String)
            : null,
        score: json['score'] as int? ?? 0,
        totalQuestions: json['total_questions'] as int? ?? 0,
        status: ParticipantStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => ParticipantStatus.inProgress,
        ),
      );
}

class ExamResponse {
  final String id;
  final String participantId;
  final String questionId;
  final String? selectedChoiceId;
  final Map<String, String> matchingResponse;
  final bool isCorrect;
  final int timeSpent;

  const ExamResponse({
    required this.id,
    required this.participantId,
    required this.questionId,
    this.selectedChoiceId,
    this.matchingResponse = const {},
    required this.isCorrect,
    this.timeSpent = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'participant_id': participantId,
        'question_id': questionId,
        'selected_choice_id': selectedChoiceId,
        'matching_response': matchingResponse,
        'is_correct': isCorrect,
        'time_spent': timeSpent,
      };

  factory ExamResponse.fromJson(Map<String, dynamic> json) => ExamResponse(
        id: json['id'] as String,
        participantId: json['participant_id'] as String,
        questionId: json['question_id'] as String,
        selectedChoiceId: json['selected_choice_id'] as String?,
        matchingResponse:
            (json['matching_response'] as Map<String, dynamic>?)?.map(
                  (k, v) => MapEntry(k, v.toString()),
                ) ??
                const {},
        isCorrect: json['is_correct'] as bool? ?? false,
        timeSpent: json['time_spent'] as int? ?? 0,
      );
}

class HardestQuestionStat {
  final String questionId;
  final String questionText;
  final int totalAttempts;
  final int correctCount;

  const HardestQuestionStat({
    required this.questionId,
    required this.questionText,
    required this.totalAttempts,
    required this.correctCount,
  });

  double get accuracy =>
      totalAttempts > 0 ? (correctCount / totalAttempts) * 100 : 0.0;
  double get errorRate => 100.0 - accuracy;
}
