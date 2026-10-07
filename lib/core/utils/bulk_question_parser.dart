import '../../models/question_model.dart';
import 'code_generator.dart';

/// Represents a parsed question from raw bulk text before converting to [Question].
class ParsedQuestion {
  final String questionText;
  final List<String> choices;
  final int correctChoiceIndex;
  final String explanation;
  final QuestionType questionType;
  final int points;

  const ParsedQuestion({
    required this.questionText,
    required this.choices,
    this.correctChoiceIndex = 0,
    this.explanation = '',
    this.questionType = QuestionType.multipleChoice,
    this.points = 1,
  });

  /// Converts this parsed question into a domain [Question] model.
  Question toQuestion({
    required String subject,
    String? category,
  }) {
    final qId = CodeGenerator.generateId('q_bulk');
    final effectiveCategory = (category != null && category.trim().isNotEmpty)
        ? category.trim()
        : (subject.trim().isNotEmpty ? subject.trim() : 'General Knowledge');

    final questionChoices = <QuestionChoice>[];
    for (int i = 0; i < choices.length; i++) {
      questionChoices.add(
        QuestionChoice(
          id: CodeGenerator.generateId('c'),
          questionId: qId,
          choiceText: choices[i],
          isCorrect: i == correctChoiceIndex,
          sortOrder: i,
        ),
      );
    }

    return Question(
      id: qId,
      topicId: 'custom',
      subjectId: 'custom',
      category: effectiveCategory,
      questionText: questionText,
      questionType: questionType,
      difficulty: Difficulty.medium,
      explanation: explanation,
      reference: '',
      choices: questionChoices,
      points: points,
    );
  }
}

/// Utility for parsing raw bulk question text formatted with numbers and A), B), C), D) options.
class BulkQuestionParser {
  /// Matches choice lines like:
  /// A) Choice text
  /// B. Choice text
  /// (C) Choice text
  /// *D) Choice text (asterisk indicates correct)
  /// a) Choice text
  /// A) (standalone on its own line)
  static final _choiceRegex = RegExp(
    r'^\s*([*]?)\s*\(?([A-Za-z])(?:[\.\)]|\s*-\s*|\s*:\s*|\))\s*(.*)$',
  );

  /// Matches answer specification lines like:
  /// Answer: C
  /// Ans: B
  /// Correct Answer: const
  static final _answerRegex = RegExp(
    r'^\s*(?:Answer|Ans|Correct(?:\s*Answer)?)\s*[:=\-]?\s*(.+)$',
    caseSensitive: false,
  );

  /// Matches explanation lines like:
  /// Explanation: Some detailed reason
  /// Exp: Another explanation
  static final _explanationRegex = RegExp(
    r'^\s*(?:Explanation|Explain|Exp)\s*[:=\-]?\s*(.+)$',
    caseSensitive: false,
  );

  /// Splits input into question blocks.
  /// If multiple numbered questions exist, splits by question headers directly so that
  /// internal empty lines inside code blocks are preserved. Otherwise splits by blank lines
  /// and merges continuation chunks.
  static List<String> splitBlocks(String rawText) {
    final normalized = rawText.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
    if (normalized.isEmpty) return [];

    final questionHeaderRegex = RegExp(
      r'(?:^|\n)\s*(?:(?:Question\s*|Q\s*|Item\s*)?\d+[\.\)]|\bQ\d+[:\.]?)\s+',
      multiLine: true,
      caseSensitive: false,
    );

    // If text contains multiple numbered question headers, split directly by those headers
    final headerMatches = questionHeaderRegex.allMatches(normalized).toList();
    if (headerMatches.length > 1) {
      final blocks = <String>[];
      for (int i = 0; i < headerMatches.length; i++) {
        final start = headerMatches[i].start;
        final end = (i + 1 < headerMatches.length) ? headerMatches[i + 1].start : normalized.length;
        final sub = normalized.substring(start, end).trim();
        if (sub.isNotEmpty) {
          blocks.add(sub);
        }
      }
      return blocks;
    }

    // Otherwise, split by blank lines and fold continuation blocks
    final rawBlocks = normalized.split(RegExp(r'\n\s*\n+'));
    final blocks = <String>[];

    for (final raw in rawBlocks) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;

      if (blocks.isEmpty) {
        blocks.add(trimmed);
        continue;
      }

      final startsWithQuestionHeader = questionHeaderRegex.hasMatch(trimmed);
      final hasChoiceA = RegExp(r'(?:^|\n)\s*[*]?\s*\(?[Aa](?:[\.\)]|\s*-\s*|\s*:\s*|\))').hasMatch(trimmed);
      final previousHasChoiceA = RegExp(r'(?:^|\n)\s*[*]?\s*\(?[Aa](?:[\.\)]|\s*-\s*|\s*:\s*|\))').hasMatch(blocks.last);

      if (startsWithQuestionHeader || (hasChoiceA && previousHasChoiceA)) {
        blocks.add(trimmed);
      } else {
        blocks[blocks.length - 1] = '${blocks.last}\n\n$trimmed';
      }
    }

    return blocks;
  }

  /// Cleans leading numbers, question prefixes like "1. ", "Question 1:", "Q1. " from prompt.
  static String cleanPrompt(String rawPrompt) {
    return rawPrompt
        .replaceFirst(
          RegExp(
            r'^\s*(?:(?:Question|Item|Q)\s*)?\d+[\.\):\-]\s*',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
  }

  /// Parses a raw text string containing one or more bulk questions.
  static List<ParsedQuestion> parse(
    String rawText, {
    QuestionType targetType = QuestionType.multipleChoice,
  }) {
    final blocks = splitBlocks(rawText);
    final results = <ParsedQuestion>[];

    for (final block in blocks) {
      final lines = block.split('\n');
      final promptLines = <String>[];
      final choices = <String>[];
      final choiceLetters = <String>[];
      int markedCorrectIndex = -1;
      String? answerSpec;
      final expLines = <String>[];
      bool parsingChoices = false;
      bool parsingExplanation = false;

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        final trimmed = line.trim();
        if (trimmed.isEmpty) {
          // If we are currently parsing choices, preserve internal blank lines inside code
          if (parsingChoices && choices.isNotEmpty && choices.last.isNotEmpty) {
            bool isSeparator = false;
            for (int j = i + 1; j < lines.length; j++) {
              final nextTrimmed = lines[j].trim();
              if (nextTrimmed.isEmpty) continue;
              if (_choiceRegex.hasMatch(nextTrimmed) ||
                  _answerRegex.hasMatch(nextTrimmed) ||
                  _explanationRegex.hasMatch(nextTrimmed)) {
                isSeparator = true;
              }
              break;
            }
            if (!isSeparator) {
              choices[choices.length - 1] = '${choices.last}\n';
            }
          }
          continue;
        }

        // Check for explanation line
        final expMatch = _explanationRegex.firstMatch(trimmed);
        if (expMatch != null) {
          parsingExplanation = true;
          parsingChoices = false;
          final expText = expMatch.group(1)?.trim() ?? '';
          if (expText.isNotEmpty) expLines.add(expText);
          continue;
        }

        if (parsingExplanation) {
          expLines.add(line.trimRight());
          continue;
        }

        // Check for answer line
        final ansMatch = _answerRegex.firstMatch(trimmed);
        if (ansMatch != null) {
          answerSpec = ansMatch.group(1)?.trim();
          continue;
        }

        // Check for choice line
        final choiceMatch = _choiceRegex.firstMatch(trimmed);
        if (choiceMatch != null) {
          parsingChoices = true;
          final asterisk = choiceMatch.group(1) ?? '';
          final letter = choiceMatch.group(2)?.toUpperCase() ?? '';
          String choiceText = choiceMatch.group(3)?.trim() ?? '';

          // Check for inline correct indicators: (correct), [correct], or trailing asterisk
          bool isCorrectChoice = asterisk.contains('*');
          if (choiceText.toLowerCase().contains('(correct)')) {
            isCorrectChoice = true;
            choiceText = choiceText.replaceAll(RegExp(r'\(correct\)', caseSensitive: false), '').trim();
          } else if (choiceText.toLowerCase().contains('[correct]')) {
            isCorrectChoice = true;
            choiceText = choiceText.replaceAll(RegExp(r'\[correct\]', caseSensitive: false), '').trim();
          } else if (choiceText.endsWith('*')) {
            isCorrectChoice = true;
            choiceText = choiceText.substring(0, choiceText.length - 1).trim();
          }

          if (isCorrectChoice) {
            markedCorrectIndex = choices.length;
          }

          choices.add(choiceText);
          choiceLetters.add(letter);
          continue;
        }

        // If we haven't started choices yet, this line is part of the question prompt
        if (!parsingChoices) {
          promptLines.add(line.trimRight());
        } else {
          // If choices have started and this is an un-prefixed line, append to last choice
          if (choices.isNotEmpty) {
            if (choices.last.isEmpty) {
              choices[choices.length - 1] = line.trimRight();
            } else {
              choices[choices.length - 1] = '${choices.last}\n${line.trimRight()}';
            }
          }
        }
      }

      // Check for inline (correct) markers in multi-line choices
      for (int cIdx = 0; cIdx < choices.length; cIdx++) {
        var c = choices[cIdx];
        if (c.toLowerCase().contains('(correct)')) {
          markedCorrectIndex = cIdx;
          c = c.replaceAll(RegExp(r'\(correct\)', caseSensitive: false), '').trim();
        } else if (c.toLowerCase().contains('[correct]')) {
          markedCorrectIndex = cIdx;
          c = c.replaceAll(RegExp(r'\[correct\]', caseSensitive: false), '').trim();
        } else if (c.endsWith('*')) {
          markedCorrectIndex = cIdx;
          c = c.substring(0, c.length - 1).trim();
        }
        choices[cIdx] = c.trim();
      }

      if (promptLines.isEmpty && choices.isEmpty) continue;

      final rawPrompt = promptLines.join('\n');
      final cleanedPrompt = cleanPrompt(rawPrompt);

      if (cleanedPrompt.isEmpty && choices.isEmpty) continue;

      // Determine correct choice index
      int finalCorrectIndex = 0;
      if (markedCorrectIndex >= 0 && markedCorrectIndex < choices.length) {
        finalCorrectIndex = markedCorrectIndex;
      } else if (answerSpec != null && answerSpec.isNotEmpty) {
        // Try finding matching choice letter (e.g. "C", "C)", "Answer: C")
        final letterMatch = RegExp(r'^([A-Za-z])\b').firstMatch(answerSpec);
        final targetLetter = letterMatch != null
            ? letterMatch.group(1)!.toUpperCase()
            : answerSpec.trim().toUpperCase();

        final idxByLetter = choiceLetters.indexOf(targetLetter);
        if (idxByLetter >= 0) {
          finalCorrectIndex = idxByLetter;
        } else {
          // Try matching text directly
          final idxByText = choices.indexWhere(
            (c) => c.toLowerCase() == answerSpec!.toLowerCase().trim(),
          );
          if (idxByText >= 0) {
            finalCorrectIndex = idxByText;
          }
        }
      }

      // If user provided a question with 0 choices, provide fallback default choices
      List<String> effectiveChoices = List<String>.from(choices);
      if (effectiveChoices.isEmpty) {
        if (targetType == QuestionType.trueFalse) {
          effectiveChoices = ['True', 'False'];
        } else {
          effectiveChoices = ['Option A', 'Option B', 'Option C', 'Option D'];
        }
      }

      // Determine question type:
      // If targetType is trueFalse, or choices are exactly True and False:
      QuestionType effectiveType = targetType;
      if (effectiveChoices.length == 2 &&
          effectiveChoices.any((c) => c.toLowerCase() == 'true') &&
          effectiveChoices.any((c) => c.toLowerCase() == 'false')) {
        effectiveType = QuestionType.trueFalse;
      }

      results.add(
        ParsedQuestion(
          questionText: cleanedPrompt.isNotEmpty ? cleanedPrompt : 'Untitled Question',
          choices: effectiveChoices,
          correctChoiceIndex: (finalCorrectIndex >= 0 && finalCorrectIndex < effectiveChoices.length)
              ? finalCorrectIndex
              : 0,
          explanation: expLines.join('\n').trim(),
          questionType: effectiveType,
          points: 1,
        ),
      );
    }

    return results;
  }
}
