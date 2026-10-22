# 📚 StuDay — The Dual-Engine Study & Exam Platform

<p align="center">
  <b>A modern, offline-first study companion and real-time live exam platform built with Flutter & Supabase.</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.9+-02569B?logo=flutter&logoColor=white" alt="Flutter Version" />
  <img src="https://img.shields.io/badge/Dart-3.9+-0175C2?logo=dart&logoColor=white" alt="Dart Version" />
  <img src="https://img.shields.io/badge/State-Riverpod-blue?logo=dart&logoColor=white" alt="Riverpod" />
  <img src="https://img.shields.io/badge/Routing-GoRouter-teal?logo=flutter&logoColor=white" alt="GoRouter" />
  <img src="https://img.shields.io/badge/Backend-Supabase-3ECF8E?logo=supabase&logoColor=white" alt="Supabase" />
  <img src="https://img.shields.io/badge/License-MIT-green" alt="License" />
</p>

---

## 🌟 What is StuDay?

**StuDay** is an all-in-one educational platform engineered for both **individual learners** and **educators / quiz hosts**. It operates on a **Dual-Engine Architecture**:

1. **Study Mode (Offline-First)**: Practice quizzes, master flashcard decks, drill weak spots, and simulate timed mock exams — completely offline without requiring an internet connection.
2. **Exam Mode (Cloud Sync)**: Host live, synchronized exams with a simple **6-character join code** (`4F9K2Q`). Participants can join and compete instantly from any device with zero account creation or sign-up friction.

---

## ✨ Key Features

### 🗂️ 1. Flashcards & Active Recall
- **Dual Study Modes**:
  - **Flip Cards (Review)**: Smooth 3D card flips displaying Front, Back, and Hint, paired with mastery tracking (*"Still Learning"* vs. *"Got It!"*).
  - **Type-in Quiz (Active Recall)**: Deepen retention by typing the answer from memory. Includes automated evaluation, displays correct answers upon error, and provides a **Pass** button to skip when needed.
- **Dedicated Deck Creator & Editor**: Easily create or edit decks with custom card counts, hints, and randomized sampling limits.

### 📝 2. Live Exam Hosting & Frictionless Join
- **Zero-Friction Access**: Participants enter a 6-character room code and their nickname. No passwords, emails, or OAuth required.
- **Real-Time Synchronized Engine**: Backed by Supabase PostgreSQL with real-time participation tracking and automated instant grading.
- **Host Dashboard**: Live participant list, submission tracking, average scores, and question-by-question analytics.

### ⚡ 3. Powerful Exam Maker & Bulk Question Parser
- **Question Types**: Multiple Choice (MCQ), True / False, and dynamic premise-target Matching Types.
- **Smart Bulk Question Parser**: Paste unformatted questions or notes directly:
  - Supports standard numbered formats (`1. Question`, `A) Choice`), plain multi-line text, and inline correct answer indicators (`*`, `(correct)`).
  - Preserves math decimals, legal abbreviations (e.g., `R.A. 10173`), and multiline code snippets.
- **Section Ordering**: Drag-and-drop section dividers to organize exams (e.g., force Matching section first, then MCQ).
- **Question Bank Sampling**: Set a bank limit (e.g., randomize 20 unique non-repetitive questions from a pool of 100).

### 📚 4. My Library & Subject Organization
- **Subject-Based Navigation**: Organize quizzes and flashcards into clear subjects (e.g., *Mathematics, Science, English, Filipino*).
- **Subject Sharing**: Generate unique share codes to distribute an entire subject bundle of quizzes to other students.
- **Clean 3-Dots Management Menu (`⋮`)**:
  - **Edit**: Smart routing opens the Flashcard Editor for decks or the Exam Maker for quizzes.
  - **Stats**: Visual performance analytics.
  - **Backup**: Export quiz and deck definitions as JSON.
  - **Delete**: Remove unwanted quizzes.

---

## 🏗️ Architecture & Technology Stack

| Layer | Technology | Details |
| :--- | :--- | :--- |
| **Framework** | **Flutter 3.9+ (Dart 3.9+)** | Cross-platform (Android, iOS, Web, Desktop) |
| **State Management** | **Flutter Riverpod** | Controller/StateNotifier pattern with dependency injection |
| **Navigation** | **GoRouter** | Declarative deep-linking with route arguments & redirects |
| **Local Cache** | **SharedPreferences** | Fast offline persistence for decks, subjects, and study history |
| **Cloud Backend** | **Supabase** | PostgreSQL database with Row-Level Security (RLS) & Realtime |
| **Environment** | **flutter_dotenv** | Secure local configuration for Supabase API keys |

---

## 📁 Project Structure

```text
quizz_app/
├── lib/
│   ├── core/
│   │   ├── config/          # SupabaseConfig, environment configuration
│   │   ├── routes/          # GoRouter definitions and route names
│   │   ├── theme/           # AppColors, AppTheme (Material 3 Dark/Light)
│   │   └── utils/           # BulkQuestionParser, CodeGenerator, responsive helpers
│   ├── controllers/         # Riverpod StateNotifiers (Study, ExamMaker, Auth, etc.)
│   ├── models/              # Immutable data models (Exam, Question, Choice, Participant)
│   ├── services/            # SupabaseExamService, LocalStorageService, SeedDataService
│   └── views/
│       ├── components/      # Reusable widgets (cards, badges, modals, buttons)
│       └── screens/
│           ├── auth/        # Username setup & profile management
│           ├── exam/        # ExamMakerScreen, ExamJoinScreen, ExamPlayScreen, Dashboard
│           ├── home/        # Creator hub, quick join, and study streaks
│           ├── library/     # MyLibraryScreen & SubjectQuizzesScreen
│           ├── splash/      # Boot sequence & session resolver
│           └── study/       # StudyHomeScreen, FlashcardsScreen, QuizPlayScreen
├── wiki/                    # LLM Wiki & architectural documentation
├── supabase_tables.sql      # Clean PostgreSQL DDL for backend tables
├── pubspec.yaml             # Project dependencies and asset definitions
└── test/                    # Comprehensive unit and widget test suite (46+ tests)
```

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`^3.9.2` or later)
- [Dart SDK](https://dart.dev/get-dart)
- An active [Supabase](https://supabase.com) project (optional for offline Study Mode)

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-username/quizz_app.git
   cd quizz_app
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Configure Environment Variables:**
   Create a `.env` file in the root directory:
   ```env
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_ANON_KEY=your-anon-key-here
   ```

4. **Initialize Database (Optional for Cloud Sync):**
   Run the SQL statements found in [`supabase_tables.sql`](supabase_tables.sql) inside your Supabase SQL Editor.

5. **Run the Application:**
   ```bash
   flutter run
   ```

---

## 🧪 Testing

StuDay maintains a comprehensive automated test suite covering unit logic, parsers, and widget interactions:

```bash
# Run static analysis
flutter analyze

# Run all unit and widget tests
flutter test
```

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
