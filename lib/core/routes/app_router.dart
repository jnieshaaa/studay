import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/quiz_session_model.dart';
import '../../models/question_model.dart';
import '../../models/exam_model.dart';
import '../../controllers/exam_participant_controller.dart';
import '../../views/screens/home/home_screen.dart';
import '../../views/screens/study/study_home_screen.dart';
import '../../views/screens/study/quiz_play_screen.dart';
import '../../views/screens/study/quiz_result_screen.dart';
import '../../views/screens/study/flashcards_screen.dart';
import '../../views/screens/study/weak_questions_screen.dart';
import '../../views/screens/exam/exam_home_screen.dart';
import '../../views/screens/exam/exam_join_screen.dart';
import '../../views/screens/exam/exam_maker_screen.dart';
import '../../views/screens/exam/exam_play_screen.dart';
import '../../views/screens/exam/exam_participant_result_screen.dart';
import '../../views/screens/exam/exam_dashboard_screen.dart';
import '../../views/screens/library/my_library_screen.dart';
import '../../views/screens/auth/username_setup_screen.dart';
import '../../views/screens/splash/splash_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    // Splash Screen (Brand placeholder & session-aware transition)
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),

    // Frictionless Username Setup Screen (Replaces old login screen)
    GoRoute(
      path: '/setup-username',
      builder: (context, state) => const UsernameSetupScreen(),
    ),

    // Alias /login for backwards compatibility
    GoRoute(
      path: '/login',
      builder: (context, state) => const UsernameSetupScreen(),
    ),

    // Creator Landing Home Screen (Only for logged-in creators)
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),

    // Personal Library & Category Organizer
    GoRoute(
      path: '/library',
      builder: (context, state) => const MyLibraryScreen(),
    ),

    // Study Mode Routes
    GoRoute(
      path: '/study',
      builder: (context, state) => const StudyHomeScreen(),
      routes: [
        GoRoute(
          path: 'quiz',
          builder: (context, state) {
            final session = state.extra as QuizSession;
            return QuizPlayScreen(session: session);
          },
        ),
        GoRoute(
          path: 'result',
          builder: (context, state) {
            final session = state.extra as QuizSession;
            return QuizResultScreen(session: session);
          },
        ),
        GoRoute(
          path: 'flashcards',
          builder: (context, state) {
            final questions = state.extra as List<Question>;
            return FlashcardsScreen(questions: questions);
          },
        ),
        GoRoute(
          path: 'weak-questions',
          builder: (context, state) => const WeakQuestionsScreen(),
        ),
      ],
    ),

    // Exam Mode Routes
    GoRoute(
      path: '/exam',
      builder: (context, state) => const ExamHomeScreen(),
      routes: [
        GoRoute(
          path: 'join',
          builder: (context, state) {
            final initialCode = state.extra as String?;
            return ExamJoinScreen(initialCode: initialCode);
          },
        ),
        GoRoute(
          path: 'maker',
          builder: (context, state) {
            final initialExam = state.extra as Exam?;
            return ExamMakerScreen(initialExam: initialExam);
          },
        ),
        GoRoute(
          path: 'play',
          builder: (context, state) {
            final param = state.extra as ExamParticipantParam;
            return ExamPlayScreen(param: param);
          },
        ),
        GoRoute(
          path: 'result',
          builder: (context, state) {
            final param = state.extra as ExamResultParam;
            return ExamParticipantResultScreen(param: param);
          },
        ),
        GoRoute(
          path: 'dashboard/:id',
          builder: (context, state) {
            final examId = state.pathParameters['id'] ?? '';
            return ExamDashboardScreen(examId: examId);
          },
        ),
      ],
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Text('Page not found: ${state.uri}'),
    ),
  ),
);
