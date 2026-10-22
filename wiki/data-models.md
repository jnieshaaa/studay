# Data Models Reference

All domain models are located in `lib/models/`. They are immutable and implement `toJson()` and `fromJson()` factories.

---

## 1. Exam Models (`lib/models/exam_model.dart`)

### Enums
- `ExamStatus`: `draft`, `published`, `closed`.
- `QuestionOrder`: `fixed`, `shuffled`.
- `ChoiceOrder`: `fixed`, `shuffled`.
- `ShowAnswersMode`: `immediately` (upon submit), `afterClose` (deadline passed), `never` (maker only).

### `Exam` Class
The core container for maker-hosted tests.

| Field | Type | Description |
| :--- | :--- | :--- |
| `id` | `String` | Unique ID (e.g. `exam_1728394`) |
| `creatorId` | `String` | User ID of the exam creator |
| `title` | `String` | Display title of the exam |
| `subject` | `String` | Subject category (default: `'General Knowledge'`) |
| `description` | `String` | Overview or instructions (may embed metadata like `<!--limit:20-->`) |
| `code` | `String` | Unique 6-character uppercase alphanumeric code (e.g. `'4F9K2Q'`) |
| `status` | `ExamStatus` | Default: `ExamStatus.draft` |
| `questionOrder`| `QuestionOrder` | Default: `QuestionOrder.shuffled` |
| `choiceOrder` | `ChoiceOrder` | Default: `ChoiceOrder.shuffled` |
| `showAnswers` | `ShowAnswersMode` | When participants can see explanations and right answers |
| `opensAt` | `DateTime?` | Optional start window |
| `closesAt` | `DateTime?` | Optional closing deadline |
| `maxAttemptsPerParticipant` | `int` | Default: `1` |
| `durationMinutes` | `int?` | Timer limit in minutes (`null` = untimed) |
| `questionLimit`| `int?` | Limit items displayed to participants (e.g. show 20 random out of 100) |
| `sectionOrder` | `List<QuestionType>` | Ordering of question types: `[multipleChoice, trueFalse, matching]` |
| `questions` | `List<Question>` | Nested list of questions |
| `createdAt` | `DateTime` | Creation timestamp |

### Key Getters
- `effectiveSubject`: Returns subject or `'General Knowledge'` if empty.
- `durationLabel`: Returns `'Untimed'` or `'${durationMinutes}m'`.
- `isExpired`: Returns `true` if `status == ExamStatus.closed` or `DateTime.now().isAfter(closesAt)`.
- `isScheduled`: Returns `true` if `opensAt != null || closesAt != null`.
- `cleanDescription`: Strips `<!--limit:X-->` and `<!--type:flashcard-->` metadata tags.
- `isFlashcardDeck`: Returns `true` if tagged with `<!--type:flashcard-->`, named with flashcard keyword, or questions are single-choice flashcards.

---

## 2. Question Models (`lib/models/question_model.dart`)

### Enums
- `QuestionType`: `multipleChoice`, `trueFalse`, `matching`.
- `Difficulty`: `easy`, `medium`, `hard`.

### `Question` Class
Reusable across both personal Study Mode and Exam Mode.

| Field | Type | Description |
| :--- | :--- | :--- |
| `id` | `String` | Unique question ID (e.g. `q_bio_1`) |
| `topicId` | `String` | Topic reference (default: `'custom'`) |
| `subjectId` | `String` | Subject reference (default: `'custom'`) |
| `category` | `String?` | Display category name (e.g. `'General Science'`) |
| `questionText` | `String` | Question statement |
| `questionType` | `QuestionType` | MCQ, True/False, or Matching |
| `difficulty` | `Difficulty` | Default: `Difficulty.medium` |
| `explanation` | `String` | Post-answer rationale / learning note |
| `reference` | `String` | Citation, book page, or syllabus link |
| `choices` | `List<QuestionChoice>`| Options for MCQ and True/False |
| `matchingPairs`| `List<MatchingPair>` | Prompts & answers for Matching Type |
| `sortOrder` | `int` | Display order (within part/section) |
| `isBookmarked` | `bool` | User starred flag (Study Mode) |
| `points` | `int` | Point weight (default: `1`) |

### Sub-objects
- **`QuestionChoice`**:
  `id`, `questionId`, `choiceText`, `isCorrect` (`bool`), `sortOrder` (`int`).
- **`MatchingPair`**:
  `id`, `questionId`, `leftText` (prompt / term), `rightText` (target definition / match).

---

## 3. Participant & Response Models (`lib/models/exam_participant_model.dart`)

### `ExamParticipant`
Represents an anonymous or registered taker who joined via code.

| Field | Type | Description |
| :--- | :--- | :--- |
| `id` | `String` | Unique participant session ID (e.g. `part_1728394_ab12`) |
| `examId` | `String` | ID of the exam joined |
| `nickname` | `String` | Participant's chosen display name |
| `deviceToken` | `String` | Anonymous device identifier for duplicate prevention |
| `joinedAt` | `DateTime` | Join timestamp |
| `submittedAt`| `DateTime?` | Submission timestamp (`null` if in progress) |
| `score` | `int` | Total score earned |
| `totalQuestions` | `int` | Total question count |
| `status` | `ParticipantStatus` | `inProgress` or `submitted` |

### `ExamResponse`
Individual question response submitted by a participant.

| Field | Type | Description |
| :--- | :--- | :--- |
| `id` | `String` | Unique response ID |
| `participantId` | `String` | Participant reference |
| `questionId` | `String` | Question reference |
| `selectedChoiceId` | `String?` | Selected choice ID (MCQ & True/False) |
| `matchingResponse` | `Map<String, String>` | Map of `leftText -> selected rightText` |
| `isCorrect` | `bool` | Automated grading result |
| `timeSpent` | `int` | Seconds spent on this question |

---

## 4. Study & Progress Models

### `QuizSession` (`lib/models/quiz_session_model.dart`)
Tracks an active or completed practice session.
- `StudyMode`: `practice`, `quickQuiz`, `timedQuiz`, `mockExam`, `mistakesReview`, `bookmarked`, `weakQuestions`.
- `QuizAnswer`: `questionId`, `selectedChoiceId`, `matchingAnswers` (`Map<String, String>`), `isCorrect`, `timeSpentSeconds`.

### `QuestionProgress` (`lib/models/user_progress_model.dart`)
- `attempts`, `correctCount`, `wrongCount`, `isBookmarked`, `lastAnsweredAt`.
- `accuracy`: `(correctCount / attempts) * 100`.
- `isWeak`: `attempts >= 1 && accuracy < 65.0`.

### `Subject` & `Topic` (`lib/models/subject_model.dart`)
- `Subject`: `id`, `name`, `description`, `icon`, `sortOrder`, `isActive`.
- `Topic`: `id`, `subjectId`, `name`, `description`, `sortOrder`.

### `UserModel` (`lib/models/user_model.dart`)
- `id`, `name`, `email`, `createdAt`, `createdExamIds` (`List<String>`), `savedSubjectIds` (`List<String>`).

### Flashcard Deck & Study Modes (`lib/views/screens/study/flashcards_screen.dart`)
- `FlashcardStudyMode`: `review` (flip card 3D), `quiz` (type-in recall).
- `FlashcardArgs`: `questions: List<Question>`, `mode: FlashcardStudyMode` (used for passing chosen mode from outside deck cards).
