# StuDay (Quizz App) — Gemini & Antigravity Instructions

> **MANDATORY INSTRUCTION**:
> **DO NOT scan raw files or explore directories from scratch.**
> This project has a complete, modular **LLM Wiki** located in [`wiki/`](file:///c:/Users/j_ant/projects/quizz_app/wiki/index.md).
> Before answering questions or writing code, read the relevant topic in `wiki/`.

---

## ⚡ Direct Knowledge Lookup

| Task Area | Target Wiki File |
| :--- | :--- |
| **System Architecture & Boot Sequence** | [`wiki/architecture.md`](file:///c:/Users/j_ant/projects/quizz_app/wiki/architecture.md) |
| **Data Models (`Exam`, `Question`, `Participant`, etc.)** | [`wiki/data-models.md`](file:///c:/Users/j_ant/projects/quizz_app/wiki/data-models.md) |
| **Supabase PostgreSQL Schema & RLS** | [`wiki/database-schema.md`](file:///c:/Users/j_ant/projects/quizz_app/wiki/database-schema.md) |
| **Riverpod Controllers & Providers** | [`wiki/state-management.md`](file:///c:/Users/j_ant/projects/quizz_app/wiki/state-management.md) |
| **GoRouter Paths & Screen Breakdown** | [`wiki/routing-and-screens.md`](file:///c:/Users/j_ant/projects/quizz_app/wiki/routing-and-screens.md) |
| **LocalStorage Keys & Supabase Service** | [`wiki/services-and-storage.md`](file:///c:/Users/j_ant/projects/quizz_app/wiki/services-and-storage.md) |
| **Exam Maker, Code Join & Question Types** | [`wiki/exam-maker-flow.md`](file:///c:/Users/j_ant/projects/quizz_app/wiki/exam-maker-flow.md) |
| **Theme Tokens (`AppColors`) & Testing** | [`wiki/conventions-and-testing.md`](file:///c:/Users/j_ant/projects/quizz_app/wiki/conventions-and-testing.md) |

---

## 📋 Behavioral Protocol

1. **Prioritize the Wiki**: When asked about a feature, logic, bug, or implementation detail, open the designated wiki file.
2. **Minimal File Reading**: Avoid reading full files or traversing directories blindly. Open `.dart` files only when performing a code edit.
3. **Compile-Time Maintenance**: Whenever code changes affect schemas, routes, models, or state definitions, update the corresponding `wiki/` file in the same task.
