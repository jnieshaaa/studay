import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../models/user_model.dart';
import 'providers.dart';

class AuthState {
  final UserModel? currentUser;
  final bool isLoading;
  final String? errorMessage;

  const AuthState({
    this.currentUser,
    this.isLoading = false,
    this.errorMessage,
  });

  bool get isAuthenticated => currentUser != null;

  AuthState copyWith({
    UserModel? currentUser,
    bool? isLoading,
    String? errorMessage,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      currentUser: clearUser ? null : (currentUser ?? this.currentUser),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  final Ref _ref;

  // Single unified demo creator profile for 1-tap fast testing
  static final UserModel demoCreator = UserModel(
    id: 'usr_demo_creator',
    name: 'Maria Santos',
    email: 'maria@studay.com',
    createdAt: DateTime.now().subtract(const Duration(days: 30)),
    createdExamIds: ['exam_sample_bio'],
  );

  AuthController(this._ref) : super(const AuthState(isLoading: true)) {
    loadActiveSession();
  }

  Future<void> loadActiveSession() async {
    final storage = _ref.read(localStorageServiceProvider);
    await storage.init();
    final user = await storage.loadCurrentUser();
    state = state.copyWith(
      currentUser: user,
      isLoading: false,
    );
  }

  Future<UserModel> setUsername(String username) async {
    final clean = username.trim().isNotEmpty
        ? username.trim()
        : 'User${DateTime.now().millisecondsSinceEpoch % 1000}';
    final storage = _ref.read(localStorageServiceProvider);
    await storage.init();

    final user = state.currentUser != null
        ? state.currentUser!.copyWith(name: clean)
        : UserModel(
            id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
            name: clean,
            email: '${clean.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')}@studay.local',
            createdAt: DateTime.now(),
          );

    await storage.saveCurrentUser(user);
    state = state.copyWith(currentUser: user, isLoading: false);
    return user;
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final storage = _ref.read(localStorageServiceProvider);
    await storage.init();

    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) {
      state = state.copyWith(isLoading: false, errorMessage: 'Please enter your email address.');
      return false;
    }

    // Check existing users or demo account
    final users = await storage.loadUsersList();
    UserModel? user = users.cast<UserModel?>().firstWhere(
          (u) => u?.email.toLowerCase() == cleanEmail,
          orElse: () => null,
        );

    if (user == null && cleanEmail == demoCreator.email.toLowerCase()) {
      user = demoCreator;
    }

    // If not found, dynamically create this user (frictionless demo flow)
    if (user == null) {
      final namePart = cleanEmail.split('@').first;
      final capitalized = namePart.isNotEmpty
          ? '${namePart[0].toUpperCase()}${namePart.substring(1)}'
          : 'Creator';
      user = UserModel(
        id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
        name: capitalized,
        email: cleanEmail,
        createdAt: DateTime.now(),
      );
    }

    await storage.saveCurrentUser(user);
    state = state.copyWith(currentUser: user, isLoading: false);
    return true;
  }

  Future<bool> register(String name, String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final storage = _ref.read(localStorageServiceProvider);
    await storage.init();

    final cleanEmail = email.trim().toLowerCase();
    final cleanName = name.trim();

    if (cleanName.isEmpty) {
      state = state.copyWith(isLoading: false, errorMessage: 'Please enter your name.');
      return false;
    }
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      state = state.copyWith(isLoading: false, errorMessage: 'Please enter a valid email.');
      return false;
    }

    final newUser = UserModel(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      name: cleanName,
      email: cleanEmail,
      createdAt: DateTime.now(),
    );

    await storage.saveCurrentUser(newUser);
    state = state.copyWith(currentUser: newUser, isLoading: false);
    return true;
  }

  Future<void> quickDemoLogin([UserModel? demoUser]) async {
    final user = demoUser ?? demoCreator;
    state = state.copyWith(isLoading: true, clearError: true);
    final storage = _ref.read(localStorageServiceProvider);
    await storage.init();
    await storage.saveCurrentUser(user);
    state = state.copyWith(currentUser: user, isLoading: false);
  }

  Future<void> logout() async {
    final storage = _ref.read(localStorageServiceProvider);
    await storage.init();
    await storage.clearCurrentUser();
    state = state.copyWith(clearUser: true);
  }

  Future<void> attachExamToUser(String examId) async {
    if (state.currentUser == null) return;
    final current = state.currentUser!;
    if (current.createdExamIds.contains(examId)) return;

    final updated = current.copyWith(
      createdExamIds: [...current.createdExamIds, examId],
    );
    final storage = _ref.read(localStorageServiceProvider);
    await storage.saveCurrentUser(updated);
    state = state.copyWith(currentUser: updated);
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref);
});
