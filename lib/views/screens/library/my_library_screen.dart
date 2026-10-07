import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/providers.dart';
import '../../../controllers/study_controller.dart';
import '../../../controllers/exam_maker_controller.dart';
import '../../../controllers/exam_participant_controller.dart';
import '../../../models/exam_model.dart';
import '../../../services/exam_service.dart';
import '../../components/common/gradient_card.dart';
import '../../components/common/custom_button.dart';

class MyLibraryScreen extends ConsumerStatefulWidget {
  const MyLibraryScreen({super.key});

  @override
  ConsumerState<MyLibraryScreen> createState() => _MyLibraryScreenState();
}

class _MyLibraryScreenState extends ConsumerState<MyLibraryScreen> {
  String? _selectedSubjectFilter;
  // All subjects start collapsed by default for a clean, uncluttered look
  final Set<String> _expandedSubjects = {};

  bool isSubjectCollapsed(String subject) => !_expandedSubjects.contains(subject);

  void _toggleSubjectCollapse(String subject) {
    setState(() {
      if (_expandedSubjects.contains(subject)) {
        _expandedSubjects.remove(subject);
      } else {
        _expandedSubjects.add(subject);
      }
    });
  }

  void _collapseAll() {
    setState(() {
      _expandedSubjects.clear();
    });
  }

  void _expandAll(List<String> subjects) {
    setState(() {
      _expandedSubjects.addAll(subjects);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authControllerProvider);
    final user = authState.currentUser;

    // Guard: Only authenticated creators can manage their library
    if (!authState.isLoading && !authState.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.go('/login', extra: '/library');
        }
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final examService = ref.watch(examServiceProvider);

    // All available created exams
    final allExams = examService.allExams;

    // Group exams by their Subject
    final Map<String, List<Exam>> examsBySubject = {};
    for (final exam in allExams) {
      final subj = exam.effectiveSubject;
      examsBySubject.putIfAbsent(subj, () => []).add(exam);
    }

    final subjectsList = examsBySubject.keys.toList()..sort();

    // Filtered subjects
    final displayedSubjects = _selectedSubjectFilter == null
        ? subjectsList
        : subjectsList.where((s) => s == _selectedSubjectFilter).toList();

    final allCollapsed = displayedSubjects.isNotEmpty &&
        displayedSubjects.every((s) => !_expandedSubjects.contains(s));

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Library', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ActionChip(
                avatar: const Icon(Icons.person, size: 16, color: AppColors.secondary),
                label: Text(
                  user.name,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
                onPressed: () => _showProfileSheet(context, ref),
              ),
            )
          else
            TextButton.icon(
              icon: const Icon(Icons.login, size: 18),
              label: const Text('Sign In'),
              onPressed: () => context.push('/login'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: ResponsiveContainer(
          maxWidth: 900,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome / Creator Header Card
              GradientCard(
                padding: const EdgeInsets.all(18),
                borderColor: AppColors.secondary.withValues(alpha: 0.4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1: Icon, Title & Description
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E1E2C) : const Color(0xFFECECF2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isDark ? const Color(0xFF28283A) : const Color(0xFFE4E4EC)),
                          ),
                          child: const Icon(Icons.collections_bookmark_outlined, color: AppColors.secondary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user != null ? '${user.name}\'s Library' : 'Creator Library',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Organize quizzes under Subject Cards. Creators save and control their work here.',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.35,
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Row 2: Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.secondary,
                              side: BorderSide(color: AppColors.secondary.withValues(alpha: 0.5)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => _showRestoreExamDialog(context),
                            icon: const Icon(Icons.cloud_download_outlined, size: 16),
                            label: const Text(
                              'Restore Exam',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.secondary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => _handleCreateQuiz(context),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text(
                              'New Quiz',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Frictionless Taker Reminder Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.pin, size: 22, color: AppColors.accent),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Taking an exam? You do NOT need to log in! Enter your 6-character code directly.',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => context.push('/exam/join'),
                      child: const Text(
                        'Join by Code',
                        style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Subject Filter Pills & Collapse Controls
              if (subjectsList.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'SUBJECTS (${subjectsList.length})',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                    Row(
                      children: [
                        if (_selectedSubjectFilter != null) ...[
                          GestureDetector(
                            onTap: () => setState(() => _selectedSubjectFilter = null),
                            child: const Text(
                              'Show All',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.secondary),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        InkWell(
                          onTap: () {
                            if (allCollapsed) {
                              _expandAll(displayedSubjects);
                            } else {
                              _collapseAll();
                            }
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            child: Row(
                              children: [
                                Icon(
                                  allCollapsed ? Icons.unfold_more : Icons.unfold_less,
                                  size: 16,
                                  color: AppColors.secondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  allCollapsed ? 'Expand All' : 'Collapse All',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.secondary),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: Text('All Subjects (${allExams.length})'),
                        selected: _selectedSubjectFilter == null,
                        selectedColor: AppColors.secondary.withValues(alpha: 0.25),
                        checkmarkColor: AppColors.secondary,
                        onSelected: (_) => setState(() => _selectedSubjectFilter = null),
                      ),
                      const SizedBox(width: 8),
                      ...subjectsList.map((subj) {
                        final count = examsBySubject[subj]?.length ?? 0;
                        final isSelected = _selectedSubjectFilter == subj;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text('$subj ($count)'),
                            selected: isSelected,
                            selectedColor: AppColors.secondary.withValues(alpha: 0.25),
                            checkmarkColor: AppColors.secondary,
                            onSelected: (_) {
                              setState(() {
                                _selectedSubjectFilter = isSelected ? null : subj;
                              });
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Collapsible Subject Cards
              if (displayedSubjects.isEmpty)
                _buildEmptyState(context, isDark)
              else
                ...displayedSubjects.map((subjectName) {
                  final subjectExams = examsBySubject[subjectName] ?? [];
                  return _buildSubjectCard(context, subjectName, subjectExams, isDark);
                }),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a dedicated Subject Card with dropdown toggle button
  Widget _buildSubjectCard(
    BuildContext context,
    String subjectName,
    List<Exam> exams,
    bool isDark,
  ) {
    final totalQuestions = exams.fold(0, (sum, e) => sum + e.questions.length);
    final iconData = _getSubjectIcon(subjectName);
    final isCollapsed = !_expandedSubjects.contains(subjectName);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: GradientCard(
        padding: const EdgeInsets.all(20),
        borderColor: _getSubjectColor(subjectName).withValues(alpha: 0.4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subject Card Header with Dropdown Button to Hide/Show Quizzes
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(iconData, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
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
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'SUBJECT',
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.secondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${exams.length} ${exams.length == 1 ? 'Quiz' : 'Quizzes'} • $totalQuestions Questions',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Add Quiz to this specific subject button
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: AppColors.secondary, size: 22),
                  tooltip: 'Add new quiz to $subjectName',
                  onPressed: () => _handleAddQuizToSubject(context, subjectName),
                ),
                // Share entire subject by code button
                IconButton(
                  icon: const Icon(Icons.share_outlined, color: AppColors.secondary, size: 21),
                  tooltip: 'Share all "$subjectName" exams by code',
                  onPressed: () => _showShareSubjectDialog(context, subjectName, exams),
                ),
                // Dropdown button to collapse/hide or expand all quizzes
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

            // When collapsed, show a compact tap-to-show helper
            if (isCollapsed) ...[
              const SizedBox(height: 10),
              InkWell(
                onTap: () => _toggleSubjectCollapse(subjectName),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF14141E) : const Color(0xFFF0F0F6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? const Color(0xFF222232) : const Color(0xFFE2E2EC)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.visibility_off_outlined,
                        size: 15,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${exams.length} ${exams.length == 1 ? 'quiz' : 'quizzes'} hidden • Tap to view or manage',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.secondary),
                    ],
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Quizzes List inside this Subject Card (e.g. Quiz 1, Quiz 2)
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: exams.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (ctx, index) {
                  final quiz = exams[index];
                  return _buildQuizTile(context, quiz, index, isDark);
                },
              ),
            ],
          ],
        ),
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
                    // Title gets full line width
                    Text(
                      quiz.title,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    // Badges like Live and Code underneath the title
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Live / Stopped Indicator
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: isLive
                                ? AppColors.success.withValues(alpha: 0.15)
                                : (isDark ? const Color(0xFF2A2A38) : const Color(0xFFE5E5ED)),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isLive ? AppColors.success.withValues(alpha: 0.4) : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isLive ? AppColors.success : Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isLive ? 'LIVE' : 'STOPPED',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: isLive
                                      ? AppColors.success
                                      : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // 6-character Code pill with copy
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: quiz.code));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Copied Exam Code: ${quiz.code}'),
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.pin, size: 12, color: AppColors.secondary),
                                const SizedBox(width: 3),
                                Text(
                                  quiz.code,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                    color: AppColors.secondary,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                const Icon(Icons.copy, size: 11, color: AppColors.secondary),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (quiz.description.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        quiz.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Creator Controls Row: Questions count, Timer button, Start/Stop toggle, Take Quiz, Dashboard
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '${quiz.questions.length} Questions',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  // Creator Timer Control Button
                  InkWell(
                    onTap: () => _showEditTimerDialog(context, quiz),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E2C) : const Color(0xFFEBEBF2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? const Color(0xFF2C2C3E) : const Color(0xFFDCDCE8),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer_outlined, size: 13, color: AppColors.secondary),
                          const SizedBox(width: 4),
                          Text(
                            quiz.durationLabel,
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 3),
                          const Icon(Icons.edit, size: 11, color: AppColors.secondary),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Start / Stop Quiz Toggle Button
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      visualDensity: VisualDensity.compact,
                      side: BorderSide(
                        color: isLive ? AppColors.error.withValues(alpha: 0.5) : AppColors.success.withValues(alpha: 0.6),
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _handleToggleStatus(context, quiz),
                    icon: Icon(
                      isLive ? Icons.pause_circle_outline : Icons.play_circle_outline,
                      size: 15,
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
                  // Take Quiz Button
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
                  // Edit Quiz Button
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      visualDensity: VisualDensity.compact,
                      side: BorderSide(color: AppColors.secondary.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => context.push('/exam/maker', extra: quiz),
                    icon: const Icon(Icons.edit_outlined, size: 14, color: AppColors.secondary),
                    label: const Text(
                      'Edit',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: AppColors.secondary),
                    ),
                  ),
                  // Dashboard Button
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      visualDensity: VisualDensity.compact,
                      side: BorderSide(color: AppColors.secondary.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => context.push('/exam/dashboard/${quiz.id}'),
                    icon: const Icon(Icons.analytics_outlined, size: 14, color: AppColors.secondary),
                    label: const Text(
                      'Stats',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: AppColors.secondary),
                    ),
                  ),
                  // Backup / Export Button
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      visualDensity: VisualDensity.compact,
                      side: BorderSide(color: isDark ? Colors.white24 : Colors.black26),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _handleBackupExam(context, quiz),
                    icon: const Icon(Icons.share_outlined, size: 14),
                    label: const Text(
                      'Backup',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            ],
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
              title: Row(
                children: [
                  const Icon(Icons.timer_outlined, color: AppColors.secondary, size: 22),
                  const SizedBox(width: 8),
                  const Text('Set Quiz Timer', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
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

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.school_outlined, size: 64, color: AppColors.secondary.withValues(alpha: 0.6)),
            const SizedBox(height: 14),
            const Text(
              'No Quizzes in Library',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Create your first subject and quiz now to get started.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 20),
            CustomButton(
              text: 'Create First Quiz',
              icon: Icons.add,
              variant: ButtonVariant.primaryGradient,
              onPressed: () => _handleCreateQuiz(context),
            ),
          ],
        ),
      ),
    );
  }

  void _handleCreateQuiz(BuildContext context) {
    final authState = ref.read(authControllerProvider);
    if (!authState.isAuthenticated) {
      context.push('/login', extra: '/exam/maker');
      return;
    }
    context.push('/exam/maker');
  }

  void _handleAddQuizToSubject(BuildContext context, String subjectName) {
    final authState = ref.read(authControllerProvider);
    if (!authState.isAuthenticated) {
      ref.read(examMakerControllerProvider.notifier).setSubject(subjectName);
      context.push('/login', extra: '/exam/maker');
      return;
    }
    ref.read(examMakerControllerProvider.notifier).setSubject(subjectName);
    context.push('/exam/maker');
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

  void _showProfileSheet(BuildContext context, WidgetRef ref) {
    final user = ref.read(authControllerProvider).currentUser;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.secondary,
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user.name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    user.email,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 20),
                  CustomButton(
                    text: 'Log Out',
                    variant: ButtonVariant.outline,
                    width: double.infinity,
                    onPressed: () async {
                      await ref.read(authControllerProvider.notifier).logout();
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'All ${exams.length} quizzes in "$subjectName" (${bundle.totalQuestions} questions) are bundled into this unique code.\n'
                    'Share it with another phone, and all quizzes will become theirs in their library!',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Big Unique Code Display
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.secondary.withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'UNIQUE SUBJECT SHARE CODE',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: AppColors.secondary),
                        ),
                        const SizedBox(height: 6),
                        SelectableText(
                          bundle.code,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            fontFamily: 'monospace',
                            color: AppColors.secondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Guaranteed unique & conflict-free',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Quizzes Included Preview
                  Text(
                    'QUIZZES INCLUDED (${exams.length}):',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 6),
                  ...exams.take(4).map((e) => Padding(
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
                  )),
                  if (exams.length > 4)
                    Text('+ ${exams.length - 4} more quizzes', style: const TextStyle(fontSize: 11, color: Colors.grey)),

                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF14141E) : const Color(0xFFECECF2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: AppColors.secondary),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'On Device B: Open My Library ➔ Restore Exam ➔ enter this code to make all quizzes theirs.',
                            style: TextStyle(fontSize: 11.5, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: const Text('Close'),
            ),
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: bundle.bundleJson));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Full Subject Bundle JSON copied to clipboard!'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.copy_all, size: 16),
              label: const Text('Copy Bundle JSON'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: bundle.code));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Subject Code "${bundle.code}" copied to clipboard!'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy Code'),
            ),
          ],
        );
      },
    );
  }

  void _showRestoreExamDialog(BuildContext context) {
    final codeController = TextEditingController();
    final jsonController = TextEditingController();
    bool isRestoring = false;
    bool showJsonPaste = false;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.cloud_download, color: AppColors.secondary),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Restore Exam or Entire Subject',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Enter a 6-character Exam Code (e.g. 4F9K2Q) or a Unique Subject Code (e.g. SUB-ENG-7K2M) to import all exams in that category:',
                        style: TextStyle(fontSize: 12, height: 1.35),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: codeController,
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 28,
                        decoration: InputDecoration(
                          labelText: 'Exam Code or Subject Code',
                          hintText: 'e.g. 4F9K2Q or SUB-ENG-7K2M...',
                          prefixIcon: const Icon(Icons.pin, color: AppColors.secondary),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () => setDialogState(() => showJsonPaste = !showJsonPaste),
                            child: Text(
                              showJsonPaste ? 'Hide JSON backup input' : 'Or paste backup JSON / bundle...',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      if (showJsonPaste) ...[
                        const SizedBox(height: 6),
                        TextField(
                          controller: jsonController,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: 'Paste single exam JSON or Subject Bundle JSON here...',
                            hintStyle: const TextStyle(fontSize: 11),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.all(10),
                          ),
                          onChanged: (_) => setDialogState(() {}),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isRestoring
                      ? null
                      : () async {
                          final code = codeController.text.trim().toUpperCase();
                          final rawJson = jsonController.text.trim();

                          if (code.isEmpty && rawJson.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter an exam code, subject code, or paste backup JSON.'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isRestoring = true);
                          try {
                            final examService = ref.read(examServiceProvider);
                            final currentUser = ref.read(authControllerProvider).currentUser;
                            final currentUserId = currentUser?.id ?? currentUser?.name ?? 'creator_local';

                            // 1. Check if input is a Subject Code or Subject Bundle JSON
                            final isSubjectCode = code.startsWith('SUB-') || code.startsWith('SUB_');
                            final isBundleJson = rawJson.contains('"subject_bundle"');

                            if (isSubjectCode || isBundleJson) {
                              final target = rawJson.isNotEmpty ? rawJson : code;
                              final imported = await examService.importSubjectBundle(
                                target,
                                newCreatorId: currentUserId,
                              );

                              for (final ex in imported) {
                                try {
                                  await ref.read(studyControllerProvider.notifier).syncCreatedExam(ex);
                                } catch (_) {}
                              }

                              if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Successfully imported all ${imported.length} exams in "${imported.first.effectiveSubject}"! They are now in your library.',
                                    ),
                                    backgroundColor: AppColors.success,
                                    duration: const Duration(seconds: 4),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                              return;
                            }

                            // 2. Check if raw JSON for single exam
                            if (rawJson.isNotEmpty) {
                              final map = jsonDecode(rawJson) as Map<String, dynamic>;
                              final exam = Exam.fromJson(map).copyWith(creatorId: currentUserId);
                              await examService.updateExam(exam);
                              try {
                                await ref.read(studyControllerProvider.notifier).syncCreatedExam(exam);
                              } catch (_) {}
                              if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Exam "${exam.title}" restored successfully!'),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              }
                              return;
                            }

                            // 3. Check if standard 6-character exam code
                            final exam = await examService.getOrFetchExamByCode(code);
                            if (exam != null) {
                              // Assign ownership if imported
                              final ownedExam = exam.copyWith(creatorId: currentUserId);
                              await examService.updateExam(ownedExam);
                              try {
                                await ref.read(studyControllerProvider.notifier).syncCreatedExam(ownedExam);
                              } catch (_) {}
                              if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Exam "${ownedExam.title}" (Code: $code) restored to your library!'),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              }
                            } else {
                              setDialogState(() => isRestoring = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Code "$code" not found. Check that it is typed correctly.'),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            setDialogState(() => isRestoring = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Import/Restore failed: $e'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          }
                        },
                  child: isRestoring
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Restore / Import'),
                ),
              ],
            );
          },
        );
      },
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
    } else if (lower.contains('civil') || lower.contains('consti') || lower.contains('gov')) {
      return Icons.account_balance;
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
