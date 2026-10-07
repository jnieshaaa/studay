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
import 'package:quizz_app/core/utils/bulk_question_parser.dart';
import 'package:quizz_app/controllers/flashcard_controller.dart';

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
      final examService = ExamService(storage, seedDefaultExams: true);

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
      final examService = ExamService(storage, seedDefaultExams: true);

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
      final examService = ExamService(storage, seedDefaultExams: true);

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

  group('Bulk Question Parser & Import Tests', () {
    test('Parses multiple questions separated by blank lines (user format)', () {
      const rawInput = '''
1. Which keyword declares a block-scoped variable that cannot be reassigned?
A) var
B) let
C) const
D) static

2. Which of the following is the correct syntax for a single-line comment in JavaScript?
A) <!-- comment -->
B) # comment
C) // comment
D) /* comment */

3. Which HTML tag and attribute combination correctly links an external JavaScript file called main.js?
A) <script href="main.js"></script>
B) <script src="main.js"></script>
C) <javascript link="main.js"></javascript>
D) <link rel="script" href="main.js">

4. Which of the following represents a valid JSON string?
A) "{ 'name': 'John', 'age': 30 }"
B) '{ "name": "John", "age": 30 }'
C) '{ name: "John", age: 30 }'
D) '{ "name": "John", "age": 30, }'

5. How do you access the first element of an array named colors?
A) colors[0]
B) colors[1]
C) colors.first()
D) colors(0)
''';

      final parsed = BulkQuestionParser.parse(rawInput);
      expect(parsed.length, 5);

      // Question 1
      expect(
        parsed[0].questionText,
        'Which keyword declares a block-scoped variable that cannot be reassigned?',
      );
      expect(parsed[0].choices.length, 4);
      expect(parsed[0].choices, ['var', 'let', 'const', 'static']);
      expect(parsed[0].correctChoiceIndex, 0); // Defaults to first choice for creator to edit

      // Question 2
      expect(
        parsed[1].questionText,
        'Which of the following is the correct syntax for a single-line comment in JavaScript?',
      );
      expect(parsed[1].choices, ['<!-- comment -->', '# comment', '// comment', '/* comment */']);

      // Question 3
      expect(
        parsed[2].questionText,
        'Which HTML tag and attribute combination correctly links an external JavaScript file called main.js?',
      );
      expect(parsed[2].choices[1], '<script src="main.js"></script>');

      // Question 4
      expect(
        parsed[3].questionText,
        'Which of the following represents a valid JSON string?',
      );
      expect(parsed[3].choices[1], '\'{ "name": "John", "age": 30 }\'');

      // Question 5
      expect(
        parsed[4].questionText,
        'How do you access the first element of an array named colors?',
      );
      expect(parsed[4].choices[0], 'colors[0]');
    });

    test('Parses answers and explanations when provided', () {
      const inputWithAnswer = '''
1. What is the capital of France?
A) Berlin
B) Madrid
C) Paris
D) Rome
Answer: C
Explanation: Paris is the capital and largest city of France.
''';

      final parsed = BulkQuestionParser.parse(inputWithAnswer);
      expect(parsed.length, 1);
      expect(parsed[0].questionText, 'What is the capital of France?');
      expect(parsed[0].correctChoiceIndex, 2); // Choice C
      expect(parsed[0].explanation, 'Paris is the capital and largest city of France.');
    });

    test('Parses inline asterisk/correct indicator on choice line', () {
      const inputWithAsterisk = '''
1. Which is an immutable variable?
A) var
B) let
*C) const
D) function
''';

      final parsed = BulkQuestionParser.parse(inputWithAsterisk);
      expect(parsed.length, 1);
      expect(parsed[0].choices, ['var', 'let', 'const', 'function']);
      expect(parsed[0].correctChoiceIndex, 2); // Choice C marked with *
    });

    test('Parses multi-line code choices with prefixes on own lines', () {
      const codeSnippetInput = '''
How should a custom error class correctly inherit from the built-in Error class?
A)
JavaScript
class CustomError extends Error {
  constructor(message) {
    super(message);
    this.name = "CustomError";
  }
}
B)
JavaScript
class CustomError implements Error {
  constructor(message) {
    this.message = message;
  }
}
C)
JavaScript
class CustomError {
  constructor(message) {
    Error.call(this, message);
  }
}
D)
JavaScript
class CustomError extends Object {
  constructor(message) {
    this.error = message;
  }
}
''';

      final parsed = BulkQuestionParser.parse(codeSnippetInput);
      expect(parsed.length, 1);
      expect(
        parsed[0].questionText,
        'How should a custom error class correctly inherit from the built-in Error class?',
      );
      expect(parsed[0].choices.length, 4);
      expect(parsed[0].choices[0], contains('class CustomError extends Error'));
      expect(parsed[0].choices[0], contains('super(message);'));
      expect(parsed[0].choices[1], contains('class CustomError implements Error'));
      expect(parsed[0].choices[2], contains('Error.call(this, message);'));
      expect(parsed[0].choices[3], contains('class CustomError extends Object'));
    });

    test('Bulk imported questions integrate into ExamMakerController and preserve subject', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(examMakerControllerProvider.notifier);
      notifier.setTitle('JavaScript Basics');
      notifier.setSubject('Web Development');

      const raw = '''
1. Which keyword declares a block-scoped variable?
A) var
B) let
C) const
D) static

2. Single line comment?
A) <!--
B) //
C) #
D) /*
''';

      final parsed = BulkQuestionParser.parse(raw);
      final questions = parsed
          .map((p) => p.toQuestion(subject: 'Web Development'))
          .toList();

      notifier.addQuestions(questions);

      final state = container.read(examMakerControllerProvider);
      expect(state.questions.length, 2);
      expect(state.questions[0].effectiveCategory, 'Web Development');
      expect(state.questions[0].choices.length, 4);
      expect(state.questions[1].questionText, 'Single line comment?');
    });

    test('ExamService retrieves responses for a participant and grades right vs wrong', () {
      final storage = LocalStorageService();
      final examService = ExamService(storage, seedDefaultExams: true);

      final exam = examService.getExamByCode('4F9K2Q')!;
      final participant = examService.joinExam(code: '4F9K2Q', nickname: 'Bob');

      final q1 = exam.questions.first;
      final correctChoice = q1.choices.firstWhere((c) => c.isCorrect);

      final responses = [
        ExamResponse(
          id: 'r1',
          participantId: participant.id,
          questionId: q1.id,
          selectedChoiceId: correctChoice.id,
          isCorrect: true,
        ),
      ];

      examService.submitResponses(
        examId: exam.id,
        participantId: participant.id,
        responses: responses,
      );

      final retrieved = examService.getResponsesForParticipant(exam.id, participant.id);
      expect(retrieved.length, 1);
      expect(retrieved.first.isCorrect, isTrue);
      expect(retrieved.first.selectedChoiceId, correctChoice.id);
    });
  });

  group('Flashcard Deck & Study Mode Tests', () {
    test('Flashcard deck questions are created and integrated into StudyController', () async {
      final storage = LocalStorageService();
      final examService = ExamService(storage, seedDefaultExams: false);

      final container = ProviderContainer(
        overrides: [
          examServiceProvider.overrideWith((ref) => examService),
        ],
      );
      addTearDown(container.dispose);

      // Create a Flashcard Deck exam with 2 cards
      final q1 = Question(
        id: 'q_fc_1',
        topicId: 'flashcards',
        subjectId: 'custom',
        category: 'JavaScript Fundamentals',
        questionText: 'What is a closure?',
        questionType: QuestionType.multipleChoice,
        difficulty: Difficulty.medium,
        explanation: 'Enclosing lexical environment',
        reference: '',
        choices: [
          QuestionChoice(
            id: 'c1',
            questionId: 'q_fc_1',
            choiceText: 'A function bundled with references to its surrounding state',
            isCorrect: true,
            sortOrder: 0,
          ),
        ],
        points: 1,
      );

      final q2 = Question(
        id: 'q_fc_2',
        topicId: 'flashcards',
        subjectId: 'custom',
        category: 'JavaScript Fundamentals',
        questionText: 'What is NaN in JavaScript?',
        questionType: QuestionType.multipleChoice,
        difficulty: Difficulty.medium,
        explanation: 'Not a Number numeric value',
        reference: '',
        choices: [
          QuestionChoice(
            id: 'c2',
            questionId: 'q_fc_2',
            choiceText: 'A special numeric value representing an unrepresentable or undefined value',
            isCorrect: true,
            sortOrder: 0,
          ),
        ],
        points: 1,
      );

      final deckExam = Exam(
        id: 'deck_js_1',
        creatorId: 'maker_1',
        title: 'JS Core Concepts',
        subject: 'JavaScript Fundamentals',
        description: 'Flashcards for JS',
        code: 'JSFC01',
        status: ExamStatus.published,
        questions: [q1, q2],
        createdAt: DateTime.now(),
      );

      final published = await examService.publishExam(deckExam);
      expect(published.questions.length, 2);

      // Sync into StudyController
      final studyNotifier = container.read(studyControllerProvider.notifier);
      await studyNotifier.syncCreatedExam(published);

      final studyState = container.read(studyControllerProvider);
      // Verify subject exists
      expect(
        studyState.subjects.any((s) => s.name == 'JavaScript Fundamentals'),
        isTrue,
      );
      // Verify questions added to study deck
      final subject = studyState.subjects.firstWhere((s) => s.name == 'JavaScript Fundamentals');
      final questions = studyState.questions
          .where((q) => q.subjectId == subject.id || q.category.toLowerCase() == subject.name.toLowerCase())
          .toList();
      expect(questions.length, 2);
      expect(questions.first.questionText, 'What is a closure?');
      expect(questions.first.choices.first.choiceText, contains('A function bundled'));
    });

    test('FlashcardController flips, records mastery, and navigates backwards', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final testQuestions = [
        Question(
          id: 'q1',
          topicId: 't1',
          subjectId: 's1',
          category: 'Math',
          questionText: 'Pi value?',
          questionType: QuestionType.multipleChoice,
          difficulty: Difficulty.easy,
          explanation: '',
          reference: '',
          choices: [
            QuestionChoice(
              id: 'c1',
              questionId: 'q1',
              choiceText: '3.14159',
              isCorrect: true,
              sortOrder: 0,
            ),
          ],
          points: 1,
        ),
        Question(
          id: 'q2',
          topicId: 't1',
          subjectId: 's1',
          category: 'Math',
          questionText: 'Euler number?',
          questionType: QuestionType.multipleChoice,
          difficulty: Difficulty.easy,
          explanation: '',
          reference: '',
          choices: [
            QuestionChoice(
              id: 'c2',
              questionId: 'q2',
              choiceText: '2.71828',
              isCorrect: true,
              sortOrder: 0,
            ),
          ],
          points: 1,
        ),
      ];

      final provider = flashcardControllerProvider(testQuestions);
      final notifier = container.read(provider.notifier);

      // Initial state
      expect(container.read(provider).currentIndex, 0);
      expect(container.read(provider).isFlipped, isFalse);

      // Flip card
      notifier.flip();
      expect(container.read(provider).isFlipped, isTrue);

      // Mark Known
      notifier.markKnown();
      expect(container.read(provider).currentIndex, 1);
      expect(container.read(provider).knownCount, 1);
      expect(container.read(provider).isFlipped, isFalse);

      // Navigate backwards
      notifier.previousCard();
      expect(container.read(provider).currentIndex, 0);

      // Advance again to end
      notifier.markStillLearning();
      expect(container.read(provider).currentIndex, 1);
      notifier.markKnown();
      expect(container.read(provider).isCompleted, isTrue);
    });
  });

  group('Subject Sharing & Conflict-Free Code Generation Tests', () {
    test('generateSubjectCode produces formatted unique code', () {
      final code1 = CodeGenerator.generateSubjectCode('English');
      final code2 = CodeGenerator.generateSubjectCode('English');
      expect(code1, startsWith('SUB-ENGL-'));
      expect(code2, startsWith('SUB-ENGL-'));
      expect(code1, isNot(equals(code2))); // Different random tokens
      expect(code1.length, 15); // 'SUB-' (4) + 'ENGL' (4) + '-' (1) + 6 chars = 15
    });

    test('Subject bundle export and import assigns unique codes avoiding any conflict', () async {
      final storageA = LocalStorageService();
      final serviceA = ExamService(storageA, seedDefaultExams: true);

      // Create 2 exams under 'English Literature'
      final exam1 = await serviceA.publishExam(
        Exam(
          id: 'exam_eng_1',
          title: 'Grammar Fundamentals',
          description: 'Grammar practice',
          subject: 'English',
          code: 'TEMP01',
          creatorId: 'teacher_device_a',
          status: ExamStatus.published,
          createdAt: DateTime.now(),
          questions: [
            Question(
              id: 'q_eng_1',
              topicId: 'top_grammar',
              subjectId: 'subj_eng',
              questionText: 'Which is a verb?',
              questionType: QuestionType.multipleChoice,
              choices: [
                QuestionChoice(id: 'c1', questionId: 'q_eng_1', choiceText: 'Run', isCorrect: true),
                QuestionChoice(id: 'c2', questionId: 'q_eng_1', choiceText: 'Blue', isCorrect: false),
              ],
            ),
          ],
        ),
      );

      final exam2 = await serviceA.publishExam(
        Exam(
          id: 'exam_eng_2',
          title: 'Vocabulary Master',
          description: 'Vocabulary practice',
          subject: 'English',
          code: 'TEMP02',
          creatorId: 'teacher_device_a',
          status: ExamStatus.published,
          createdAt: DateTime.now(),
          questions: [
            Question(
              id: 'q_eng_2',
              topicId: 'top_vocab',
              subjectId: 'subj_eng',
              questionText: 'Synonym of Happy?',
              questionType: QuestionType.multipleChoice,
              choices: [
                QuestionChoice(id: 'c3', questionId: 'q_eng_2', choiceText: 'Joyful', isCorrect: true),
                QuestionChoice(id: 'c4', questionId: 'q_eng_2', choiceText: 'Sad', isCorrect: false),
              ],
            ),
          ],
        ),
      );

      final originalCode1 = exam1.code;
      final originalCode2 = exam2.code;
      expect(originalCode1, isNot(equals(originalCode2)));

      // Export the subject bundle from Device A
      final bundle = await serviceA.exportSubjectBundle('English');
      expect(bundle.code, startsWith('SUB-ENGL-'));
      expect(bundle.examsCount, 2);
      expect(bundle.totalQuestions, 2);
      expect(bundle.bundleJson, contains('Grammar Fundamentals'));
      expect(bundle.bundleJson, contains('Vocabulary Master'));

      // Now on Device B: separate fresh storage and service
      final storageB = LocalStorageService();
      final serviceB = ExamService(storageB, seedDefaultExams: false);

      // Import the bundle onto Device B with user B taking ownership
      final importedExams = await serviceB.importSubjectBundle(
        bundle.bundleJson,
        newCreatorId: 'user_device_b',
      );

      expect(importedExams.length, 2);

      final importedExam1 = importedExams.firstWhere((e) => e.title == 'Grammar Fundamentals');
      final importedExam2 = importedExams.firstWhere((e) => e.title == 'Vocabulary Master');

      // 1. Verify recipient owns the exams
      expect(importedExam1.creatorId, 'user_device_b');
      expect(importedExam2.creatorId, 'user_device_b');

      // 2. CRITICAL: Verify exam codes inside that subject are UNIQUE and avoid collision
      expect(importedExam1.code, isNot(equals(originalCode1))); // Different from Device A's code
      expect(importedExam2.code, isNot(equals(originalCode2))); // Different from Device A's code
      expect(importedExam1.code, isNot(equals(importedExam2.code))); // Different from each other!
      expect(importedExam1.code.length, 6);
      expect(importedExam2.code.length, 6);

      // 3. Verify question and choice IDs are fresh and non-colliding
      expect(importedExam1.id, isNot(equals(exam1.id)));
      expect(importedExam1.questions.first.id, isNot(equals('q_eng_1')));
      expect(importedExam1.questions.first.choices.first.id, isNot(equals('c1')));

      // 4. Verify quizzes can be looked up and joined with their new unique codes on Device B
      final fetched1 = serviceB.getExamByCode(importedExam1.code);
      final fetched2 = serviceB.getExamByCode(importedExam2.code);
      expect(fetched1, isNotNull);
      expect(fetched2, isNotNull);
      expect(fetched1!.title, 'Grammar Fundamentals');
      expect(fetched2!.title, 'Vocabulary Master');
    });
  });
}
