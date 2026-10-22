# System Architecture

## 1. High-Level Concept

**StuDay** solves two distinct problems in one unified application:
1. **Study Mode (Personal, Offline-First)**: A private study engine where learners can review flashcards, take practice quizzes, drill weak questions, and track subject mastery without needing any internet connection.
2. **Exam Mode (Shared, Maker-Hosted)**: A frictionless exam distribution engine where a maker/creator creates an exam with multiple sections and question types, and generates a 6-character code (e.g. `4F9K2Q`). Participants take the exam on their devices without creating an account.

```text
┌─────────────────────────────────────────────────────────────┐
│                       StuDay App Layer                      │
├──────────────────────────────┬──────────────────────────────┤
│       STUDY MODE             │          EXAM MODE           │
│   (Personal Mastery)         │     (Maker & Join Code)      │
├──────────────────────────────┼──────────────────────────────┤
│ • Flashcards                 │ • Exam Creator (Maker)       │
│ • Practice Quiz (untimed)    │ • 6-Char Join Code Flow      │
│ • Quick Quiz (5 mins)        │ • Anonymous Participant Join │
│ • Timed Quiz / Mock Exam     │ • Live Dashboard / Feed      │
│ • Mistakes & Weak Drill      │ • Question Limit & Shuffling │
├──────────────────────────────┼──────────────────────────────┤
│    LocalStorageService       │     SupabaseExamService      │
│     (SharedPreferences)      │    (PostgreSQL + Realtime)   │
│                              │              ▲               │
│                              │    (Fallback to Local)       │
└──────────────────────────────┴──────────────────────────────┘
```

---

## 2. Boot Lifecycle & Initialization Sequence

The application boot sequence in `lib/main.dart` executes as follows:

```text
main()
  │
  ├── 1. WidgetsFlutterBinding.ensureInitialized()
  │
  ├── 2. SupabaseConfig.initialize()
  │       ├── Loads `.env` file via flutter_dotenv
  │       ├── Checks SUPABASE_URL & SUPABASE_ANON_KEY (fallback to defaults)
  │       └── Initializes Supabase client if configured (non-fatal if offline/missing)
  │
  └── 3. runApp(ProviderScope(child: QuizzApp()))
          │
          └── MaterialApp.router -> GoRouter initialLocation: '/splash'
```

### Splash Screen Resolution (`/splash`):
1. `SplashScreen` reads `AuthController` (`authControllerProvider`).
2. `AuthController.loadActiveSession()` queries `LocalStorageService.loadCurrentUser()`.
3. If an existing `UserModel` is found:
   - Sets state `currentUser`.
   - Routes automatically to `/` (Home Screen).
4. If no user is logged in:
   - Routes to `/setup-username` (Frictionless display name setup).

---

## 3. The Dual-Engine Data Strategy

### Study Mode (Offline-First)
- **Engine**: `LocalStorageService` utilizing `shared_preferences`.
- **Data Cached**:
  - Offline Question Bank: Key `quizz_questions_v2`
  - Custom Subjects & Categories: Key `quizz_custom_subjects_v2`
  - Question Progress & Weak Metrics: Key `quizz_progress_v2`
  - Completed Quiz Session History: Key `quizz_history_v2`
  - Created Exam Cache: Key `quizz_created_exams_v2`
  - Active User Profile: Key `quizz_current_user_v2`
- **Resilience**: The app pre-populates with default seed data from `SeedDataService` if local storage is empty.

### Exam Mode (Online-First with Local Cache Fallback)
- **Engine**: `SupabaseExamService` communicating with Supabase PostgreSQL via the official `supabase_flutter` SDK.
- **Publishing an Exam**:
  1. Maker taps "Publish" in `ExamMakerScreen`.
  2. `ExamMakerController.publishExam()` calls `ExamService.publishExam()`.
  3. `ExamService` pushes data to `SupabaseExamService.publishExam()`.
  4. At the same time, `ExamService` stores the exam in `LocalStorageService.saveCreatedExams()`.
  5. Even if the Supabase network call fails, the exam is safely cached locally and marked active.
- **Joining an Exam**:
  1. Participant enters 6-character code (e.g. `4F9K2Q`) in `ExamJoinScreen`.
  2. `ExamService.getExamByCode(code)` first checks local in-memory/cache.
  3. If not found locally, calls `SupabaseExamService.getExamByCode(code)`.
  4. Returns the validated `Exam` object with questions, choices, and matching pairs.

---

## 4. Configuration Management (`lib/core/config/supabase_config.dart`)

- **Configuration Source Hierarchy**:
  1. `.env` file variables (`SUPABASE_URL`, `SUPABASE_ANON_KEY`).
  2. `--dart-define` compilation flags (`SUPABASE_URL`, `SUPABASE_ANON_KEY`).
  3. Built-in fallback constants (`_defaultUrl`, `_defaultAnonKey`).
- **Safety**:
  `SupabaseConfig.isConfigured` checks if the URL starts with `http` and does not contain dummy placeholders like `your-project`.
  If unconfigured or offline, `SupabaseConfig.client` gracefully returns `null`, preventing crash loops.
