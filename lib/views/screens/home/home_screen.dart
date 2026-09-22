import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../controllers/study_controller.dart';
import '../../../controllers/auth_controller.dart';
import '../../../models/user_model.dart';
import '../../../models/quiz_session_model.dart';
import '../../components/common/gradient_card.dart';
import '../../components/common/custom_button.dart';
import '../../components/common/stat_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final studyState = ref.watch(studyControllerProvider);
    final authState = ref.watch(authControllerProvider);
    final isWide = !Responsive.isMobile(context);

    // Gatekeeper: only authenticated creators can access this dashboard
    if (!authState.isLoading && !authState.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.go('/login');
        }
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final cardBg = isDark ? const Color(0xFF161620) : Colors.white;
    final borderColor = isDark ? const Color(0xFF28283A) : const Color(0xFFE4E4EC);
    final textPrimary = isDark ? const Color(0xFFF3F3F7) : const Color(0xFF1B1B24);
    final textSecondary = isDark ? const Color(0xFF8E8EA2) : const Color(0xFF707084);

    int totalAnswered = 0;
    int totalCorrect = 0;
    for (final p in studyState.progressMap.values) {
      totalAnswered += p.attempts.toInt();
      totalCorrect += p.correctCount.toInt();
    }
    final overallAccuracy =
        totalAnswered > 0 ? ((totalCorrect / totalAnswered) * 100).toInt() : 0;

    final stat1 = StatCard(
      title: 'Total Answered',
      value: '$totalAnswered',
      icon: Icons.quiz_outlined,
      accentColor: AppColors.secondary,
    );
    final stat2 = StatCard(
      title: 'Accuracy',
      value: '$overallAccuracy%',
      icon: Icons.track_changes,
      accentColor: AppColors.accent,
    );
    final stat3 = StatCard(
      title: 'Starred Items',
      value: '${studyState.bookmarkedQuestions.length}',
      icon: Icons.star_border,
      accentColor: AppColors.highlight,
      onTap: () {
        final session = ref
            .read(studyControllerProvider.notifier)
            .buildQuizSession(mode: StudyMode.bookmarked);
        context.push('/study/quiz', extra: session);
      },
    );
    final stat4 = StatCard(
      title: 'Weak Questions',
      value: '${studyState.weakQuestions.length}',
      icon: Icons.warning_amber,
      accentColor: AppColors.primary,
      onTap: () => context.push('/study/weak-questions'),
    );

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Brand Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1F1F2C) : const Color(0xFFECECF2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderColor),
                            ),
                            child: const Icon(
                              Icons.local_fire_department_rounded,
                              color: AppColors.secondary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Studay',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                    color: textPrimary,
                                  ),
                                ),
                                Text(
                                  'Creator Dashboard',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Action controls: My Library & User Account
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            side: BorderSide(color: borderColor),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => context.push('/library'),
                          icon: Icon(Icons.collections_bookmark_outlined, size: 15, color: textPrimary),
                          label: Text(
                            'My Library',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textPrimary),
                          ),
                        ),
                        _buildUserChip(context, ref, authState.currentUser),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Minimalist Hero Card (No loud gradients)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E2A) : const Color(0xFFF0F0F5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor),
                        ),
                        child: const Text(
                          'CREATOR DASHBOARD',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.secondary,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Master Your Subjects & Exams',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Manage your subjects (Filipino, English, Math), publish custom exams, and track results.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Two Modes: Responsive Layout (Side-by-side on wide screens, Stack on mobile)
                if (isWide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildStudyModeCard(context, isDark)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildExamModeCard(context, isDark)),
                    ],
                  )
                else
                  Column(
                    children: [
                      _buildStudyModeCard(context, isDark),
                      const SizedBox(height: 16),
                      _buildExamModeCard(context, isDark),
                    ],
                  ),
                const SizedBox(height: 16),

                // Dedicated My Library & Category Card
                _buildLibraryCard(context, isDark),
                const SizedBox(height: 28),

                // Personal Performance Stats Header
                Text(
                  'YOUR PERFORMANCE OVERVIEW',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 14),

                // Responsive Stat Cards
                if (isWide)
                  Row(
                    children: [
                      Expanded(child: stat1),
                      const SizedBox(width: 12),
                      Expanded(child: stat2),
                      const SizedBox(width: 12),
                      Expanded(child: stat3),
                      const SizedBox(width: 12),
                      Expanded(child: stat4),
                    ],
                  )
                else
                  Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: stat1),
                          const SizedBox(width: 12),
                          Expanded(child: stat2),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: stat3),
                          const SizedBox(width: 12),
                          Expanded(child: stat4),
                        ],
                      ),
                    ],
                  ),
                const SizedBox(height: 24),

                // Quick Action - Takers join without login
                CustomButton(
                  text: 'Enter Exam Join Code (No Login Needed)',
                  icon: Icons.pin,
                  variant: ButtonVariant.primaryGradient,
                  width: double.infinity,
                  onPressed: () => context.push('/exam/join'),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudyModeCard(BuildContext context, bool isDark) {
    final borderColor = isDark ? const Color(0xFF28283A) : const Color(0xFFE4E4EC);
    return GradientCard(
      onTap: () => context.push('/study'),
      padding: const EdgeInsets.all(20),
      borderColor: borderColor,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E2C) : const Color(0xFFECECF2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: const Icon(Icons.school_outlined, color: AppColors.secondary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    const Text(
                      'Study Mode',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1A1A24) : const Color(0xFFEAEAF0),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'OFFLINE',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFF9E9EB2) : const Color(0xFF6B6B7F),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Practice, timed quizzes, flashcards, and weak questions targeted review.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark
                        ? const Color(0xFF8E8EA2)
                        : const Color(0xFF707084),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right, color: isDark ? const Color(0xFF6E6E82) : const Color(0xFFA0A0B0)),
        ],
      ),
    );
  }

  Widget _buildExamModeCard(BuildContext context, bool isDark) {
    final borderColor = isDark ? const Color(0xFF28283A) : const Color(0xFFE4E4EC);
    return GradientCard(
      onTap: () => context.push('/exam'),
      padding: const EdgeInsets.all(20),
      borderColor: borderColor,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E2C) : const Color(0xFFECECF2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: const Icon(Icons.group_outlined, color: AppColors.secondary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    const Text(
                      'Exam Mode',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1A1A24) : const Color(0xFFEAEAF0),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'JOIN CODE',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFF9E9EB2) : const Color(0xFF6B6B7F),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Maker exam builder (MCQ, True/False, Matching) & guest code-join taking.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark
                        ? const Color(0xFF8E8EA2)
                        : const Color(0xFF707084),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right, color: isDark ? const Color(0xFF6E6E82) : const Color(0xFFA0A0B0)),
        ],
      ),
    );
  }

  Widget _buildLibraryCard(BuildContext context, bool isDark) {
    final borderColor = isDark ? const Color(0xFF28283A) : const Color(0xFFE4E4EC);
    return GradientCard(
      onTap: () => context.push('/library'),
      padding: const EdgeInsets.all(20),
      borderColor: borderColor,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E2C) : const Color(0xFFECECF2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: const Icon(Icons.collections_bookmark_outlined, color: AppColors.secondary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    const Text(
                      'Subject Cards & Quizzes',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1A1A24) : const Color(0xFFEAEAF0),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'MY LIBRARY',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFF9E9EB2) : const Color(0xFF6B6B7F),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Explore subject cards (Filipino, English, Math) and their quizzes (Quiz 1, Quiz 2). Creators save their work here.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark
                        ? const Color(0xFF8E8EA2)
                        : const Color(0xFF707084),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right, color: isDark ? const Color(0xFF6E6E82) : const Color(0xFFA0A0B0)),
        ],
      ),
    );
  }

  Widget _buildUserChip(BuildContext context, WidgetRef ref, UserModel? user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF28283A) : const Color(0xFFE4E4EC);

    if (user != null) {
      return InkWell(
        onTap: () => _showAccountSheet(context, ref, user),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B1B27) : const Color(0xFFEFEFF5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 11,
                backgroundColor: isDark ? const Color(0xFF28283A) : const Color(0xFFD0D0DC),
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                user.name.split(' ').first,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_drop_down, size: 16, color: isDark ? const Color(0xFF8E8EA2) : const Color(0xFF707084)),
            ],
          ),
        ),
      );
    }

    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        side: BorderSide(color: borderColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () => context.push('/login'),
      icon: const Icon(Icons.person_outline, size: 14),
      label: const Text('Sign In', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }

  void _showAccountSheet(BuildContext context, WidgetRef ref, UserModel user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF28283A) : const Color(0xFFE4E4EC);

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF161620) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: isDark ? const Color(0xFF28283A) : const Color(0xFFE0E0EC),
                      child: Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                          ),
                          Text(
                            user.email,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? const Color(0xFF8E8EA2) : const Color(0xFF707084),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E2A) : const Color(0xFFF0F0F5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor),
                      ),
                      child: const Text(
                        'CREATOR',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(Icons.collections_bookmark_outlined, color: AppColors.secondary),
                  title: const Text('Go to My Library', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('View Subject Cards (Filipino, English, Math) and quizzes'),
                  trailing: const Icon(Icons.chevron_right),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/library');
                  },
                ),
                Divider(height: 16, color: borderColor),
                ListTile(
                  leading: const Icon(Icons.logout, color: AppColors.error),
                  title: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.error)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await ref.read(authControllerProvider.notifier).logout();
                    if (context.mounted) {
                      context.go('/login');
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
