# State Management & Riverpod Providers

The project uses **Flutter Riverpod** (`flutter_riverpod`). Controllers inherit from either `StateNotifier<T>` for immutable state graphs or `ChangeNotifier` for multi-subscriber service registries.

---

## 1. Provider Registry Table

| Provider | Type | File | Description |
| :--- | :--- | :--- | :--- |
| `localStorageServiceProvider` | `Provider<LocalStorageService>` | `controllers/providers.dart` | Local SharedPreferences singleton access. |
| `supabaseExamServiceProvider` | `Provider<SupabaseExamService>` | `controllers/providers.dart` | Supabase remote backend client service. |
| `examServiceProvider` | `ChangeNotifierProvider<ExamService>` | `controllers/providers.dart` | Primary orchestrator for exam creation, code registry, and live participant feeds. |
| `authControllerProvider` | `StateNotifierProvider<AuthController, AuthState>` | `controllers/auth_controller.dart` | Frictionless username authentication, active creator profile, session caching. |
| `studyControllerProvider` | `StateNotifierProvider<StudyController, StudyState>` | `controllers/study_controller.dart` | Study mode catalog: subjects, topics, question bank, bookmarks, weak question metrics. |
| `examMakerControllerProvider` | `StateNotifierProvider<ExamMakerController, ExamMakerState>` | `controllers/exam_maker_controller.dart` | Form state for building/editing exams, adding questions, setting timers, and publishing. |
| `examParticipantControllerProvider` | `StateNotifierProvider.autoDispose.family<ExamParticipantController, ExamParticipantPlayState, ExamParticipantParam>` | `controllers/exam_participant_controller.dart` | Handles taking an exam: answering MCQ, True/False, Matching, timer countdown, submission. |
| `quizControllerProvider` | `StateNotifierProvider.autoDispose.family<QuizController, QuizPlayState, QuizSession>` | `controllers/quiz_controller.dart` | Manages active practice quizzes, instant answer feedback, scoring, and history logging. |
| `flashcardControllerProvider` | `StateNotifierProvider.autoDispose.family<FlashcardController, FlashcardState, List<Question>>` | `controllers/flashcard_controller.dart` | Flashcard deck flipping, confidence ratings (Again/Hard/Good/Easy), progress tracking. |

---

## 2. Controller Breakdown & Responsibilities

### 1. `AuthController` (`AuthState`)
- **State**: `currentUser` (`UserModel?`), `isLoading` (`bool`), `errorMessage` (`String?`).
- **Methods**:
  - `loadActiveSession()`: Checks `LocalStorageService.loadCurrentUser()`.
  - `setUsername(String username)`: Creates or updates local `UserModel` with display name.
  - `loginAsDemoCreator()`: Instantly populates with sample creator profile (`Maria Santos`) for rapid testing.
  - `logout()`: Clears active session in `LocalStorageService`.

### 2. `ExamService` (ChangeNotifier)
- Acts as a bridge between local storage and Supabase remote storage.
- Maintains in-memory caches:
  - `_examsById`: `Map<String, Exam>`
  - `_examsByCode`: `Map<String, Exam>` (lookup by 6-char code)
  - `_participantsByExam`: `Map<String, List<ExamParticipant>>`
  - `_responsesByExam`: `Map<String, List<ExamResponse>>`
- Key Methods:
  - `publishExam(Exam exam)`: Pushes to Supabase and saves locally.
  - `getExamByCode(String code)`: Queries local cache first, then Supabase.
  - `joinExam({code, nickname, deviceToken})`: Registers participant session.
  - `submitExamResponses(...)`: Saves responses, scores, and updates participant status.
  - `watchExamParticipants(String examId)`: Provides live list of participants.

### 3. `ExamMakerController` (`ExamMakerState`)
- **State**: `title`, `subject`, `description`, `questions`, `questionOrder`, `choiceOrder`, `showAnswers`, `maxAttempts`, `durationMinutes`, `questionLimit`, `closesAt`, `sectionOrder`, `isPublishing`, `editingExamId`.
- **Methods**:
  - `initForNewExam()`: Resets builder to pristine state with a fresh 6-character code.
  - `initForEdit(Exam exam)`: Pre-populates all fields to edit an existing exam.
  - `addQuestion(Question q)` / `updateQuestion(int index, Question q)` / `deleteQuestion(int index)`.
  - `reorderSections(List<QuestionType> newOrder)`.
  - `publishExam()`: Validates inputs and triggers `ExamService.publishExam()`.

### 4. `ExamParticipantController` (`ExamParticipantPlayState`)
- **State**: `exam`, `participant`, `currentIndex`, `selectedChoices` (`Map<questionId, choiceId>`), `matchingAnswers` (`Map<questionId, Map<left, right>>`), `activeMatchingLeft`, `isSubmitting`, `submissionResult`.
- **Methods**:
  - `selectChoice(String choiceId)`: Selects option for MCQ or True/False.
  - `selectMatchingLeft(String left)` & `selectMatchingRight(String right)`: Pairs premise to match.
  - `nextQuestion()` & `previousQuestion()`.
  - `submitExam()`: Evaluates correctness of all questions, calculates total points, logs responses to `ExamService`.

### 5. `StudyController` (`StudyState`)
- **State**: `subjects`, `topics`, `questions`, `progressMap`, `selectedSubjectId`, `selectedTopicId`.
- **Derived Getters**: `filteredQuestions`, `bookmarkedQuestions`, `weakQuestions`, `mistakeQuestions`.
- **Methods**:
  - `toggleBookmark(String questionId)`.
  - `recordQuestionResult({questionId, isCorrect})`: Updates `QuestionProgress` (attempts, correct, wrong, accuracy).
  - `createCustomSubject(...)` & `importQuestions(...)`.
