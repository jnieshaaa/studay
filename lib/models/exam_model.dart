import 'question_model.dart';

enum ExamStatus {
  draft,
  published,
  closed;

  String get label {
    switch (this) {
      case ExamStatus.draft:
        return 'Draft';
      case ExamStatus.published:
        return 'Active';
      case ExamStatus.closed:
        return 'Closed';
    }
  }
}

enum QuestionOrder { fixed, shuffled }

enum ChoiceOrder { fixed, shuffled }

enum ShowAnswersMode {
  immediately,
  afterClose,
  never;

  String get label {
    switch (this) {
      case ShowAnswersMode.immediately:
        return 'Immediately upon submit';
      case ShowAnswersMode.afterClose:
        return 'After exam closes';
      case ShowAnswersMode.never:
        return 'Never (Maker only)';
    }
  }
}

class Exam {
  final String id;
  final String creatorId;
  final String title;
  final String subject; // e.g. 'Filipino', 'English', 'Math', 'Science'
  final String description;
  final String code; // 6-character code e.g. 4F9K2Q
  final ExamStatus status;
  final QuestionOrder questionOrder;
  static const List<QuestionType> defaultSectionOrder = [
    QuestionType.multipleChoice,
    QuestionType.trueFalse,
    QuestionType.matching,
  ];

  final ChoiceOrder choiceOrder;
  final ShowAnswersMode showAnswers;
  final DateTime? opensAt;
  final DateTime? closesAt;
  final int maxAttemptsPerParticipant;
  final int? durationMinutes; // Timer limit in minutes e.g. 10, 15, 30, or null for untimed
  final int? questionLimit; // Max items shown in exam (e.g. 20 out of 100). If null or <= 0, show all.
  final List<QuestionType> sectionOrder;
  final List<Question> questions;
  final DateTime createdAt;

  const Exam({
    required this.id,
    required this.creatorId,
    required this.title,
    this.subject = 'General Knowledge',
    required this.description,
    required this.code,
    this.status = ExamStatus.draft,
    this.questionOrder = QuestionOrder.shuffled,
    this.choiceOrder = ChoiceOrder.shuffled,
    this.showAnswers = ShowAnswersMode.immediately,
    this.opensAt,
    this.closesAt,
    this.maxAttemptsPerParticipant = 1,
    this.durationMinutes,
    this.questionLimit,
    this.sectionOrder = defaultSectionOrder,
    this.questions = const [],
    required this.createdAt,
  });

  String get effectiveSubject =>
      subject.trim().isNotEmpty ? subject.trim() : 'General Knowledge';

  String get durationLabel {
    if (durationMinutes == null || durationMinutes! <= 0) return 'Untimed';
    return '${durationMinutes}m';
  }

  bool get isExpired {
    if (status == ExamStatus.closed) return true;
    if (closesAt != null && DateTime.now().isAfter(closesAt!)) return true;
    return false;
  }

  bool get isScheduled => opensAt != null || closesAt != null;

  int get totalPoints =>
      questions.fold(0, (sum, q) => sum + (q.points > 0 ? q.points : 1));

  List<String> get categories {
    final set = <String>{};
    for (final q in questions) {
      final cat = q.effectiveCategory;
      if (cat.isNotEmpty) {
        set.add(cat);
      }
    }
    return set.toList()..sort();
  }

  /// Returns all questions sorted strictly by the exam's sectionOrder
  List<Question> get orderedQuestions {
    final ordered = <Question>[];
    for (final type in sectionOrder) {
      ordered.addAll(questions.where((q) => q.questionType == type));
    }
    for (final q in questions) {
      if (!sectionOrder.contains(q.questionType)) {
        ordered.add(q);
      }
    }
    return ordered;
  }

  /// Returns the 1-based part number for a given question type in this exam
  int getPartNumber(QuestionType type) {
    final idx = sectionOrder.indexOf(type);
    return idx >= 0 ? idx + 1 : sectionOrder.length;
  }

  /// Total number of distinct question types present in this exam
  int get activePartsCount {
    final presentTypes = questions.map((q) => q.questionType).toSet();
    return presentTypes.length;
  }

  /// Effective question count for takers (e.g. 20 if questionLimit is 20 out of 100 questions)
  int get effectiveQuestionCount =>
      (questionLimit != null && questionLimit! > 0 && questionLimit! < questions.length)
          ? questionLimit!
          : questions.length;

  /// Whether this exam samples a subset from a larger question bank
  bool get hasQuestionLimit =>
      questionLimit != null && questionLimit! > 0 && questionLimit! < questions.length;

  /// User-friendly label for question count or sample size (e.g. "20 of 100 Qs" or "20 Qs")
  String get questionLimitLabel => hasQuestionLimit
      ? '$questionLimit of ${questions.length} Qs'
      : '${questions.length} Qs';

  /// Whether this exam is created specifically as a flashcard deck
  bool get isFlashcardDeck {
    if (description.contains('<!--type:flashcard-->')) return true;
    if (title.toLowerCase().contains('flashcard')) return true;
    if (description.toLowerCase().contains('flashcard')) return true;
    if (questions.isNotEmpty &&
        questions.every((q) =>
            q.topicId == 'flashcards' ||
            (q.questionType == QuestionType.multipleChoice && q.choices.length <= 1))) {
      return true;
    }
    return false;
  }

  /// Clean description without any embedded metadata comments
  String get cleanDescription =>
      description.replaceAll(RegExp(r'\s*<!--(limit:\d+|type:\w+)-->'), '').trim();

  static int? _parseLimitFromDesc(String desc) {
    final match = RegExp(r'<!--limit:(\d+)-->').firstMatch(desc);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  Exam copyWith({
    String? id,
    String? creatorId,
    String? title,
    String? subject,
    String? description,
    String? code,
    ExamStatus? status,
    QuestionOrder? questionOrder,
    ChoiceOrder? choiceOrder,
    ShowAnswersMode? showAnswers,
    DateTime? opensAt,
    DateTime? closesAt,
    bool clearOpensAt = false,
    bool clearClosesAt = false,
    int? maxAttemptsPerParticipant,
    int? durationMinutes,
    bool clearDuration = false,
    int? questionLimit,
    bool clearQuestionLimit = false,
    List<QuestionType>? sectionOrder,
    List<Question>? questions,
    DateTime? createdAt,
  }) {
    return Exam(
      id: id ?? this.id,
      creatorId: creatorId ?? this.creatorId,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      description: description ?? this.description,
      code: code ?? this.code,
      status: status ?? this.status,
      questionOrder: questionOrder ?? this.questionOrder,
      choiceOrder: choiceOrder ?? this.choiceOrder,
      showAnswers: showAnswers ?? this.showAnswers,
      opensAt: clearOpensAt ? null : (opensAt ?? this.opensAt),
      closesAt: clearClosesAt ? null : (closesAt ?? this.closesAt),
      maxAttemptsPerParticipant:
          maxAttemptsPerParticipant ?? this.maxAttemptsPerParticipant,
      durationMinutes: clearDuration ? null : (durationMinutes ?? this.durationMinutes),
      questionLimit: clearQuestionLimit ? null : (questionLimit ?? this.questionLimit),
      sectionOrder: sectionOrder ?? this.sectionOrder,
      questions: questions ?? this.questions,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'creator_id': creatorId,
        'title': title,
        'subject': subject,
        'description': description,
        'code': code,
        'status': status.name,
        'question_order': questionOrder.name,
        'choice_order': choiceOrder.name,
        'show_answers': showAnswers.name,
        'opens_at': opensAt?.toIso8601String(),
        'closes_at': closesAt?.toIso8601String(),
        'max_attempts_per_participant': maxAttemptsPerParticipant,
        'duration_minutes': durationMinutes,
        'question_limit': questionLimit,
        'section_order': sectionOrder.map((t) => t.name).toList(),
        'questions': questions.map((q) => q.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
      };

  factory Exam.fromJson(Map<String, dynamic> json) {
    final rawDesc = json['description'] as String? ?? '';
    final parsedLimit = _parseLimitFromDesc(rawDesc);
    final limit = json['question_limit'] as int? ?? parsedLimit;

    return Exam(
      id: json['id'] as String,
      creatorId: json['creator_id'] as String? ?? '',
      title: json['title'] as String,
      subject: json['subject'] as String? ?? 'General Knowledge',
      description: rawDesc,
      code: json['code'] as String,
      status: ExamStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => ExamStatus.published,
      ),
      questionOrder: QuestionOrder.values.firstWhere(
        (o) => o.name == json['question_order'],
        orElse: () => QuestionOrder.shuffled,
      ),
      choiceOrder: ChoiceOrder.values.firstWhere(
        (o) => o.name == json['choice_order'],
        orElse: () => ChoiceOrder.shuffled,
      ),
      showAnswers: ShowAnswersMode.values.firstWhere(
        (m) => m.name == json['show_answers'],
        orElse: () => ShowAnswersMode.immediately,
      ),
      opensAt: json['opens_at'] != null
          ? DateTime.tryParse(json['opens_at'] as String)
          : null,
      closesAt: json['closes_at'] != null
          ? DateTime.tryParse(json['closes_at'] as String)
          : null,
      maxAttemptsPerParticipant:
          json['max_attempts_per_participant'] as int? ?? 1,
      durationMinutes: json['duration_minutes'] as int?,
      questionLimit: limit,
      sectionOrder: (json['section_order'] as List<dynamic>?)
              ?.map((name) => QuestionType.values.firstWhere(
                    (t) => t.name == name,
                    orElse: () => QuestionType.multipleChoice,
                  ))
              .toList() ??
          defaultSectionOrder,
      questions: (json['questions'] as List<dynamic>?)
              ?.map((q) => Question.fromJson(q as Map<String, dynamic>))
              .toList() ??
          const [],
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class ExamMakerArgs {
  final Exam? initialExam;
  final List<Question>? initialQuestions;
  final String? initialSubject;

  const ExamMakerArgs({
    this.initialExam,
    this.initialQuestions,
    this.initialSubject,
  });
}
