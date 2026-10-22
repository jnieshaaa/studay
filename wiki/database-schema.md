# Database & Supabase Schema

The project uses Supabase PostgreSQL. The canonical schema is defined in [`supabase_tables.sql`](file:///c:/Users/j_ant/projects/quizz_app/supabase_tables.sql).

---

## 1. Table Definitions & Relationships

```text
users (id) ──< exams (creator_id)
                 │
                 ├──< exam_questions (exam_id)
                 │       ├──< exam_choices (question_id)
                 │       └──< exam_matching_pairs (question_id)
                 │
                 └──< exam_participants (exam_id)
                         └──< exam_participant_answers (participant_id)

subjects (id) ──< topics (subject_id)
```

---

## 2. Table Specifications

### 1. `public.users`
Accounts / Exam creators.
- `id` (`TEXT PRIMARY KEY`): User identifier (e.g. `'usr_123'`).
- `name` (`TEXT NOT NULL`): Display name.
- `email` (`TEXT NOT NULL DEFAULT ''`): Email address.
- `created_exam_ids` (`JSONB NOT NULL DEFAULT '[]'`): Array of owned exam IDs.
- `saved_subject_ids` (`JSONB NOT NULL DEFAULT '[]'`): Array of bookmarked subject IDs.
- `created_at` (`TIMESTAMPTZ NOT NULL DEFAULT NOW()`).

### 2. `public.subjects` & 3. `public.topics`
Curriculum hierarchy for question organization.
- `subjects`: `id` (`TEXT PRIMARY KEY`), `name`, `description`, `icon`, `sort_order`, `is_active`, `created_at`.
- `topics`: `id` (`TEXT PRIMARY KEY`), `subject_id` (`TEXT NOT NULL REFERENCES subjects(id) ON DELETE CASCADE`), `name`, `description`, `sort_order`.

### 4. `public.exams`
Maker-created examinations.
- `id` (`TEXT PRIMARY KEY`): e.g. `'exam_1728394'`.
- `creator_id` (`TEXT NOT NULL`): Creator's user ID.
- `title` (`TEXT NOT NULL`): Exam title.
- `subject` (`TEXT NOT NULL DEFAULT 'General Knowledge'`).
- `description` (`TEXT NOT NULL DEFAULT ''`): Optional metadata comments like `<!--limit:20-->`.
- `code` (`TEXT NOT NULL UNIQUE`): 6-character alphanumeric join code (e.g. `'4F9K2Q'`).
- `status` (`TEXT NOT NULL DEFAULT 'published'`): `'draft'`, `'published'`, or `'closed'`.
- `question_order` (`TEXT NOT NULL DEFAULT 'shuffled'`): `'fixed'` or `'shuffled'`.
- `choice_order` (`TEXT NOT NULL DEFAULT 'shuffled'`): `'fixed'` or `'shuffled'`.
- `show_answers` (`TEXT NOT NULL DEFAULT 'immediately'`): `'immediately'`, `'afterClose'`, `'never'`.
- `opens_at` (`TIMESTAMPTZ`): Optional start time.
- `closes_at` (`TIMESTAMPTZ`): Optional deadline time.
- `max_attempts_per_participant` (`INTEGER NOT NULL DEFAULT 1`).
- `duration_minutes` (`INTEGER`): Timer limit in minutes (`NULL` = untimed).
- `section_order` (`JSONB NOT NULL DEFAULT '["multipleChoice", "trueFalse", "matching"]'`).
- `created_at`, `updated_at` (`TIMESTAMPTZ`).

### 5. `public.exam_questions`
Questions attached to an exam.
- `id` (`TEXT PRIMARY KEY`): e.g. `'q_12345'`.
- `exam_id` (`TEXT NOT NULL REFERENCES exams(id) ON DELETE CASCADE`).
- `topic_id`, `subject_id`, `category` (`TEXT`).
- `question_text` (`TEXT NOT NULL`).
- `question_type` (`TEXT NOT NULL`): `'multipleChoice'`, `'trueFalse'`, or `'matching'`.
- `difficulty` (`TEXT DEFAULT 'medium'`).
- `explanation`, `reference` (`TEXT DEFAULT ''`).
- `sort_order` (`INTEGER NOT NULL DEFAULT 0`).
- `points` (`INTEGER NOT NULL DEFAULT 1`).
- `created_at` (`TIMESTAMPTZ`).

### 6. `public.exam_choices`
Options for Multiple Choice and True/False questions.
- `id` (`TEXT PRIMARY KEY`): Choice ID.
- `question_id` (`TEXT NOT NULL REFERENCES exam_questions(id) ON DELETE CASCADE`).
- `choice_text` (`TEXT NOT NULL`).
- `is_correct` (`BOOLEAN NOT NULL DEFAULT FALSE`).
- `sort_order` (`INTEGER NOT NULL DEFAULT 0`).

### 7. `public.exam_matching_pairs`
Matching premise-response pairs.
- `id` (`TEXT PRIMARY KEY`).
- `question_id` (`TEXT NOT NULL REFERENCES exam_questions(id) ON DELETE CASCADE`).
- `left_text` (`TEXT NOT NULL`).
- `right_text` (`TEXT NOT NULL`).

### 8. `public.exam_participants`
Participants who joined an exam session.
- `id` (`TEXT PRIMARY KEY`): e.g. `'part_12345'`.
- `exam_id` (`TEXT NOT NULL REFERENCES exams(id) ON DELETE CASCADE`).
- `nickname` (`TEXT NOT NULL`).
- `device_token` (`TEXT NOT NULL`).
- `status` (`TEXT NOT NULL DEFAULT 'inProgress'`): `'inProgress'` or `'submitted'`.
- `score` (`INTEGER NOT NULL DEFAULT 0`).
- `total_questions` (`INTEGER NOT NULL DEFAULT 0`).
- `joined_at` (`TIMESTAMPTZ NOT NULL DEFAULT NOW()`).
- `submitted_at` (`TIMESTAMPTZ`).

### 9. `public.exam_participant_answers`
Answers logged for each question by participants.
- `id` (`TEXT PRIMARY KEY`).
- `participant_id` (`TEXT NOT NULL REFERENCES exam_participants(id) ON DELETE CASCADE`).
- `question_id` (`TEXT NOT NULL REFERENCES exam_questions(id) ON DELETE CASCADE`).
- `selected_choice_id` (`TEXT`).
- `matching_response` (`JSONB NOT NULL DEFAULT '{}'`).
- `is_correct` (`BOOLEAN NOT NULL DEFAULT FALSE`).
- `time_spent_seconds` (`INTEGER NOT NULL DEFAULT 0`).

### 10. `public.exam_analytics`
Pre-aggregated rollups for instant maker dashboards.
- `exam_id` (`TEXT PRIMARY KEY REFERENCES exams(id) ON DELETE CASCADE`).
- `total_participants` (`INTEGER DEFAULT 0`).
- `completed_participants` (`INTEGER DEFAULT 0`).
- `average_score` (`NUMERIC(5,2) DEFAULT 0.00`).
- `highest_score`, `lowest_score` (`INTEGER DEFAULT 0`).
- `question_breakdown` (`JSONB DEFAULT '{}'`).
- `updated_at` (`TIMESTAMPTZ DEFAULT NOW()`).

---

## 3. High-Performance Indexes

The following indexes are applied in PostgreSQL for sub-millisecond lookups:
- `idx_exams_code`: `exams(UPPER(code))` — Instant join-code lookup.
- `idx_exams_creator`: `exams(creator_id)` — Creator exam listing.
- `idx_exam_questions_exam_id`: `exam_questions(exam_id)`.
- `idx_exam_choices_question_id`: `exam_choices(question_id)`.
- `idx_exam_matching_pairs_question_id`: `exam_matching_pairs(question_id)`.
- `idx_exam_participants_exam_id`: `exam_participants(exam_id)`.
- `idx_exam_participant_answers_participant_id`: `exam_participant_answers(participant_id)`.

---

## 4. Row Level Security (RLS) Policy Design

- **Exams**:
  - `SELECT`: Public access (anyone with the 6-character code can view published exams).
  - `INSERT / UPDATE / DELETE`: Creator only (matched by `creator_id`).
- **Participants**:
  - `INSERT`: Open to public (anonymous join flow with device token).
  - `UPDATE`: Owner or maker.
  - `SELECT`: Maker of the exam and the participant themselves.
- **Participant Answers**:
  - `INSERT`: Open to participant.
  - `SELECT`: Maker can review all answers; participant can review their own.
