import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../screens/ai/ai_generator_screen.dart';

/// Launches the dedicated full screen AI Document Generator.
/// Enables creators and students to generate either Exam Questions or Flashcard Decks.
void showAiStudyGeneratorModal(
  BuildContext context,
  WidgetRef ref, {
  String? defaultSubject,
  String initialMode = 'exam',
}) {
  if (GoRouter.maybeOf(context) != null) {
    context.push(
      '/ai-generator',
      extra: AiGeneratorArgs(
        defaultSubject: defaultSubject,
        initialMode: initialMode,
      ),
    );
  } else {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AiGeneratorScreen(
          defaultSubject: defaultSubject,
          initialMode: initialMode,
        ),
      ),
    );
  }
}
