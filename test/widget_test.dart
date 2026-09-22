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
import 'package:quizz_app/controllers/auth_controller.dart';
import 'package:quizz_app/controllers/exam_maker_controller.dart';

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

    // Verify a quiz tile inside a subject card is visible initially
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

    // Test Collapsible Subject Cards: tap dropdown button on Filipino
    final hideDropdownBtn = find.byTooltip('Hide quizzes').first;
    await tester.ensureVisible(hideDropdownBtn);
    await tester.tap(hideDropdownBtn);
    await tester.pumpAndSettle();

    // Filipino quizzes should now be hidden
    expect(find.text('1 quiz hidden • Tap to view or manage'), findsOneWidget);

    // Tap to expand again
    final showDropdownBtn = find.byTooltip('Show quizzes').first;
    await tester.ensureVisible(showDropdownBtn);
    await tester.tap(showDropdownBtn);
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
    expect(find.textContaining('PART 1'), findsWidgets);
    expect(find.textContaining('PART 2'), findsWidgets);
    expect(find.textContaining('PART 3'), findsWidgets);

    // Verify creator can change starting section to Matching Type
    final matchingChip = find.widgetWithText(ChoiceChip, 'Matching Type');
    expect(matchingChip, findsOneWidget);
    await tester.tap(matchingChip);
    await tester.pumpAndSettle();

    // Verify state updated to have Matching Type first
    expect(container.read(examMakerControllerProvider).sectionOrder.first.label, 'Matching Type');
    expect(find.text('Starts with: Matching Type'), findsOneWidget);

    // Verify Import Bank is absent
    expect(find.text('Import Bank'), findsNothing);

    // Tap Add Matching button
    final addMatchingBtn = find.text('Add Matching');
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
}
