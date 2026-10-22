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
| `/library` | `MyLibraryScreen` | `views/screens/library/my_library_screen.dart` | None. Subject categories, personal decks, custom packs. |
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
- **`ExamDashboardScreen`**:
  - Realtime maker monitoring view.
  - Summary stats: Participant count, average score, pass rate, highest/lowest scores.
  - Tabular roster of participants with timestamp and score breakdown.
