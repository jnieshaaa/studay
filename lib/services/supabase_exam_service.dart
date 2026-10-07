import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/exam_model.dart';
import '../models/question_model.dart';
import '../models/exam_participant_model.dart';
import '../core/config/supabase_config.dart';

/// Supabase service handling remote exam publishing, code-based joining,
/// response submissions, and live dashboard results feeds.
class SupabaseExamService {
  SupabaseClient? get _client => SupabaseConfig.client;

  bool get isAvailable => SupabaseConfig.isInitialized && _client != null;

  /// Publishes or updates an exam and all its nested questions in Supabase.
  Future<bool> publishExam(Exam exam) async {
    final client = _client;
    if (client == null) return false;

    try {
      // 1. Upsert exam header
      final examMap = {
        'id': exam.id,
        'creator_id': exam.creatorId,
        'title': exam.title,
        'subject': exam.effectiveSubject,
        'description': exam.description,
        'code': exam.code.trim().toUpperCase(),
        'status': exam.status.name,
        'question_order': exam.questionOrder.name,
        'choice_order': exam.choiceOrder.name,
        'show_answers': exam.showAnswers.name,
        'opens_at': exam.opensAt?.toIso8601String(),
        'closes_at': exam.closesAt?.toIso8601String(),
        'max_attempts_per_participant': exam.maxAttemptsPerParticipant,
        'duration_minutes': exam.durationMinutes,
        'section_order': exam.sectionOrder.map((t) => t.name).toList(),
        'created_at': exam.createdAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      await client.from('exams').upsert(examMap);

      // 2. Clear old questions to avoid duplicates on edit
      await client.from('exam_questions').delete().eq('exam_id', exam.id);

      // 3. Insert questions and child choices / pairs
      for (int i = 0; i < exam.questions.length; i++) {
        final q = exam.questions[i];
        final qMap = {
          'id': q.id,
          'exam_id': exam.id,
          'topic_id': q.topicId,
          'subject_id': q.subjectId,
          'category': q.effectiveCategory,
          'question_text': q.questionText,
          'question_type': q.questionType.name,
          'difficulty': q.difficulty.name,
          'explanation': q.explanation,
          'reference': q.reference,
          'sort_order': i,
          'points': q.points,
        };
        await client.from('exam_questions').insert(qMap);

        if (q.questionType == QuestionType.multipleChoice ||
            q.questionType == QuestionType.trueFalse) {
          if (q.choices.isNotEmpty) {
            final choicesData = q.choices
                .map(
                  (c) => {
                    'id': c.id,
                    'question_id': q.id,
                    'choice_text': c.choiceText,
                    'is_correct': c.isCorrect,
                    'sort_order': c.sortOrder,
                  },
                )
                .toList();
            await client.from('exam_choices').insert(choicesData);
          }
        } else if (q.questionType == QuestionType.matching) {
          if (q.matchingPairs.isNotEmpty) {
            final pairsData = q.matchingPairs
                .map(
                  (p) => {
                    'id': p.id,
                    'question_id': q.id,
                    'left_text': p.leftText,
                    'right_text': p.rightText,
                  },
                )
                .toList();
            await client.from('exam_matching_pairs').insert(pairsData);
          }
        }
      }

      debugPrint(
        '[SupabaseExamService] Successfully published exam ${exam.code} to Supabase',
      );
      return true;
    } catch (e) {
      debugPrint('[SupabaseExamService] Error publishing exam: $e');
      return false;
    }
  }

  /// Fetches an exam by its 6-character join code.
  Future<Exam?> fetchExamByCode(String code) async {
    final client = _client;
    if (client == null) return null;

    try {
      final normalizedCode = code.trim().toUpperCase();
      final examRows = await client
          .from('exams')
          .select()
          .eq('code', normalizedCode)
          .limit(1);

      if (examRows.isEmpty) return null;
      final examRow = Map<String, dynamic>.from(examRows.first);
      final examId = examRow['id'] as String;

      // Fetch questions with nested choices and matching pairs
      final questionRows = await client
          .from('exam_questions')
          .select('*, exam_choices(*), exam_matching_pairs(*)')
          .eq('exam_id', examId)
          .order('sort_order', ascending: true);

      final questions = <Question>[];
      for (final qMap in questionRows) {
        final rawChoices = (qMap['exam_choices'] as List<dynamic>?) ?? [];
        final choices =
            rawChoices
                .map(
                  (c) => QuestionChoice.fromJson(Map<String, dynamic>.from(c)),
                )
                .toList()
              ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

        final rawPairs = (qMap['exam_matching_pairs'] as List<dynamic>?) ?? [];
        final pairs = rawPairs
            .map((p) => MatchingPair.fromJson(Map<String, dynamic>.from(p)))
            .toList();

        questions.add(
          Question(
            id: qMap['id'] as String,
            topicId: qMap['topic_id'] as String? ?? 'custom',
            subjectId: qMap['subject_id'] as String? ?? 'custom',
            category: qMap['category'] as String? ?? '',
            questionText: qMap['question_text'] as String,
            questionType: QuestionType.values.firstWhere(
              (t) => t.name == qMap['question_type'],
              orElse: () => QuestionType.multipleChoice,
            ),
            difficulty: Difficulty.values.firstWhere(
              (d) => d.name == qMap['difficulty'],
              orElse: () => Difficulty.medium,
            ),
            explanation: qMap['explanation'] as String? ?? '',
            reference: qMap['reference'] as String? ?? '',
            choices: choices,
            matchingPairs: pairs,
            points: qMap['points'] as int? ?? 1,
          ),
        );
      }

      examRow['questions'] = questions.map((q) => q.toJson()).toList();
      return Exam.fromJson(examRow);
    } catch (e) {
      debugPrint('[SupabaseExamService] Error fetching exam by code: $e');
      return null;
    }
  }

  /// Publishes a subject bundle to Supabase
  Future<bool> publishSubjectBundle(String code, String subject, Map<String, dynamic> bundleData) async {
    final client = _client;
    if (client == null) return false;
    try {
      await client.from('subject_bundles').upsert({
        'code': code.trim().toUpperCase(),
        'subject': subject,
        'bundle_data': bundleData,
        'updated_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('[SupabaseExamService] Bundle upload info: $e');
      return false;
    }
  }

  /// Fetches a subject bundle by unique code from Supabase
  Future<Map<String, dynamic>?> fetchSubjectBundle(String code) async {
    final client = _client;
    if (client == null) return null;
    try {
      final rows = await client
          .from('subject_bundles')
          .select('bundle_data')
          .eq('code', code.trim().toUpperCase())
          .limit(1);
      if (rows.isNotEmpty) {
        final data = rows.first['bundle_data'];
        if (data is Map) return Map<String, dynamic>.from(data);
      }
    } catch (e) {
      debugPrint('[SupabaseExamService] Fetch bundle info: $e');
    }
    return null;
  }

  /// Records a guest participant entering an exam.
  Future<bool> recordParticipant(ExamParticipant participant) async {
    final client = _client;
    if (client == null) return false;

    try {
      await client.from('exam_participants').upsert(participant.toJson());
      return true;
    } catch (e) {
      debugPrint('[SupabaseExamService] Error recording participant: $e');
      return false;
    }
  }

  /// Submits an exam's participant score and all individual responses.
  Future<bool> submitExamResponses({
    required ExamParticipant participant,
    required List<ExamResponse> responses,
  }) async {
    final client = _client;
    if (client == null) return false;

    try {
      // 1. Update participant status and score
      await client.from('exam_participants').upsert(participant.toJson());

      // 2. Insert individual responses
      if (responses.isNotEmpty) {
        final responsesData = responses.map((r) => r.toJson()).toList();
        await client.from('exam_responses').upsert(responsesData);
      }

      debugPrint(
        '[SupabaseExamService] Successfully submitted responses for participant ${participant.id}',
      );
      return true;
    } catch (e) {
      debugPrint('[SupabaseExamService] Error submitting exam responses: $e');
      return false;
    }
  }

  /// Fetches all participants who joined and submitted an exam.
  Future<List<ExamParticipant>> fetchParticipants(String examId) async {
    final client = _client;
    if (client == null) return [];

    try {
      final rows = await client
          .from('exam_participants')
          .select()
          .eq('exam_id', examId)
          .order('joined_at', ascending: false);

      return rows
          .map((r) => ExamParticipant.fromJson(Map<String, dynamic>.from(r)))
          .toList();
    } catch (e) {
      debugPrint('[SupabaseExamService] Error fetching participants: $e');
      return [];
    }
  }

  /// Fetches all responses submitted for an exam.
  Future<List<ExamResponse>> fetchResponsesForExam(String examId) async {
    final client = _client;
    if (client == null) return [];

    try {
      final rows = await client
          .from('exam_responses')
          .select('*, exam_participants!inner(exam_id)')
          .eq('exam_participants.exam_id', examId);

      return rows
          .map((r) => ExamResponse.fromJson(Map<String, dynamic>.from(r)))
          .toList();
    } catch (e) {
      debugPrint('[SupabaseExamService] Error fetching exam responses: $e');
      return [];
    }
  }

  /// Sets up a Realtime subscription for live participant updates on the maker dashboard.
  RealtimeChannel? subscribeToParticipants({
    required String examId,
    required void Function(ExamParticipant participant) onUpdate,
  }) {
    final client = _client;
    if (client == null) return null;

    try {
      final channel = client.channel('public:exam_participants:$examId');
      channel
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'exam_participants',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'exam_id',
              value: examId,
            ),
            callback: (payload) {
              final record = payload.newRecord;
              if (record.isNotEmpty) {
                onUpdate(
                  ExamParticipant.fromJson(Map<String, dynamic>.from(record)),
                );
              }
            },
          )
          .subscribe();

      return channel;
    } catch (e) {
      debugPrint('[SupabaseExamService] Error subscribing to participants: $e');
      return null;
    }
  }
}
