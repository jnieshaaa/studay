# Routing & Screen Navigation

Navigation in StuDay is powered by **GoRouter** (`go_router`), configured in [`lib/core/routes/app_router.dart`](file:///c:/Users/j_ant/projects/quizz_app/lib/core/routes/app_router.dart).

---

## 1. Route Map & Parameters

| Path | Screen Widget | File Location | Route Parameters / Extra |
| :--- | :--- | :--- | :--- |
| `/splash` | `SplashScreen` | `views/screens/splash/splash_screen.dart` | None. Initial location. Resolves auth state. |
| `/setup-username` | `UsernameSetupScreen` | `views/screens/auth/username_setup_screen.dart` | None. Frictionless nickname creation. |
| `/login` | `UsernameSetupScreen` | `views/screens/auth/username_setup_screen.dart` | Alias for `/setup-username`. |
| `/` | `HomeScreen` | `views/screens/home/home_screen.dart` | None. Main Creator hub with Study & Exam entry cards. |
| `/library` | `MyLibraryScreen` | `views/screens/library/my_library_screen.dart` | None. Clickable subject cards, Restore Exam, creator hub. |
| `/library/subject` | `SubjectQuizzesScreen` | `views/screens/library/subject_quizzes_screen.dart` | `extra: String` (clicked subject name). Quizzes & creator controls. |
| `/study` | `StudyHomeScreen` | `views/screens/study/study_home_screen.dart` | None. Study mode selector (Practice, Flashcards, Weak Drill). |
| `/study/quiz` | `QuizPlayScreen` | `views/screens/study/quiz_play_screen.dart` | `extra: QuizSession` |
| `/study/result` | `QuizResultScreen` | `views/screens/study/quiz_result_screen.dart` | `extra: QuizSession` |
| `/study/flashcards` | `FlashcardsScreen` | `views/screens/study/flashcards_screen.dart` | `extra: List<Question>` |
| `/study/weak-questions` | `WeakQuestionsScreen` | `views/screens/study/weak_questions_screen.dart` | None. Loads weak questions from `StudyController`. |
| `/exam` | `ExamHomeScreen` | `views/screens/exam/exam_home_screen.dart` | None. Exam Mode hub (Join Exam vs Host/Create Exam). |
| `/exam/join` | `ExamJoinScreen` | `views/screens/exam/exam_join_screen.dart` | `extra: String?` (optional initial 6-character code). |
| `/exam/maker` | `ExamMakerScreen` | `views/screens/exam/exam_maker_screen.dart` | `extra: Exam?` (optional initial exam for edit mode). |
| `/exam/play` | `ExamPlayScreen` | `views/screens/exam/exam_play_screen.dart` | `extra: ExamParticipantParam` (contains `exam`, `participant`). |
| `/exam/result` | `ExamParticipantResultScreen` | `views/screens/exam/exam_participant_result_screen.dart` | `extra: ExamResultParam` (contains `exam`, `participant`, `responses`). |
| `/exam/dashboard/:id` | `ExamDashboardScreen` | `views/screens/exam/exam_dashboard_screen.dart` | `pathParameters['id']`: ID of the exam to monitor. |

---

## 2. Navigating with GoRouter Code Examples

### Moving to Study Practice Quiz
```dart
final session = QuizSession(
  id: 'session_${DateTime.now().millisecondsSinceEpoch}',
  mode: StudyMode.practice,
  questions: questions,
  startedAt: DateTime.now(),
);
context.push('/study/quiz', extra: session);
```

### Joining an Exam and Playing
```dart
// Join Screen after verifying 6-char code
final participant = await examService.joinExam(
  code: '4F9K2Q',
  nickname: 'Alex',
  deviceToken: 'dev_123',
);
final param = ExamParticipantParam(exam: exam, participant: participant);
context.pushReplacement('/exam/play', extra: param);
```

### Opening Creator Exam Dashboard
```dart
context.push('/exam/dashboard/${exam.id}');
```

---

## 3. Screen Structure & Responsibilities

- **`HomeScreen`**:
  - Top bar shows active creator greeting and quick switch profile.
  - Quick action buttons: "Start Studying", "Join Exam with Code", "Host/Create Exam".
  - Displays recent exams created by the user and overall study streak.
- **`ExamMakerScreen`**:
  - Full-featured exam builder with live section reordering (`ReorderableListView`).
  - Section dividers for Multiple Choice, True/False, and Matching Type.
  - Floating action button to invoke `BulkImportQuestionsDialog`.
  - Settings sheet for timer, question limits, answer visibility, and scheduling.
- **`ExamPlayScreen`**:
  - Self-paced exam taker interface.
  - Interactive choice selector for MCQ / True-False and premise-target connector for Matching questions.
  - Auto-submits on timer expiration if `durationMinutes` is active.
- **`FlashcardsScreen`**:
  - Accepts `FlashcardArgs(questions, mode)` / `initialMode: FlashcardStudyMode` without mid-session tab switching to keep learners fully focused on their chosen mode:
    1. **Card Flip Review**: Interactive 3D flip card (front question / back answer) with "Still Learning" and "Got It!" mastery buttons.
    2. **Type-in Quiz (Active Recall)**: Displays question prompt with text box where learner types what is on the back of the card. Evaluates answer, highlights correct answer if wrong, and includes a **"Pass"** button to allow skipping without typing.
  - Deck completion screen includes replay options in the same mode or switching to the alternative mode.
- **`StudyHomeScreen`**:
  - Clean dropdown filter using `'__ALL__'` sentinel string, allowing immediate and reliable re-selection of "All Subjects".
  - Shows outside mode buttons directly on flashcard deck cards: **"Flip Cards"** (Review) and **"Type Quiz"** (Active Recall).
  - Regular exams strictly show **"Practice"** and **"Take Quiz"** (all flashcard options removed from exams).
- **`MyLibraryScreen`**:
  - Replaced inline expandable accordion cards with clean, dedicated **clickable subject cards**.
  - Clicking any subject card navigates to `SubjectQuizzesScreen` with the clicked subject name as parameter.
  - Features full-width dropdown filter for "All Subjects" (`'__ALL__'`), "Restore Exam", and "New Quiz" creator controls.
- **`SubjectQuizzesScreen`**:
  - Dedicated screen displaying all quizzes, flashcard decks, and questions under the selected subject.
  - Responsive header banner wrapped in `LayoutBuilder`: wraps the "+ Add to Subject" action button under the title on viewports `< 460px` to prevent `RenderFlex` overflow, and wraps the subject title in `Flexible` with `TextOverflow.ellipsis`.
  - Clean card layout:
    - Top header: Quiz index, title, status badges (`LIVE`/`STOPPED`, `CODE`, `FLASHCARDS`), and a sleek **three-vertical-dots (`⋮`) menu** containing: **Edit**, **Stats** (Analytics Dashboard), **Backup** (JSON copy), and **Delete**.
    - **Smart Edit Action**: Selecting "Edit" checks `quiz.isFlashcardDeck`. If it is a flashcard deck, it opens `CreateFlashcardSheet(existingDeck: quiz)` for in-place deck editing; otherwise, it opens `ExamMakerScreen`.
    - Configuration pills: Questions count, Question Sampling limit modal, Timer modal, and Schedule modal.
    - Action row: Primary buttons only — **Start/Stop** live toggle and **Take Quiz** (or **Flip Cards** & **Type Quiz** for decks).
  - Subject actions: "+ Add to Subject" (presents bottom sheet to choose between "Exam / Quiz" and "Flashcard Deck") and "Share Entire Subject" by unique code.
- **`CreateFlashcardSheet`**:
  - Bottom sheet modal supporting both **creation** and **editing** (`existingDeck: Exam?`) of flashcard decks.
  - In edit mode, auto-populates title, subject, sampling limit, and flashcard draft items (front, back, hint).
  - Saving in edit mode updates the deck via `examService.updateExam(updated)`, preserving original ID, 6-character code, and owner attribution.
