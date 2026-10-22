# LLM Wiki Protocol

When working on this codebase:

1. **Zero-Scratch Rule**: Do NOT run directory listings, fuzzy greps, or full-file inspections from scratch to understand the codebase.
2. **Consult LLM Wiki**: Immediately open the relevant compiled documentation inside [`wiki/`](file:///c:/Users/j_ant/projects/quizz_app/wiki/index.md):
   - Architecture & dual-mode sync: `wiki/architecture.md`
   - Data structures & models: `wiki/data-models.md`
   - Supabase schema & SQL: `wiki/database-schema.md`
   - Riverpod state & providers: `wiki/state-management.md`
   - GoRouter & screens: `wiki/routing-and-screens.md`
   - SharedPreferences & services: `wiki/services-and-storage.md`
   - Exam maker & 6-char join flow: `wiki/exam-maker-flow.md`
   - Theme tokens & conventions: `wiki/conventions-and-testing.md`
3. **Surgical Dart File Access**: Only view raw `.dart` files when executing targeted code replacements.
4. **Wiki Maintenance**: If you add, modify, or delete models, database fields, providers, or routes, update the respective markdown file in `wiki/`.
