import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quizz_app/main.dart';
import 'package:quizz_app/views/screens/splash/splash_screen.dart';
import 'package:quizz_app/views/screens/auth/username_setup_screen.dart';
import 'package:quizz_app/views/screens/library/my_library_screen.dart';
import 'package:quizz_app/views/screens/study/study_home_screen.dart';
import 'package:quizz_app/views/screens/exam/exam_maker_screen.dart';
import 'package:quizz_app/models/question_model.dart';
import 'package:quizz_app/views/screens/exam/exam_section_questions_screen.dart';
import 'package:quizz_app/controllers/auth_controller.dart';
import 'package:quizz_app/controllers/exam_maker_controller.dart';
import 'package:quizz_app/controllers/providers.dart';
import 'package:quizz_app/views/screens/study/create_flashcard_sheet.dart';
import 'package:quizz_app/views/screens/study/flashcards_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SplashScreen.hasShownSplashThisSession = false;
  });

  testWidgets('Studay opens with SplashScreen, then navigates to UsernameSetupScreen on first launch', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: QuizzApp(),
      ),
    );

    // Initial frame renders SplashScreen
    expect(find.text('Study & Exam Maker'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Let the splash timer finish and transition to UsernameSetupScreen
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pumpAndSettle();

    // Now on UsernameSetupScreen
    expect(find.text('What should we call you?'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Taking a quiz? Join by Code'), findsOneWidget);

    // Tap Continue with the auto-generated username
    final continueBtn = find.text('Continue');
    await tester.ensureVisible(continueBtn);
    await tester.tap(continueBtn);
    await tester.pumpAndSettle();

    // Now enters Dashboard
    expect(find.text('Studay'), findsWidgets);
    expect(find.text('Study Mode'), findsOneWidget);
    expect(find.text('Exam Mode'), findsOneWidget);
  });

  testWidgets('UsernameSetupScreen renders auto-generated username, centered input, and bottom continue button', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: UsernameSetupScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify title and guidance
    expect(find.text('What should we call you?'), findsOneWidget);
    expect(find.text('You can keep this auto-generated name or change it.'), findsOneWidget);

    // Verify centered input contains auto-generated "User..."
    final inputFinder = find.byType(TextFormField);
    expect(inputFinder, findsOneWidget);
    final textFormField = tester.widget<TextFormField>(inputFinder);
    expect(textFormField.controller?.text.startsWith('User'), isTrue);

    // Verify continue button and guest taker link at bottom
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Taking a quiz? Join by Code'), findsOneWidget);
  });

  testWidgets('UsernameSetupScreen allows custom username and updates AuthState upon continue', (WidgetTester tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: UsernameSetupScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(container.read(authControllerProvider).isAuthenticated, isFalse);

    // Type a custom name
    final inputFinder = find.byType(TextFormField);
    await tester.enterText(inputFinder, 'Alex Santos');
    await tester.pumpAndSettle();

    // Tap Continue
    final continueBtn = find.text('Continue');
    await tester.ensureVisible(continueBtn);
    await tester.tap(continueBtn);
    await tester.pumpAndSettle();

    expect(container.read(authControllerProvider).isAuthenticated, isTrue);
    expect(container.read(authControllerProvider).currentUser?.name, 'Alex Santos');
  });

  testWidgets('MyLibraryScreen renders collapsible subject cards with creator controls (start/stop, timer, edit)', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(examServiceProvider).seedDefaultExamsForTesting();

    // Set username as creator
    await container.read(authControllerProvider.notifier).setUsername('Maria Santos');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: MyLibraryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify creator header
    expect(find.text("Maria Santos's Library"), findsOneWidget);

    // Verify subjects exist
    expect(find.text('Filipino'), findsWidgets);
    expect(find.text('English'), findsWidgets);
    expect(find.text('Math'), findsWidgets);

    // Verify subject cards start collapsed by default for a clean, uncluttered overview
    expect(find.text('1 quiz hidden • Tap to view or manage'), findsWidgets);
    expect(find.text('Quiz 1: Wika at Balarila'), findsNothing);

    // Tap Filipino header to expand it
    final filipinoHeader = find.text('Filipino').first;
    await tester.ensureVisible(filipinoHeader);
    await tester.tap(filipinoHeader);
    await tester.pumpAndSettle();

    // Verify Filipino quizzes are now visible
    expect(find.text('Quiz 1: Wika at Balarila'), findsOneWidget);
    expect(find.text('LIVE'), findsWidgets);
    expect(find.text('Stop'), findsWidgets);
    expect(find.text('Edit'), findsWidgets);

    // Test Stop button
    final stopBtn = find.text('Stop').first;
    await tester.ensureVisible(stopBtn);
    await tester.tap(stopBtn);
    await tester.pumpAndSettle();
    expect(find.text('STOPPED'), findsWidgets);
    expect(find.text('Start'), findsWidgets);

    // Test Start button
    final startBtn = find.text('Start').first;
    await tester.ensureVisible(startBtn);
    await tester.tap(startBtn);
    await tester.pumpAndSettle();
    expect(find.text('LIVE'), findsWidgets);

    // Test Collapsible Subject Cards: tap Filipino header again to collapse
    await tester.tap(filipinoHeader);
    await tester.pumpAndSettle();

    // Filipino quizzes should now be hidden again
    expect(find.text('Quiz 1: Wika at Balarila'), findsNothing);

    // Expand again to test timer dialog
    await tester.tap(filipinoHeader);
    await tester.pumpAndSettle();
    expect(find.text('Quiz 1: Wika at Balarila'), findsOneWidget);

    // Test Timer dialog: tap timer pill
    final timerEditBtn = find.byIcon(Icons.timer_outlined).first;
    await tester.ensureVisible(timerEditBtn);
    await tester.tap(timerEditBtn);
    await tester.pumpAndSettle();

    expect(find.text('Set Quiz Timer'), findsOneWidget);
    expect(find.text('15m'), findsWidgets);
    await tester.tap(find.text('Save Timer'));
    await tester.pumpAndSettle();
  });

  testWidgets('StudyHomeScreen displays created quiz subject cards with Practice, Flashcards, and Take Quiz', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(examServiceProvider).seedDefaultExamsForTesting();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: StudyHomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Study Mode header
    expect(find.text('Study Mode'), findsOneWidget);

    // Verify Created Quiz Subject Cards Section
    expect(find.textContaining('SUBJECT QUIZ CARDS'), findsOneWidget);
    expect(find.text('Study or take created quizzes'), findsOneWidget);

    // Verify Practice, Flashcards, and Take Quiz buttons exist
    expect(find.text('Practice'), findsWidgets);
    expect(find.text('Flashcards'), findsWidgets);
    expect(find.text('Take Quiz'), findsWidgets);

    // Test collapsing a subject card in Study Mode
    final hideBtn = find.byTooltip('Hide quizzes').first;
    await tester.ensureVisible(hideBtn);
    await tester.tap(hideBtn);
    await tester.pumpAndSettle();

    expect(find.textContaining('hidden • Tap to open and study'), findsOneWidget);
  });

  testWidgets('ExamMakerScreen fits narrow mobile screen (360px), separates question sections, and supports Quick Bulk Paste', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ExamMakerScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Section Order card exists
    expect(find.text('EXAM SECTION ORDER'), findsOneWidget);
    expect(find.text('Start first with:'), findsOneWidget);

    // Verify 3 separate parts exist
    expect(find.textContaining('Part 1:'), findsWidgets);
    expect(find.textContaining('Part 2:'), findsWidgets);
    expect(find.textContaining('Part 3:'), findsWidgets);

    // Verify creator can change starting section to Matching Type
    final matchingChip = find.widgetWithText(ChoiceChip, 'Matching Type');
    expect(matchingChip, findsOneWidget);
    await tester.tap(matchingChip);
    await tester.pumpAndSettle();

    // Verify state updated to have Matching Type first
    expect(container.read(examMakerControllerProvider).sectionOrder.first.label, 'Matching Type');
    expect(find.text('Starts with: Matching Type'), findsOneWidget);
    expect(find.textContaining('Part 1: Matching Type'), findsOneWidget);

    // Verify QUESTIONS BY SECTION header is removed for a cleaner UI
    expect(find.textContaining('QUESTIONS BY SECTION'), findsNothing);

    // Enter required details to proceed to Step 2
    final titleField = find.widgetWithText(TextField, 'Exam Title *');
    await tester.enterText(titleField, 'Midterm Reviewer');
    final subjectField = find.widgetWithText(TextField, 'Subject Category *');
    await tester.enterText(subjectField, 'Science');

    // Tap Continue to Step 2
    final continueBtn = find.text('Continue to Step 2: Manage Questions ->');
    await tester.ensureVisible(continueBtn);
    await tester.tap(continueBtn);
    await tester.pumpAndSettle();

    // In Step 2, tap "Add Matching Type" button inside Part 1
    final addMatchingBtn = find.text('Add Matching Type').first;
    await tester.ensureVisible(addMatchingBtn);
    await tester.tap(addMatchingBtn);
    await tester.pumpAndSettle();

    // Verify AddQuestionSheet opens and has Quick Paste button
    expect(find.text('MATCHING PAIRS (Left matches Right)'), findsOneWidget);
    final quickPasteBtn = find.text('Quick Paste');
    expect(quickPasteBtn, findsOneWidget);

    // Tap Quick Paste to open Bulk Paste dialog
    await tester.tap(quickPasteBtn);
    await tester.pumpAndSettle();

    expect(find.text('⚡ Quick Bulk Paste Pairs'), findsOneWidget);
    expect(find.text('Insert Sample'), findsOneWidget);

    // Tap Insert Sample
    await tester.tap(find.text('Insert Sample'));
    await tester.pumpAndSettle();

    expect(find.textContaining('pairs recognized'), findsOneWidget);

    // Tap Apply Pairs
    await tester.tap(find.text('Apply Pairs'));
    await tester.pumpAndSettle();

    // Dialog closed and pairs populated
    expect(find.text('⚡ Quick Bulk Paste Pairs'), findsNothing);
    expect(find.text('Manila'), findsOneWidget);
    expect(find.text('Philippines'), findsOneWidget);
  });

  testWidgets('ExamSectionQuestionsScreen modal locks question type to section and does not show tabs for other types', (tester) async {
    tester.view.physicalSize = const Size(400, 850);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ExamSectionQuestionsScreen(sectionType: QuestionType.multipleChoice),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify screen title
    expect(find.textContaining('Part 1: Multiple Choice'), findsOneWidget);

    // Tap Add MCQ button
    final addMcqBtn = find.text('Add MCQ').first;
    await tester.tap(addMcqBtn);
    await tester.pumpAndSettle();

    // In AddQuestionSheet:
    // 1. Title should say "Add Multiple Choice"
    expect(find.text('Add Multiple Choice'), findsOneWidget);
    expect(find.text('Part 1: Multiple Choice'), findsWidgets);

    // 2. The SegmentedButton with other question types (T/F, Match) must NOT exist
    expect(find.widgetWithText(ButtonSegment<QuestionType>, 'T/F'), findsNothing);
    expect(find.widgetWithText(ButtonSegment<QuestionType>, 'Match'), findsNothing);

    // 3. Multiple Choice options are displayed
    expect(find.text('OPTIONS (Mark the correct answer)'), findsOneWidget);
    expect(find.byType(Radio<int>), findsNWidgets(4));
  });

  testWidgets('CreateFlashcardSheet renders inputs, supports quick paste flashcards dialog, and adds cards', (tester) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: CreateFlashcardSheet(initialSubject: 'Science'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify title and subject
    expect(find.text('Create Flashcard Deck'), findsOneWidget);
    expect(find.text('Quick Paste Cards'), findsOneWidget);
    expect(find.text('Add Another Flashcard'), findsOneWidget);

    // Tap Quick Paste to open dialog
    await tester.tap(find.text('Quick Paste Cards'));
    await tester.pumpAndSettle();

    expect(find.text('⚡ Quick Paste Flashcards'), findsOneWidget);
    expect(find.text('Insert Sample'), findsOneWidget);

    // Tap Insert Sample
    await tester.tap(find.text('Insert Sample'));
    await tester.pumpAndSettle();

    expect(find.textContaining('flashcards detected'), findsOneWidget);

    // Tap Add Flashcards
    await tester.tap(find.text('Add Flashcards'));
    await tester.pumpAndSettle();

    // Quick Paste dialog closed and cards added
    expect(find.text('⚡ Quick Paste Flashcards'), findsNothing);
    expect(find.text('Photosynthesis'), findsOneWidget);
    expect(find.text('Mitochondria'), findsOneWidget);

    // Tap Add Another Flashcard
    await tester.ensureVisible(find.text('Add Another Flashcard'));
    await tester.tap(find.text('Add Another Flashcard'));
    await tester.pumpAndSettle();

    expect(find.text('CARD 4'), findsOneWidget);
  });

  testWidgets('FlashcardsScreen displays flashcards, flips on tap, and allows navigating previous and next', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final questions = [
      Question(
        id: 'q1',
        topicId: 't1',
        subjectId: 's1',
        category: 'History',
        questionText: 'When was the Declaration of Independence adopted?',
        questionType: QuestionType.multipleChoice,
        difficulty: Difficulty.easy,
        explanation: 'Signed in Philadelphia',
        reference: '',
        choices: [
          QuestionChoice(
            id: 'c1',
            questionId: 'q1',
            choiceText: 'July 4, 1776',
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
        category: 'History',
        questionText: 'Who was the first president of the United States?',
        questionType: QuestionType.multipleChoice,
        difficulty: Difficulty.easy,
        explanation: 'Elected in 1789',
        reference: '',
        choices: [
          QuestionChoice(
            id: 'c2',
            questionId: 'q2',
            choiceText: 'George Washington',
            isCorrect: true,
            sortOrder: 0,
          ),
        ],
        points: 1,
      ),
    ];

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: FlashcardsScreen(questions: questions),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Front of Card 1
    expect(find.text('Flashcards Focus'), findsOneWidget);
    expect(find.text('QUESTION / FRONT'), findsOneWidget);
    expect(find.text('When was the Declaration of Independence adopted?'), findsOneWidget);

    // Tap card to flip
    await tester.tap(find.text('When was the Declaration of Independence adopted?'));
    await tester.pumpAndSettle();

    // Back of Card 1
    expect(find.text('ANSWER / BACK'), findsOneWidget);
    expect(find.text('July 4, 1776'), findsOneWidget);
    expect(find.text('Signed in Philadelphia'), findsOneWidget);

    // Tap Got It!
    await tester.tap(find.text('Got It!'));
    await tester.pumpAndSettle();

    // Now on Card 2
    expect(find.text('2/2'), findsOneWidget);
    expect(find.text('QUESTION / FRONT'), findsOneWidget);
    expect(find.text('Who was the first president of the United States?'), findsOneWidget);

    // Back button in AppBar should be present
    final backBtn = find.byIcon(Icons.arrow_back_ios_new);
    expect(backBtn, findsOneWidget);
    await tester.tap(backBtn);
    await tester.pumpAndSettle();

    // Back on Card 1
    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('When was the Declaration of Independence adopted?'), findsOneWidget);
  });

  testWidgets('MyLibraryScreen allows sharing a subject with unique code and opening restore dialog', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(examServiceProvider).seedDefaultExamsForTesting();
    await container.read(authControllerProvider.notifier).setUsername('Maria Santos');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: MyLibraryScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Restore Exam button exists in header card
    final restoreBtn = find.text('Restore Exam');
    expect(restoreBtn, findsOneWidget);

    // Tap Restore Exam to open restore dialog
    await tester.tap(restoreBtn);
    await tester.pumpAndSettle();

    expect(find.text('Restore Exam or Entire Subject'), findsOneWidget);
    expect(find.text('Enter a 6-character Exam Code (e.g. 4F9K2Q) or a Unique Subject Code (e.g. SUB-ENG-7K2M) to import all exams in that category:'), findsOneWidget);

    // Close restore dialog
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Find the Share Subject icon button on a subject card
    final shareSubjectBtn = find.byIcon(Icons.share_outlined);
    expect(shareSubjectBtn, findsWidgets);

    // Tap the first share button
    await tester.tap(shareSubjectBtn.first);
    await tester.pumpAndSettle();

    // Verify Share Subject dialog opens with unique code section
    expect(find.text('UNIQUE SUBJECT SHARE CODE'), findsOneWidget);
    expect(find.text('Guaranteed unique & conflict-free'), findsOneWidget);
    expect(find.text('Copy Code'), findsOneWidget);
    expect(find.text('Copy Bundle JSON'), findsOneWidget);

    // Close share dialog
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
  });
}

