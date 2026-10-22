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
  ///
  /// Restricted to choice letters A-H (case-insensitive) followed by ')' or '.' with whitespace.
  /// This prevents abbreviations like 'R.A.', 'P.D.', 'A.M.', 'U.S.', or math decimals like '3.14'
  /// from being falsely matched as choice letters.
  static final _choiceRegex = RegExp(
    r'^\s*([*]?)\s*[\[\(]?([A-Ha-h])(?:[\]\)]\s*|\.(?:\s+|$)|(?:\s*-\s*|\s*:\s*)\s*)(.*)$',
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
      final isAnswerOrExplanation = _answerRegex.hasMatch(trimmed) || _explanationRegex.hasMatch(trimmed);
      final startsWithSubsequentChoice = RegExp(
        r'^\s*[*]?\s*[\[\(]?[B-Hb-h](?:[\]\)]\s*|\.(?:\s+|$)|(?:\s*-\s*|\s*:\s*)\s*)',
      ).hasMatch(trimmed);

      final hasChoiceA = RegExp(
        r'(?:^|\n)\s*[*]?\s*[\[\(]?[Aa](?:[\]\)]\s*|\.(?:\s+|$)|(?:\s*-\s*|\s*:\s*)\s*)',
      ).hasMatch(trimmed);
      final prevHasChoiceA = RegExp(
        r'(?:^|\n)\s*[*]?\s*[\[\(]?[Aa](?:[\]\)]\s*|\.(?:\s+|$)|(?:\s*-\s*|\s*:\s*)\s*)',
      ).hasMatch(blocks.last);
      final prevHasAnyPrefixedChoice = RegExp(
        r'(?:^|\n)\s*[*]?\s*[\[\(]?[A-Ha-h](?:[\]\)]\s*|\.(?:\s+|$)|(?:\s*-\s*|\s*:\s*)\s*)',
      ).hasMatch(blocks.last);

      if (startsWithQuestionHeader) {
        blocks.add(trimmed);
      } else if (isAnswerOrExplanation || startsWithSubsequentChoice) {
        // Unambiguous continuation of previous question
        blocks[blocks.length - 1] = '${blocks.last}\n\n$trimmed';
      } else if (hasChoiceA) {
        final trimmedFirstLine = trimmed.split('\n').firstWhere((l) => l.trim().isNotEmpty, orElse: () => '').trim();
        final firstLineIsChoiceA = RegExp(
          r'^\s*[*]?\s*[\[\(]?[Aa](?:[\]\)]\s*|\.(?:\s+|$)|(?:\s*-\s*|\s*:\s*)\s*)',
        ).hasMatch(trimmedFirstLine);
        final prevLineCount = blocks.last.split('\n').where((l) => l.trim().isNotEmpty).length;

        if (!firstLineIsChoiceA || prevHasChoiceA || prevLineCount >= 2) {
          // It's a new question because it has its own prompt, or previous block is already complete
          blocks.add(trimmed);
        } else {
          // Choices for previous 1-line question prompt
          blocks[blocks.length - 1] = '${blocks.last}\n\n$trimmed';
        }
      } else if (prevHasAnyPrefixedChoice) {
        // Previous block was using prefixed choices (A/B/C/D).
        // If current block has multiple lines without prefixes, treat it as a new question.
        final lineCount = trimmed.split('\n').where((l) => l.trim().isNotEmpty).length;
        if (lineCount >= 2) {
          blocks.add(trimmed);
        } else {
          blocks[blocks.length - 1] = '${blocks.last}\n\n$trimmed';
        }
      } else {
        // Plain format (no A/B/C/D prefixes in current or previous block)
        // Each block separated by empty lines is treated as a separate question.
        blocks.add(trimmed);
      }
    }

    return blocks;
  }

  /// Cleans leading numbers, question prefixes like "1. ", "Question 1:", "Q1. " from prompt.
  /// Requires whitespace after the delimiter so that decimal numbers like "3.14" are not truncated.
  static String cleanPrompt(String rawPrompt) {
    return rawPrompt
        .replaceFirst(
          RegExp(
            r'^\s*(?:(?:Question|Item|Q)\s*)?\d+[\.\):\-]\s+',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
  }

  /// Parses a raw text string containing one or more bulk questions.
  /// Supports both standard prefixed format (A), B), C), D)) and simple plain format
  /// (question prompt followed directly by choices on separate lines, with questions separated by blank lines).
  static List<ParsedQuestion> parse(
    String rawText, {
    QuestionType targetType = QuestionType.multipleChoice,
  }) {
    final blocks = splitBlocks(rawText);
    final results = <ParsedQuestion>[];

    for (final block in blocks) {
      final lines = block.split('\n');
      final trimmedLines = lines.map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      if (trimmedLines.isEmpty) continue;

      // Check if this block contains genuine prefixed choices (e.g. A and B).
      // Requiring at least 2 choice prefixes prevents a question prompt or abbreviation
      // starting with "A." from being falsely treated as a choice block.
      final choiceMatchesCount = trimmedLines.where((l) => _choiceRegex.hasMatch(l)).length;
      final hasPrefixedChoices = choiceMatchesCount >= 2;

      if (hasPrefixedChoices) {
        // Parser for prefixed questions (A), B), C), D)
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
            final num = int.tryParse(answerSpec.trim());
            if (num != null && num >= 1 && num <= choices.length) {
              finalCorrectIndex = num - 1;
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
        }

        List<String> effectiveChoices = List<String>.from(choices);
        if (effectiveChoices.isEmpty) {
          if (targetType == QuestionType.trueFalse) {
            effectiveChoices = ['True', 'False'];
          } else {
            effectiveChoices = ['Option A', 'Option B', 'Option C', 'Option D'];
          }
        }

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
      } else {
        // PLAIN FORMAT: No A), B), C), D) prefixes. Simple and clean creator format.
        final contentLines = <String>[];
        final expLines = <String>[];
        String? answerSpec;
        bool parsingExplanation = false;

        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) continue;

          final expMatch = _explanationRegex.firstMatch(trimmed);
          if (expMatch != null) {
            parsingExplanation = true;
            final expText = expMatch.group(1)?.trim() ?? '';
            if (expText.isNotEmpty) expLines.add(expText);
            continue;
          }

          if (parsingExplanation) {
            expLines.add(line.trimRight());
            continue;
          }

          final ansMatch = _answerRegex.firstMatch(trimmed);
          if (ansMatch != null) {
            answerSpec = ansMatch.group(1)?.trim();
            continue;
          }

          contentLines.add(line.trimRight());
        }

        if (contentLines.isEmpty) continue;

        String rawPrompt = '';
        List<String> rawChoices = [];

        if (contentLines.length == 1) {
          rawPrompt = contentLines.first;
          rawChoices = [];
        } else if (contentLines.length == 2 &&
            (targetType == QuestionType.trueFalse ||
                contentLines[1].trim().toLowerCase() == 'true' ||
                contentLines[1].trim().toLowerCase() == 'false')) {
          rawPrompt = contentLines[0];
          rawChoices = [contentLines[1]];
        } else {
          // Identify split point between prompt lines and choice lines
          int splitIndex = -1;

          // Check if lines end with bullets or numbered choices (e.g. "- choice", "• choice", "1) choice", "1. choice")
          final bulletRegex = RegExp(r'^(?:[-*•]|\(?\d+[\.\)])\s+');
          for (int i = 1; i < contentLines.length; i++) {
            if (bulletRegex.hasMatch(contentLines[i].trim())) {
              bool allBullets = true;
              for (int j = i; j < contentLines.length; j++) {
                if (!bulletRegex.hasMatch(contentLines[j].trim())) {
                  allBullets = false;
                  break;
                }
              }
              if (allBullets) {
                splitIndex = i;
                break;
              }
            }
          }

          if (splitIndex < 0) {
            // Find the last line among prompt candidates (leaving at least 2 choices at bottom)
            // that ends with '?'
            int lastPromptQuestionMark = -1;
            int lastPromptColon = -1;
            final maxPromptIdx = contentLines.length - 3; // leaves at least 2 choices

            for (int i = 0; i <= maxPromptIdx; i++) {
              final line = contentLines[i].trim();
              if (line.endsWith('?')) {
                lastPromptQuestionMark = i;
              } else if (line.endsWith(':')) {
                lastPromptColon = i;
              }
            }

            if (lastPromptQuestionMark >= 0) {
              splitIndex = lastPromptQuestionMark + 1;
            } else if (lastPromptColon >= 0) {
              splitIndex = lastPromptColon + 1;
            } else {
              // No question mark or colon found in prompt candidates
              if (targetType == QuestionType.trueFalse) {
                if (contentLines.length >= 3 &&
                    contentLines[contentLines.length - 2].trim().toLowerCase() == 'true' &&
                    contentLines[contentLines.length - 1].trim().toLowerCase() == 'false') {
                  splitIndex = contentLines.length - 2;
                } else {
                  splitIndex = 1;
                }
              } else if (contentLines.length <= 5) {
                // 2 to 5 lines: line 0 is prompt, remaining lines are choices
                splitIndex = 1;
              } else {
                // More than 5 lines: take the last 4 lines as standard MCQ choices
                splitIndex = contentLines.length - 4;
              }
            }
          }

          rawPrompt = contentLines.sublist(0, splitIndex).join('\n');
          rawChoices = contentLines.sublist(splitIndex);
        }

        // Clean choices and look for inline correct indicators
        int markedCorrectIndex = -1;
        final choices = <String>[];

        for (int cIdx = 0; cIdx < rawChoices.length; cIdx++) {
          var c = rawChoices[cIdx].trim();
          bool isCorrectChoice = false;

          // Check for asterisk marker: *choice or choice*
          if (c.startsWith('*')) {
            isCorrectChoice = true;
            c = c.substring(1).trim();
          }
          if (c.endsWith('*')) {
            isCorrectChoice = true;
            c = c.substring(0, c.length - 1).trim();
          }

          // Check for (correct) or [correct]
          if (c.toLowerCase().contains('(correct)')) {
            isCorrectChoice = true;
            c = c.replaceAll(RegExp(r'\(correct\)', caseSensitive: false), '').trim();
          } else if (c.toLowerCase().contains('[correct]')) {
            isCorrectChoice = true;
            c = c.replaceAll(RegExp(r'\[correct\]', caseSensitive: false), '').trim();
          }

          // Strip any leading bullet markers: "- ", "• ", "1) ", "1. "
          c = c.replaceFirst(RegExp(r'^(?:[-*•]|\(?\d+[\.\)])\s+'), '').trim();

          if (isCorrectChoice) {
            markedCorrectIndex = cIdx;
          }

          choices.add(c);
        }

        // Determine correct choice index
        int finalCorrectIndex = 0;
        if (markedCorrectIndex >= 0 && markedCorrectIndex < choices.length) {
          finalCorrectIndex = markedCorrectIndex;
        } else if (answerSpec != null && answerSpec.isNotEmpty) {
          final trimmedAnswer = answerSpec.trim();
          final letterMatch = RegExp(r'^([A-Za-z])\b').firstMatch(trimmedAnswer);
          if (letterMatch != null) {
            final letter = letterMatch.group(1)!.toUpperCase();
            final letterIdx = letter.codeUnitAt(0) - 65; // A -> 0, B -> 1, C -> 2, D -> 3
            if (letterIdx >= 0 && letterIdx < choices.length) {
              finalCorrectIndex = letterIdx;
            }
          }
          if (finalCorrectIndex == 0 && markedCorrectIndex < 0) {
            final num = int.tryParse(trimmedAnswer);
            if (num != null && num >= 1 && num <= choices.length) {
              finalCorrectIndex = num - 1;
            } else {
              final idxByText = choices.indexWhere(
                (c) => c.toLowerCase() == trimmedAnswer.toLowerCase(),
              );
              if (idxByText >= 0) {
                finalCorrectIndex = idxByText;
              }
            }
          }
        }

        List<String> effectiveChoices = List<String>.from(choices);
        if (effectiveChoices.isEmpty) {
          if (targetType == QuestionType.trueFalse) {
            effectiveChoices = ['True', 'False'];
          } else {
            effectiveChoices = ['Option A', 'Option B', 'Option C', 'Option D'];
          }
        }

        QuestionType effectiveType = targetType;
        if (effectiveChoices.length == 2 &&
            effectiveChoices.any((c) => c.toLowerCase() == 'true') &&
            effectiveChoices.any((c) => c.toLowerCase() == 'false')) {
          effectiveType = QuestionType.trueFalse;
        }

        final cleanedPrompt = cleanPrompt(rawPrompt);

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
    }

    return results;
  }
}
