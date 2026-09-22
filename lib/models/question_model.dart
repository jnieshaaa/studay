enum QuestionType {
  multipleChoice,
  trueFalse,
  matching;

  String get label {
    switch (this) {
      case QuestionType.multipleChoice:
        return 'Multiple Choice';
      case QuestionType.trueFalse:
        return 'True / False';
      case QuestionType.matching:
        return 'Matching Type';
    }
  }
}

enum Difficulty {
  easy,
  medium,
  hard;

  String get label {
    switch (this) {
      case Difficulty.easy:
        return 'Easy';
      case Difficulty.medium:
        return 'Medium';
      case Difficulty.hard:
        return 'Hard';
    }
  }
}

class QuestionChoice {
  final String id;
  final String questionId;
  final String choiceText;
  final bool isCorrect;
  final int sortOrder;

  const QuestionChoice({
    required this.id,
    required this.questionId,
    required this.choiceText,
    required this.isCorrect,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'question_id': questionId,
        'choice_text': choiceText,
        'is_correct': isCorrect,
        'sort_order': sortOrder,
      };

  factory QuestionChoice.fromJson(Map<String, dynamic> json) => QuestionChoice(
        id: json['id'] as String,
        questionId: json['question_id'] as String? ?? '',
        choiceText: json['choice_text'] as String,
        isCorrect: json['is_correct'] as bool? ?? false,
        sortOrder: json['sort_order'] as int? ?? 0,
      );
}

class MatchingPair {
  final String id;
  final String questionId;
  final String leftText;
  final String rightText;

  const MatchingPair({
    required this.id,
    required this.questionId,
    required this.leftText,
    required this.rightText,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'question_id': questionId,
        'left_text': leftText,
        'right_text': rightText,
      };

  factory MatchingPair.fromJson(Map<String, dynamic> json) => MatchingPair(
        id: json['id'] as String,
        questionId: json['question_id'] as String? ?? '',
        leftText: json['left_text'] as String,
        rightText: json['right_text'] as String,
      );
}

class Question {
  final String id;
  final String topicId;
  final String subjectId;
  final String category; // e.g. "General Knowledge", "Math", "Constitution"
  final String questionText;
  final QuestionType questionType;
  final Difficulty difficulty;
  final String explanation;
  final String reference;
  final List<QuestionChoice> choices;
  final List<MatchingPair> matchingPairs;
  final int points;
  final bool isBookmarked;

  const Question({
    required this.id,
    required this.topicId,
    required this.subjectId,
    this.category = '',
    required this.questionText,
    required this.questionType,
    this.difficulty = Difficulty.medium,
    this.explanation = '',
    this.reference = '',
    this.choices = const [],
    this.matchingPairs = const [],
    this.points = 1,
    this.isBookmarked = false,
  });

  String get effectiveCategory {
    if (category.trim().isNotEmpty) return category.trim();
    if (topicId.isNotEmpty && topicId != 'custom') {
      return topicId
          .replaceAll('top_', '')
          .replaceAll('_', ' ')
          .split(' ')
          .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
          .join(' ');
    }
    return 'General Knowledge';
  }

  Question copyWith({
    String? id,
    String? topicId,
    String? subjectId,
    String? category,
    String? questionText,
    QuestionType? questionType,
    Difficulty? difficulty,
    String? explanation,
    String? reference,
    List<QuestionChoice>? choices,
    List<MatchingPair>? matchingPairs,
    int? points,
    bool? isBookmarked,
  }) {
    return Question(
      id: id ?? this.id,
      topicId: topicId ?? this.topicId,
      subjectId: subjectId ?? this.subjectId,
      category: category ?? this.category,
      questionText: questionText ?? this.questionText,
      questionType: questionType ?? this.questionType,
      difficulty: difficulty ?? this.difficulty,
      explanation: explanation ?? this.explanation,
      reference: reference ?? this.reference,
      choices: choices ?? this.choices,
      matchingPairs: matchingPairs ?? this.matchingPairs,
      points: points ?? this.points,
      isBookmarked: isBookmarked ?? this.isBookmarked,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'topic_id': topicId,
        'subject_id': subjectId,
        'category': category,
        'question_text': questionText,
        'question_type': questionType.name,
        'difficulty': difficulty.name,
        'explanation': explanation,
        'reference': reference,
        'choices': choices.map((c) => c.toJson()).toList(),
        'matching_pairs': matchingPairs.map((p) => p.toJson()).toList(),
        'points': points,
        'is_bookmarked': isBookmarked,
      };

  factory Question.fromJson(Map<String, dynamic> json) => Question(
        id: json['id'] as String,
        topicId: json['topic_id'] as String? ?? '',
        subjectId: json['subject_id'] as String? ?? '',
        category: json['category'] as String? ?? '',
        questionText: json['question_text'] as String,
        questionType: QuestionType.values.byName(
          json['question_type'] as String? ?? 'multipleChoice',
        ),
        difficulty: Difficulty.values.byName(
          json['difficulty'] as String? ?? 'medium',
        ),
        explanation: json['explanation'] as String? ?? '',
        reference: json['reference'] as String? ?? '',
        choices: (json['choices'] as List<dynamic>?)
                ?.map((c) => QuestionChoice.fromJson(c as Map<String, dynamic>))
                .toList() ??
            const [],
        matchingPairs: (json['matching_pairs'] as List<dynamic>?)
                ?.map((p) => MatchingPair.fromJson(p as Map<String, dynamic>))
                .toList() ??
            const [],
        points: json['points'] as int? ?? 1,
        isBookmarked: json['is_bookmarked'] as bool? ?? false,
      );
}
