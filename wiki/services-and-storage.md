# Services & Storage Layer

All service classes are located in [`lib/services/`](file:///c:/Users/j_ant/projects/quizz_app/lib/services/).

---

## 1. `LocalStorageService` (`lib/services/local_storage_service.dart`)

The primary offline persistence engine using `shared_preferences`.

### Storage Keys Reference
| Constant | SharedPreferences Key | Stored Content | Format |
| :--- | :--- | :--- | :--- |
| `_keyQuestions` | `'quizz_questions_v2'` | Offline Question Bank | JSON Array of `Question` objects |
| `_keyCustomSubjects` | `'quizz_custom_subjects_v2'` | User-created Subjects | JSON Array of `Subject` objects |
| `_keyProgress` | `'quizz_progress_v2'` | Question mastery & weak metrics | JSON Map of `questionId -> QuestionProgress` |
| `_keyHistory` | `'quizz_history_v2'` | Past completed quiz sessions | JSON Array of `QuizSession` metadata |
| `_keyCreatedExams` | `'quizz_created_exams_v2'` | Creator's created exams | JSON Array of `Exam` objects |
| `_keyCurrentUser` | `'quizz_current_user_v2'` | Active user profile | JSON Object of `UserModel` |
| `_keyUsersList` | `'quizz_users_list_v2'` | Saved user accounts for fast switching | JSON Array of `UserModel` |
| `_keySubjectBundles` | `'quizz_subject_bundles_v2'` | Custom imported question bundles | JSON Array of bundle records |

### Legacy Cleansing Mechanism
When loading questions via `loadQuestions()`, the service automatically filters out legacy mock IDs (`q_fil_1`, `q_fil_2`, `q_eng_1`, etc.) to prevent duplicate or conflicting sample data across app updates.

---

## 2. `SupabaseExamService` (`lib/services/supabase_exam_service.dart`)

Communicates with Supabase PostgreSQL.

### Core Methods
1. **`publishExam(Exam exam) -> Future<bool>`**:
   - Step 1: Upserts into `exams` table. Embeds `questionLimit` in description tag `<!--limit:X-->`.
   - Step 2: Deletes existing questions for this `exam_id` (ensuring clean state during edits).
   - Step 3: Inserts questions into `exam_questions`.
   - Step 4: Batch inserts choices into `exam_choices` and matching pairs into `exam_matching_pairs`.
2. **`getExamByCode(String code) -> Future<Exam?>`**:
   - Queries `exams` by uppercase code: `.eq('code', code.trim().toUpperCase())`.
   - Fetches nested `exam_questions(exam_choices(*), exam_matching_pairs(*))`.
   - Parses into an in-memory `Exam` object, reconstructing question orders and choices.
3. **`joinExam({examId, nickname, deviceToken}) -> Future<ExamParticipant?>`**:
   - Inserts record into `exam_participants` table with status `'inProgress'`.
4. **`submitExamResponses({participantId, examId, score, totalQuestions, responses}) -> Future<bool>`**:
   - Updates participant row: `score`, `total_questions`, `submitted_at = now()`, `status = 'submitted'`.
   - Inserts individual rows into `exam_participant_answers`.
5. **`fetchExamParticipants(String examId) -> Future<List<ExamParticipant>>`**:
   - Retrieves all participants for the maker's live dashboard.

---

## 3. `ExamService` Orchestrator (`lib/services/exam_service.dart`)

Inherits from `ChangeNotifier` and acts as the central coordinator between `LocalStorageService` and `SupabaseExamService`.
- **Hybrid Guarantee**:
  - Whenever an exam is published, it is pushed to Supabase **and** saved into local storage.
  - If a device is offline or Supabase fails, the exam remains 100% playable locally.
  - Join code lookups search local in-memory registry before falling back to remote Supabase queries.

---

## 4. `SeedDataService` (`lib/services/seed_data_service.dart`)

Provides initial out-of-the-box content for first launch:
- Standard subjects: Filipino, English, Mathematics, General Science, Civil Service / General Info.
- Sample questions spanning all 3 question types:
  - Multiple Choice with single correct answer.
  - True/False with explanations.
  - Matching Type pairs (e.g. Science terms and definitions).
