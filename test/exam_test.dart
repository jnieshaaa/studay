import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quizz_app/core/utils/code_generator.dart';
import 'package:quizz_app/models/question_model.dart';
import 'package:quizz_app/models/subject_model.dart';
import 'package:quizz_app/models/exam_model.dart';
import 'package:quizz_app/models/exam_participant_model.dart';
import 'package:quizz_app/services/local_storage_service.dart';
import 'package:quizz_app/services/exam_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quizz_app/controllers/providers.dart';
import 'package:quizz_app/controllers/study_controller.dart';
import 'package:quizz_app/controllers/exam_maker_controller.dart';
import 'package:quizz_app/controllers/exam_participant_controller.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Code Generator Tests', () {
    test('Generates valid 6-character exam codes', () {
      final code = CodeGenerator.generateExamCode();
      expect(code.length, 6);
      expect(code, equals(code.toUpperCase()));
      // Verify no ambiguous characters
      expect(code.contains('0'), isFalse);
      expect(code.contains('O'), isFalse);
      expect(code.contains('1'), isFalse);
      expect(code.contains('I'), isFalse);
    });

    test('Generates random device tokens', () {
      final token1 = CodeGenerator.generateDeviceToken();
      final token2 = CodeGenerator.generateDeviceToken();
      expect(token1, startsWith('dev_'));
      expect(token1, isNot(equals(token2)));
    });
  });

  group('Exam Service & Grading Tests', () {
    test('Published exam can be joined with 6-char code and graded correctly', () async {
      final storage = LocalStorageService();
      final examService = ExamService(storage);

      // Pre-seeded demo exam
      final exam = examService.getExamByCode('4F9K2Q');
      expect(exam, isNotNull);
      expect(exam!.title, contains('Cell Biology'));

      // Join as new participant
      final participant = examService.joinExam(
        code: '4F9K2Q',
        nickname: 'test_student',
      );
      expect(participant.nickname, 'test_student');
      expect(participant.status, ParticipantStatus.inProgress);
      expect(participant.totalQuestions, exam.questions.length);

      // Answer questions
      final responses = <ExamResponse>[];
      for (final q in exam.questions) {
        if (q.questionType == QuestionType.multipleChoice ||
            q.questionType == QuestionType.trueFalse) {
          final correctChoice = q.choices.firstWhere((c) => c.isCorrect);
          responses.add(ExamResponse(
            id: 'r_${q.id}',
            participantId: participant.id,
            questionId: q.id,
            selectedChoiceId: correctChoice.id,
            isCorrect: true,
          ));
        } else if (q.questionType == QuestionType.matching) {
          final matchingMap = {
            for (final pair in q.matchingPairs) pair.leftText: pair.rightText
          };
          responses.add(ExamResponse(
            id: 'r_${q.id}',
            participantId: participant.id,
            questionId: q.id,
            matchingResponse: matchingMap,
            isCorrect: true,
          ));
        }
      }

      // Submit responses
      final submitted = examService.submitResponses(
        examId: exam.id,
        participantId: participant.id,
        responses: responses,
      );

      expect(submitted.status, ParticipantStatus.submitted);
      expect(submitted.score, exam.questions.length);
      expect(submitted.percentage, 100.0);

      // Verify Leaderboard ranking
      final leaderboard = examService.getParticipants(exam.id);
      expect(leaderboard.any((p) => p.id == participant.id), isTrue);

      // Verify Hardest Questions stats
      final hardest = examService.getHardestQuestions(exam.id);
      expect(hardest.length, exam.questions.length);
    });

    test('Matching questions support dynamic pair count (e.g. 5 pairs)', () {
      final pairs = List.generate(
        5,
        (i) => MatchingPair(
          id: 'p_$i',
          questionId: 'q_dyn',
          leftText: 'Concept ${i + 1}',
          rightText: 'Definition ${i + 1}',
        ),
      );

      final q = Question(
        id: 'q_dyn',
        topicId: 'custom',
        subjectId: 'custom',
        questionText: 'Match all 5 concepts with their definitions',
        questionType: QuestionType.matching,
        matchingPairs: pairs,
      );

      expect(q.matchingPairs.length, 5);
      expect(q.matchingPairs[4].leftText, 'Concept 5');
    });

    test('LocalStorageService persists and loads custom subjects for study decks', () async {
      final storage = LocalStorageService();
      await storage.init();

      final customSubj = const Subject(
        id: 'subj_test_custom',
        name: 'Custom Review Deck',
        description: 'Imported from exam',
        icon: 'school',
      );

      await storage.saveCustomSubject(customSubj);
      final loaded = await storage.loadCustomSubjects();

      expect(loaded.any((s) => s.id == 'subj_test_custom'), isTrue);
      expect(loaded.firstWhere((s) => s.id == 'subj_test_custom').name, 'Custom Review Deck');
    });

    test('Exam categories aggregation and category-specific filtering', () {
      final q1 = const Question(
        id: 'q1',
        topicId: 'math_algebra',
        subjectId: 'subj_mth',
        questionText: 'What is 15% of 200?',
        questionType: QuestionType.multipleChoice,
        category: 'Math',
      );
      final q2 = const Question(
        id: 'q2',
        topicId: 'gk_current',
        subjectId: 'subj_gen',
        questionText: 'Who is the author of Noli Me Tangere?',
        questionType: QuestionType.multipleChoice,
        category: 'General Knowledge',
      );
      final q3 = const Question(
        id: 'q3',
        topicId: 'math_geometry',
        subjectId: 'subj_mth',
        questionText: 'What is the sum of angles in a triangle?',
        questionType: QuestionType.multipleChoice,
        category: 'Math',
      );

      final exam = Exam(
        id: 'exam_diag_mock',
        creatorId: 'maker_john',
        title: 'Diagnostic Comprehensive Exam',
        description: 'Multi-category preparation exam',
        code: 'DGN101',
        status: ExamStatus.published,
        questions: [q1, q2, q3],
        createdAt: DateTime.now(),
      );

      // Verify dynamic category aggregation
      expect(exam.categories, equals(['General Knowledge', 'Math']));

      // Filter specifically for "Math" only
      final mathOnlyQuestions = exam.questions.where((q) => q.effectiveCategory == 'Math').toList();
      expect(mathOnlyQuestions.length, 2);
      expect(mathOnlyQuestions.every((q) => q.category == 'Math'), isTrue);

      // Filter specifically for "General Knowledge"
      final gkOnlyQuestions = exam.questions.where((q) => q.effectiveCategory == 'General Knowledge').toList();
      expect(gkOnlyQuestions.length, 1);
      expect(gkOnlyQuestions.first.questionText, contains('Noli Me Tangere'));
    });

    test('Subject Cards grouping: Exams are assigned to subjects (Filipino, English, Math)', () {
      final storage = LocalStorageService();
      final examService = ExamService(storage);

      final allExams = examService.allExams;
      final Map<String, List<Exam>> examsBySubject = {};
      for (final exam in allExams) {
        examsBySubject.putIfAbsent(exam.effectiveSubject, () => []).add(exam);
      }

      // Verify subjects are properly populated
      expect(examsBySubject.containsKey('Filipino'), isTrue);
      expect(examsBySubject.containsKey('English'), isTrue);
      expect(examsBySubject.containsKey('Math'), isTrue);
      expect(examsBySubject.containsKey('Science'), isTrue);

      // Verify Math subject contains both Quiz 1 and Quiz 2
      final mathExams = examsBySubject['Math']!;
      expect(mathExams.length, greaterThanOrEqualTo(2));
      expect(mathExams.any((e) => e.title.contains('Quiz 1')), isTrue);
      expect(mathExams.any((e) => e.title.contains('Quiz 2')), isTrue);

      // Verify Filipino subject contains Quiz 1
      final filipinoExams = examsBySubject['Filipino']!;
      expect(filipinoExams.any((e) => e.title.contains('Quiz 1')), isTrue);
      expect(filipinoExams.any((e) => e.code == 'FIL101'), isTrue);
    });

    test('Guest takers can join and take exams with 6-char code without account/login', () {
      final storage = LocalStorageService();
      final examService = ExamService(storage);

      // Guest taker with no account signs in with code
      final participant = examService.joinExam(
        code: '4F9K2Q',
        nickname: 'Guest Taker',
      );

      expect(participant.status, ParticipantStatus.inProgress);
      expect(participant.nickname, 'Guest Taker');
      expect(participant.deviceToken, startsWith('dev_'));
    });

    test('Quiz automatically added to library when created, supports start/stop control and timers', () async {
      final storage = LocalStorageService();
      final examService = ExamService(storage);

      // Create and publish a new quiz
      final newExam = Exam(
        id: 'exam_custom_1',
        creatorId: 'maker_maria',
        title: 'Quiz 3: Philippine History',
        subject: 'History',
        description: 'Mock history quiz',
        code: '',
        durationMinutes: 15,
        questions: const [
          Question(
            id: 'q_hist_1',
            topicId: 'top_hist',
            subjectId: 'subj_hist',
            questionType: QuestionType.multipleChoice,
            questionText: 'When was Philippine independence proclaimed?',
            choices: [
              QuestionChoice(id: 'c1', questionId: 'q_hist_1', choiceText: 'June 12, 1898', isCorrect: true),
              QuestionChoice(id: 'c2', questionId: 'q_hist_1', choiceText: 'July 4, 1946', isCorrect: false),
            ],
          ),
        ],
        createdAt: DateTime(2026, 1, 1),
      );

      final published = await examService.publishExam(newExam);
      expect(published.code.length, 6);
      expect(published.durationMinutes, 15);
      expect(published.durationLabel, '15m');
      expect(published.status, ExamStatus.published);

      // Verify it is automatically in allExams (Library)
      expect(examService.allExams.any((e) => e.id == published.id), isTrue);

      // Verify taker can join while published (live)
      final taker1 = examService.joinExam(code: published.code, nickname: 'Taker 1');
      expect(taker1.nickname, 'Taker 1');

      // Creator STOPS the quiz
      await examService.toggleExamStatus(published.id);
      final stoppedExam = examService.getExamById(published.id);
      expect(stoppedExam?.status, ExamStatus.closed);

      // Verify taker CANNOT join while stopped
      expect(
        () => examService.joinExam(code: published.code, nickname: 'Taker 2'),
        throwsA(predicate((e) => e.toString().contains('stopped by the creator'))),
      );

      // Creator STARTS the quiz again
      await examService.toggleExamStatus(published.id);
      final restartedExam = examService.getExamById(published.id);
      expect(restartedExam?.status, ExamStatus.published);

      // Verify taker can join again
      final taker3 = examService.joinExam(code: published.code, nickname: 'Taker 3');
      expect(taker3.nickname, 'Taker 3');

      // Creator updates timer to 30 mins
      await examService.updateExamTimer(published.id, 30);
      final timedExam = examService.getExamById(published.id);
      expect(timedExam?.durationMinutes, 30);
      expect(timedExam?.durationLabel, '30m');

      // Creator removes timer (untimed)
      await examService.updateExamTimer(published.id, null);
      final untimedExam = examService.getExamById(published.id);
      expect(untimedExam?.durationMinutes, isNull);
      expect(untimedExam?.durationLabel, 'Untimed');
    });

    test('Created quiz subjects and questions are integrated in StudyController', () async {
      final storage = LocalStorageService();
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
        ],
      );
      addTearDown(container.dispose);

      final examService = container.read(examServiceProvider);
      final studyNotifier = container.read(studyControllerProvider.notifier);

      // Create an exam under a custom subject
      final customExam = Exam(
        id: 'exam_study_custom',
        creatorId: 'maker_maria',
        title: 'Quiz 1: World Literature',
        subject: 'Literature',
        description: 'World lit study deck',
        code: '',
        durationMinutes: 20,
        questions: const [
          Question(
            id: 'q_lit_1',
            topicId: 'top_lit',
            subjectId: 'subj_lit',
            questionType: QuestionType.multipleChoice,
            questionText: 'Who wrote Noli Me Tangere?',
            choices: [
              QuestionChoice(id: 'l1', questionId: 'q_lit_1', choiceText: 'Jose Rizal', isCorrect: true),
              QuestionChoice(id: 'l2', questionId: 'q_lit_1', choiceText: 'Andres Bonifacio', isCorrect: false),
            ],
          ),
        ],
        createdAt: DateTime.now(),
      );

      final published = await examService.publishExam(customExam);
      await studyNotifier.syncCreatedExam(published);

      final studyState = container.read(studyControllerProvider);
      // Verify Literature subject is available in study mode
      expect(studyState.subjects.any((s) => s.name.toLowerCase() == 'literature'), isTrue);
      // Verify question is available in study mode
      expect(studyState.questions.any((q) => q.id == 'q_lit_1'), isTrue);

      // Verify quiz session can be built for this exam with its time limit
      final session = studyNotifier.buildQuizSessionForExam(published);
      expect(session.questions.length, 1);
      expect(session.timeLimitSeconds, 20 * 60);
    });

    test('Creator can edit questions of an already published exam and update it preserving its code', () async {
      final storage = LocalStorageService();
      final examService = ExamService(storage);
      final container = ProviderContainer(
        overrides: [
          examServiceProvider.overrideWith((ref) => examService),
        ],
      );
      addTearDown(container.dispose);

      final examMaker = container.read(examMakerControllerProvider.notifier);

      // Create and publish initial exam
      examMaker.setTitle('Initial Exam Title');
      examMaker.setSubject('Math');
      examMaker.addQuestion(const Question(
        id: 'q_edit_1',
        topicId: 'top_math',
        subjectId: 'subj_math',
        questionText: 'What is 2 + 2?',
        questionType: QuestionType.multipleChoice,
        choices: [
          QuestionChoice(id: 'c1', questionId: 'q_edit_1', choiceText: '4', isCorrect: true),
          QuestionChoice(id: 'c2', questionId: 'q_edit_1', choiceText: '5', isCorrect: false),
        ],
      ));

      final published = await examMaker.publish();
      expect(published, isNotNull);
      final originalCode = published!.code;
      expect(originalCode.length, 6);

      // Creator enters Edit mode
      examMaker.initForEdit(published);
      expect(container.read(examMakerControllerProvider).isEditing, isTrue);

      // Creator edits question prompt and adds a new choice
      examMaker.updateQuestion(
        0,
        const Question(
          id: 'q_edit_1',
          topicId: 'top_math',
          subjectId: 'subj_math',
          questionText: 'What is 2 + 2? (Updated)',
          questionType: QuestionType.multipleChoice,
          choices: [
            QuestionChoice(id: 'c1', questionId: 'q_edit_1', choiceText: '4', isCorrect: true),
            QuestionChoice(id: 'c2', questionId: 'q_edit_1', choiceText: '5', isCorrect: false),
            QuestionChoice(id: 'c3', questionId: 'q_edit_1', choiceText: '6', isCorrect: false),
          ],
        ),
      );

      // Creator saves the edited exam
      final updated = await examMaker.publish();
      expect(updated, isNotNull);
      expect(updated!.id, published.id);
      expect(updated.code, originalCode); // Same code preserved!
      expect(updated.questions.first.questionText, 'What is 2 + 2? (Updated)');
      expect(updated.questions.first.choices.length, 3);

      // Verify exam in ExamService is updated
      final fromService = examService.getExamByCode(originalCode);
      expect(fromService, isNotNull);
      expect(fromService!.questions.first.questionText, 'What is 2 + 2? (Updated)');
    });

    test('Section Order: Creator can set Matching Type first, and questions are ordered strictly by sections', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final examMaker = container.read(examMakerControllerProvider.notifier);

      // Add a mix of questions
      examMaker.setTitle('Science & Geography Exam');
      examMaker.setSubject('Science');

      final qMcq = const Question(
        id: 'q_mcq',
        topicId: 't1',
        subjectId: 's1',
        questionText: 'What is H2O?',
        questionType: QuestionType.multipleChoice,
        choices: [
          QuestionChoice(id: 'c1', questionId: 'q_mcq', choiceText: 'Water', isCorrect: true),
        ],
      );
      final qTf = const Question(
        id: 'q_tf',
        topicId: 't1',
        subjectId: 's1',
        questionText: 'Earth is the 3rd planet.',
        questionType: QuestionType.trueFalse,
        choices: [
          QuestionChoice(id: 'c2', questionId: 'q_tf', choiceText: 'True', isCorrect: true),
        ],
      );
      final qMatch = const Question(
        id: 'q_match',
        topicId: 't1',
        subjectId: 's1',
        questionText: 'Match capitals to countries',
        questionType: QuestionType.matching,
        matchingPairs: [
          MatchingPair(id: 'm1', questionId: 'q_match', leftText: 'Manila', rightText: 'Philippines'),
          MatchingPair(id: 'm2', questionId: 'q_match', leftText: 'Tokyo', rightText: 'Japan'),
        ],
      );

      examMaker.addQuestion(qMcq);
      examMaker.addQuestion(qTf);
      examMaker.addQuestion(qMatch);

      // Default section order starts with Multiple Choice
      expect(container.read(examMakerControllerProvider).sectionOrder.first, QuestionType.multipleChoice);

      // Set Matching Type to start first!
      examMaker.setFirstSection(QuestionType.matching);
      final state = container.read(examMakerControllerProvider);
      expect(state.sectionOrder.first, QuestionType.matching);
      expect(state.sectionOrder, containsAllInOrder([QuestionType.matching, QuestionType.multipleChoice, QuestionType.trueFalse]));

      // Publish exam
      final published = await examMaker.publish();
      expect(published, isNotNull);
      expect(published!.sectionOrder.first, QuestionType.matching);

      // Verify orderedQuestions puts matching first, followed by MCQ, then True/False
      final ordered = published.orderedQuestions;
      expect(ordered.length, 3);
      expect(ordered[0].questionType, QuestionType.matching);
      expect(ordered[1].questionType, QuestionType.multipleChoice);
      expect(ordered[2].questionType, QuestionType.trueFalse);

      // Verify serialization / deserialization roundtrip
      final json = published.toJson();
      final fromJson = Exam.fromJson(json);
      expect(fromJson.sectionOrder, published.sectionOrder);
      expect(fromJson.orderedQuestions.first.questionType, QuestionType.matching);
    });

    test('ExamParticipantController keeps question types strictly separated even with shuffle enabled', () {
      final questions = [
        const Question(id: 'mcq1', topicId: 't', subjectId: 's', questionText: 'MCQ 1', questionType: QuestionType.multipleChoice),
        const Question(id: 'mcq2', topicId: 't', subjectId: 's', questionText: 'MCQ 2', questionType: QuestionType.multipleChoice),
        const Question(id: 'tf1', topicId: 't', subjectId: 's', questionText: 'TF 1', questionType: QuestionType.trueFalse),
        const Question(id: 'tf2', topicId: 't', subjectId: 's', questionText: 'TF 2', questionType: QuestionType.trueFalse),
        const Question(id: 'm1', topicId: 't', subjectId: 's', questionText: 'M 1', questionType: QuestionType.matching),
        const Question(id: 'm2', topicId: 't', subjectId: 's', questionText: 'M 2', questionType: QuestionType.matching),
      ];

      // Creator sets Matching first, then True/False, then Multiple Choice
      final exam = Exam(
        id: 'exam_sep_test',
        creatorId: 'c1',
        title: 'Separation Test',
        description: 'Testing separate parts',
        code: 'SEP123',
        sectionOrder: const [QuestionType.matching, QuestionType.trueFalse, QuestionType.multipleChoice],
        questionOrder: QuestionOrder.shuffled, // Shuffle is enabled!
        questions: questions,
        createdAt: DateTime.now(),
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final participant = ExamParticipant(
        id: 'p1',
        examId: exam.id,
        nickname: 'Alice',
        deviceToken: 'dev_1',
        status: ParticipantStatus.inProgress,
        joinedAt: DateTime.now(),
        totalQuestions: 6,
      );

      final param = ExamParticipantParam(exam, participant);
      final playState = container.read(examParticipantControllerProvider(param));

      final preparedQuestions = playState.exam.questions;
      expect(preparedQuestions.length, 6);

      // First two MUST be matching type (Part 1)
      expect(preparedQuestions[0].questionType, QuestionType.matching);
      expect(preparedQuestions[1].questionType, QuestionType.matching);

      // Next two MUST be true/false (Part 2)
      expect(preparedQuestions[2].questionType, QuestionType.trueFalse);
      expect(preparedQuestions[3].questionType, QuestionType.trueFalse);

      // Last two MUST be multiple choice (Part 3)
      expect(preparedQuestions[4].questionType, QuestionType.multipleChoice);
      expect(preparedQuestions[5].questionType, QuestionType.multipleChoice);
    });
  });
}
