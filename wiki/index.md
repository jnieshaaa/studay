# StuDay (Quizz App) — LLM Wiki Index

> **LLM DIRECTIVE**: This wiki is the compiled single source of truth for the codebase. **DO NOT** read source code files from scratch or perform exhaustive multi-file scans. Check this index, open the specific wiki topic you need, and only view raw source files when performing surgical code edits.

---

## ⚡ Quick Architecture Overview

**StuDay** is a subject-agnostic Flutter & Dart study and exam platform with two distinct operational modes:

| Mode | Purpose | Engine / Connectivity | Primary State / Service |
| :--- | :--- | :--- | :--- |
| **Study Mode** | Personal flashcards, practice quizzes, timed mock exams, weak question drilling, and mistake replay | **Offline-First** via `SharedPreferences` (`LocalStorageService`) with offline question bank and mastery stats | `StudyController`, `QuizController`, `FlashcardController` |
| **Exam Mode** | Creator / Maker hosts exams with a 6-character code (`4F9K2Q`); participants join with zero account signup | **Online-First** via `Supabase` PostgreSQL (`SupabaseExamService`) with local backup fallback | `ExamMakerController`, `ExamParticipantController`, `ExamService` |

---

## 🗺️ Wiki Topic Map (Jump Directly to What You Need)

| Topic | Wiki File | When to Consult |
| :--- | :--- | :--- |
| **Architecture & Data Flow** | [`wiki/architecture.md`](file:///c:/Users/j_ant/projects/quizz_app/wiki/architecture.md) | Understanding offline vs online sync, boot lifecycle, Supabase config, and app structure. |
| **Data Models Reference** | [`wiki/data-models.md`](file:///c:/Users/j_ant/projects/quizz_app/wiki/data-models.md) | Inspecting fields, enums, JSON keys, and constructors for `Exam`, `Question`, `ExamParticipant`, etc. |
| **Database & Supabase Schema** | [`wiki/database-schema.md`](file:///c:/Users/j_ant/projects/quizz_app/wiki/database-schema.md) | Writing backend queries, RLS policies, table relations, or checking SQL definitions. |
| **State Management & Providers** | [`wiki/state-management.md`](file:///c:/Users/j_ant/projects/quizz_app/wiki/state-management.md) | Understanding Riverpod providers, StateNotifier/ChangeNotifier pattern, and state mutation flows. |
| **Routing & Screen Hierarchy** | [`wiki/routing-and-screens.md`](file:///c:/Users/j_ant/projects/quizz_app/wiki/routing-and-screens.md) | Navigating with `GoRouter`, screen parameters (`extra`, `pathParameters`), and widget trees. |
| **Services & Storage Layer** | [`wiki/services-and-storage.md`](file:///c:/Users/j_ant/projects/quizz_app/wiki/services-and-storage.md) | Inspecting `LocalStorageService` cache keys, `SupabaseConfig`, and seed data mechanisms. |
| **Exam Maker & Participant Flow** | [`wiki/exam-maker-flow.md`](file:///c:/Users/j_ant/projects/quizz_app/wiki/exam-maker-flow.md) | Modifying quiz creation, 6-char codes, bulk question parsing, question types, and scoring. |
| **Conventions, Styling & Testing** | [`wiki/conventions-and-testing.md`](file:///c:/Users/j_ant/projects/quizz_app/wiki/conventions-and-testing.md) | Code style, linter requirements, theme color tokens (`AppColors`), and test recipes. |

---

## 📂 Project Directory Structure

```text
quizz_app/
├── lib/
│   ├── core/
│   │   ├── config/        # SupabaseConfig, environment variable handling
│   │   ├── routes/        # appRouter (GoRouter configuration)
│   │   ├── theme/         # AppColors, AppTheme (Material 3 Dark/Light)
│   │   └── utils/         # BulkQuestionParser, CodeGenerator, Responsive utils
│   ├── controllers/       # Riverpod StateNotifiers & ChangeNotifier controllers
│   ├── models/            # Immutable models (Exam, Question, Subject, User, etc.)
│   ├── services/          # SupabaseExamService, LocalStorageService, SeedDataService
│   ├── views/
│   │   ├── components/    # Shared reusable UI widgets (cards, badges, modals)
│   │   └── screens/
│   │       ├── auth/      # UsernameSetupScreen (frictionless nickname login)
│   │       ├── exam/      # ExamMakerScreen, ExamJoinScreen, ExamPlayScreen, Dashboard
│   │       ├── home/      # HomeScreen (Maker hub & quick actions)
│   │       ├── library/   # MyLibraryScreen (Subject bundles & categories)
│   │       ├── splash/    # SplashScreen (App entrypoint & session resolver)
│   │       └── study/     # StudyHomeScreen, QuizPlayScreen, FlashcardsScreen
│   └── main.dart          # Entrypoint: SupabaseConfig.initialize() + ProviderScope
├── wiki/                  # <-- THIS LLM WIKI
├── supabase_tables.sql    # Clean SQL DDL for all 10 PostgreSQL tables
├── supabase_schema.sql    # Legacy schema with RLS and migration notes
└── pubspec.yaml           # Flutter 3.9+, Riverpod, GoRouter, Supabase
```

---

## 🔄 LLM Wiki Maintenance Protocol

1. **Read First**: Whenever prompted about a feature, bug, or design, read the matching page in `wiki/`.
2. **Surgical Inspection**: Only read raw `.dart` files if you need exact line numbers for `replace_file_content`.
3. **Compile-Time Update**: If your edits add a new model field, provider, route, or table column, update the relevant file in `wiki/` before finishing your response.
