import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/question_model.dart';
import 'local_storage_service.dart';

class AiApiKeyMissingException implements Exception {
  final String message;
  const AiApiKeyMissingException([this.message = 'A Gemini API Key is required to generate content.']);

  @override
  String toString() => message;
}

class AiGenerationException implements Exception {
  final String message;
  const AiGenerationException([this.message = 'AI generation is temporarily unavailable. Please try again shortly.']);

  @override
  String toString() => message;
}

/// Service that leverages Google Gemini to automatically generate
/// exam questions and flashcards from lecture notes, slides, or PDF text.
class AiGeneratorService {
  final LocalStorageService _storage;

  AiGeneratorService(this._storage);

  /// Computes a deterministic SHA-256 hash of the input document text.
  /// Normalizes whitespace so minor spacing differences don't invalidate the cache.
  String computeDocumentHash(String text) {
    final normalized = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    final bytes = utf8.encode(normalized);
    return sha256.convert(bytes).toString();
  }

  /// Computes a cache key based on the document fingerprint and generation parameters.
  String computeCacheKey(
    String text, {
    required String mode,
    int count = 10,
    List<QuestionType>? types,
  }) {
    final docHash = computeDocumentHash(text);
    final effectiveTypes = types ??
        (mode == 'exam'
            ? const [
                QuestionType.multipleChoice,
                QuestionType.trueFalse,
                QuestionType.matching,
              ]
            : null);
    final typeKey = effectiveTypes != null && effectiveTypes.isNotEmpty
        ? (effectiveTypes.map((t) => t.name).toList()..sort()).join(',')
        : 'default';
    return 'ai_v2_${mode}_${docHash}_${count}_$typeKey';
  }

  /// Checks if cached questions exist for the given text and parameters.
  Future<bool> hasCachedQuestions(
    String text, {
    int count = 10,
    List<QuestionType>? types,
  }) async {
    final key = computeCacheKey(text, mode: 'exam', count: count, types: types);
    return _storage.hasCachedAiResult(key);
  }

  /// Checks if cached flashcards exist for the given text and count.
  Future<bool> hasCachedFlashcards(
    String text, {
    int count = 15,
  }) async {
    final key = computeCacheKey(text, mode: 'flashcard', count: count);
    return _storage.hasCachedAiResult(key);
  }

  /// Retrieves cached questions from local storage if available.
  Future<List<Question>?> getCachedQuestions(
    String text, {
    int count = 10,
    List<QuestionType>? types,
  }) async {
    final key = computeCacheKey(text, mode: 'exam', count: count, types: types);
    final rawJson = await _storage.loadCachedAiResult(key);
    if (rawJson == null || rawJson.isEmpty) return null;

    try {
      final dynamic decoded = jsonDecode(rawJson);
      if (decoded is List) {
        final questions = decoded
            .map((q) => Question.fromJson(q as Map<String, dynamic>))
            .toList();

        // Quality check: Reject stale cached questions that contain structural noise (e.g. "Part 1", "Chapter 2")
        final hasNoise = questions.any((q) =>
            isStructuralNoise(q.questionText) ||
            isStructuralNoiseQuestion(q.questionText) ||
            q.questionText.contains(RegExp(r'\b(Part|Chapter|Section|Module)\s*\d+\b', caseSensitive: false)));

        if (hasNoise) {
          debugPrint('[AiGeneratorService] Cached questions contain structural noise. Discarding cache entry.');
          return null;
        }

        return questions;
      }
    } catch (e) {
      debugPrint('[AiGeneratorService] Failed to decode cached questions: $e');
    }
    return null;
  }

  /// Retrieves cached flashcards from local storage if available.
  Future<List<Map<String, String>>?> getCachedFlashcards(
    String text, {
    int count = 15,
  }) async {
    final key = computeCacheKey(text, mode: 'flashcard', count: count);
    final rawJson = await _storage.loadCachedAiResult(key);
    if (rawJson == null || rawJson.isEmpty) return null;

    try {
      final dynamic decoded = jsonDecode(rawJson);
      if (decoded is List) {
        final List<Map<String, String>> cards = [];
        for (final item in decoded) {
          if (item is Map) {
            cards.add({
              'front': (item['front'] ?? '').toString(),
              'back': (item['back'] ?? '').toString(),
              'hint': (item['hint'] ?? '').toString(),
            });
          }
        }
        // Quality check: reject if cards contain structural noise
        if (cards.any((c) => isStructuralNoise(c['front'] ?? ''))) {
          debugPrint('[AiGeneratorService] Cached flashcards contain structural noise. Discarding cache entry.');
          return null;
        }
        if (cards.isNotEmpty) return cards;
      }
    } catch (e) {
      debugPrint('[AiGeneratorService] Failed to decode cached flashcards: $e');
    }
    return null;
  }

  /// Resolves the active Gemini API key from explicit param, local storage, or .env.
  Future<String?> getActiveApiKey({String? explicitKey}) async {
    if (explicitKey != null && explicitKey.trim().isNotEmpty) {
      return explicitKey.trim();
    }
    final storedKey = await _storage.loadGeminiApiKey();
    if (storedKey != null && storedKey.trim().isNotEmpty) {
      return storedKey.trim();
    }
    if (dotenv.isInitialized) {
      final envKey = dotenv.env['GEMINI_API_KEY'];
      if (envKey != null && envKey.trim().isNotEmpty) {
        return envKey.trim();
      }
    }
    return null;
  }

  /// Saves the user-supplied Gemini API key to local storage for future reuse.
  Future<void> saveApiKey(String apiKey) async {
    await _storage.saveGeminiApiKey(apiKey);
  }


  /// Attempts content generation with automatic candidate model fallback
  /// if a specific model identifier is not enabled for the provided API key or region.
  Future<GenerateContentResponse> _generateContentWithFallback({
    required String prompt,
    String? explicitKey,
  }) async {
    final key = await getActiveApiKey(explicitKey: explicitKey);
    if (key == null || key.isEmpty) {
      throw const AiApiKeyMissingException(
        'Please provide a Gemini API Key to use automated AI generation.',
      );
    }

    final candidateModels = [
      'gemini-1.5-flash',
      'gemini-1.5-flash-latest',
      'gemini-2.0-flash',
      'gemini-1.5-pro',
      'gemini-pro',
    ];

    Object? lastError;
    for (final modelName in candidateModels) {
      try {
        final model = GenerativeModel(
          model: modelName,
          apiKey: key,
          generationConfig: GenerationConfig(
            temperature: 0.4,
            responseMimeType: 'application/json',
          ),
        );
        final response = await model.generateContent([Content.text(prompt)]);
        return response;
      } catch (e) {
        lastError = e;
        debugPrint('[AiGeneratorService] Model $modelName failed: $e');
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('not found') || errStr.contains('not supported')) {
          continue;
        }
        break;
      }
    }

    throw lastError ?? Exception('All Gemini candidate models failed to generate content.');
  }

  /// Generates structured exam questions (MCQ, True/False, Matching) from text.
  /// If the identical text and options were processed previously, loads instantly from cache.
  Future<List<Question>> generateQuestionsFromText(
    String text, {
    int count = 10,
    String? subject,
    List<QuestionType> types = const [
      QuestionType.multipleChoice,
      QuestionType.trueFalse,
      QuestionType.matching,
    ],
    String? apiKey,
    bool skipCache = false,
  }) async {
    if (text.trim().isEmpty) {
      throw ArgumentError('Input text is empty.');
    }

    // 1. Check content cache first to avoid re-generating identical content & wasting tokens
    if (!skipCache) {
      final cached = await getCachedQuestions(text, count: count, types: types);
      if (cached != null && cached.isNotEmpty) {
        debugPrint(
          '[AiGeneratorService] Token-Saver: Returned ${cached.length} questions from local cache (0 tokens consumed).',
        );
        return cached;
      }
    }

    final totalExpected = count * types.length;

    final typeBreakdown = types.map((t) {
      switch (t) {
        case QuestionType.multipleChoice:
          return '$count Multiple Choice questions (each with 4 choices and exactly 1 correct answer)';
        case QuestionType.trueFalse:
          return '$count True/False questions (statements with True and False options and 1 correct answer)';
        case QuestionType.matching:
          return '$count Matching Type questions (each question containing 3 to 6 premise -> target pairs to match)';
      }
    }).join('\n- ');

    final prompt = '''
You are an expert educational exam writer. Analyze the following document text and create an exam containing exactly $count questions FOR EACH of the selected question types (a total of $totalExpected questions):
- $typeBreakdown

Subject: ${subject ?? 'General Knowledge'}.

CRITICAL QUALITY AND CONTEXT GUIDELINES:
1. STRICT SUBJECT-MATTER FOCUS: Base every question strictly on the academic, scientific, or factual knowledge within the text.
2. NEVER ASK ABOUT DOCUMENT STRUCTURE OR LAYOUT:
   - Absolutely NEVER generate questions asking about parts, chapters, modules, units, sections, page numbers, or headings (e.g. NEVER ask "What is discussed in Part 1?", "Which chapter covers X?", "According to section 2...", or match "Part 1" to a topic).
   - Completely ignore structural headers like "Part 1", "Part 2", "Chapter 3", "Module 4", "Table of Contents", etc. Focus 100% on the substantive topics and principles within them.
3. DIVERSIFY ACROSS QUESTION TYPES (NO DUPLICATES):
   - Multiple Choice: Test comprehension of principles, distinguishing between terms, functions, and application of concepts. Use 4 clear, plausible choices.
   - True/False: Formulate meaningful, standalone factual statements about the subject matter. For False statements, create realistic, plausible modifications (e.g. reversed conditions, swapped functions), accompanied by clear explanations.
   - Matching: Group distinct terms, mechanisms, or components with their exact definitions or roles. Do NOT simply re-use the exact same questions from Multiple Choice.
4. ACCURACY AND DISTRACTORS: All choices and facts must be directly supported by the text. No obvious placeholder answers or trivial giveaway choices.

Return a STRICT JSON array of question objects adhering to this schema:
[
  {
    "type": "multipleChoice",
    "question": "Question prompt here",
    "choices": [
      {"text": "Option A", "isCorrect": false},
      {"text": "Option B", "isCorrect": true},
      {"text": "Option C", "isCorrect": false},
      {"text": "Option D", "isCorrect": false}
    ],
    "explanation": "Clear explanation why Option B is correct"
  },
  {
    "type": "trueFalse",
    "question": "Statement to evaluate",
    "choices": [
      {"text": "True", "isCorrect": true},
      {"text": "False", "isCorrect": false}
    ],
    "explanation": "Explanation for statement"
  },
  {
    "type": "matching",
    "question": "Match each term with its correct definition",
    "matchingPairs": [
      {"left": "Term 1", "right": "Definition 1"},
      {"left": "Term 2", "right": "Definition 2"},
      {"left": "Term 3", "right": "Definition 3"}
    ],
    "explanation": "Summary of connections"
  }
]

Document text:
$text
''';

    try {
      final response = await _generateContentWithFallback(
        prompt: prompt,
        explicitKey: apiKey,
      );
      final rawResponse = response.text?.trim() ?? '[]';
      final cleanedJson = _cleanJsonString(rawResponse);
      final dynamic parsed = jsonDecode(cleanedJson);

      if (parsed is! List) {
        throw const FormatException('Expected a JSON array of questions.');
      }

      final List<Question> result = [];
      final now = DateTime.now().millisecondsSinceEpoch;

      for (int i = 0; i < parsed.length; i++) {
        final item = parsed[i] as Map<String, dynamic>;
        final typeStr = (item['type'] ?? 'multipleChoice').toString();
        final qText = (item['question'] ?? '').toString().trim();
        final explanation = (item['explanation'] ?? '').toString().trim();

        if (qText.isEmpty) continue;
        if (isStructuralNoiseQuestion(qText)) continue;

        final qId = 'ai_q_${now}_$i';

        if (typeStr == 'matching' && item['matchingPairs'] is List) {
          final rawPairs = item['matchingPairs'] as List<dynamic>;
          final pairs = <MatchingPair>[];

          for (int pIdx = 0; pIdx < rawPairs.length; pIdx++) {
            final p = rawPairs[pIdx] as Map<String, dynamic>;
            final left = (p['left'] ?? '').toString().trim();
            final right = (p['right'] ?? '').toString().trim();
            if (left.isNotEmpty && right.isNotEmpty && !isStructuralNoise(left)) {
              pairs.add(
                MatchingPair(
                  id: 'mp_${qId}_$pIdx',
                  questionId: qId,
                  leftText: left,
                  rightText: right,
                ),
              );
            }
          }

          if (pairs.length >= 2) {
            result.add(
              Question(
                id: qId,
                topicId: 'custom',
                subjectId: 'custom',
                category: subject ?? 'General Knowledge',
                questionText: qText,
                questionType: QuestionType.matching,
                explanation: '',
                matchingPairs: pairs,
              ),
            );
          }
        } else if (typeStr == 'trueFalse') {
          final rawChoices = item['choices'] as List<dynamic>? ?? [];
          final choices = <QuestionChoice>[];

          for (int cIdx = 0; cIdx < rawChoices.length; cIdx++) {
            final c = rawChoices[cIdx] as Map<String, dynamic>;
            final text = (c['text'] ?? '').toString().trim();
            final isCorrect = c['isCorrect'] == true;
            choices.add(
              QuestionChoice(
                id: 'ch_${qId}_$cIdx',
                questionId: qId,
                choiceText: text,
                isCorrect: isCorrect,
                sortOrder: cIdx,
              ),
            );
          }

          result.add(
            Question(
              id: qId,
              topicId: 'custom',
              subjectId: 'custom',
              category: subject ?? 'General Knowledge',
              questionText: qText,
              questionType: QuestionType.trueFalse,
              explanation: explanation,
              choices: choices.isNotEmpty
                  ? choices
                  : [
                      QuestionChoice(id: 'ch_${qId}_0', questionId: qId, choiceText: 'True', isCorrect: true, sortOrder: 0),
                      QuestionChoice(id: 'ch_${qId}_1', questionId: qId, choiceText: 'False', isCorrect: false, sortOrder: 1),
                    ],
            ),
          );
        } else {
          // Multiple Choice default
          final rawChoices = item['choices'] as List<dynamic>? ?? [];
          final choices = <QuestionChoice>[];

          for (int cIdx = 0; cIdx < rawChoices.length; cIdx++) {
            final c = rawChoices[cIdx] as Map<String, dynamic>;
            final text = (c['text'] ?? '').toString().trim();
            final isCorrect = c['isCorrect'] == true;
            if (text.isNotEmpty) {
              choices.add(
                QuestionChoice(
                  id: 'ch_${qId}_$cIdx',
                  questionId: qId,
                  choiceText: text,
                  isCorrect: isCorrect,
                  sortOrder: cIdx,
                ),
              );
            }
          }

          // Ensure at least one correct choice
          if (choices.isNotEmpty && !choices.any((c) => c.isCorrect)) {
            choices[0] = choices[0].copyWith(isCorrect: true);
          }

          if (choices.length >= 2) {
            result.add(
              Question(
                id: qId,
                topicId: 'custom',
                subjectId: 'custom',
                category: subject ?? 'General Knowledge',
                questionText: qText,
                questionType: QuestionType.multipleChoice,
                explanation: explanation,
                choices: choices,
              ),
            );
          }
        }
      }

      // 2. Cache successful generated questions locally for instant token-free reuse
      if (result.isNotEmpty) {
        final key = computeCacheKey(text, mode: 'exam', count: count, types: types);
        final jsonStr = jsonEncode(result.map((q) => q.toJson()).toList());
        await _storage.saveCachedAiResult(key, jsonStr);
      }

      return result;
    } catch (e) {
      if (e is AiApiKeyMissingException) {
        rethrow;
      }
      debugPrint('[AiGeneratorService] Cloud generation error: $e. Engaging Smart On-Device Extractor fallback...');
      final localQuestions = generateQuestionsLocally(
        text,
        count: count,
        subject: subject,
        types: types,
      );
      if (localQuestions.isNotEmpty) {
        final key = computeCacheKey(text, mode: 'exam', count: count, types: types);
        final jsonStr = jsonEncode(localQuestions.map((q) => q.toJson()).toList());
        await _storage.saveCachedAiResult(key, jsonStr);
        return localQuestions;
      }
      rethrow;
    }
  }

  /// Generates flashcard drafts (front, back, hint) from text.
  /// If identical text and count were previously generated, loads directly from local cache (0 tokens).
  Future<List<Map<String, String>>> generateFlashcardsFromText(
    String text, {
    int count = 15,
    String? subject,
    String? apiKey,
    bool skipCache = false,
  }) async {
    if (text.trim().isEmpty) {
      throw ArgumentError('Input text is empty.');
    }

    // 1. Check content cache first to avoid re-generating identical content & wasting tokens
    if (!skipCache) {
      final cached = await getCachedFlashcards(text, count: count);
      if (cached != null && cached.isNotEmpty) {
        debugPrint(
          '[AiGeneratorService] Token-Saver: Returned ${cached.length} flashcards from local cache (0 tokens consumed).',
        );
        return cached;
      }
    }

    final prompt = '''
You are a study expert creating flashcards for spaced repetition.
Analyze the following document text and extract $count essential flashcard pairs.
Focus on definitions, formulas, key concepts, terminology, and facts.
Subject: ${subject ?? 'General Knowledge'}.

CRITICAL QUALITY GUIDELINES:
- Extract exclusively substantive educational terms, concepts, definitions, formulas, and key facts.
- Do NOT create flashcards for document structure, layout, or section markers (e.g. NEVER create cards for "Part 1", "Chapter 2", "Module 3", "Table of Contents", or page references).

Return a STRICT JSON array of objects:
[
  {
    "front": "Term, concept, or question",
    "back": "Clear definition, formula, or concise explanation",
    "hint": "Optional short hint or memory clue"
  }
]

Document text:
$text
''';

    try {
      final response = await _generateContentWithFallback(
        prompt: prompt,
        explicitKey: apiKey,
      );
      final rawResponse = response.text?.trim() ?? '[]';
      final cleanedJson = _cleanJsonString(rawResponse);
      final dynamic parsed = jsonDecode(cleanedJson);

      if (parsed is! List) {
        throw const FormatException('Expected a JSON array of flashcards.');
      }

      final List<Map<String, String>> cards = [];
      for (final item in parsed) {
        if (item is Map) {
          final front = (item['front'] ?? '').toString().trim();
          final back = (item['back'] ?? '').toString().trim();
          final hint = (item['hint'] ?? '').toString().trim();

          if (front.isNotEmpty && back.isNotEmpty) {
            cards.add({
              'front': front,
              'back': back,
              'hint': hint,
            });
          }
        }
      }

      // 2. Cache successful flashcards locally for instant token-free reuse
      if (cards.isNotEmpty) {
        final key = computeCacheKey(text, mode: 'flashcard', count: count);
        await _storage.saveCachedAiResult(key, jsonEncode(cards));
      }

      return cards;
    } catch (e) {
      if (e is AiApiKeyMissingException) {
        rethrow;
      }
      debugPrint('[AiGeneratorService] Cloud generation error: $e. Engaging Smart On-Device Extractor fallback...');
      final localCards = generateFlashcardsLocally(
        text,
        count: count,
        subject: subject,
      );
      if (localCards.isNotEmpty) {
        final key = computeCacheKey(text, mode: 'flashcard', count: count);
        await _storage.saveCachedAiResult(key, jsonEncode(localCards));
        return localCards;
      }
      rethrow;
    }
  }

  /// Checks if a candidate term or string is structural or administrative document noise.
  bool isStructuralNoise(String text) {
    final clean = text.trim().toLowerCase();
    if (clean.length < 2) return true;

    // Pure numbers, symbols, or Roman numerals
    if (RegExp(r'^[\d\s\.\-_/:\(\)ivxlcdm]+$', caseSensitive: false).hasMatch(clean)) {
      return true;
    }

    // Structural headings like "Part 1", "Chapter 2", "Module 3", "Section 4.1", "Topic A", etc.
    final structuralPattern = RegExp(
      r'^(part|chapter|section|module|unit|lesson|topic|page|table|figure|fig|appendix|exercise|step|no|item|volume|vol|slide|test|quiz|exam)\b[\s\d\.\-_ivxlcdm]*$',
      caseSensitive: false,
    );
    if (structuralPattern.hasMatch(clean)) {
      return true;
    }

    // Single words that are generic document sections or instructions
    const administrativeWords = {
      'table of contents',
      'contents',
      'index',
      'syllabus',
      'course outline',
      'overview',
      'summary',
      'introduction',
      'conclusion',
      'reference',
      'references',
      'bibliography',
      'works cited',
      'glossary',
      'notes',
      'study guide',
      'objective',
      'objectives',
      'learning objectives',
      'instruction',
      'instructions',
      'directions',
      'true or false',
      'multiple choice',
      'matching type',
      'identification',
      'fill in the blanks',
      'answer key',
      'answers',
      'all rights reserved',
      'copyright',
      'author',
      'published',
      'edition',
      'preview',
      'review',
      'discussion',
      'background',
    };
    if (administrativeWords.contains(clean)) {
      return true;
    }

    // Exclude terms that start with structural indicators: e.g. "Part 1 -", "Chapter 2:"
    if (RegExp(r'^(part|chapter|module|section|unit|lesson)\s*[\d\.\-_ivxlcdm]+\b', caseSensitive: false).hasMatch(clean)) {
      return true;
    }

    return false;
  }

  /// Strips leading structural prefixes like "Part 1:", "Chapter 2 -", "1. ", "• "
  String stripStructuralPrefix(String line) {
    var s = line.trim();
    // Remove list bullets / numbering: "1. ", "a) ", "• ", "- "
    s = s.replaceAll(RegExp(r'^[\s•\-\*#\d\.\)]+\s*'), '');
    // Remove "Part 1:", "Chapter 2 -", "Section A.", "Module 3:"
    s = s.replaceAll(
      RegExp(
        r'^(part|chapter|section|module|unit|lesson|topic|page|figure|table)\s*[\d\.\-_ivxlcdm]*\s*[:\-–—\.]\s*',
        caseSensitive: false,
      ),
      '',
    ).trim();
    return s;
  }

  /// Determines if a question prompt is asking about document layout rather than educational subject matter.
  bool isStructuralNoiseQuestion(String qText) {
    final lower = qText.toLowerCase();
    if (lower.contains(RegExp(r'\b(what is|which topic|what topic|what subject|what does)\s+(covered in|discussed in|in|is)\s+(part|chapter|module|section|unit)\s*\d+\b', caseSensitive: false))) {
      return true;
    }
    if (lower.contains(RegExp(r'\b(part|chapter|section|module|unit)\s*\d+\b.*\b(covers|discusses|describes|contains)\b', caseSensitive: false))) {
      return true;
    }
    return false;
  }

  /// Extracts standalone, substantive factual statements from text, filtering out headers and noise.
  List<String> extractFactsFromText(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return [];

    final rawSentences = clean.split(RegExp(r'(?<=[.!?])\s+'));
    final facts = <String>[];
    final seen = <String>{};

    for (final raw in rawSentences) {
      final s = stripStructuralPrefix(raw).replaceAll(RegExp(r'\s+'), ' ').trim();
      // Must be a proper sentence of reasonable length
      if (s.length < 35 || s.length > 280) continue;
      // Must not be a question or exclamation
      if (s.endsWith('?') || s.endsWith('!')) continue;
      // Must have at least 5 words
      final words = s.split(' ');
      if (words.length < 5) continue;

      // Check structural noise
      final firstThree = words.take(3).join(' ').toLowerCase();
      if (isStructuralNoise(firstThree) || isStructuralNoise(words.first)) continue;

      // Filter out boilerplate instructions
      final lower = s.toLowerCase();
      if (lower.startsWith('select the') ||
          lower.startsWith('choose the') ||
          lower.startsWith('read the') ||
          lower.startsWith('answer the') ||
          lower.startsWith('please refer') ||
          lower.startsWith('for more information') ||
          lower.startsWith('all rights reserved') ||
          lower.startsWith('click here') ||
          lower.contains('table of contents') ||
          lower.contains('copyright ©')) {
        continue;
      }

      final key = lower.replaceAll(RegExp(r'[^\w\s]'), '');
      if (!seen.contains(key)) {
        seen.add(key);
        final normalized = s.endsWith('.') ? s : '$s.';
        facts.add(normalized);
      }
    }

    return facts;
  }

  /// Extracts key concepts (term -> definition/context) directly from text without requiring external AI APIs.
  List<MapEntry<String, String>> extractConceptsFromText(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return [];

    final results = <MapEntry<String, String>>[];
    final seenTerms = <String>{};

    void addConcept(String rawTerm, String rawDef) {
      final t = rawTerm.trim().replaceAll(RegExp(r'^[\W_]+|[\W_]+$'), '');
      final d = rawDef.trim().replaceAll(RegExp(r'\s+'), ' ');

      if (isStructuralNoise(t)) return;
      if (isStructuralNoise(d)) return;

      // Term must be concise (1 to 6 words, 2 to 50 chars)
      final termWords = t.split(RegExp(r'\s+'));
      if (t.length < 2 || t.length > 50 || termWords.length > 6) return;

      // Definition must be substantive (at least 12 chars, 3 words, max 350 chars)
      final defWords = d.split(RegExp(r'\s+'));
      if (d.length < 12 || d.length > 350 || defWords.length < 3) return;

      final lower = t.toLowerCase();
      if (!seenTerms.contains(lower)) {
        seenTerms.add(lower);
        results.add(MapEntry(t, d));
      }
    }

    final lines = clean.split('\n');
    for (final line in lines) {
      final stripped = stripStructuralPrefix(line);
      if (stripped.isEmpty) continue;

      // Pattern 1: Bolded markdown term: "**Term**: Definition" or "**Term** - Definition"
      final boldMatch = RegExp(r'^\*{2}([^*]+)\*{2}\s*[:\-–—]?\s*(.+)$').firstMatch(stripped);
      if (boldMatch != null) {
        addConcept(boldMatch.group(1)!, boldMatch.group(2)!);
        continue;
      }

      // Pattern 2: Term with delimiter: "Term: Definition" or "Term - Definition"
      final delimiterMatch = RegExp(r'^([A-Z][A-Za-z0-9\s\-_/()]{1,45})\s*[:\-–—]\s*(.+)$').firstMatch(stripped);
      if (delimiterMatch != null) {
        addConcept(delimiterMatch.group(1)!, delimiterMatch.group(2)!);
        continue;
      }
    }

    // Pattern 3: Prose definition phrases: "X is defined as Y", "X refers to Y", "X means Y"
    final definitionRegex = RegExp(
      r'([A-Z][A-Za-z0-9\s\-_]{2,40})\s+(?:is defined as|refers to|means|is described as|represents|is characterized by|can be defined as)\s+([^.!?\n]{15,300})[.!?\n]',
      caseSensitive: false,
    );
    for (final m in definitionRegex.allMatches(clean)) {
      addConcept(m.group(1)!, m.group(2)!);
    }

    // Pattern 4: Copula statements: "X is/are Y"
    final copulaRegex = RegExp(
      r'([A-Z][A-Za-z0-9\s\-_]{2,35})\s+(?:is an?|are|consists of|includes|acts as|serves as)\s+([^.!?\n]{20,300})[.!?\n]',
    );
    for (final m in copulaRegex.allMatches(clean)) {
      addConcept(m.group(1)!, m.group(2)!);
    }

    return results;
  }

  /// Creates a plausible False statement from an authentic fact or concept assertion.
  String _createContrastingStatement(
    String statement,
    List<MapEntry<String, String>> concepts,
  ) {
    const contrastPairs = [
      [' increases ', ' decreases '],
      [' increase ', ' decrease '],
      [' higher ', ' lower '],
      [' always ', ' never '],
      [' primary ', ' secondary '],
      [' requires ', ' does not require '],
      [' directly ', ' indirectly '],
      [' internal ', ' external '],
      [' positive ', ' negative '],
      [' aerobic ', ' anaerobic '],
      [' presence ', ' absence '],
      [' dominant ', ' recessive '],
      [' can be ', ' cannot be '],
      [' accelerates ', ' inhibits '],
      [' promotes ', ' prevents '],
      [' before ', ' after '],
      [' greater than ', ' less than '],
      [' maximizes ', ' minimizes '],
      [' essential ', ' non-essential '],
    ];

    for (final pair in contrastPairs) {
      if (statement.toLowerCase().contains(pair[0])) {
        final regex = RegExp(pair[0], caseSensitive: false);
        return statement.replaceFirst(regex, pair[1]);
      } else if (statement.toLowerCase().contains(pair[1])) {
        final regex = RegExp(pair[1], caseSensitive: false);
        return statement.replaceFirst(regex, pair[0]);
      }
    }

    // Concept subject swapping if multiple concepts exist
    if (concepts.length >= 2) {
      for (int i = 0; i < concepts.length; i++) {
        final term = concepts[i].key;
        if (statement.toLowerCase().contains(term.toLowerCase())) {
          final replacement = concepts[(i + 1) % concepts.length].key;
          final regex = RegExp(RegExp.escape(term), caseSensitive: false);
          return statement.replaceFirst(regex, replacement);
        }
      }
    }

    // Negate auxiliary verbs
    if (statement.contains(' is ')) {
      return statement.replaceFirst(' is ', ' is not ');
    } else if (statement.contains(' are ')) {
      return statement.replaceFirst(' are ', ' are not ');
    } else if (statement.contains(' can ')) {
      return statement.replaceFirst(' can ', ' cannot ');
    }

    return 'It is incorrect that $statement';
  }

  /// Generates structured exam questions locally on-device without any API call or tokens.
  /// Produces [count] questions for each question type specified in [types].
  List<Question> generateQuestionsLocally(
    String text, {
    int count = 10,
    String? subject,
    List<QuestionType> types = const [
      QuestionType.multipleChoice,
      QuestionType.trueFalse,
      QuestionType.matching,
    ],
  }) {
    final concepts = extractConceptsFromText(text);
    final facts = extractFactsFromText(text);
    final questions = <Question>[];
    final now = DateTime.now().millisecondsSinceEpoch;
    int idCounter = 0;

    // Fallback if neither concepts nor facts could be cleanly extracted
    if (concepts.isEmpty && facts.isEmpty) {
      final sentences = text
          .split(RegExp(r'(?<=[.!?])\s+'))
          .where((s) => s.trim().length > 25 && !isStructuralNoise(s))
          .toList();

      for (final type in types) {
        for (int i = 0; i < count; i++) {
          final s = sentences.isNotEmpty
              ? sentences[i % sentences.length].trim()
              : 'Core concept #${i + 1} from ${subject ?? 'study notes'}';
          final qId = 'local_q_${now}_${idCounter++}';

          if (type == QuestionType.multipleChoice) {
            questions.add(
              Question(
                id: qId,
                topicId: 'custom',
                subjectId: 'custom',
                category: subject ?? 'General Knowledge',
                questionText: 'According to the study material: "$s". Which statement is accurate?',
                questionType: QuestionType.multipleChoice,
                explanation: 'Directly supported by the study text.',
                choices: [
                  QuestionChoice(id: 'ch_${qId}_0', questionId: qId, choiceText: 'This statement is accurate and directly supported by text', isCorrect: true, sortOrder: 0),
                  QuestionChoice(id: 'ch_${qId}_1', questionId: qId, choiceText: 'This statement is contradicted by the document', isCorrect: false, sortOrder: 1),
                  QuestionChoice(id: 'ch_${qId}_2', questionId: qId, choiceText: 'The document does not address this topic', isCorrect: false, sortOrder: 2),
                  QuestionChoice(id: 'ch_${qId}_3', questionId: qId, choiceText: 'None of the above', isCorrect: false, sortOrder: 3),
                ],
              ),
            );
          } else if (type == QuestionType.trueFalse) {
            final isTrue = i % 2 == 0;
            questions.add(
              Question(
                id: qId,
                topicId: 'custom',
                subjectId: 'custom',
                category: subject ?? 'General Knowledge',
                questionText: isTrue ? 'True or False: $s' : 'True or False: It is not the case that $s',
                questionType: QuestionType.trueFalse,
                explanation: isTrue
                    ? 'True. As stated in the study material: "$s"'
                    : 'False. The text confirms: "$s"',
                choices: [
                  QuestionChoice(id: 'ch_${qId}_0', questionId: qId, choiceText: 'True', isCorrect: isTrue, sortOrder: 0),
                  QuestionChoice(id: 'ch_${qId}_1', questionId: qId, choiceText: 'False', isCorrect: !isTrue, sortOrder: 1),
                ],
              ),
            );
          } else if (type == QuestionType.matching) {
            final matchPairs = <MatchingPair>[];
            for (int p = 0; p < 3; p++) {
              final pairIdx = (i * 3 + p) % (sentences.isNotEmpty ? sentences.length : 3);
              final sText = sentences.isNotEmpty ? sentences[pairIdx] : 'Topic ${p + 1}';
              final words = sText.split(' ');
              final left = words.take(3).join(' ');
              final right = words.skip(3).take(8).join(' ');
              matchPairs.add(
                MatchingPair(
                  id: 'mp_${qId}_$p',
                  questionId: qId,
                  leftText: left.isNotEmpty ? left : 'Concept ${p + 1}',
                  rightText: right.isNotEmpty ? right : 'Detail ${p + 1}',
                ),
              );
            }
            questions.add(
              Question(
                id: qId,
                topicId: 'custom',
                subjectId: 'custom',
                category: subject ?? 'General Knowledge',
                questionText: 'Match each concept or premise with its continuation (Set ${i + 1}):',
                questionType: QuestionType.matching,
                explanation: '',
                matchingPairs: matchPairs,
              ),
            );
          }
        }
      }
      return questions;
    }

    final allTerms = concepts.map((c) => c.key).toList();

    for (final type in types) {
      if (type == QuestionType.multipleChoice) {
        for (int i = 0; i < count; i++) {
          final qId = 'local_q_${now}_${idCounter++}';
          final style = i % 3;

          if (style == 0 && concepts.isNotEmpty) {
            // Style 0: Reverse Identification ("Which term matches: '...'?")
            final concept = concepts[i % concepts.length];
            final otherTerms = allTerms.where((t) => t != concept.key).toList()..shuffle();
            final distractors = otherTerms.take(3).toList();
            while (distractors.length < 3) {
              distractors.add('Concept ${distractors.length + 1}');
            }
            final choiceTexts = [concept.key, ...distractors]..shuffle();
            final choices = <QuestionChoice>[];
            for (int c = 0; c < choiceTexts.length; c++) {
              choices.add(
                QuestionChoice(
                  id: 'ch_${qId}_$c',
                  questionId: qId,
                  choiceText: choiceTexts[c],
                  isCorrect: choiceTexts[c] == concept.key,
                  sortOrder: c,
                ),
              );
            }
            questions.add(
              Question(
                id: qId,
                topicId: 'custom',
                subjectId: 'custom',
                category: subject ?? 'General Knowledge',
                questionText: 'Which term corresponds to the following description: "${concept.value}"?',
                questionType: QuestionType.multipleChoice,
                explanation: '${concept.key} is the correct term for this definition.',
                choices: choices,
              ),
            );
          } else if (style == 1 && concepts.isNotEmpty) {
            // Style 1: Concept Definition ("Which of the following best defines '...'?")
            final concept = concepts[(i + 1) % concepts.length];
            final otherDefs = concepts.where((c) => c.key != concept.key).map((c) => c.value).toList()..shuffle();
            final defDistractors = otherDefs.take(3).toList();
            while (defDistractors.length < 3) {
              defDistractors.add('Alternative description ${defDistractors.length + 1}');
            }
            final choiceDefs = [concept.value, ...defDistractors]..shuffle();
            final choices = <QuestionChoice>[];
            for (int c = 0; c < choiceDefs.length; c++) {
              choices.add(
                QuestionChoice(
                  id: 'ch_${qId}_$c',
                  questionId: qId,
                  choiceText: choiceDefs[c],
                  isCorrect: choiceDefs[c] == concept.value,
                  sortOrder: c,
                ),
              );
            }
            questions.add(
              Question(
                id: qId,
                topicId: 'custom',
                subjectId: 'custom',
                category: subject ?? 'General Knowledge',
                questionText: 'Which of the following best defines "${concept.key}"?',
                questionType: QuestionType.multipleChoice,
                explanation: '${concept.key} is defined as: ${concept.value}',
                choices: choices,
              ),
            );
          } else {
            // Style 2: Factual Principle / Comprehension (using facts if available, otherwise concepts)
            if (facts.isNotEmpty) {
              final fact = facts[i % facts.length];
              final otherFacts = facts.where((f) => f != fact).toList()..shuffle();
              final factDistractors = <String>[];
              for (final f in otherFacts.take(2)) {
                factDistractors.add(_createContrastingStatement(f, concepts));
              }
              while (factDistractors.length < 3) {
                factDistractors.add('Statement not supported by document context (${factDistractors.length + 1})');
              }
              final choiceList = [fact, ...factDistractors]..shuffle();
              final choices = <QuestionChoice>[];
              for (int c = 0; c < choiceList.length; c++) {
                choices.add(
                  QuestionChoice(
                    id: 'ch_${qId}_$c',
                    questionId: qId,
                    choiceText: choiceList[c],
                    isCorrect: choiceList[c] == fact,
                    sortOrder: c,
                  ),
                );
              }
              questions.add(
                Question(
                  id: qId,
                  topicId: 'custom',
                  subjectId: 'custom',
                  category: subject ?? 'General Knowledge',
                  questionText: 'According to the study material, which of the following statements regarding ${subject ?? 'the subject'} is correct?',
                  questionType: QuestionType.multipleChoice,
                  explanation: 'Directly supported by the document: "$fact"',
                  choices: choices,
                ),
              );
            } else {
              // Fallback to concept term identification with different phrasing
              final concept = concepts[i % concepts.length];
              final otherTerms = allTerms.where((t) => t != concept.key).toList()..shuffle();
              final distractors = otherTerms.take(3).toList();
              while (distractors.length < 3) {
                distractors.add('Concept ${distractors.length + 1}');
              }
              final choiceTexts = [concept.key, ...distractors]..shuffle();
              final choices = <QuestionChoice>[];
              for (int c = 0; c < choiceTexts.length; c++) {
                choices.add(
                  QuestionChoice(
                    id: 'ch_${qId}_$c',
                    questionId: qId,
                    choiceText: choiceTexts[c],
                    isCorrect: choiceTexts[c] == concept.key,
                    sortOrder: c,
                  ),
                );
              }
              questions.add(
                Question(
                  id: qId,
                  topicId: 'custom',
                  subjectId: 'custom',
                  category: subject ?? 'General Knowledge',
                  questionText: 'Which key concept is described as: "${concept.value}"?',
                  questionType: QuestionType.multipleChoice,
                  explanation: '${concept.key} is the correct concept.',
                  choices: choices,
                ),
              );
            }
          }
        }
      } else if (type == QuestionType.trueFalse) {
        for (int i = 0; i < count; i++) {
          final qId = 'local_q_${now}_${idCounter++}';
          final isTrue = i % 2 == 0;

          if (facts.isNotEmpty) {
            final fact = facts[i % facts.length];
            final statement = isTrue ? fact : _createContrastingStatement(fact, concepts);

            questions.add(
              Question(
                id: qId,
                topicId: 'custom',
                subjectId: 'custom',
                category: subject ?? 'General Knowledge',
                questionText: 'True or False: $statement',
                questionType: QuestionType.trueFalse,
                explanation: isTrue
                    ? 'True. The study material confirms that: "$fact"'
                    : 'False. The correct document fact is: "$fact"',
                choices: [
                  QuestionChoice(id: 'ch_${qId}_0', questionId: qId, choiceText: 'True', isCorrect: isTrue, sortOrder: 0),
                  QuestionChoice(id: 'ch_${qId}_1', questionId: qId, choiceText: 'False', isCorrect: !isTrue, sortOrder: 1),
                ],
              ),
            );
          } else {
            // Use concepts with clear pedagogical statements
            final concept = concepts[i % concepts.length];
            final statement = isTrue
                ? '${concept.key} is characterized by: ${concept.value}.'
                : '${concept.key} is characterized by: ${concepts[(i + 1) % concepts.length].value}.';

            questions.add(
              Question(
                id: qId,
                topicId: 'custom',
                subjectId: 'custom',
                category: subject ?? 'General Knowledge',
                questionText: 'True or False: $statement',
                questionType: QuestionType.trueFalse,
                explanation: isTrue
                    ? 'True. In the study material, ${concept.key} is defined as: ${concept.value}'
                    : 'False. ${concept.key} actually refers to: ${concept.value}',
                choices: [
                  QuestionChoice(id: 'ch_${qId}_0', questionId: qId, choiceText: 'True', isCorrect: isTrue, sortOrder: 0),
                  QuestionChoice(id: 'ch_${qId}_1', questionId: qId, choiceText: 'False', isCorrect: !isTrue, sortOrder: 1),
                ],
              ),
            );
          }
        }
      } else if (type == QuestionType.matching) {
        for (int i = 0; i < count; i++) {
          final qId = 'local_q_${now}_${idCounter++}';
          final matchPairs = <MatchingPair>[];

          if (concepts.length >= 2) {
            final startIdx = (i * 3) % concepts.length;
            final pairCount = (concepts.length < 3) ? concepts.length : 3;

            for (int p = 0; p < pairCount; p++) {
              final c = concepts[(startIdx + p) % concepts.length];
              matchPairs.add(
                MatchingPair(
                  id: 'mp_${qId}_$p',
                  questionId: qId,
                  leftText: c.key,
                  rightText: c.value.length > 80 ? '${c.value.substring(0, 80)}...' : c.value,
                ),
              );
            }
          } else {
            // If few concepts, pair fact premise and conclusion
            final pool = facts.isNotEmpty ? facts : [text];
            for (int p = 0; p < 3; p++) {
              final sText = pool[(i * 3 + p) % pool.length];
              final words = sText.split(' ');
              final left = words.take(3).join(' ');
              final right = words.skip(3).take(8).join(' ');
              matchPairs.add(
                MatchingPair(
                  id: 'mp_${qId}_$p',
                  questionId: qId,
                  leftText: left.isNotEmpty ? left : 'Concept ${p + 1}',
                  rightText: right.isNotEmpty ? right : 'Detail ${p + 1}',
                ),
              );
            }
          }

          questions.add(
            Question(
              id: qId,
              topicId: 'custom',
              subjectId: 'custom',
              category: subject ?? 'General Knowledge',
              questionText: 'Match each concept or term with its corresponding description (Set ${i + 1}):',
              questionType: QuestionType.matching,
              explanation: '',
              matchingPairs: matchPairs,
            ),
          );
        }
      }
    }

    return questions;
  }

  /// Generates flashcards locally on-device without any API call or tokens.
  List<Map<String, String>> generateFlashcardsLocally(
    String text, {
    int count = 15,
    String? subject,
  }) {
    final concepts = extractConceptsFromText(text);
    if (concepts.isEmpty) {
      final facts = extractFactsFromText(text);
      final cards = <Map<String, String>>[];
      for (int i = 0; i < facts.length && cards.length < count; i++) {
        final f = facts[i];
        cards.add({
          'front': 'Key Concept ${i + 1}',
          'back': f,
          'hint': subject ?? 'Study Document',
        });
      }
      return cards;
    }

    final effective = concepts.take(count).toList();
    return effective.map((c) {
      return {
        'front': c.key,
        'back': c.value,
        'hint': subject ?? 'Study Document',
      };
    }).toList();
  }

  /// Removes Markdown code fencing like ```json ... ``` if returned by the LLM.
  String _cleanJsonString(String raw) {
    var cleaned = raw.trim();
    if (cleaned.startsWith('```json')) {
      cleaned = cleaned.substring(7);
    } else if (cleaned.startsWith('```')) {
      cleaned = cleaned.substring(3);
    }
    if (cleaned.endsWith('```')) {
      cleaned = cleaned.substring(0, cleaned.length - 3);
    }
    return cleaned.trim();
  }
}
