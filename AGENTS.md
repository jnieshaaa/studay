# StuDay (Quizz App) — Agent & LLM Guidelines

> **CRITICAL DIRECTIVE FOR ALL LLMS AND AGENTS**:
> **DO NOT scan the codebase or read raw source files from scratch.**
> This repository features a pre-compiled **LLM Wiki** in [`wiki/`](file:///c:/Users/j_ant/projects/quizz_app/wiki/index.md). 
> All system architecture, data models, database schemas, Riverpod providers, GoRouter routes, and services are fully documented and kept up-to-date there.

---

## 🚀 Fast Lookup: Jump Directly to What You Need

Before calling file view or grep tools on the codebase, open the matching wiki file:

| If your task involves... | Consult this Wiki File first |
| :--- | :--- |
| **System architecture, offline vs online sync, boot sequence** | [`wiki/architecture.md`](file:///c:/Users/j_ant/projects/quizz_app/wiki/architecture.md) |
| **Data structures (`Exam`, `Question`, `ExamParticipant`, etc.)** | [`wiki/data-models.md`](file:///c:/Users/j_ant/projects/quizz_app/wiki/data-models.md) |
| **Supabase PostgreSQL tables, columns, RLS, or SQL migrations** | [`wiki/database-schema.md`](file:///c:/Users/j_ant/projects/quizz_app/wiki/database-schema.md) |
| **Riverpod controllers, state classes, or provider definitions** | [`wiki/state-management.md`](file:///c:/Users/j_ant/projects/quizz_app/wiki/state-management.md) |
| **Navigation, GoRouter paths, route parameters, or screens** | [`wiki/routing-and-screens.md`](file:///c:/Users/j_ant/projects/quizz_app/wiki/routing-and-screens.md) |
| **SharedPreferences keys, Supabase client, or seed data** | [`wiki/services-and-storage.md`](file:///c:/Users/j_ant/projects/quizz_app/wiki/services-and-storage.md) |
| **Exam Maker, 6-char join codes, bulk parsing, or scoring** | [`wiki/exam-maker-flow.md`](file:///c:/Users/j_ant/projects/quizz_app/wiki/exam-maker-flow.md) |
| **Theme colors (`AppColors`), coding style, or test recipes** | [`wiki/conventions-and-testing.md`](file:///c:/Users/j_ant/projects/quizz_app/wiki/conventions-and-testing.md) |

---

## 🛠️ Tech Stack Snapshot

- **Framework**: Flutter 3.9+ (Dart SDK ^3.9.2).
- **Architecture**: Dual Engine — Offline-First (Study Mode) & Cloud Sync (Exam Mode).
- **State Management**: Flutter Riverpod (`flutter_riverpod`, `flutter_riverpod/legacy.dart`).
- **Routing**: GoRouter (`go_router ^17.2.3`).
- **Backend**: Supabase (`supabase_flutter ^2.17.2`) + PostgreSQL.
- **Local Cache**: SharedPreferences (`shared_preferences ^2.5.5`) via `LocalStorageService`.
- **Environment**: Flutter Dotenv (`flutter_dotenv ^5.2.1`).

---

## 📜 Agent Rules of Engagement

1. **Check Wiki First**: Always read the corresponding `wiki/<topic>.md` file before inspecting source code.
2. **Surgical Source Inspection Only**: Only use `view_file` on `.dart` files when you have identified the exact file from the wiki and need precise line ranges for code modifications.
3. **Keep the Wiki Fresh**: Whenever you add a new model field, provider, route, or database column, update the relevant markdown file in `wiki/` during the same turn.
