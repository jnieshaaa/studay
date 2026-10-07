import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/code_generator.dart';
import '../../../models/exam_model.dart';
import '../../../models/question_model.dart';
import '../../../controllers/providers.dart';
import '../../../controllers/study_controller.dart';
import '../../../controllers/auth_controller.dart';

/// Shows the bottom sheet / modal dialog for creating a flashcard deck in Study Mode.
void showCreateFlashcardSheet({
  required BuildContext context,
  String? initialSubject,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => CreateFlashcardSheet(initialSubject: initialSubject),
  );
}

class CreateFlashcardSheet extends ConsumerStatefulWidget {
  final String? initialSubject;
  const CreateFlashcardSheet({super.key, this.initialSubject});

  @override
  ConsumerState<CreateFlashcardSheet> createState() => _CreateFlashcardSheetState();
}

class _FlashcardDraft {
  final TextEditingController frontController;
  final TextEditingController backController;
  final TextEditingController hintController;
  bool showHint;

  _FlashcardDraft({
    String front = '',
    String back = '',
    String hint = '',
    this.showHint = false,
  })  : frontController = TextEditingController(text: front),
        backController = TextEditingController(text: back),
        hintController = TextEditingController(text: hint);

  void dispose() {
    frontController.dispose();
    backController.dispose();
    hintController.dispose();
  }
}

class _CreateFlashcardSheetState extends ConsumerState<CreateFlashcardSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _customSubjectController;

  String? _selectedSubject;
  bool _isCustomSubject = false;
  bool _isSaving = false;

  final List<_FlashcardDraft> _cards = [];

  @override
  void initState() {
    super.initState();
    final subj = widget.initialSubject;
    _selectedSubject = (subj != null && subj.isNotEmpty) ? subj : null;
    _titleController = TextEditingController(
      text: _selectedSubject != null ? '$_selectedSubject Flashcards' : 'Quick Study Flashcards',
    );
    _customSubjectController = TextEditingController();

    // Start with 2 empty cards
    _cards.addAll([
      _FlashcardDraft(),
      _FlashcardDraft(),
    ]);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _customSubjectController.dispose();
    for (final card in _cards) {
      card.dispose();
    }
    super.dispose();
  }

  void _addCard({String front = '', String back = '', String hint = ''}) {
    setState(() {
      _cards.add(_FlashcardDraft(front: front, back: back, hint: hint));
    });
  }

  void _removeCard(int index) {
    if (_cards.length <= 1) return;
    setState(() {
      _cards[index].dispose();
      _cards.removeAt(index);
    });
  }

  void _showQuickPasteDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (dlgCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final raw = textController.text;
            final parsedPairs = _parseQuickPasteCards(raw);

            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.bolt, color: AppColors.secondary),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '⚡ Quick Paste Flashcards',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Paste multiple flashcards below. Each line can be formatted as:\n'
                        '• Front - Back\n'
                        '• Front : Back\n'
                        '• Front \t Back (tab-separated from Quizlet/Excel)\n'
                        '• Front = Back',
                        style: TextStyle(fontSize: 12, height: 1.4),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'PASTE OR TYPE',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                          InkWell(
                            onTap: () {
                              textController.text =
                                  'Photosynthesis - Process by which plants make food\n'
                                  'Mitochondria - Powerhouse of the cell\n'
                                  'DNA - Genetic blueprint of living organisms';
                              setDialogState(() {});
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                              child: Text(
                                'Insert Sample',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.secondary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: textController,
                        minLines: 5,
                        maxLines: 14,
                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                        decoration: InputDecoration(
                          hintText: "Photosynthesis - Process by which plants convert sunlight into energy\n"
                              "Mitochondria - The powerhouse of the cell\n"
                              "JavaScript - High-level multi-paradigm programming language",
                          hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontFamily: 'sans-serif'),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),
                      if (parsedPairs.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          '✓ ${parsedPairs.length} flashcards detected',
                          style: const TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dlgCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: parsedPairs.isNotEmpty
                      ? () {
                          setState(() {
                            // Clear existing empty cards if any
                            final bool hasOnlyEmpty = _cards.every(
                              (c) => c.frontController.text.trim().isEmpty && c.backController.text.trim().isEmpty,
                            );
                            if (hasOnlyEmpty) {
                              for (final c in _cards) {
                                c.dispose();
                              }
                              _cards.clear();
                            }

                            for (final p in parsedPairs) {
                              _addCard(front: p.key, back: p.value);
                            }
                          });
                          Navigator.pop(dlgCtx);
                        }
                      : null,
                  child: const Text('Add Flashcards'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<MapEntry<String, String>> _parseQuickPasteCards(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return [];

    final lines = trimmed.split(RegExp(r'\r?\n'));
    final results = <MapEntry<String, String>>[];

    for (final line in lines) {
      final l = line.trim();
      if (l.isEmpty) continue;

      // Try tab delimiter (from spreadsheets / Quizlet)
      if (l.contains('\t')) {
        final parts = l.split('\t');
        if (parts.length >= 2 && parts[0].trim().isNotEmpty && parts[1].trim().isNotEmpty) {
          results.add(MapEntry(parts[0].trim(), parts.sublist(1).join(' ').trim()));
          continue;
        }
      }

      // Try " - " delimiter
      if (l.contains(' - ')) {
        final idx = l.indexOf(' - ');
        final front = l.substring(0, idx).trim();
        final back = l.substring(idx + 3).trim();
        if (front.isNotEmpty && back.isNotEmpty) {
          results.add(MapEntry(front, back));
          continue;
        }
      }

      // Try " : " or ":"
      if (l.contains(':')) {
        final idx = l.indexOf(':');
        final front = l.substring(0, idx).trim();
        final back = l.substring(idx + 1).trim();
        if (front.isNotEmpty && back.isNotEmpty) {
          results.add(MapEntry(front, back));
          continue;
        }
      }

      // Try " = " or "="
      if (l.contains('=')) {
        final idx = l.indexOf('=');
        final front = l.substring(0, idx).trim();
        final back = l.substring(idx + 1).trim();
        if (front.isNotEmpty && back.isNotEmpty) {
          results.add(MapEntry(front, back));
          continue;
        }
      }

      // Try " ? " or "?"
      if (l.contains('?')) {
        final idx = l.indexOf('?');
        final front = l.substring(0, idx + 1).trim();
        final back = l.substring(idx + 1).trim();
        if (front.isNotEmpty && back.isNotEmpty) {
          results.add(MapEntry(front, back));
          continue;
        }
      }
    }

    return results;
  }

  Future<Exam?> _saveDeck({bool startStudy = false}) async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a title for your flashcard deck.'),
          backgroundColor: AppColors.error,
        ),
      );
      return null;
    }

    String effectiveSubject = 'General Study';
    if (_isCustomSubject) {
      final custom = _customSubjectController.text.trim();
      if (custom.isNotEmpty) effectiveSubject = custom;
    } else if (_selectedSubject != null && _selectedSubject!.isNotEmpty) {
      effectiveSubject = _selectedSubject!;
    }

    // Filter valid cards
    final validCards = _cards.where((c) {
      return c.frontController.text.trim().isNotEmpty && c.backController.text.trim().isNotEmpty;
    }).toList();

    if (validCards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill out at least 1 flashcard (Front & Back).'),
          backgroundColor: AppColors.error,
        ),
      );
      return null;
    }

    setState(() => _isSaving = true);

    try {
      final examService = ref.read(examServiceProvider);
      final studyNotifier = ref.read(studyControllerProvider.notifier);
      final currentUser = ref.read(authControllerProvider).currentUser;

      final questions = <Question>[];
      for (int i = 0; i < validCards.length; i++) {
        final c = validCards[i];
        final qId = CodeGenerator.generateId('q_fc');
        final front = c.frontController.text.trim();
        final back = c.backController.text.trim();
        final hint = c.hintController.text.trim();

        questions.add(
          Question(
            id: qId,
            topicId: 'flashcards',
            subjectId: 'custom',
            category: effectiveSubject,
            questionText: front,
            questionType: QuestionType.multipleChoice,
            difficulty: Difficulty.medium,
            explanation: hint.isNotEmpty ? hint : 'Key Concept: $back',
            reference: '',
            choices: [
              QuestionChoice(
                id: CodeGenerator.generateId('c_ans'),
                questionId: qId,
                choiceText: back,
                isCorrect: true,
                sortOrder: 0,
              ),
            ],
            points: 1,
          ),
        );
      }

      final deckExam = Exam(
        id: CodeGenerator.generateId('deck'),
        creatorId: currentUser?.id ?? currentUser?.name ?? 'maker_local',
        title: title,
        subject: effectiveSubject,
        description: 'Personal study flashcard deck with ${questions.length} cards.',
        code: '', // Code generated on publish
        status: ExamStatus.published,
        questions: questions,
        createdAt: DateTime.now(),
      );

      final published = await examService.publishExam(deckExam);

      try {
        await studyNotifier.syncCreatedExam(published);
      } catch (_) {}

      setState(() => _isSaving = false);

      if (mounted) {
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Created Flashcard Deck "$title" (${questions.length} cards) in $effectiveSubject!',
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );

        if (startStudy) {
          // Immediately launch the flashcard focus study session
          context.push('/study/flashcards', extra: published.questions);
        }
      }

      return published;
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save flashcards: $e'), backgroundColor: AppColors.error),
        );
      }
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final studyState = ref.watch(studyControllerProvider);
    final existingSubjects = studyState.subjects.map((s) => s.name).toSet().toList()..sort();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161622) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top Grab Bar & Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 16, 10),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: AppColors.flameGradient,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.style, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create Flashcard Deck',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Build front & back study cards to memorize concepts faster',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Scrollable Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Deck Title
                  const Text(
                    'DECK TITLE *',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      hintText: 'e.g. JavaScript Array Methods, Biology Terms...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Subject Selector
                  const Text(
                    'SUBJECT / CATEGORY',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _isCustomSubject
                              ? '__custom__'
                              : (_selectedSubject != null && existingSubjects.contains(_selectedSubject)
                                  ? _selectedSubject
                                  : (existingSubjects.isNotEmpty ? existingSubjects.first : '__custom__')),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          items: [
                            ...existingSubjects.map((s) => DropdownMenuItem(value: s, child: Text(s))),
                            const DropdownMenuItem(
                              value: '__custom__',
                              child: Text('+ Create New Subject...', style: TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ],
                          onChanged: (val) {
                            if (val == '__custom__') {
                              setState(() {
                                _isCustomSubject = true;
                              });
                            } else {
                              setState(() {
                                _isCustomSubject = false;
                                _selectedSubject = val;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  if (_isCustomSubject) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _customSubjectController,
                      decoration: InputDecoration(
                        hintText: 'Enter new subject name...',
                        prefixIcon: const Icon(Icons.school_outlined, size: 18),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Header for Cards List with Quick Paste
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'CARDS (${_cards.length})',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                      ),
                      TextButton.icon(
                        onPressed: _showQuickPasteDialog,
                        icon: const Icon(Icons.bolt, size: 15, color: AppColors.secondary),
                        label: const Text(
                          'Quick Paste Cards',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.secondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Cards List
                  ...List.generate(_cards.length, (i) {
                    final card = _cards[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1C1C2A) : const Color(0xFFF7F7FD),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? const Color(0xFF2C2C3E) : const Color(0xFFE2E2F0),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.secondary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'CARD ${i + 1}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: AppColors.secondary,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              TextButton(
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                ),
                                onPressed: () {
                                  setState(() {
                                    card.showHint = !card.showHint;
                                  });
                                },
                                child: Text(
                                  card.showHint ? 'Hide Hint' : '+ Add Hint',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                              if (_cards.length > 1)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18),
                                  color: Colors.red.shade400,
                                  tooltip: 'Delete Card',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _removeCard(i),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Front Input
                          const Text(
                            'FRONT (Prompt / Term / Question)',
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 4),
                          TextField(
                            controller: card.frontController,
                            minLines: 2,
                            maxLines: 8,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            style: const TextStyle(fontSize: 13, height: 1.35),
                            decoration: InputDecoration(
                              hintText: 'Enter question, term, or code snippet...',
                              hintStyle: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                              contentPadding: const EdgeInsets.all(10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Back Input
                          const Text(
                            'BACK (Answer / Definition / Solution)',
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 4),
                          TextField(
                            controller: card.backController,
                            minLines: 2,
                            maxLines: 8,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            style: const TextStyle(fontSize: 13, height: 1.35),
                            decoration: InputDecoration(
                              hintText: 'Enter answer, meaning, explanation, or code output...',
                              hintStyle: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                              contentPadding: const EdgeInsets.all(10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),

                          // Optional Hint Field
                          if (card.showHint) ...[
                            const SizedBox(height: 10),
                            const Text(
                              'HINT / EXTRA EXPLANATION (Optional)',
                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                            ),
                            const SizedBox(height: 4),
                            TextField(
                              controller: card.hintController,
                              minLines: 1,
                              maxLines: 4,
                              style: const TextStyle(fontSize: 12),
                              decoration: InputDecoration(
                                hintText: 'Enter optional memory aid or hint...',
                                contentPadding: const EdgeInsets.all(8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),

                  // Add Another Card Button
                  OutlinedButton.icon(
                    onPressed: () => _addCard(),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Another Flashcard'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: BorderSide(color: AppColors.secondary.withValues(alpha: 0.5)),
                      foregroundColor: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Bottom Bar Actions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF14141E) : const Color(0xFFF3F3FA),
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () => _saveDeck(startStudy: false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Save Deck', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : () => _saveDeck(startStudy: true),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.play_arrow_rounded, size: 20),
                    label: const Text(
                      'Save & Focus (Start Now)',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
