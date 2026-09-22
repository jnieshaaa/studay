import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../controllers/providers.dart';
import '../../../controllers/study_controller.dart';
import '../../../models/exam_participant_model.dart';
import '../../components/exam/join_code_display.dart';
import '../../components/exam/leaderboard_tile.dart';
import '../../components/exam/hardest_question_tile.dart';
import '../../components/common/stat_card.dart';

class ExamDashboardScreen extends ConsumerStatefulWidget {
  final String examId;

  const ExamDashboardScreen({super.key, required this.examId});

  @override
  ConsumerState<ExamDashboardScreen> createState() => _ExamDashboardScreenState();
}

class _ExamDashboardScreenState extends ConsumerState<ExamDashboardScreen> {
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final examService = ref.watch(examServiceProvider);
    final exam = examService.getExamById(widget.examId);
    final isMobile = Responsive.isMobile(context);

    if (exam == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Exam Dashboard')),
        body: const Center(child: Text('Exam not found.')),
      );
    }

    final participants = examService.getParticipants(exam.id);
    final submittedCount = participants.where((p) => p.status == ParticipantStatus.submitted).length;
    final joinedCount = participants.length;
    final hardestQuestions = examService.getHardestQuestions(exam.id);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Maker Dashboard', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: AppColors.secondary),
            tooltip: 'Import to Study Deck',
            onPressed: () async {
              final subj = await ref
                  .read(studyControllerProvider.notifier)
                  .importExamAsStudyDeck(exam);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Imported "${subj.name}" as Study Deck!'),
                    backgroundColor: AppColors.secondary,
                  ),
                );
                context.push('/study');
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.secondary),
            tooltip: 'Edit Questions & Settings',
            onPressed: () => context.push('/exam/maker', extra: exam),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.secondary),
            tooltip: 'Refresh Results',
            onPressed: () => setState(() {}),
          ),
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: ResponsiveContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Join Code Display Banner
              JoinCodeDisplay(
                code: exam.code,
                title: exam.title,
              ),
              const SizedBox(height: 18),

              // Participation Metrics
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      title: 'Joined Participants',
                      value: '$joinedCount',
                      icon: Icons.people_outline,
                      accentColor: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      title: 'Submitted Exams',
                      value: '$submittedCount',
                      icon: Icons.assignment_turned_in_outlined,
                      accentColor: AppColors.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // Responsive Tab Selector: Leaderboard vs Hardest Questions
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: SegmentedButton<int>(
                    segments: [
                      ButtonSegment(
                        value: 0,
                        icon: const Icon(Icons.leaderboard, size: 18),
                        label: Text(isMobile
                            ? 'Rankings (${participants.length})'
                            : 'Leaderboard (${participants.length})'),
                      ),
                      ButtonSegment(
                        value: 1,
                        icon: const Icon(Icons.analytics_outlined, size: 18),
                        label: Text(isMobile
                            ? 'Hardest Qs (${hardestQuestions.length})'
                            : 'Hardest Questions (${hardestQuestions.length})'),
                      ),
                    ],
                    selected: {_selectedTabIndex},
                    onSelectionChanged: (set) {
                      setState(() => _selectedTabIndex = set.first);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Tab 1: Leaderboard View
              if (_selectedTabIndex == 0) ...[
                if (participants.isEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text('No participants have joined yet. Share the code!'),
                    ),
                  ),
                ] else ...[
                  ...participants.asMap().entries.map((entry) {
                    final rank = entry.key + 1;
                    final participant = entry.value;
                    return LeaderboardTile(
                      rank: rank,
                      participant: participant,
                    );
                  }),
                ],
              ] else ...[
                // Tab 2: Hardest Questions Analytics
                if (hardestQuestions.isEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text('No response analytics available yet.'),
                    ),
                  ),
                ] else ...[
                  ...hardestQuestions.asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final stat = entry.value;
                    return HardestQuestionTile(
                      index: idx,
                      stat: stat,
                    );
                  }),
                ],
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
