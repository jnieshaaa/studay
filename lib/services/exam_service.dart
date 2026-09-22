import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/exam_model.dart';
import '../models/question_model.dart';
import '../models/exam_participant_model.dart';
import '../core/utils/code_generator.dart';
import 'seed_data_service.dart';
import 'local_storage_service.dart';

class ExamService extends ChangeNotifier {
  final LocalStorageService _storage;

  // In-memory registry of active exams and participants
  final Map<String, Exam> _examsByCode = {};
  final Map<String, Exam> _examsById = {};
  final Map<String, List<ExamParticipant>> _participantsByExam = {};
  final Map<String, List<ExamResponse>> _responsesByExam = {};

  /// Returns all in-memory exams
  List<Exam> get allExams => _examsById.values.toList();

  ExamService(this._storage) {
    _initSampleExamFromProposal();
    _initExamsFromStorage();
  }

  Future<void> _initExamsFromStorage() async {
    final stored = await _storage.loadCreatedExams();
    for (final exam in stored) {
      _examsById[exam.id] = exam;
      _examsByCode[exam.code.toUpperCase()] = exam;
    }
    notifyListeners();
  }

  /// Seeds the exact sample exam featured in Section 7 & 8 of Proposal v2
  void _initSampleExamFromProposal() {
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

    // Seed mock leaderboard participants from Proposal v2: juanb (9/10), maria_c (9/10), kevin92 (8/10)
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

  /// Publishes a new exam, assigns a 6-character code, and persists it
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
    notifyListeners();
    return updated;
  }

  /// Updates an existing exam (e.g. edited questions, title, settings) and persists it
  Future<Exam> updateExam(Exam updatedExam) async {
    _examsById[updatedExam.id] = updatedExam;
    _examsByCode[updatedExam.code.toUpperCase()] = updatedExam;

    await _storage.saveCreatedExam(updatedExam);
    notifyListeners();
    return updatedExam;
  }

  /// Looks up an exam by its 6-character code (case-insensitive)
  Exam? getExamByCode(String code) {
    final cleanCode = code.trim().toUpperCase();
    return _examsByCode[cleanCode];
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

    return updated;
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
