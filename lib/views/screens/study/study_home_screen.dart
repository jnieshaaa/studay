import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../controllers/study_controller.dart';
import '../../../controllers/providers.dart';
import '../../../controllers/exam_participant_controller.dart';
import '../../../models/quiz_session_model.dart';
import '../../../models/exam_model.dart';
import '../../components/common/gradient_card.dart';
import '../../components/common/ai_study_generator_modal.dart';
import 'create_flashcard_sheet.dart';
import 'flashcards_screen.dart';

class StudyHomeScreen extends ConsumerStatefulWidget {
  const StudyHomeScreen({super.key});

  @override
  ConsumerState<StudyHomeScreen> createState() => _StudyHomeScreenState();
}

class _StudyHomeScreenState extends ConsumerState<StudyHomeScreen> {
  final Set<String> _collapsedStudySubjects = {};

  void _toggleSubjectCollapse(String subject) {
    setState(() {
      if (_collapsedStudySubjects.contains(subject)) {
        _collapsedStudySubjects.remove(subject);
      } else {
        _collapsedStudySubjects.add(subject);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final studyState = ref.watch(studyControllerProvider);
    final studyNotifier = ref.read(studyControllerProvider.notifier);
    final examService = ref.watch(examServiceProvider);

    // Group all created exams by their subject
    final allExams = examService.allExams;
    final Map<String, List<Exam>> examsBySubject = {};
    for (final exam in allExams) {
      final subj = exam.effectiveSubject;
      examsBySubject.putIfAbsent(subj, () => []).add(exam);
    }
    final allSubjectNames = examsBySubject.keys.toList()..sort();

    // Filter displayed subjects if a specific subject chip is selected
    final selectedSubjectObj = studyState.selectedSubjectId != null
        ? studyState.subjects.where((s) => s.id == studyState.selectedSubjectId).firstOrNull
        : null;

    final displayedSubjectNames = studyState.selectedSubjectId != null
        ? allSubjectNames.where((name) {
            if (selectedSubjectObj != null && name.toLowerCase() == selectedSubjectObj.name.toLowerCase()) {
              return true;
            }
            return name.toLowerCase() == studyState.selectedSubjectId!.toLowerCase();
          }).toList()
        : allSubjectNames;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Study Mode',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: Color(0xFF6366F1)),
            tooltip: 'AI PDF Generator',
            onPressed: () => showAiStudyGeneratorModal(
              context,
              ref,
              defaultSubject: selectedSubjectObj?.name,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.style, color: AppColors.secondary),
            tooltip: 'Create Flashcards',
            onPressed: () => showCreateFlashcardSheet(
              context: context,
              initialSubject: selectedSubjectObj?.name,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.download, color: AppColors.secondary),
            tooltip: 'Import Exam as Study Deck',
            onPressed: () => _showImportExamSheet(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_outline, color: AppColors.secondary),
            tooltip: 'Starred Questions',
            onPressed: () {
              final session = studyNotifier.buildQuizSession(mode: StudyMode.bookmarked);
              context.push('/study/quiz', extra: session);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: ResponsiveContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Clean Dropdown Subject Filter & Action Bar
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF14141E) : const Color(0xFFF4F4F8),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? const Color(0xFF28283C) : const Color(0xFFDFDFEA),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: studyState.selectedSubjectId ?? '__ALL__',
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.secondary, size: 28),
                          dropdownColor: isDark ? const Color(0xFF1B1B26) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          items: [
                            DropdownMenuItem<String>(
                              value: '__ALL__',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.apps_rounded,
                                    size: 18,
                                    color: (studyState.selectedSubjectId == null || studyState.selectedSubjectId == '__ALL__')
                                        ? AppColors.secondary
                                        : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'All Subjects (${allSubjectNames.length})',
                                    style: TextStyle(
                                      fontWeight: (studyState.selectedSubjectId == null || studyState.selectedSubjectId == '__ALL__')
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      color: (studyState.selectedSubjectId == null || studyState.selectedSubjectId == '__ALL__')
                                          ? AppColors.secondary
                                          : null,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ...allSubjectNames.map((subjName) {
                              final subjObj = studyState.subjects.where((s) => s.name.toLowerCase() == subjName.toLowerCase()).firstOrNull;
                              final subjId = subjObj?.id ?? subjName;
                              final isSelected = studyState.selectedSubjectId == subjId || studyState.selectedSubjectId == subjName;
                              final examsCount = examsBySubject[subjName]?.length ?? 0;
                              return DropdownMenuItem<String>(
                                value: subjId,
                                child: Row(
                                  children: [
                                    Icon(
                                      _getSubjectIcon(subjName),
                                      size: 18,
                                      color: isSelected ? AppColors.secondary : _getSubjectColor(subjName),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '$subjName ($examsCount)',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                          color: isSelected ? AppColors.secondary : null,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                          onChanged: (newSubjId) {
                            final effectiveId = (newSubjId == null || newSubjId == '__ALL__') ? null : newSubjId;
                            studyNotifier.selectSubject(effectiveId);
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Quick Action 1: Create Flashcards
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.tertiary.withValues(alpha: 0.15),
                      padding: const EdgeInsets.all(11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: AppColors.tertiary.withValues(alpha: 0.35)),
                      ),
                    ),
                    icon: const Icon(Icons.style_rounded, size: 20, color: AppColors.tertiary),
                    tooltip: 'Create Flashcards',
                    onPressed: () => showCreateFlashcardSheet(
                      context: context,
                      initialSubject: selectedSubjectObj?.name,
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Quick Action 2: Import Deck
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.secondary.withValues(alpha: 0.15),
                      padding: const EdgeInsets.all(11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: AppColors.secondary.withValues(alpha: 0.35)),
                      ),
                    ),
                    icon: const Icon(Icons.download_rounded, size: 20, color: AppColors.secondary),
                    tooltip: 'Import Exam as Study Deck',
                    onPressed: () => _showImportExamSheet(context, ref),
                  ),
                  const SizedBox(width: 6),
                  // Quick Action 3: AI PDF Study Generator
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.15),
                      padding: const EdgeInsets.all(11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: const Color(0xFF6366F1).withValues(alpha: 0.4)),
                      ),
                    ),
                    icon: const Icon(Icons.auto_awesome, size: 20, color: Color(0xFF6366F1)),
                    tooltip: 'AI PDF Generator (Exams & Decks)',
                    onPressed: () => showAiStudyGeneratorModal(
                      context,
                      ref,
                      defaultSubject: selectedSubjectObj?.name,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Subject Quiz Cards Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'SUBJECT QUIZ CARDS (${displayedSubjectNames.length})',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  Text(
                    'Study or take created quizzes',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Subject Quiz Cards List or Empty State
              if (displayedSubjectNames.isEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1B1B28) : const Color(0xFFF7F7FA),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF2B2B3D) : const Color(0xFFE4E4EC),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.quiz_outlined,
                        size: 40,
                        color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        selectedSubjectObj != null
                            ? 'No quizzes created in "${selectedSubjectObj.name}" yet'
                            : 'No quizzes available for study',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Create an exam in Exam Maker or import a shared deck to study here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.style, size: 16),
                            label: const Text('Create Flashcards'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.secondary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                            onPressed: () => showCreateFlashcardSheet(
                              context: context,
                              initialSubject: selectedSubjectObj?.name,
                            ),
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Create Quiz in Exam Maker'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                            onPressed: () => context.go('/exam/maker'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else ...[
                ...displayedSubjectNames.map((subjName) {
                  final examsInSubj = examsBySubject[subjName] ?? [];
                  return _buildStudySubjectCard(context, subjName, examsInSubj, isDark);
                }),
              ],
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  void _showImportExamSheet(BuildContext context, WidgetRef ref) async {
    final examService = ref.read(examServiceProvider);
    final allExams = examService.allExams;

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Import Exam as Study Deck',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Convert any created or shared exam into a personal study deck with flashcards, practice, and quizzes.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (allExams.isEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No exams found to import.\nCreate an exam in Exam Maker first!',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                  ] else ...[
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 340),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: allExams.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final exam = allExams[i];
                          return ListTile(
                            tileColor: isDark ? const Color(0xFF252538) : const Color(0xFFF4F4F8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.school, color: AppColors.secondary, size: 22),
                            ),
                            title: Text(
                              exam.title,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                            subtitle: Text(
                              'Code: ${exam.code} • ${exam.questions.length} questions',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                            ),
                            trailing: ElevatedButton.icon(
                              icon: const Icon(Icons.download, size: 16),
                              label: const Text('Import'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                minimumSize: Size.zero,
                              ),
                              onPressed: () async {
                                final subj = await ref
                                    .read(studyControllerProvider.notifier)
                                    .importExamAsStudyDeck(exam);
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Imported "${subj.name}" as Study Deck!'),
                                      backgroundColor: AppColors.secondary,
                                    ),
                                  );
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStudySubjectCard(
    BuildContext context,
    String subjectName,
    List<Exam> exams,
    bool isDark,
  ) {
    final totalQuestions = exams.fold(0, (sum, e) => sum + e.questions.length);
    final iconData = _getSubjectIcon(subjectName);
    final isCollapsed = _collapsedStudySubjects.contains(subjectName);
    final bool isAllFlashcards = exams.isNotEmpty && exams.every((e) => e.isFlashcardDeck);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GradientCard(
        padding: const EdgeInsets.all(18),
        borderColor: (isAllFlashcards ? AppColors.tertiary : _getSubjectColor(subjectName)).withValues(alpha: 0.35),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Dropdown Button to Collapse/Expand Quizzes
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (isAllFlashcards ? AppColors.tertiary : _getSubjectColor(subjectName)).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isAllFlashcards ? Icons.style_rounded : iconData,
                    color: isAllFlashcards ? AppColors.tertiary : _getSubjectColor(subjectName),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _toggleSubjectCollapse(subjectName),
                    borderRadius: BorderRadius.circular(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              subjectName,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: (isAllFlashcards ? AppColors.tertiary : AppColors.secondary).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isAllFlashcards ? 'FLASHCARD DECK' : 'STUDY DECK',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: isAllFlashcards ? AppColors.tertiary : AppColors.secondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isAllFlashcards
                              ? '${exams.length} ${exams.length == 1 ? 'Deck' : 'Decks'} • $totalQuestions Flashcards total'
                              : '${exams.length} ${exams.length == 1 ? 'Quiz' : 'Quizzes'} • $totalQuestions Questions total',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Add Flashcard to this subject
                IconButton(
                  icon: const Icon(Icons.style_outlined, color: AppColors.secondary, size: 21),
                  tooltip: 'Create Flashcards for $subjectName',
                  onPressed: () => showCreateFlashcardSheet(
                    context: context,
                    initialSubject: subjectName,
                  ),
                ),
                // Dropdown arrow toggle button
                IconButton(
                  icon: Icon(
                    isCollapsed ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    size: 24,
                  ),
                  tooltip: isCollapsed ? 'Show quizzes' : 'Hide quizzes',
                  onPressed: () => _toggleSubjectCollapse(subjectName),
                ),
              ],
            ),

            // Collapsed indicator or Quizzes List
            if (isCollapsed) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _toggleSubjectCollapse(subjectName),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF14141E) : const Color(0xFFF0F0F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.visibility_off_outlined, size: 14, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                      const SizedBox(width: 6),
                      Text(
                        '${exams.length} ${exams.length == 1 ? (isAllFlashcards ? 'deck' : 'quiz') : (isAllFlashcards ? 'decks' : 'quizzes')} hidden • Tap to open and study',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.secondary),
                    ],
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 14),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: exams.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) {
                  final quiz = exams[i];
                  return _buildStudyQuizTile(context, quiz, isDark);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStudyQuizTile(BuildContext context, Exam quiz, bool isDark) {
    final isFlashcard = quiz.isFlashcardDeck;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14141E) : const Color(0xFFF7F7FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? (isFlashcard ? AppColors.tertiary.withValues(alpha: 0.25) : const Color(0xFF222232))
              : (isFlashcard ? AppColors.tertiary.withValues(alpha: 0.3) : const Color(0xFFE4E4EC)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            quiz.title,
                            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (isFlashcard) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.tertiary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.tertiary.withValues(alpha: 0.35)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.style, size: 10.5, color: AppColors.tertiary),
                                SizedBox(width: 3.5),
                                Text(
                                  'FLASHCARDS',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.tertiary,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (quiz.description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        quiz.cleanDescription.isNotEmpty ? quiz.cleanDescription : quiz.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!isFlashcard) ...[
                // Timer chip for standard timed quizzes
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E2C) : const Color(0xFFEBEBF2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer_outlined, size: 12, color: AppColors.secondary),
                      const SizedBox(width: 3),
                      Text(
                        quiz.durationLabel,
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Card count chip for flashcard decks
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E2C) : const Color(0xFFEBEBF2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.layers_outlined, size: 12, color: AppColors.tertiary),
                      const SizedBox(width: 3),
                      Text(
                        '${quiz.questions.length} cards',
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          // Actions Row: Flip Cards & Type Quiz for Flashcards, or Practice & Take Quiz for Exams
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (isFlashcard) ...[
                // 1. Flip Cards (Review Mode)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.secondary),
                    foregroundColor: AppColors.secondary,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _studyFlashcards(context, quiz, FlashcardStudyMode.review),
                  icon: const Icon(Icons.flip_to_back_rounded, size: 14),
                  label: const Text('Flip Cards', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5)),
                ),
                // 2. Type-in Quiz (Active Recall Mode)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.tertiary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _studyFlashcards(context, quiz, FlashcardStudyMode.quiz),
                  icon: const Icon(Icons.edit_note_rounded, size: 14),
                  label: const Text('Type Quiz', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5)),
                ),
              ] else ...[
                // 1. Practice Button (Study with explanations)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    visualDensity: VisualDensity.compact,
                    side: BorderSide(color: AppColors.secondary.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _practiceExam(context, quiz),
                  icon: const Icon(Icons.lightbulb_outline, size: 14, color: AppColors.secondary),
                  label: const Text('Practice', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: AppColors.secondary)),
                ),
                // 2. Take Quiz Button (Strictly for exams)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _takeExam(context, quiz),
                  icon: const Icon(Icons.play_arrow, size: 14),
                  label: const Text('Take Quiz', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _practiceExam(BuildContext context, Exam quiz) {
    final session = ref.read(studyControllerProvider.notifier).buildQuizSessionForExam(quiz);
    context.push('/study/quiz', extra: session);
  }

  void _studyFlashcards(BuildContext context, Exam quiz, FlashcardStudyMode mode) {
    final questions = quiz.hasQuestionLimit
        ? (quiz.questions.toList()..shuffle()).take(quiz.questionLimit!).toList()
        : quiz.questions;
    context.push(
      '/study/flashcards',
      extra: FlashcardArgs(questions: questions, mode: mode),
    );
  }

  void _takeExam(BuildContext context, Exam quiz) {
    final examService = ref.read(examServiceProvider);
    final participant = examService.joinExam(
      code: quiz.code,
      nickname: 'Creator Study',
    );
    context.push(
      '/exam/play',
      extra: ExamParticipantParam(quiz, participant),
    );
  }

  IconData _getSubjectIcon(String subject) {
    final lower = subject.toLowerCase();
    if (lower.contains('math') || lower.contains('numer')) {
      return Icons.calculate;
    } else if (lower.contains('filipino') || lower.contains('tagalog')) {
      return Icons.translate;
    } else if (lower.contains('english') || lower.contains('verbal') || lower.contains('reading')) {
      return Icons.menu_book;
    } else if (lower.contains('science') || lower.contains('bio') || lower.contains('chem')) {
      return Icons.biotech;
    }
    return Icons.school;
  }

  Color _getSubjectColor(String subject) {
    final lower = subject.toLowerCase();
    if (lower.contains('math')) return AppColors.secondary;
    if (lower.contains('filipino')) return AppColors.primary;
    if (lower.contains('english')) return AppColors.accent;
    if (lower.contains('science')) return AppColors.tertiary;
    return AppColors.highlight;
  }
}
