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
import '../../../models/exam_model.dart';
import '../../../services/exam_service.dart';
import '../../components/common/gradient_card.dart';
import '../../components/common/custom_button.dart';
import '../../components/common/ai_study_generator_modal.dart';
import 'subject_quizzes_screen.dart';

class MyLibraryScreen extends ConsumerStatefulWidget {
  const MyLibraryScreen({super.key});

  @override
  ConsumerState<MyLibraryScreen> createState() => _MyLibraryScreenState();
}

class _MyLibraryScreenState extends ConsumerState<MyLibraryScreen> {
  String? _selectedSubjectFilter;

  void _openSubject(BuildContext context, String subjectName) {
    if (GoRouter.maybeOf(context) != null) {
      context.push('/library/subject', extra: subjectName);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SubjectQuizzesScreen(subjectName: subjectName),
        ),
      );
    }
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Library', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: Color(0xFF6366F1)),
            tooltip: 'AI Study Generator',
            onPressed: () => showAiStudyGeneratorModal(context, ref),
          ),
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
                                'Organize quizzes under Subject Cards. Tap any subject to view and manage quizzes.',
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
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
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
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          onPressed: () => showAiStudyGeneratorModal(context, ref),
                          icon: const Icon(Icons.auto_awesome, size: 15),
                          label: const Text(
                            'AI PDF Generator',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                          ),
                        ),
                        ElevatedButton.icon(
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

              // Clean Subject Dropdown Filter
              if (subjectsList.isNotEmpty) ...[
                Container(
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
                      value: _selectedSubjectFilter ?? '__ALL__',
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
                                color: (_selectedSubjectFilter == null || _selectedSubjectFilter == '__ALL__')
                                    ? AppColors.secondary
                                    : (isDark ? Colors.white70 : Colors.black87),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'All Subjects (${allExams.length})',
                                style: TextStyle(
                                  fontWeight: (_selectedSubjectFilter == null || _selectedSubjectFilter == '__ALL__')
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: (_selectedSubjectFilter == null || _selectedSubjectFilter == '__ALL__')
                                      ? AppColors.secondary
                                      : null,
                                  fontSize: 13.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...subjectsList.map((subj) {
                          final count = examsBySubject[subj]?.length ?? 0;
                          final isSelected = _selectedSubjectFilter == subj;
                          return DropdownMenuItem<String>(
                            value: subj,
                            child: Row(
                              children: [
                                Icon(
                                  _getSubjectIcon(subj),
                                  size: 18,
                                  color: isSelected ? AppColors.secondary : _getSubjectColor(subj),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '$subj ($count)',
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
                      onChanged: (newSubj) {
                        setState(() {
                          _selectedSubjectFilter =
                              (newSubj == null || newSubj == '__ALL__') ? null : newSubj;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // Clickable Subject Cards
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

  /// Builds a clickable Subject Card. Tapping it opens SubjectQuizzesScreen.
  Widget _buildSubjectCard(
    BuildContext context,
    String subjectName,
    List<Exam> exams,
    bool isDark,
  ) {
    final iconData = _getSubjectIcon(subjectName);
    final subjectColor = _getSubjectColor(subjectName);
    final liveCount = exams.where((e) => e.status == ExamStatus.published).length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GradientCard(
        padding: EdgeInsets.zero,
        borderColor: subjectColor.withValues(alpha: 0.35),
        child: InkWell(
          onTap: () => _openSubject(context, subjectName),
          onLongPress: () => _showShareSubjectDialog(context, subjectName, exams),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                // Subject Icon Box
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        subjectColor,
                        subjectColor.withValues(alpha: 0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: subjectColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(iconData, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),

                // Subject Details: Title on top, Badges strictly below
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        subjectName,
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: subjectColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'SUBJECT',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: subjectColor,
                              ),
                            ),
                          ),
                          if (liveCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppColors.success.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: AppColors.success,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$liveCount LIVE',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.success,
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
                const SizedBox(width: 8),

                // Chevron indicating clickable card
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E2C) : const Color(0xFFECECF2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
              'Create a quiz or restore one using an Exam Code to begin.',
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

                  // Big Share Code Box
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.secondary.withValues(alpha: 0.15),
                          AppColors.primary.withValues(alpha: 0.10),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.secondary.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'UNIQUE SUBJECT SHARE CODE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: AppColors.secondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: SelectableText(
                                bundle.subjectCode,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                  color: AppColors.secondary,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, color: AppColors.secondary, size: 20),
                              tooltip: 'Copy Code',
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: bundle.subjectCode));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Copied Subject Code: ${bundle.subjectCode}'),
                                    backgroundColor: AppColors.success,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.verified, size: 13, color: AppColors.success),
                            const SizedBox(width: 4),
                            Text(
                              'Guaranteed unique & conflict-free',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Quizzes Included in Bundle
                  Text(
                    'Included Quizzes (${exams.length}):',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF14141E) : const Color(0xFFF4F4F8),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? const Color(0xFF242436) : const Color(0xFFE4E4EE)),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: exams.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (c, i) {
                        final ex = exams[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Row(
                            children: [
                              Text(
                                '${i + 1}.',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  ex.title,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${ex.questions.length} Qs',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.data_object, size: 16),
              label: const Text('Copy Bundle JSON'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: bundle.bundleJson));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Copied Subject Bundle JSON to clipboard!'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy Code'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: bundle.subjectCode));
                Navigator.pop(dlgCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Copied Subject Code: ${bundle.subjectCode}'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: const Text('Close'),
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

    showDialog(
      context: context,
      builder: (dialogCtx) {
        final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (stfCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.cloud_download_outlined, color: AppColors.secondary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Restore Exam or Entire Subject',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
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
                        'Enter a 6-character Exam Code (e.g. 4F9K2Q) or a Unique Subject Code (e.g. SUB-ENG-7K2M) to import all exams in that category:',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: codeController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: 'Exam or Subject Code',
                          hintText: 'e.g. 4F9K2Q or SUB-FIL-8A2F',
                          prefixIcon: const Icon(Icons.pin, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF14141E) : const Color(0xFFF7F7FA),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              'OR PASTE BACKUP JSON',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: jsonController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Paste Backup JSON',
                          hintText: 'Paste single exam or subject bundle JSON...',
                          prefixIcon: const Icon(Icons.code, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF14141E) : const Color(0xFFF7F7FA),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isRestoring ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: isRestoring
                      ? null
                      : () async {
                          final code = codeController.text.trim().toUpperCase();
                          final rawJson = jsonController.text.trim();

                          if (code.isEmpty && rawJson.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter an Exam / Subject Code or paste backup JSON'),
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
