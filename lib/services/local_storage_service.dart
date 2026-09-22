import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/subject_model.dart';
import '../models/user_model.dart';
import '../models/question_model.dart';
import '../models/user_progress_model.dart';
import '../models/quiz_session_model.dart';
import '../models/exam_model.dart';
import 'seed_data_service.dart';

class LocalStorageService {
  static const String _keyQuestions = 'quizz_questions_v2';
  static const String _keyCustomSubjects = 'quizz_custom_subjects_v2';
  static const String _keyProgress = 'quizz_progress_v2';
  static const String _keyHistory = 'quizz_history_v2';
  static const String _keyCreatedExams = 'quizz_created_exams_v2';
  static const String _keyCurrentUser = 'quizz_current_user_v2';
  static const String _keyUsersList = 'quizz_users_list_v2';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // --- Questions (Offline Question Bank) ---
  Future<List<Question>> loadQuestions() async {
    await init();
    final jsonStr = _prefs?.getString(_keyQuestions);
    if (jsonStr == null || jsonStr.isEmpty) {
      final initialQuestions = SeedDataService.getInitialQuestions();
      await saveQuestions(initialQuestions);
      return initialQuestions;
    }
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list.map((q) => Question.fromJson(q as Map<String, dynamic>)).toList();
    } catch (e) {
      return SeedDataService.getInitialQuestions();
    }
  }

  Future<void> saveQuestions(List<Question> questions) async {
    await init();
    final jsonStr = jsonEncode(questions.map((q) => q.toJson()).toList());
    await _prefs?.setString(_keyQuestions, jsonStr);
  }

  // --- Question Progress & Mastery ---
  Future<Map<String, QuestionProgress>> loadProgress() async {
    await init();
    final jsonStr = _prefs?.getString(_keyProgress);
    if (jsonStr == null || jsonStr.isEmpty) return {};
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return map.map(
        (k, v) => MapEntry(k, QuestionProgress.fromJson(v as Map<String, dynamic>)),
      );
    } catch (e) {
      return {};
    }
  }

  Future<void> saveProgress(Map<String, QuestionProgress> progress) async {
    await init();
    final map = progress.map((k, v) => MapEntry(k, v.toJson()));
    await _prefs?.setString(_keyProgress, jsonEncode(map));
  }

  // --- Quiz Session History ---
  Future<List<Map<String, dynamic>>> loadHistory() async {
    await init();
    final jsonStr = _prefs?.getString(_keyHistory);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  Future<void> recordQuizSession(QuizSession session) async {
    await init();
    final history = await loadHistory();
    history.insert(0, {
      'id': session.id,
      'mode': session.mode.name,
      'score': session.score,
      'total': session.totalQuestions,
      'percentage': session.percentage,
      'date': session.completedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    });
    // Keep max 50 sessions in history
    if (history.length > 50) history.removeRange(50, history.length);
    await _prefs?.setString(_keyHistory, jsonEncode(history));
  }

  // --- Created Exams (Maker) ---
  Future<List<Exam>> loadCreatedExams() async {
    await init();
    final jsonStr = _prefs?.getString(_keyCreatedExams);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list.map((e) => Exam.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveCreatedExam(Exam exam) async {
    await init();
    final exams = await loadCreatedExams();
    final index = exams.indexWhere((e) => e.id == exam.id);
    if (index >= 0) {
      exams[index] = exam;
    } else {
      exams.insert(0, exam);
    }
    await _prefs?.setString(
      _keyCreatedExams,
      jsonEncode(exams.map((e) => e.toJson()).toList()),
    );
  }

  // --- Custom & Imported Subjects ---
  Future<List<Subject>> loadCustomSubjects() async {
    await init();
    final jsonStr = _prefs?.getString(_keyCustomSubjects);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list.map((s) => Subject.fromJson(s as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveCustomSubjects(List<Subject> subjects) async {
    await init();
    final jsonStr = jsonEncode(subjects.map((s) => s.toJson()).toList());
    await _prefs?.setString(_keyCustomSubjects, jsonStr);
  }

  Future<void> saveCustomSubject(Subject subject) async {
    await init();
    final existing = await loadCustomSubjects();
    final index = existing.indexWhere((s) => s.id == subject.id);
    if (index >= 0) {
      existing[index] = subject;
    } else {
      existing.add(subject);
    }
    await saveCustomSubjects(existing);
  }

  // --- User Accounts (Dynamic / Offline-First) ---
  Future<UserModel?> loadCurrentUser() async {
    await init();
    final jsonStr = _prefs?.getString(_keyCurrentUser);
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return UserModel.fromJson(map);
    } catch (e) {
      return null;
    }
  }

  Future<void> saveCurrentUser(UserModel user) async {
    await init();
    final jsonStr = jsonEncode(user.toJson());
    await _prefs?.setString(_keyCurrentUser, jsonStr);
    await saveUserToList(user);
  }

  Future<void> clearCurrentUser() async {
    await init();
    await _prefs?.remove(_keyCurrentUser);
  }

  Future<List<UserModel>> loadUsersList() async {
    await init();
    final jsonStr = _prefs?.getString(_keyUsersList);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list.map((u) => UserModel.fromJson(u as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveUserToList(UserModel user) async {
    await init();
    final users = await loadUsersList();
    final idx = users.indexWhere((u) => u.id == user.id || u.email == user.email);
    if (idx >= 0) {
      users[idx] = user;
    } else {
      users.add(user);
    }
    await _prefs?.setString(
      _keyUsersList,
      jsonEncode(users.map((u) => u.toJson()).toList()),
    );
  }
}
