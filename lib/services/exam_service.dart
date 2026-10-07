import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/exam_model.dart';
import '../models/subject_model.dart';
import '../models/question_model.dart';
import '../models/exam_participant_model.dart';
import '../core/utils/code_generator.dart';
import 'seed_data_service.dart';
import 'local_storage_service.dart';
import 'supabase_exam_service.dart';

class ExamService extends ChangeNotifier {
  final LocalStorageService _storage;
  final SupabaseExamService? _supabase;

  // In-memory registry of active exams and participants
  final Map<String, Exam> _examsByCode = {};
  final Map<String, Exam> _examsById = {};
  final Map<String, List<ExamParticipant>> _participantsByExam = {};
  final Map<String, List<ExamResponse>> _responsesByExam = {};

  /// Returns all in-memory exams
  List<Exam> get allExams => _examsById.values.toList();

  ExamService(
    this._storage, {
    SupabaseExamService? supabase,
    bool seedDefaultExams = false,
  }) : _supabase = supabase {
    if (seedDefaultExams) {
      _initDefaultExams();
    }
    _initExamsFromStorage();
  }

  /// Manually seeds default demo exams (for testing harnesses)
  void seedDefaultExamsForTesting() {
    _initDefaultExams();
    notifyListeners();
  }

  Future<void> _initExamsFromStorage() async {
    final stored = await _storage.loadCreatedExams();
    for (final exam in stored) {
      _examsById[exam.id] = exam;
      _examsByCode[exam.code.toUpperCase()] = exam;
    }
    notifyListeners();
  }

  /// Seeds initial default exams
  void _initDefaultExams() {
    final questions = SeedDataService.getInitialQuestions();
    // Choose 5 diverse Science questions (MCQ, True/False, Matching)
    final sampleQuestions = [
      questions[6], // Photosynthesis MCQ
      questions[7], // Mitochondria T/F
      questions[8], // Biology Matching
      questions[9], // Chemistry pH MCQ
      questions[10], // Chemistry H2O T/F
    ];

    const sampleCode = '4F9K2Q';
    final sampleExam = Exam(
      id: 'exam_sample_bio',
      creatorId: 'maker_maria',
      title: 'Quiz 1: Cell Biology & Chemistry',
      subject: 'Science',
      description: 'Review quiz with multiple choice, true/false, and matching type.',
      code: sampleCode,
      status: ExamStatus.published,
      questionOrder: QuestionOrder.fixed,
      choiceOrder: ChoiceOrder.fixed,
      showAnswers: ShowAnswersMode.immediately,
      closesAt: DateTime.now().add(const Duration(days: 7)),
      questions: sampleQuestions,
      createdAt: DateTime.now().subtract(const Duration(hours: 12)),
    );

    _examsByCode[sampleCode] = sampleExam;
    _examsById[sampleExam.id] = sampleExam;

    // Filipino Subject - Quiz 1
    final filExam = Exam(
      id: 'exam_fil_1',
      creatorId: 'maker_maria',
      title: 'Quiz 1: Wika at Balarila',
      subject: 'Filipino',
      description: 'Pagsasanay sa wastong gamit ng mga salita, sawikain, at tayutay sa wikang Filipino.',
      code: 'FIL101',
      status: ExamStatus.published,
      questions: [
        const Question(
          id: 'q_fil_1',
          topicId: 'top_fil',
          subjectId: 'subj_fil',
          questionText: 'Piliin ang wastong salita: "Pumunta si Ana _____ palengke upang mamili ng gulay."',
          questionType: QuestionType.multipleChoice,
          choices: [
            QuestionChoice(id: 'f1_1', questionId: 'q_fil_1', choiceText: 'sa', isCorrect: true),
            QuestionChoice(id: 'f1_2', questionId: 'q_fil_1', choiceText: 'ng', isCorrect: false),
            QuestionChoice(id: 'f1_3', questionId: 'q_fil_1', choiceText: 'nang', isCorrect: false),
            QuestionChoice(id: 'f1_4', questionId: 'q_fil_1', choiceText: 'may', isCorrect: false),
          ],
          explanation: 'Ang katagang "sa" ay ginagamit bilang pang-ukol na nagtuturo ng direksyon o pook.',
        ),
        const Question(
          id: 'q_fil_2',
          topicId: 'top_fil',
          subjectId: 'subj_fil',
          questionText: 'Ang sawikaing "nagbibilang ng poste" ay nangangahulugang walang trabaho o hanapbuhay.',
          questionType: QuestionType.trueFalse,
          choices: [
            QuestionChoice(id: 'f2_1', questionId: 'q_fil_2', choiceText: 'True', isCorrect: true),
            QuestionChoice(id: 'f2_2', questionId: 'q_fil_2', choiceText: 'False', isCorrect: false),
          ],
          explanation: 'Tama. Ang "nagbibilang ng poste" ay tanyag na sawikaing Tagalog para sa taong walang hanapbuhay.',
        ),
      ],
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    );
    _examsByCode[filExam.code] = filExam;
    _examsById[filExam.id] = filExam;

    // English Subject - Quiz 1
    final engExam = Exam(
      id: 'exam_eng_1',
      creatorId: 'maker_maria',
      title: 'Quiz 1: Grammar & Vocabulary',
      subject: 'English',
      description: 'Core English grammar, correlative conjunctions, and sentence correction.',
      code: 'ENG101',
      status: ExamStatus.published,
      questions: [
        questions[2],
        const Question(
          id: 'q_eng_2',
          topicId: 'top_eng',
          subjectId: 'subj_eng',
          questionText: 'Choose the word that is most opposite in meaning to "CANDID":',
          questionType: QuestionType.multipleChoice,
          choices: [
            QuestionChoice(id: 'e2_1', questionId: 'q_eng_2', choiceText: 'Deceitful', isCorrect: true),
            QuestionChoice(id: 'e2_2', questionId: 'q_eng_2', choiceText: 'Honest', isCorrect: false),
            QuestionChoice(id: 'e2_3', questionId: 'q_eng_2', choiceText: 'Blunt', isCorrect: false),
            QuestionChoice(id: 'e2_4', questionId: 'q_eng_2', choiceText: 'Articulate', isCorrect: false),
          ],
          explanation: 'Candid means truthful and straightforward; its direct antonym is deceitful.',
        ),
      ],
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    );
    _examsByCode[engExam.code] = engExam;
    _examsById[engExam.id] = engExam;

    // Math Subject - Quiz 1
    final mathExam1 = Exam(
      id: 'exam_mth_1',
      creatorId: 'maker_maria',
      title: 'Quiz 1: Basic Algebra & Percentages',
      subject: 'Math',
      description: 'Review of algebraic simplification, ratios, and percentage word problems.',
      code: 'MTH101',
      status: ExamStatus.published,
      questions: [
        questions[4],
        const Question(
          id: 'q_mth_dyn_1',
          topicId: 'top_mth',
          subjectId: 'subj_mth',
          questionText: 'If 3x + 7 = 22, what is the value of 2x - 3?',
          questionType: QuestionType.multipleChoice,
          choices: [
            QuestionChoice(id: 'm1_1', questionId: 'q_mth_dyn_1', choiceText: '7', isCorrect: true),
            QuestionChoice(id: 'm1_2', questionId: 'q_mth_dyn_1', choiceText: '5', isCorrect: false),
            QuestionChoice(id: 'm1_3', questionId: 'q_mth_dyn_1', choiceText: '10', isCorrect: false),
            QuestionChoice(id: 'm1_4', questionId: 'q_mth_dyn_1', choiceText: '12', isCorrect: false),
          ],
          explanation: '3x = 15 => x = 5. Then 2(5) - 3 = 10 - 3 = 7.',
        ),
      ],
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    );
    _examsByCode[mathExam1.code] = mathExam1;
    _examsById[mathExam1.id] = mathExam1;

    // Math Subject - Quiz 2
    final mathExam2 = Exam(
      id: 'exam_mth_2',
      creatorId: 'maker_maria',
      title: 'Quiz 2: Geometry & Word Problems',
      subject: 'Math',
      description: 'Perimeter, area calculations, and speed-distance word problems.',
      code: 'MTH102',
      status: ExamStatus.published,
      questions: [
        const Question(
          id: 'q_mth_geo_1',
          topicId: 'top_mth',
          subjectId: 'subj_mth',
          questionText: 'A rectangle has a perimeter of 48 cm. If its length is twice its width, what is its width?',
          questionType: QuestionType.multipleChoice,
          choices: [
            QuestionChoice(id: 'mg1_1', questionId: 'q_mth_geo_1', choiceText: '8 cm', isCorrect: true),
            QuestionChoice(id: 'mg1_2', questionId: 'q_mth_geo_1', choiceText: '16 cm', isCorrect: false),
            QuestionChoice(id: 'mg1_3', questionId: 'q_mth_geo_1', choiceText: '12 cm', isCorrect: false),
            QuestionChoice(id: 'mg1_4', questionId: 'q_mth_geo_1', choiceText: '6 cm', isCorrect: false),
          ],
          explanation: '2(w + 2w) = 48 => 6w = 48 => w = 8 cm.',
        ),
      ],
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    );
    _examsByCode[mathExam2.code] = mathExam2;
    _examsById[mathExam2.id] = mathExam2;

    // Seed mock leaderboard participants: juanb (9/10), maria_c (9/10), kevin92 (8/10)
    final p1 = ExamParticipant(
      id: 'p_1',
      examId: sampleExam.id,
      nickname: 'juanb',
      deviceToken: 'dev_juanb',
      joinedAt: DateTime.now().subtract(const Duration(hours: 3)),
      submittedAt: DateTime.now().subtract(const Duration(hours: 2)),
      score: 5,
      totalQuestions: 5,
      status: ParticipantStatus.submitted,
    );
    final p2 = ExamParticipant(
      id: 'p_2',
      examId: sampleExam.id,
      nickname: 'maria_c',
      deviceToken: 'dev_mariac',
      joinedAt: DateTime.now().subtract(const Duration(hours: 4)),
      submittedAt: DateTime.now().subtract(const Duration(hours: 3)),
      score: 5,
      totalQuestions: 5,
      status: ParticipantStatus.submitted,
    );
    final p3 = ExamParticipant(
      id: 'p_3',
      examId: sampleExam.id,
      nickname: 'kevin92',
      deviceToken: 'dev_kevin92',
      joinedAt: DateTime.now().subtract(const Duration(hours: 5)),
      submittedAt: DateTime.now().subtract(const Duration(hours: 4)),
      score: 4,
      totalQuestions: 5,
      status: ParticipantStatus.submitted,
    );
    final p4 = ExamParticipant(
      id: 'p_4',
      examId: sampleExam.id,
      nickname: 'alyssa_r',
      deviceToken: 'dev_alyssa',
      joinedAt: DateTime.now().subtract(const Duration(hours: 1)),
      submittedAt: null,
      score: 0,
      totalQuestions: 5,
      status: ParticipantStatus.inProgress,
    );

    _participantsByExam[sampleExam.id] = [p1, p2, p3, p4];

    // Seed mock responses to generate realistic Hardest Question analytics
    _responsesByExam[sampleExam.id] = [
      ExamResponse(id: 'r1', participantId: 'p_1', questionId: sampleQuestions[0].id, isCorrect: true),
      ExamResponse(id: 'r2', participantId: 'p_1', questionId: sampleQuestions[1].id, isCorrect: true),
      ExamResponse(id: 'r3', participantId: 'p_1', questionId: sampleQuestions[2].id, isCorrect: true),
      ExamResponse(id: 'r4', participantId: 'p_1', questionId: sampleQuestions[3].id, isCorrect: true),
      ExamResponse(id: 'r5', participantId: 'p_1', questionId: sampleQuestions[4].id, isCorrect: true),

      ExamResponse(id: 'r6', participantId: 'p_2', questionId: sampleQuestions[0].id, isCorrect: true),
      ExamResponse(id: 'r7', participantId: 'p_2', questionId: sampleQuestions[1].id, isCorrect: true),
      ExamResponse(id: 'r8', participantId: 'p_2', questionId: sampleQuestions[2].id, isCorrect: true),
      ExamResponse(id: 'r9', participantId: 'p_2', questionId: sampleQuestions[3].id, isCorrect: false), // missed
      ExamResponse(id: 'r10', participantId: 'p_2', questionId: sampleQuestions[4].id, isCorrect: true),

      ExamResponse(id: 'r11', participantId: 'p_3', questionId: sampleQuestions[0].id, isCorrect: false), // missed
      ExamResponse(id: 'r12', participantId: 'p_3', questionId: sampleQuestions[1].id, isCorrect: true),
      ExamResponse(id: 'r13', participantId: 'p_3', questionId: sampleQuestions[2].id, isCorrect: false), // missed
      ExamResponse(id: 'r14', participantId: 'p_3', questionId: sampleQuestions[3].id, isCorrect: true),
      ExamResponse(id: 'r15', participantId: 'p_3', questionId: sampleQuestions[4].id, isCorrect: true),
    ];
  }

  /// Publishes a new exam, assigns a 6-character code, and persists it locally & remotely
  Future<Exam> publishExam(Exam exam) async {
    String code;
    do {
      code = CodeGenerator.generateExamCode();
    } while (_examsByCode.containsKey(code));

    final published = exam.copyWith(
      code: code,
      status: ExamStatus.published,
    );

    _examsByCode[code] = published;
    _examsById[published.id] = published;
    _participantsByExam[published.id] = [];
    _responsesByExam[published.id] = [];

    await _storage.saveCreatedExam(published);

    final supabase = _supabase;
    if (supabase != null && supabase.isAvailable) {
      try {
        await supabase.publishExam(published);
      } catch (e) {
        debugPrint('[ExamService] Remote publish failed (saved locally): $e');
      }
    }

    notifyListeners();
    return published;
  }

  /// Toggles exam status between published (active) and closed (stopped)
  Future<Exam> toggleExamStatus(String examId) async {
    final exam = _examsById[examId];
    if (exam == null) {
      throw Exception('Quiz not found.');
    }
    final newStatus = exam.status == ExamStatus.published
        ? ExamStatus.closed
        : ExamStatus.published;
    final updated = exam.copyWith(status: newStatus);

    _examsById[examId] = updated;
    _examsByCode[updated.code.toUpperCase()] = updated;

    await _storage.saveCreatedExam(updated);

    final supabase = _supabase;
    if (supabase != null && supabase.isAvailable) {
      try {
        await supabase.publishExam(updated);
      } catch (e) {
        debugPrint('[ExamService] Remote status toggle failed (saved locally): $e');
      }
    }

    notifyListeners();
    return updated;
  }

  /// Updates or clears countdown timer (in minutes) for an exam
  Future<Exam> updateExamTimer(String examId, int? durationMinutes) async {
    final exam = _examsById[examId];
    if (exam == null) {
      throw Exception('Quiz not found.');
    }
    final updated = exam.copyWith(
      durationMinutes: durationMinutes,
      clearDuration: durationMinutes == null || durationMinutes <= 0,
    );

    _examsById[examId] = updated;
    _examsByCode[updated.code.toUpperCase()] = updated;

    await _storage.saveCreatedExam(updated);

    final supabase = _supabase;
    if (supabase != null && supabase.isAvailable) {
      try {
        await supabase.publishExam(updated);
      } catch (e) {
        debugPrint('[ExamService] Remote timer update failed (saved locally): $e');
      }
    }

    notifyListeners();
    return updated;
  }

  /// Updates an existing exam (e.g. edited questions, title, settings) and persists it
  Future<Exam> updateExam(Exam updatedExam) async {
    _examsById[updatedExam.id] = updatedExam;
    _examsByCode[updatedExam.code.toUpperCase()] = updatedExam;

    await _storage.saveCreatedExam(updatedExam);

    final supabase = _supabase;
    if (supabase != null && supabase.isAvailable) {
      try {
        await supabase.publishExam(updatedExam);
      } catch (e) {
        debugPrint('[ExamService] Remote update failed (saved locally): $e');
      }
    }

    notifyListeners();
    return updatedExam;
  }

  /// Looks up an exam by its 6-character code from in-memory cache (case-insensitive)
  Exam? getExamByCode(String code) {
    final cleanCode = code.trim().toUpperCase();
    return _examsByCode[cleanCode];
  }

  /// Looks up an exam by its 6-character code, fetching from Supabase if not found locally
  Future<Exam?> getOrFetchExamByCode(String code) async {
    final cleanCode = code.trim().toUpperCase();
    final local = _examsByCode[cleanCode];
    if (local != null) return local;

    final supabase = _supabase;
    if (supabase != null && supabase.isAvailable) {
      try {
        final remote = await supabase.fetchExamByCode(cleanCode);
        if (remote != null) {
          _examsByCode[cleanCode] = remote;
          _examsById[remote.id] = remote;
          await _storage.saveCreatedExam(remote);
          notifyListeners();
          return remote;
        }
      } catch (e) {
        debugPrint('[ExamService] Remote fetch by code failed: $e');
      }
    }
    return null;
  }

  /// Exports all exams belonging to [subjectName] into a bundle with a unique Subject Code
  Future<SubjectBundleResult> exportSubjectBundle(String subjectName) async {
    final matchingExams = allExams
        .where((e) => e.effectiveSubject.toLowerCase() == subjectName.trim().toLowerCase())
        .toList();

    if (matchingExams.isEmpty) {
      throw Exception('No exams found under subject "$subjectName"');
    }

    // Generate a unique, conflict-free subject code (e.g. SUB-ENG-7K2M9P)
    String uniqueCode;
    do {
      uniqueCode = CodeGenerator.generateSubjectCode(subjectName, length: 6);
    } while (await _storage.loadSubjectBundle(uniqueCode) != null);
    final totalQuestions = matchingExams.fold(0, (sum, e) => sum + e.questions.length);

    final bundleMap = {
      'type': 'subject_bundle',
      'version': 1,
      'code': uniqueCode,
      'subject': subjectName,
      'exported_at': DateTime.now().toIso8601String(),
      'exams_count': matchingExams.length,
      'total_questions': totalQuestions,
      'exams': matchingExams.map((e) => e.toJson()).toList(),
    };

    final bundleJson = jsonEncode(bundleMap);

    // Save locally to storage
    await _storage.saveSubjectBundle(uniqueCode, bundleMap);

    // Sync to Supabase if connected
    final supabase = _supabase;
    if (supabase != null && supabase.isAvailable) {
      try {
        await supabase.publishSubjectBundle(uniqueCode, subjectName, bundleMap);
      } catch (e) {
        debugPrint('[ExamService] Remote publish subject bundle: $e');
      }
    }

    return SubjectBundleResult(
      code: uniqueCode,
      subject: subjectName,
      examsCount: matchingExams.length,
      totalQuestions: totalQuestions,
      bundleJson: bundleJson,
    );
  }

  /// Imports an entire Subject Bundle or Single Exam from a code or raw JSON string.
  /// Reassigns [newCreatorId] and regenerates IDs/codes where needed to guarantee zero conflicts.
  Future<List<Exam>> importSubjectBundle(
    String codeOrJson, {
    required String newCreatorId,
  }) async {
    final trimmed = codeOrJson.trim();
    Map<String, dynamic>? bundleData;

    // Check if raw JSON was pasted
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final parsed = jsonDecode(trimmed);
        if (parsed is Map<String, dynamic>) {
          if (parsed['type'] == 'subject_bundle' && parsed.containsKey('exams')) {
            bundleData = parsed;
          } else if (parsed.containsKey('title') && parsed.containsKey('questions')) {
            // It's a single exam JSON! Wrap it as a 1-exam bundle
            final exam = Exam.fromJson(parsed);
            bundleData = {
              'type': 'subject_bundle',
              'subject': exam.effectiveSubject,
              'code': exam.code,
              'exams': [parsed],
            };
          }
        }
      } catch (e) {
        debugPrint('[ExamService] JSON parse error: $e');
      }
    }

    // If not raw JSON, treat as a code (e.g. SUB-ENG-7K2M or 6-char exam code)
    if (bundleData == null) {
      final normalizedCode = trimmed.toUpperCase().replaceAll(' ', '');
      // 1. Try local storage bundle
      bundleData = await _storage.loadSubjectBundle(normalizedCode);

      // 2. Try Supabase bundle
      if (bundleData == null && _supabase != null && _supabase!.isAvailable) {
        bundleData = await _supabase!.fetchSubjectBundle(normalizedCode);
      }

      // 3. If still not found and code could be a single exam code, try fetching single exam
      if (bundleData == null) {
        final singleExam = await getOrFetchExamByCode(normalizedCode);
        if (singleExam != null) {
          bundleData = {
            'type': 'subject_bundle',
            'subject': singleExam.effectiveSubject,
            'code': singleExam.code,
            'exams': [singleExam.toJson()],
          };
        }
      }
    }

    if (bundleData == null || !bundleData.containsKey('exams')) {
      throw Exception('Subject code or bundle "$trimmed" not found. Please verify the code.');
    }

    final examsRaw = bundleData['exams'] as List<dynamic>? ?? [];
    if (examsRaw.isEmpty) {
      throw Exception('This subject bundle contains no quizzes.');
    }

    final subjectName = (bundleData['subject'] as String?)?.trim() ?? 'Imported Subject';
    final importedExams = <Exam>[];

    // Ensure subject exists in custom subjects
    final subjectId = 'subj_${subjectName.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';
    await _storage.saveCustomSubject(
      Subject(
        id: subjectId,
        name: subjectName,
        description: 'Imported subject containing ${examsRaw.length} quizzes',
        icon: 'school',
        sortOrder: 99,
      ),
    );

    for (final rawExam in examsRaw) {
      final examMap = Map<String, dynamic>.from(rawExam as Map);
      final originalExam = Exam.fromJson(examMap);

      // Generate a new unique exam ID to avoid conflicts
      final newExamId = CodeGenerator.generateId('exam');

      // ALWAYS generate a fresh, unique 6-character exam code for each exam in this subject!
      // This ensures Device B has its own independent quizzes and guarantees zero collision
      // with Device A's exam code or other existing quizzes.
      String examCode;
      do {
        examCode = CodeGenerator.generateExamCode();
      } while (_examsByCode.containsKey(examCode) || importedExams.any((e) => e.code == examCode));

      // Re-map questions with unique conflict-free IDs
      final newQuestions = <Question>[];
      for (final q in originalExam.questions) {
        final newQId = CodeGenerator.generateId('q');
        final newChoices = q.choices.map<QuestionChoice>((c) => c.copyWith(
          id: CodeGenerator.generateId('c'),
          questionId: newQId,
        )).toList();

        final newPairs = q.matchingPairs.map<MatchingPair>((p) => p.copyWith(
          id: CodeGenerator.generateId('m'),
          questionId: newQId,
          leftText: p.leftText,
          rightText: p.rightText,
        )).toList();

        newQuestions.add(q.copyWith(
          id: newQId,
          subjectId: subjectId,
          category: subjectName,
          choices: newChoices,
          matchingPairs: newPairs,
        ));
      }

      final importedExam = originalExam.copyWith(
        id: newExamId,
        creatorId: newCreatorId,
        subject: subjectName,
        code: examCode,
        status: ExamStatus.published,
        questions: newQuestions,
        createdAt: DateTime.now(),
      );

      _examsById[importedExam.id] = importedExam;
      _examsByCode[importedExam.code.toUpperCase()] = importedExam;
      _participantsByExam[importedExam.id] = [];
      _responsesByExam[importedExam.id] = [];

      await _storage.saveCreatedExam(importedExam);

      if (_supabase != null && _supabase!.isAvailable) {
        try {
          await _supabase!.publishExam(importedExam);
        } catch (_) {}
      }

      importedExams.add(importedExam);
    }

    notifyListeners();
    return importedExams;
  }

  /// Gets an exam by its ID
  Exam? getExamById(String id) {
    return _examsById[id];
  }

  /// Joins an exam by code and returns the registered participant
  ExamParticipant joinExam({
    required String code,
    required String nickname,
  }) {
    final exam = getExamByCode(code);
    if (exam == null) {
      throw Exception('Exam code "$code" not found. Please verify the 6-character code.');
    }
    if (exam.status == ExamStatus.closed) {
      throw Exception('This quiz has been stopped by the creator.');
    }
    if (exam.isExpired) {
      throw Exception('This quiz is closed or has expired.');
    }

    final participant = ExamParticipant(
      id: CodeGenerator.generateId('p'),
      examId: exam.id,
      nickname: nickname.trim().isEmpty ? 'Guest Participant' : nickname.trim(),
      deviceToken: CodeGenerator.generateDeviceToken(),
      joinedAt: DateTime.now(),
      totalQuestions: exam.questions.length,
      status: ParticipantStatus.inProgress,
    );

    _participantsByExam.putIfAbsent(exam.id, () => []).add(participant);

    final supabase = _supabase;
    if (supabase != null && supabase.isAvailable) {
      supabase.recordParticipant(participant).catchError((e) {
        debugPrint('[ExamService] Remote participant registration failed: $e');
        return false;
      });
    }

    return participant;
  }

  /// Submits answers for a participant and calculates their score
  ExamParticipant submitResponses({
    required String examId,
    required String participantId,
    required List<ExamResponse> responses,
  }) {
    final participants = _participantsByExam[examId] ?? [];
    final pIndex = participants.indexWhere((p) => p.id == participantId);
    if (pIndex < 0) {
      throw Exception('Participant not found.');
    }

    final participant = participants[pIndex];
    if (participant.status == ParticipantStatus.submitted) {
      throw Exception('You have already submitted this exam.');
    }

    final score = responses.where((r) => r.isCorrect).length;
    final updated = ExamParticipant(
      id: participant.id,
      examId: participant.examId,
      nickname: participant.nickname,
      deviceToken: participant.deviceToken,
      joinedAt: participant.joinedAt,
      submittedAt: DateTime.now(),
      score: score,
      totalQuestions: participant.totalQuestions,
      status: ParticipantStatus.submitted,
    );

    participants[pIndex] = updated;
    _responsesByExam.putIfAbsent(examId, () => []).addAll(responses);

    final supabase = _supabase;
    if (supabase != null && supabase.isAvailable) {
      supabase
          .submitExamResponses(participant: updated, responses: responses)
          .catchError((e) {
        debugPrint('[ExamService] Remote responses submission failed: $e');
        return false;
      });
    }

    notifyListeners();
    return updated;
  }

  /// Refreshes participants & responses from Supabase for live/remote leaderboard
  Future<List<ExamParticipant>> syncParticipantsFromRemote(String examId) async {
    final supabase = _supabase;
    if (supabase != null && supabase.isAvailable) {
      try {
        final remoteParticipants = await supabase.fetchParticipants(examId);
        final remoteResponses = await supabase.fetchResponsesForExam(examId);

        if (remoteParticipants.isNotEmpty) {
          final existing = _participantsByExam[examId] ?? [];
          final map = {for (final p in existing) p.id: p};
          for (final p in remoteParticipants) {
            map[p.id] = p;
          }
          _participantsByExam[examId] = map.values.toList();
        }

        if (remoteResponses.isNotEmpty) {
          final existing = _responsesByExam[examId] ?? [];
          final map = {for (final r in existing) r.id: r};
          for (final r in remoteResponses) {
            map[r.id] = r;
          }
          _responsesByExam[examId] = map.values.toList();
        }

        notifyListeners();
      } catch (e) {
        debugPrint('[ExamService] Remote participants sync failed: $e');
      }
    }
    return getParticipants(examId);
  }

  /// Subscribes to Realtime participant submissions
  RealtimeChannel? subscribeToLiveParticipants(String examId) {
    final supabase = _supabase;
    if (supabase == null || !supabase.isAvailable) return null;
    return supabase.subscribeToParticipants(
      examId: examId,
      onUpdate: (updatedParticipant) {
        final list = _participantsByExam.putIfAbsent(examId, () => []);
        final idx = list.indexWhere((p) => p.id == updatedParticipant.id);
        if (idx >= 0) {
          list[idx] = updatedParticipant;
        } else {
          list.add(updatedParticipant);
        }
        notifyListeners();
      },
    );
  }

  /// Returns participants for maker leaderboard
  List<ExamParticipant> getParticipants(String examId) {
    final list = _participantsByExam[examId] ?? [];
    final sorted = List<ExamParticipant>.from(list);
    // Sort submitted first, then by highest score
    sorted.sort((a, b) {
      if (a.status == ParticipantStatus.submitted && b.status != ParticipantStatus.submitted) {
        return -1;
      }
      if (b.status == ParticipantStatus.submitted && a.status != ParticipantStatus.submitted) {
        return 1;
      }
      return b.score.compareTo(a.score);
    });
    return sorted;
  }

  /// Returns responses for a specific participant in an exam
  List<ExamResponse> getResponsesForParticipant(String examId, String participantId) {
    final list = _responsesByExam[examId] ?? [];
    return list.where((r) => r.participantId == participantId).toList();
  }

  /// Returns per-question analytics (hardest questions)
  List<HardestQuestionStat> getHardestQuestions(String examId) {
    final exam = _examsById[examId];
    if (exam == null) return [];

    final responses = _responsesByExam[examId] ?? [];
    final stats = <HardestQuestionStat>[];

    for (final q in exam.questions) {
      final qResponses = responses.where((r) => r.questionId == q.id).toList();
      final totalAttempts = qResponses.length;
      final correctCount = qResponses.where((r) => r.isCorrect).length;

      stats.add(HardestQuestionStat(
        questionId: q.id,
        questionText: q.questionText,
        totalAttempts: max(1, totalAttempts),
        correctCount: correctCount,
      ));
    }

    // Sort by lowest accuracy / highest error rate
    stats.sort((a, b) => a.accuracy.compareTo(b.accuracy));
    return stats;
  }
}

class SubjectBundleResult {
  final String code;
  final String subject;
  final int examsCount;
  final int totalQuestions;
  final String bundleJson;

  const SubjectBundleResult({
    required this.code,
    required this.subject,
    required this.examsCount,
    required this.totalQuestions,
    required this.bundleJson,
  });
}
