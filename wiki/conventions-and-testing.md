# Conventions, Design System & Testing

---

## 1. Architectural & Coding Conventions

1. **Layered Separation**:
   - **Views (`lib/views/`)**: Pure UI widgets. Never perform direct network queries or SharedPreferences calls inside `build()`.
   - **Controllers (`lib/controllers/`)**: Business logic & state mutation using Riverpod `StateNotifier<T>` or `ChangeNotifier`.
   - **Services (`lib/services/`)**: External integrations (Supabase, LocalStorage, Seed data). Stateless or lightweight singletons.
   - **Models (`lib/models/`)**: Immutable Dart classes with `toJson()` and `fromJson()` factories.
2. **Immutability**:
   - State objects and models are marked `@immutable` or `const` where possible.
   - Use `copyWith(...)` for state transitions.
3. **Logging & Diagnostics**:
   - Avoid `print()`. Use `debugPrint('[Component] message')` to adhere to `analysis_options.yaml`.

---

## 2. Design System & Theme Tokens

The application design is built on a modern, dark-mode first Material 3 theme. Defined in [`lib/core/theme/app_colors.dart`](file:///c:/Users/j_ant/projects/quizz_app/lib/core/theme/app_colors.dart) and [`lib/core/theme/app_theme.dart`](file:///c:/Users/j_ant/projects/quizz_app/lib/core/theme/app_theme.dart).

### Color Palette Tokens
| Token | Hex Value | Usage |
| :--- | :--- | :--- |
| `AppColors.primary` | `0xFFF97316` | Fire Orange — Main CTA buttons, active highlights, key badges |
| `AppColors.secondary` | `0xFF38BDF8` | Sky Blue — Secondary actions, study cards, links |
| `AppColors.tertiary` | `0xFFA855F7` | Electric Purple — Matching question indicators, special badges |
| `AppColors.darkBg` | `0xFF0F172A` | Slate 900 — Main scaffold background |
| `AppColors.darkSurface` | `0xFF1E293B` | Slate 800 — Cards, sheets, dialog surfaces |
| `AppColors.darkCard` | `0xFF1E293B` | Slate 800 — Card backgrounds |
| `AppColors.darkBorder` | `0xFF334155` | Slate 700 — Outlines, dividers, card borders |
| `AppColors.textPrimaryDark` | `0xFFF8FAFC` | Slate 50 — High-contrast typography |
| `AppColors.textSecondaryDark`| `0xFF94A3B8` | Slate 400 — Subtitles, metadata, secondary labels |
| `AppColors.success` | `0xFF22C55E` | Emerald Green — Correct answers, passed score indicators |
| `AppColors.error` | `0xFFEF4444` | Red — Wrong answers, deadline expired, validation alerts |

### Typography & Component Specs
- Primary Font: Roboto / System Default.
- Cards: Rounded corners (`BorderRadius.circular(16)`) with subtle 1px border (`AppColors.darkBorder`).
- Buttons: Rounded corners (`BorderRadius.circular(14)`), minimum height 48px for comfortable touch targets.

---

## 3. Linter & Static Analysis

The project enforces `flutter_lints: ^5.0.0` configured in [`analysis_options.yaml`](file:///c:/Users/j_ant/projects/quizz_app/analysis_options.yaml).

### Running Analysis
```bash
flutter analyze
```

---

## 4. Testing & Verification

Unit and widget tests are located in `test/`.

### Running Tests
```bash
flutter test
```

### Best Practices for Tests
- When testing controllers, pass mock or memory implementations of `LocalStorageService` and `SupabaseExamService`.
- For `ExamService`, use `ExamService(storage, seedDefaultExams: true)` or call `.seedDefaultExamsForTesting()` to load fixture data.
