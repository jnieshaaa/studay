import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../models/exam_model.dart';
import '../../../models/question_model.dart';
import '../../../controllers/providers.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/exam_maker_controller.dart';
import '../../../controllers/exam_participant_controller.dart';
import '../../../services/exam_service.dart';
import '../../components/common/gradient_card.dart';
import '../../components/common/custom_button.dart';
import '../study/flashcards_screen.dart';
import '../study/create_flashcard_sheet.dart';
import '../exam/exam_maker_screen.dart';
import '../exam/exam_dashboard_screen.dart';

/// Screen displayed when clicking a subject card in My Library.
/// Displays all quizzes, decks, and creator controls for the selected subject.
class SubjectQuizzesScreen extends ConsumerStatefulWidget {
  final String subjectName;

  const SubjectQuizzesScreen({
    super.key,
    required this.subjectName,
  });

  @override
  ConsumerState<SubjectQuizzesScreen> createState() => _SubjectQuizzesScreenState();
}

class _SubjectQuizzesScreenState extends ConsumerState<SubjectQuizzesScreen> {
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final examService = ref.watch(examServiceProvider);

    // Get all exams belonging to this clicked subject
    final subjectExams = examService.allExams
        .where((e) => e.effectiveSubject.toLowerCase() == widget.subjectName.toLowerCase())
        .toList();

    final totalQuestions = subjectExams.fold(0, (sum, e) => sum + e.questions.length);
    final liveCount = subjectExams.where((e) => e.status == ExamStatus.published).length;
    final subjectColor = _getSubjectColor(widget.subjectName);
    final iconData = _getSubjectIcon(widget.subjectName);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.subjectName,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            Text(
              '${subjectExams.length} ${subjectExams.length == 1 ? 'Quiz' : 'Quizzes'} • $totalQuestions Questions',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
        actions: [
          // Share entire subject by code button
          IconButton(
            icon: const Icon(Icons.share_outlined, color: AppColors.secondary, size: 21),
            tooltip: 'Share all "${widget.subjectName}" exams by code',
            onPressed: () => _showShareSubjectDialog(context, widget.subjectName, subjectExams),
          ),
          // Add Quiz to this subject button
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: AppColors.secondary, size: 22),
            tooltip: 'Add new quiz to ${widget.subjectName}',
            onPressed: () => _handleAddQuizToSubject(context, widget.subjectName),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: ResponsiveContainer(
          maxWidth: 820,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),

              // Subject Banner Card
              GradientCard(
                padding: const EdgeInsets.all(16),
                borderColor: subjectColor.withValues(alpha: 0.35),
                child: LayoutBuilder(
                  builder: (ctx, constraints) {
                    final isNarrow = constraints.maxWidth < 460;
                    final infoWidget = Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(iconData, color: Colors.white, size: 26),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      widget.subjectName,
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.secondary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'SUBJECT',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.secondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${subjectExams.length} ${subjectExams.length == 1 ? 'Quiz' : 'Quizzes'} • $totalQuestions Questions total • $liveCount Live',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );

                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          infoWidget,
                          const SizedBox(height: 12),
                          CustomButton(
                            text: '+ Add to ${widget.subjectName}',
                            icon: Icons.add,
                            width: double.infinity,
                            variant: ButtonVariant.primaryGradient,
                            height: 36,
                            onPressed: () => _handleAddQuizToSubject(context, widget.subjectName),
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: infoWidget),
                        const SizedBox(width: 12),
                        CustomButton(
                          text: '+ Add to Subject',
                          icon: Icons.add,
                          variant: ButtonVariant.primaryGradient,
                          height: 38,
                          onPressed: () => _handleAddQuizToSubject(context, widget.subjectName),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Header for Quizzes List
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'QUIZZES & DECKS IN ${widget.subjectName.toUpperCase()}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  Text(
                    '${subjectExams.length} items',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // List of Quizzes or Empty State
              if (subjectExams.isEmpty)
                _buildEmptyState(context, isDark)
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: subjectExams.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, index) {
                    final quiz = subjectExams[index];
                    return _buildQuizTile(context, quiz, index, isDark);
                  },
                ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14141E) : const Color(0xFFF7F7FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF242436) : const Color(0xFFE4E4EC),
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.quiz_outlined, size: 48, color: isDark ? Colors.white24 : Colors.black26),
          const SizedBox(height: 12),
          Text(
            'No Quizzes in ${widget.subjectName} yet',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Create your first quiz or flashcard deck for ${widget.subjectName}.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 18),
          CustomButton(
            text: 'Create Quiz in ${widget.subjectName}',
            icon: Icons.add,
            variant: ButtonVariant.primaryGradient,
            onPressed: () => _handleAddQuizToSubject(context, widget.subjectName),
          ),
        ],
      ),
    );
  }

  /// Builds an individual quiz row with Creator Controls (Start/Stop, Timer, Take Quiz)
  Widget _buildQuizTile(BuildContext context, Exam quiz, int index, bool isDark) {
    final isLive = quiz.status == ExamStatus.published;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14141E) : const Color(0xFFF7F7FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF242436) : const Color(0xFFE6E6EE),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Q1 number + Full Title on top, with Live & Code badges underneath
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'Q${index + 1}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quiz.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Live / Stopped Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: (isLive ? AppColors.success : AppColors.error).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isLive ? 'LIVE' : 'STOPPED',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: isLive ? AppColors.success : AppColors.error,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        // 6-Character Join Code Pill
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: quiz.code));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Copied code "${quiz.code}" to clipboard!'),
                                duration: const Duration(seconds: 1),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'CODE: ${quiz.code}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.secondary,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                const Icon(Icons.copy, size: 10, color: AppColors.secondary),
                              ],
                            ),
                          ),
                        ),
                        // FLASHCARDS Badge if applicable
                        if (quiz.isFlashcardDeck)
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
                                Icon(Icons.style_rounded, size: 10.5, color: AppColors.tertiary),
                                SizedBox(width: 3),
                                Text(
                                  'FLASHCARDS',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.tertiary,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // Three vertical dots menu for Edit, Stats, Backup, and Delete
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  size: 20,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
                tooltip: 'Options for ${quiz.title}',
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: isDark ? const Color(0xFF28283C) : const Color(0xFFE4E4EC),
                  ),
                ),
                color: isDark ? const Color(0xFF1B1B26) : Colors.white,
                elevation: 6,
                onSelected: (action) {
                  switch (action) {
                    case 'edit':
                      if (quiz.isFlashcardDeck) {
                        showCreateFlashcardSheet(
                          context: context,
                          initialSubject: quiz.effectiveSubject,
                          existingDeck: quiz,
                        );
                      } else {
                        if (GoRouter.maybeOf(context) != null) {
                          context.push('/exam/maker', extra: quiz);
                        } else {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => ExamMakerScreen(initialExam: quiz)),
                          );
                        }
                      }
                      break;
                    case 'stats':
                      if (GoRouter.maybeOf(context) != null) {
                        context.push('/exam/dashboard/${quiz.id}');
                      } else {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => ExamDashboardScreen(examId: quiz.id)),
                        );
                      }
                      break;
                    case 'backup':
                      _handleBackupExam(context, quiz);
                      break;
                    case 'delete':
                      _confirmDeleteQuiz(context, quiz);
                      break;
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem<String>(
                    value: 'edit',
                    child: Row(
                      children: [
                        const Icon(Icons.edit_outlined, size: 18, color: AppColors.secondary),
                        const SizedBox(width: 10),
                        const Text(
                          'Edit',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'stats',
                    child: Row(
                      children: [
                        const Icon(Icons.analytics_outlined, size: 18, color: AppColors.accent),
                        const SizedBox(width: 10),
                        const Text(
                          'Stats',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'backup',
                    child: Row(
                      children: [
                        Icon(
                          Icons.cloud_download_outlined,
                          size: 18,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Backup',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(height: 1),
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                        const SizedBox(width: 10),
                        const Text(
                          'Delete',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          if (quiz.cleanDescription.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 44),
              child: Text(
                quiz.cleanDescription,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),

          // Pills row: Questions count, Question Limit Pill, Timer Pill, Schedule Pill
          Padding(
            padding: const EdgeInsets.only(left: 44),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E2C) : const Color(0xFFEBEBF2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${quiz.questions.length} Questions',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
                  ),
                ),
                // Question limit setting chip
                InkWell(
                  onTap: () => _showEditQuestionLimitDialog(context, quiz),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: quiz.hasQuestionLimit
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : (isDark ? const Color(0xFF1E1E2C) : const Color(0xFFEBEBF2)),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: quiz.hasQuestionLimit
                            ? AppColors.primary.withValues(alpha: 0.4)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.shuffle_rounded,
                          size: 11,
                          color: quiz.hasQuestionLimit ? AppColors.primary : AppColors.secondary,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          quiz.questionLimitLabel,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: quiz.hasQuestionLimit ? AppColors.primary : null,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.edit, size: 9, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                // Timer Chip (tap to edit)
                InkWell(
                  onTap: () => _showEditTimerDialog(context, quiz),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: quiz.durationMinutes != null && quiz.durationMinutes! > 0
                          ? AppColors.secondary.withValues(alpha: 0.15)
                          : (isDark ? const Color(0xFF1E1E2C) : const Color(0xFFEBEBF2)),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: quiz.durationMinutes != null && quiz.durationMinutes! > 0
                            ? AppColors.secondary.withValues(alpha: 0.4)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer_outlined, size: 11, color: AppColors.secondary),
                        const SizedBox(width: 3),
                        Text(
                          quiz.durationLabel,
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.edit, size: 9, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                // Schedule pill
                InkWell(
                  onTap: () => _showScheduleDialog(context, quiz),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: quiz.isScheduled
                          ? AppColors.accent.withValues(alpha: 0.15)
                          : (isDark ? const Color(0xFF1E1E2C) : const Color(0xFFEBEBF2)),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: quiz.isScheduled
                            ? AppColors.accent.withValues(alpha: 0.4)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 10, color: AppColors.accent),
                        const SizedBox(width: 3),
                        Text(
                          quiz.isScheduled ? 'Scheduled' : 'No Schedule',
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.edit, size: 9, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Actions Row: Start/Stop Live, Take Quiz / Flashcard Modes, Edit, Dashboard, Backup
          Padding(
            padding: const EdgeInsets.only(left: 44),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                // Start / Stop Toggle Button
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    visualDensity: VisualDensity.compact,
                    side: BorderSide(
                      color: isLive ? AppColors.error : AppColors.success,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _handleToggleStatus(context, quiz),
                  icon: Icon(
                    isLive ? Icons.pause_circle_outline : Icons.play_circle_outline,
                    size: 14,
                    color: isLive ? AppColors.error : AppColors.success,
                  ),
                  label: Text(
                    isLive ? 'Stop' : 'Start',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                      color: isLive ? AppColors.error : AppColors.success,
                    ),
                  ),
                ),
                // Action Buttons: Flip Cards & Type Quiz for Flashcards, or Take Quiz for Exams
                if (quiz.isFlashcardDeck) ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.secondary),
                      foregroundColor: AppColors.secondary,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      final sampleQuestions = quiz.hasQuestionLimit
                          ? (List<Question>.from(quiz.questions)..shuffle()).take(quiz.questionLimit!).toList()
                          : quiz.questions;
                      context.push(
                        '/study/flashcards',
                        extra: FlashcardArgs(questions: sampleQuestions, mode: FlashcardStudyMode.review),
                      );
                    },
                    icon: const Icon(Icons.flip_to_back_rounded, size: 14),
                    label: const Text('Flip Cards', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5)),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.tertiary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      final sampleQuestions = quiz.hasQuestionLimit
                          ? (List<Question>.from(quiz.questions)..shuffle()).take(quiz.questionLimit!).toList()
                          : quiz.questions;
                      context.push(
                        '/study/flashcards',
                        extra: FlashcardArgs(questions: sampleQuestions, mode: FlashcardStudyMode.quiz),
                      );
                    },
                    icon: const Icon(Icons.edit_note_rounded, size: 14),
                    label: const Text('Type Quiz', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5)),
                  ),
                ] else ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _launchQuiz(context, quiz),
                    icon: const Icon(Icons.play_arrow, size: 15),
                    label: const Text('Take Quiz', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Toggle Active/Stopped status of the quiz
  Future<void> _handleToggleStatus(BuildContext context, Exam quiz) async {
    final isCurrentlyLive = quiz.status == ExamStatus.published;
    await ref.read(examServiceProvider).toggleExamStatus(quiz.id);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isCurrentlyLive
                ? '"${quiz.title}" stopped. Takers cannot join while stopped.'
                : '"${quiz.title}" started and open for participants!',
          ),
          backgroundColor: isCurrentlyLive ? AppColors.error : AppColors.success,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Dialog to view/change quiz countdown timer
  void _showEditTimerDialog(BuildContext context, Exam quiz) {
    int? selectedMins = quiz.durationMinutes;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return AlertDialog(
              backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.timer_outlined, color: AppColors.secondary, size: 22),
                  SizedBox(width: 8),
                  Text('Set Quiz Timer', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Set a countdown limit for "${quiz.title}". Takers will see a live timer bar during the quiz.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      null, // Untimed
                      5,
                      10,
                      15,
                      30,
                      45,
                      60,
                    ].map((mins) {
                      final isSelected = selectedMins == mins;
                      final label = mins == null ? 'Untimed' : '${mins}m';
                      return ChoiceChip(
                        label: Text(label),
                        selected: isSelected,
                        selectedColor: AppColors.secondary.withValues(alpha: 0.25),
                        checkmarkColor: AppColors.secondary,
                        onSelected: (_) {
                          setDialogState(() {
                            selectedMins = mins;
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    await ref.read(examServiceProvider).updateExamTimer(quiz.id, selectedMins);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            selectedMins == null
                                ? 'Timer removed for "${quiz.title}"'
                                : 'Timer set to ${selectedMins}m for "${quiz.title}"',
                          ),
                          backgroundColor: AppColors.secondary,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  child: const Text('Save Timer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditQuestionLimitDialog(BuildContext context, Exam quiz) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    int? selectedLimit = quiz.questionLimit;
    final customController = TextEditingController(
      text: quiz.questionLimit != null && quiz.questionLimit! > 0
          ? '${quiz.questionLimit}'
          : '',
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.shuffle_rounded, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text('Questions Per Exam', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Set how many questions will randomly appear in "${quiz.title}" (Total in bank: ${quiz.questions.length}). Questions will never repeat.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      null, // All
                      10,
                      20,
                      25,
                      50,
                    ].where((n) => n == null || n < quiz.questions.length).map((limit) {
                      final isSelected = selectedLimit == limit;
                      final label = limit == null ? 'All (${quiz.questions.length})' : '$limit Qs';
                      return ChoiceChip(
                        label: Text(label),
                        selected: isSelected,
                        selectedColor: AppColors.primary.withValues(alpha: 0.25),
                        checkmarkColor: AppColors.primary,
                        onSelected: (_) {
                          setDialogState(() {
                            selectedLimit = limit;
                            customController.text = limit == null ? '' : '$limit';
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: customController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Custom Item Count',
                      hintText: 'e.g. 20',
                      prefixIcon: const Icon(Icons.pin, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (val) {
                      final parsed = int.tryParse(val.trim());
                      setDialogState(() {
                        selectedLimit = (parsed != null && parsed > 0 && parsed < quiz.questions.length)
                            ? parsed
                            : null;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    await ref.read(examServiceProvider).updateExamQuestionLimit(quiz.id, selectedLimit);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            selectedLimit == null
                                ? 'Displaying all ${quiz.questions.length} questions for "${quiz.title}"'
                                : 'Sample size set to $selectedLimit unique questions for "${quiz.title}"',
                          ),
                          backgroundColor: AppColors.primary,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  child: const Text('Save Limit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showScheduleDialog(BuildContext context, Exam quiz) {
    DateTime? selectedStart = quiz.opensAt;
    DateTime? selectedEnd = quiz.closesAt;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return AlertDialog(
              backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.calendar_today_outlined, color: AppColors.accent, size: 22),
                  SizedBox(width: 8),
                  Text('Schedule Exam Access', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Optional access window for "${quiz.title}". Participants can only take the exam between the start and end dates.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.login, color: AppColors.success),
                    title: const Text('Opens At', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    subtitle: Text(
                      selectedStart != null
                          ? '${selectedStart!.month}/${selectedStart!.day}/${selectedStart!.year} ${selectedStart!.hour}:${selectedStart!.minute.toString().padLeft(2, '0')}'
                          : 'Immediate access',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: TextButton(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedStart ?? DateTime.now(),
                          firstDate: DateTime.now().subtract(const Duration(days: 1)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null && context.mounted) {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(selectedStart ?? DateTime.now()),
                          );
                          if (time != null) {
                            setDialogState(() {
                              selectedStart = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                            });
                          }
                        }
                      },
                      child: const Text('Change'),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.timer_off_outlined, color: AppColors.error),
                    title: const Text('Closes At', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    subtitle: Text(
                      selectedEnd != null
                          ? '${selectedEnd!.month}/${selectedEnd!.day}/${selectedEnd!.year} ${selectedEnd!.hour}:${selectedEnd!.minute.toString().padLeft(2, '0')}'
                          : 'No deadline set',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: TextButton(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedEnd ?? DateTime.now().add(const Duration(days: 7)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null && context.mounted) {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(selectedEnd ?? DateTime.now()),
                          );
                          if (time != null) {
                            setDialogState(() {
                              selectedEnd = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                            });
                          }
                        }
                      },
                      child: const Text('Change'),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setDialogState(() {
                      selectedStart = null;
                      selectedEnd = null;
                    });
                  },
                  child: const Text('Clear Schedule', style: TextStyle(color: Colors.grey)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    await ref.read(examServiceProvider).updateExamSchedule(quiz.id, selectedStart, selectedEnd);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Exam schedule updated successfully!'),
                          backgroundColor: AppColors.accent,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  child: const Text('Save Schedule'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteQuiz(BuildContext context, Exam quiz) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.error),
            const SizedBox(width: 8),
            const Text('Delete Quiz?'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${quiz.title}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(examServiceProvider).deleteExam(quiz.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Deleted "${quiz.title}".'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _handleAddQuizToSubject(BuildContext context, String subjectName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (bCtx) {
        final isDark = Theme.of(bCtx).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B1B26) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Add to "$subjectName"',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose what you would like to create in $subjectName:',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                tileColor: isDark ? const Color(0xFF14141E) : const Color(0xFFF7F7FA),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.quiz_outlined, color: AppColors.primary, size: 22),
                ),
                title: const Text('Exam / Quiz', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text('Multiple Choice, True/False, Matching Type tests with timer & scoring', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(bCtx);
                  final authState = ref.read(authControllerProvider);
                  if (!authState.isAuthenticated) {
                    ref.read(examMakerControllerProvider.notifier).setSubject(subjectName);
                    context.push('/login', extra: '/exam/maker');
                    return;
                  }
                  ref.read(examMakerControllerProvider.notifier).setSubject(subjectName);
                  context.push('/exam/maker');
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                tileColor: isDark ? const Color(0xFF14141E) : const Color(0xFFF7F7FA),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.tertiary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.style_rounded, color: AppColors.tertiary, size: 22),
                ),
                title: const Text('Flashcard Deck', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text('Front & back study cards for review flipping and type-in recall', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(bCtx);
                  showCreateFlashcardSheet(
                    context: context,
                    initialSubject: subjectName,
                  );
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  void _launchQuiz(BuildContext context, Exam quiz) {
    final examService = ref.read(examServiceProvider);
    final participant = examService.joinExam(
      code: quiz.code,
      nickname: ref.read(authControllerProvider).currentUser?.name ?? 'Learner',
    );

    context.push(
      '/exam/play',
      extra: ExamParticipantParam(quiz, participant),
    );
  }

  void _handleBackupExam(BuildContext context, Exam quiz) {
    final jsonStr = jsonEncode(quiz.toJson());
    Clipboard.setData(ClipboardData(text: jsonStr));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Backup for "${quiz.title}" (Code: ${quiz.code}) copied to clipboard! You can paste or save it anywhere.',
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showShareSubjectDialog(BuildContext context, String subjectName, List<Exam> exams) async {
    final examService = ref.read(examServiceProvider);
    SubjectBundleResult bundle;
    try {
      bundle = await examService.exportSubjectBundle(subjectName);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share subject: $e'), backgroundColor: AppColors.error),
        );
      }
      return;
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (dlgCtx) {
        final isDark = Theme.of(dlgCtx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppColors.flameGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.share, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Share "$subjectName"',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Share this entire subject category (${exams.length} ${exams.length == 1 ? 'quiz' : 'quizzes'}). When imported by another creator or learner, fresh unique codes are generated to guarantee zero conflict!',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 16),

                // Unique Subject Share Code Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.secondary.withValues(alpha: 0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.key, size: 14, color: AppColors.secondary),
                          SizedBox(width: 6),
                          Text(
                            'UNIQUE SUBJECT SHARE CODE',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.secondary,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        bundle.subjectCode,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          color: AppColors.secondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Guaranteed unique & conflict-free',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Summary of quizzes included
                Text(
                  'Included Quizzes (${exams.length}):',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                ...exams.take(5).map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline, size: 14, color: AppColors.success),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${e.title} (${e.questions.length} Qs)',
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                if (exams.length > 5)
                  Text(
                    '+ ${exams.length - 5} more quizzes...',
                    style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white54 : Colors.black45),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: bundle.subjectCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Copied subject share code "${bundle.subjectCode}"!'),
                    backgroundColor: AppColors.secondary,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy Code'),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: bundle.bundleJson));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Copied entire Subject Bundle JSON!'),
                    backgroundColor: AppColors.primary,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.data_object, size: 16),
              label: const Text('Copy Bundle JSON'),
            ),
          ],
        );
      },
    );
  }
}
