import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../controllers/exam_maker_controller.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/study_controller.dart';
import '../../../controllers/providers.dart';
import '../../../models/exam_model.dart';
import '../../../models/question_model.dart';
import '../../../core/utils/code_generator.dart';
import '../../components/common/gradient_card.dart';
import '../../components/common/custom_button.dart';
import 'exam_section_questions_screen.dart';
import 'bulk_import_questions_dialog.dart';

class ExamMakerScreen extends ConsumerStatefulWidget {
  final Exam? initialExam;
  const ExamMakerScreen({super.key, this.initialExam});

  @override
  ConsumerState<ExamMakerScreen> createState() => _ExamMakerScreenState();
}

class _ExamMakerScreenState extends ConsumerState<ExamMakerScreen> {
  int _currentStep = 0; // 0: Details & Settings, 1: Questions & Publish
  late final TextEditingController _subjectController;
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late final TextEditingController _durationController;
  String? _titleError;
  String? _subjectError;

  @override
  void initState() {
    super.initState();
    final exam = widget.initialExam;
    // For a brand new exam, ALWAYS clear the textfield and never pre-fill an existing subject!
    _subjectController = TextEditingController(text: exam?.subject ?? '');
    _titleController = TextEditingController(text: exam?.title ?? '');
    _descController = TextEditingController(text: exam?.description ?? '');
    _durationController = TextEditingController(
      text: exam?.durationMinutes != null && exam!.durationMinutes! > 0
          ? '${exam.durationMinutes}'
          : '',
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (exam != null) {
        ref.read(examMakerControllerProvider.notifier).initForEdit(exam);
      } else {
        ref.read(examMakerControllerProvider.notifier).reset();
      }
    });
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _titleController.dispose();
    _descController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  List<String> _getExistingSubjects() {
    final subjectsSet = <String>{};
    try {
      final studySubjects = ref.read(studyControllerProvider).subjects;
      for (final s in studySubjects) {
        if (s.name.trim().isNotEmpty) {
          subjectsSet.add(s.name.trim());
        }
      }
    } catch (_) {}

    try {
      final exams = ref.read(examServiceProvider).allExams;
      for (final e in exams) {
        if (e.subject.trim().isNotEmpty) {
          subjectsSet.add(e.subject.trim());
        }
      }
    } catch (_) {}

    final list = subjectsSet.toList();
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  bool _validateStep1() {
    bool valid = true;
    final title = _titleController.text.trim();
    final subject = _subjectController.text.trim();

    if (title.isEmpty) {
      setState(() => _titleError = 'Exam Title is required');
      valid = false;
    } else {
      setState(() => _titleError = null);
    }

    if (subject.isEmpty) {
      setState(() => _subjectError = 'Subject Category is required');
      valid = false;
    } else {
      setState(() => _subjectError = null);
    }

    if (valid) {
      final notifier = ref.read(examMakerControllerProvider.notifier);
      notifier.setTitle(title);
      notifier.setSubject(subject);
      notifier.setDescription(_descController.text.trim());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in required fields (Title & Subject).'),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 2),
        ),
      );
    }

    return valid;
  }

  void _showAddQuestionDialog([QuestionType? initialType]) {
    showAddQuestionSheet(
      context,
      defaultCategory: _subjectController.text.trim().isNotEmpty
          ? _subjectController.text.trim()
          : 'General Knowledge',
      initialType: initialType,
      lockType: initialType != null,
      onQuestionAdded: (q) {
        ref.read(examMakerControllerProvider.notifier).addQuestion(q);
      },
    );
  }

  Future<void> _onPublish() async {
    final authState = ref.read(authControllerProvider);
    if (!authState.isAuthenticated) {
      context.push('/setup-username');
      return;
    }

    final notifier = ref.read(examMakerControllerProvider.notifier);
    notifier.setTitle(_titleController.text.trim());
    notifier.setSubject(_subjectController.text.trim());
    notifier.setDescription(_descController.text.trim());

    final state = ref.read(examMakerControllerProvider);
    if (state.questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one question before publishing.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final router = GoRouter.of(context);
    final saved = await notifier.publish();
    if (saved != null && mounted) {
      ref.read(authControllerProvider.notifier).attachExamToUser(saved.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.isEditing
              ? 'Successfully updated "${saved.title}"!'
              : 'Published "${saved.title}"! Code: ${saved.code}'),
          backgroundColor: AppColors.success,
        ),
      );
      if (state.isEditing && router.canPop()) {
        router.pop();
      } else {
        router.pushReplacement('/exam/dashboard/${saved.id}');
      }
    }
  }

  Widget _buildStepIndicator(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B1B28) : const Color(0xFFF7F7FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF2B2B3D) : const Color(0xFFE4E4EC),
        ),
      ),
      child: Row(
        children: [
          // Step 1
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _currentStep = 0),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _currentStep == 0
                          ? AppColors.secondary
                          : AppColors.success,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: _currentStep > 0
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : const Text(
                            '1',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'STEP 1',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: _currentStep == 0
                                ? AppColors.secondary
                                : (isDark ? Colors.white60 : Colors.black54),
                          ),
                        ),
                        Text(
                          'Details & Settings',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: _currentStep == 0
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: _currentStep == 0
                                ? (isDark ? Colors.white : Colors.black87)
                                : (isDark ? Colors.white70 : Colors.black54),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Icon(
            Icons.chevron_right,
            size: 20,
            color: isDark ? Colors.white30 : Colors.black26,
          ),
          const SizedBox(width: 8),
          // Step 2
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                if (_validateStep1()) {
                  setState(() => _currentStep = 1);
                }
              },
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _currentStep == 1
                          ? AppColors.secondary
                          : (isDark ? Colors.white12 : Colors.black12),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '2',
                      style: TextStyle(
                        color: _currentStep == 1 ? Colors.white : Colors.grey,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'STEP 2',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: _currentStep == 1
                                ? AppColors.secondary
                                : (isDark ? Colors.white60 : Colors.black54),
                          ),
                        ),
                        Text(
                          'Questions & Publish',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: _currentStep == 1
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: _currentStep == 1
                                ? (isDark ? Colors.white : Colors.black87)
                                : (isDark ? Colors.white70 : Colors.black54),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(examMakerControllerProvider);
    final notifier = ref.read(examMakerControllerProvider.notifier);
    final existingSubjects = _getExistingSubjects();

    return PopScope(
      canPop: _currentStep == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_currentStep == 1) {
          setState(() => _currentStep = 0);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (_currentStep == 1) {
                setState(() => _currentStep = 0);
              } else {
                Navigator.of(context).maybePop();
              }
            },
          ),
          title: Text(
            state.isEditing
                ? (_currentStep == 0 ? 'Edit Quiz - Setup' : 'Edit Quiz - Questions')
                : (_currentStep == 0 ? 'Create Exam - Setup' : 'Create Exam - Questions'),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          actions: [
            if (state.questions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${state.questions.length} Qs',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.secondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: SingleChildScrollView(
          child: ResponsiveContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (state.errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            state.errorMessage!,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Two-Step Progress Indicator
                _buildStepIndicator(isDark),

                // ==========================================
                // STEP 1: BASIC DETAILS, SETTINGS & SECTION ORDER
                // ==========================================
                if (_currentStep == 0) ...[
                  // 1. Basic Info Card
                  GradientCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'BASIC DETAILS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            labelText: 'Exam Title *',
                            hintText: 'e.g. Midterm General Science Reviewer',
                            errorText: _titleError,
                            prefixIcon: const Icon(Icons.title, size: 20),
                          ),
                          onChanged: (val) {
                            if (_titleError != null && val.trim().isNotEmpty) {
                              setState(() => _titleError = null);
                            }
                            notifier.setTitle(val);
                          },
                        ),
                        const SizedBox(height: 16),

                        // Subject Input with Dropdown inside textfield
                        TextField(
                          controller: _subjectController,
                          decoration: InputDecoration(
                            labelText: 'Subject Category *',
                            hintText: 'e.g. Science, Mathematics, History...',
                            errorText: _subjectError,
                            prefixIcon: const Icon(Icons.category_outlined, size: 20),
                            suffixIcon: existingSubjects.isNotEmpty
                                ? PopupMenuButton<String>(
                                    icon: const Icon(Icons.arrow_drop_down, size: 28),
                                    tooltip: 'Select existing subject',
                                    onSelected: (val) {
                                      setState(() {
                                        _subjectController.text = val;
                                        _subjectError = null;
                                      });
                                      notifier.setSubject(val);
                                    },
                                    itemBuilder: (context) => existingSubjects
                                        .map((s) => PopupMenuItem<String>(
                                              value: s,
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.folder_outlined,
                                                      size: 18, color: AppColors.secondary),
                                                  const SizedBox(width: 8),
                                                  Text(s,
                                                      style: const TextStyle(
                                                          fontWeight: FontWeight.w600)),
                                                ],
                                              ),
                                            ))
                                        .toList(),
                                  )
                                : null,
                          ),
                          onChanged: (val) {
                            if (_subjectError != null && val.trim().isNotEmpty) {
                              setState(() => _subjectError = null);
                            }
                            notifier.setSubject(val);
                          },
                        ),
                        const SizedBox(height: 16),

                        TextField(
                          controller: _descController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Description / Instructions',
                            hintText: 'Optional instructions for participants...',
                            prefixIcon: Icon(Icons.notes, size: 20),
                          ),
                          onChanged: notifier.setDescription,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. Exam Section Order (Parts) Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1B1B28) : const Color(0xFFF7F7FA),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? const Color(0xFF2B2B3D) : const Color(0xFFE4E4EC),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.format_list_numbered,
                                    size: 18, color: AppColors.secondary),
                                SizedBox(width: 8),
                                Text(
                                  'EXAM SECTION ORDER',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Starts with: ${state.sectionOrder.first.label}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.secondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Question types are grouped into separate parts. Choose which type takers answer first, second, or third.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Quick "Start First With" Chips
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Start first with:',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                            ...QuestionType.values.map((type) {
                              final isFirst = state.sectionOrder.first == type;
                              return ChoiceChip(
                                label: Text(type.label),
                                selected: isFirst,
                                selectedColor: AppColors.secondary,
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isFirst ? Colors.white : null,
                                ),
                                onSelected: (_) => notifier.setFirstSection(type),
                              );
                            }),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 10),

                        // Reorderable & Clickable parts list
                        ...state.sectionOrder.asMap().entries.map((entry) {
                          final partIdx = entry.key;
                          final type = entry.value;
                          final count =
                              state.questions.where((q) => q.questionType == type).length;
                          final isFirst = partIdx == 0;
                          final isLast = partIdx == state.sectionOrder.length - 1;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkCard : AppColors.lightCard,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isFirst
                                    ? AppColors.secondary.withValues(alpha: 0.5)
                                    : (isDark
                                        ? const Color(0xFF2B2B3D)
                                        : const Color(0xFFE4E4EC)),
                              ),
                            ),
                            child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 26,
                                        height: 26,
                                        decoration: BoxDecoration(
                                          color: isFirst
                                              ? AppColors.secondary
                                              : (isDark ? Colors.white12 : Colors.black12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          '${partIdx + 1}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: isFirst ? Colors.white : null,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    'Part ${partIdx + 1}: ${type.label}',
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w700,
                                                      fontSize: 13,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: count > 0
                                                        ? AppColors.secondary
                                                            .withValues(alpha: 0.15)
                                                        : (isDark
                                                            ? Colors.white10
                                                            : Colors.black12),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    '$count Qs',
                                                    style: TextStyle(
                                                      fontSize: 10.5,
                                                      fontWeight: FontWeight.w800,
                                                      color: count > 0
                                                          ? AppColors.secondary
                                                          : Colors.grey,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              count == 0
                                                  ? 'Questions configured in Step 2'
                                                  : '$count questions configured',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isDark
                                                    ? AppColors.textSecondaryDark
                                                    : AppColors.textSecondaryLight,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.arrow_upward, size: 18),
                                        tooltip: 'Move Up',
                                        onPressed:
                                            !isFirst ? () => notifier.moveSectionUp(type) : null,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.arrow_downward, size: 18),
                                        tooltip: 'Move Down',
                                        onPressed:
                                            !isLast ? () => notifier.moveSectionDown(type) : null,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ],
                                  ),
                                ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 3. Exam Settings Card (Same screen as requested)
                  GradientCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'EXAM SETTINGS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Time Limit Number Field (instead of cards)
                        TextField(
                          controller: _durationController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(
                            labelText: 'Time Limit (minutes)',
                            hintText: 'e.g. 15, 30, 45, 90...',
                            prefixIcon: Icon(Icons.timer_outlined, size: 20),
                            suffixText: 'mins',
                            helperText: 'Enter duration in minutes. Leave empty or 0 for untimed.',
                          ),
                          onChanged: (val) {
                            final trimmed = val.trim();
                            if (trimmed.isEmpty) {
                              notifier.setDurationMinutes(null);
                            } else {
                              final parsed = int.tryParse(trimmed);
                              notifier.setDurationMinutes(
                                parsed != null && parsed > 0 ? parsed : null,
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        const Divider(height: 1),

                        SwitchListTile(
                          title: const Text('Shuffle Questions'),
                          subtitle: const Text('Randomize question sequence per participant'),
                          value: state.questionOrder == QuestionOrder.shuffled,
                          activeTrackColor: AppColors.secondary,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (val) {
                            notifier.setQuestionOrder(
                              val ? QuestionOrder.shuffled : QuestionOrder.fixed,
                            );
                          },
                        ),
                        const Divider(height: 1),

                        SwitchListTile(
                          title: const Text('Shuffle Multiple Choice Options'),
                          subtitle: const Text('Prevent memorization by letter (A, B, C, D)'),
                          value: state.choiceOrder == ChoiceOrder.shuffled,
                          activeTrackColor: AppColors.secondary,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (val) {
                            notifier.setChoiceOrder(
                              val ? ChoiceOrder.shuffled : ChoiceOrder.fixed,
                            );
                          },
                        ),
                        const Divider(height: 1),
                        const SizedBox(height: 14),

                        const Text('Show Answers to Participants',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<ShowAnswersMode>(
                          isExpanded: true,
                          initialValue: state.showAnswers,
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                          items: ShowAnswersMode.values.map((mode) {
                            return DropdownMenuItem(
                              value: mode,
                              child: Text(
                                mode.label,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) notifier.setShowAnswers(val);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Button to Advance to Step 2
                  CustomButton(
                    text: 'Continue to Step 2: Manage Questions ->',
                    icon: Icons.arrow_forward,
                    variant: ButtonVariant.primaryGradient,
                    width: double.infinity,
                    onPressed: () {
                      if (_validateStep1()) {
                        setState(() => _currentStep = 1);
                      }
                    },
                  ),
                  const SizedBox(height: 32),
                ],

                // ==========================================
                // STEP 2: QUESTIONS MANAGER & PUBLISH
                // ==========================================
                if (_currentStep == 1) ...[
                  // Overview Header Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1B1B28) : const Color(0xFFF7F7FA),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? const Color(0xFF2B2B3D) : const Color(0xFFE4E4EC),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _titleController.text.trim().isNotEmpty
                                    ? _titleController.text.trim()
                                    : 'Untitled Exam',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => setState(() => _currentStep = 0),
                              icon: const Icon(Icons.edit, size: 14),
                              label: const Text('Edit Details', style: TextStyle(fontSize: 12)),
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _subjectController.text.trim().isNotEmpty
                                    ? _subjectController.text.trim()
                                    : 'General Knowledge',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.secondary,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white10 : Colors.black12,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                state.durationMinutes != null && state.durationMinutes! > 0
                                    ? '${state.durationMinutes} mins'
                                    : 'Untimed',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: state.questions.isNotEmpty
                                    ? AppColors.success.withValues(alpha: 0.15)
                                    : AppColors.error.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${state.questions.length} Total Questions',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: state.questions.isNotEmpty
                                      ? AppColors.success
                                      : AppColors.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Quick Bulk Paste Banner
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.secondary.withValues(alpha: 0.12),
                          AppColors.primary.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.secondary.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.bolt, color: AppColors.secondary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Quick Bulk Paste Questions',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                              Text(
                                'Paste multiple questions & options at once instead of 1:1 typing.',
                                style: TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => showBulkImportQuestionsSheet(context),
                          icon: const Icon(Icons.playlist_add, size: 16),
                          label: const Text('Bulk Paste', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            foregroundColor: Colors.white,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Questions Sections (Rendered strictly by sectionOrder)
                  ...state.sectionOrder.asMap().entries.map((entry) {
                    final partIdx = entry.key;
                    final type = entry.value;
                    final questionsForType =
                        state.questions.where((q) => q.questionType == type).toList();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1B1B28) : const Color(0xFFF7F7FA),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? const Color(0xFF2B2B3D) : const Color(0xFFE4E4EC),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Section Header
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: AppColors.secondary,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${partIdx + 1}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Part ${partIdx + 1}: ${type.label}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: questionsForType.isNotEmpty
                                        ? AppColors.secondary.withValues(alpha: 0.15)
                                        : (isDark ? Colors.white10 : Colors.black12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${questionsForType.length} Qs',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: questionsForType.isNotEmpty
                                          ? AppColors.secondary
                                          : Colors.grey,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                if (type != QuestionType.matching)
                                  IconButton(
                                    icon: const Icon(Icons.bolt,
                                        size: 20, color: AppColors.secondary),
                                    tooltip: 'Bulk Paste to Part ${partIdx + 1}',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => showBulkImportQuestionsSheet(
                                      context,
                                      initialType: type,
                                      lockType: true,
                                      partNumber: partIdx + 1,
                                    ),
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline,
                                      size: 20, color: AppColors.secondary),
                                  tooltip: 'Add Question to Part ${partIdx + 1}',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _showAddQuestionDialog(type),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.open_in_new, size: 18),
                                  tooltip: 'Full Section Manager',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            ExamSectionQuestionsScreen(sectionType: type),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),

                          // Section Questions List
                          if (questionsForType.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Center(
                                child: Column(
                                  children: [
                                    Text(
                                      'No ${type.label} questions added yet.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? AppColors.textSecondaryDark
                                            : AppColors.textSecondaryLight,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      alignment: WrapAlignment.center,
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed: () => _showAddQuestionDialog(type),
                                          icon: const Icon(Icons.add, size: 15),
                                          label: Text('Add ${type.label}'),
                                          style: OutlinedButton.styleFrom(
                                            visualDensity: VisualDensity.compact,
                                          ),
                                        ),
                                        if (type != QuestionType.matching)
                                          OutlinedButton.icon(
                                            onPressed: () => showBulkImportQuestionsSheet(
                                              context,
                                              initialType: type,
                                              lockType: true,
                                              partNumber: partIdx + 1,
                                            ),
                                            icon: const Icon(Icons.bolt,
                                                size: 15, color: AppColors.secondary),
                                            label: const Text('Bulk Paste'),
                                            style: OutlinedButton.styleFrom(
                                              visualDensity: VisualDensity.compact,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: questionsForType.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, qIdx) {
                                final q = questionsForType[qIdx];
                                final globalIdx = state.questions.indexOf(q);

                                return ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 4),
                                  leading: CircleAvatar(
                                    radius: 12,
                                    backgroundColor:
                                        isDark ? Colors.white12 : Colors.black12,
                                    child: Text(
                                      '${qIdx + 1}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    q.questionText,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 12.5, fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Text(
                                    type == QuestionType.matching
                                        ? '${q.matchingPairs.length} pairs • ${q.points} pt(s)'
                                        : '${q.choices.length} choices • ${q.points} pt(s)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? AppColors.textSecondaryDark
                                          : AppColors.textSecondaryLight,
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 16),
                                        tooltip: 'Edit Question',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () {
                                          showAddQuestionSheet(
                                            context,
                                            defaultCategory: _subjectController.text.trim(),
                                            initialType: type,
                                            initialQuestion: q,
                                            lockType: true,
                                            onQuestionAdded: (updatedQ) {
                                              notifier.updateQuestion(globalIdx, updatedQ);
                                            },
                                          );
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline,
                                            size: 16, color: AppColors.error),
                                        tooltip: 'Delete',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () => notifier.removeQuestion(globalIdx),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 16),

                  // Bottom Action Button: Publish (expanded to full width)
                  CustomButton(
                    width: double.infinity,
                    text: state.isEditing
                        ? 'Save Changes'
                        : 'Publish Exam',
                    icon: state.isEditing
                        ? Icons.check_circle_outline
                        : Icons.rocket_launch,
                    isLoading: state.isPublishing,
                    variant: state.isEditing
                        ? ButtonVariant.secondary
                        : ButtonVariant.primaryGradient,
                    onPressed: _onPublish,
                  ),
                  const SizedBox(height: 32),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Public helper function to display the Add / Edit Question modal bottom sheet.
void showAddQuestionSheet(
  BuildContext context, {
  String? defaultCategory,
  QuestionType? initialType,
  Question? initialQuestion,
  bool lockType = false,
  int? partNumber,
  required Function(Question q) onQuestionAdded,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: AddQuestionSheet(
          defaultCategory: defaultCategory,
          initialType: initialType,
          initialQuestion: initialQuestion,
          lockType: lockType,
          partNumber: partNumber,
          onQuestionAdded: onQuestionAdded,
        ),
      ),
    ),
  );
}

class AddQuestionSheet extends StatefulWidget {
  final String? defaultCategory;
  final QuestionType? initialType;
  final Question? initialQuestion;
  final bool lockType;
  final int? partNumber;
  final Function(Question q) onQuestionAdded;
  const AddQuestionSheet({
    super.key,
    this.defaultCategory,
    this.initialType,
    this.initialQuestion,
    this.lockType = false,
    this.partNumber,
    required this.onQuestionAdded,
  });

  @override
  State<AddQuestionSheet> createState() => _AddQuestionSheetState();
}

class _BulkChoiceItem {
  final String text;
  final bool isCorrect;
  const _BulkChoiceItem(this.text, {this.isCorrect = false});
}

class _AddQuestionSheetState extends State<AddQuestionSheet> {
  late QuestionType _selectedType;
  late final TextEditingController _promptController;
  late final TextEditingController _expController;
  late final TextEditingController _categoryController;

  // MCQ choices
  final List<TextEditingController> _choiceControllers = [];
  int _correctChoiceIndex = 0;

  // True/False
  bool _tfCorrectValue = true;

  // Matching pairs
  final List<TextEditingController> _leftControllers = [];
  final List<TextEditingController> _rightControllers = [];

  // Question Prompt height expansion toggle
  bool _isPromptExpanded = false;

  @override
  void initState() {
    super.initState();
    final init = widget.initialQuestion;
    _selectedType = (widget.lockType && widget.initialType != null)
        ? widget.initialType!
        : (init?.questionType ?? widget.initialType ?? QuestionType.multipleChoice);
    _promptController = TextEditingController(text: init?.questionText ?? '');
    _expController = TextEditingController(text: init?.explanation ?? '');
    _categoryController = TextEditingController(
      text: init?.effectiveCategory ??
          (widget.defaultCategory?.isNotEmpty == true ? widget.defaultCategory! : 'General Knowledge'),
    );

    if (init != null) {
      if (init.questionType == QuestionType.multipleChoice) {
        for (int i = 0; i < init.choices.length; i++) {
          _choiceControllers.add(TextEditingController(text: init.choices[i].choiceText));
          if (init.choices[i].isCorrect) {
            _correctChoiceIndex = i;
          }
        }
        while (_choiceControllers.length < 4) {
          _choiceControllers.add(TextEditingController());
        }
      } else if (init.questionType == QuestionType.trueFalse) {
        final tChoice = init.choices.firstWhere(
          (c) => c.choiceText.toLowerCase() == 'true',
          orElse: () => init.choices.first,
        );
        _tfCorrectValue = tChoice.isCorrect;
      } else if (init.questionType == QuestionType.matching) {
        for (final pair in init.matchingPairs) {
          _leftControllers.add(TextEditingController(text: pair.leftText));
          _rightControllers.add(TextEditingController(text: pair.rightText));
        }
      }
    }

    if (_choiceControllers.isEmpty) {
      _choiceControllers.addAll([
        TextEditingController(),
        TextEditingController(),
        TextEditingController(),
        TextEditingController(),
      ]);
    }
    if (_leftControllers.isEmpty) {
      _leftControllers.addAll([
        TextEditingController(),
        TextEditingController(),
        TextEditingController(),
      ]);
      _rightControllers.addAll([
        TextEditingController(),
        TextEditingController(),
        TextEditingController(),
      ]);
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    _expController.dispose();
    _categoryController.dispose();
    for (final c in _choiceControllers) {
      c.dispose();
    }
    for (final c in _leftControllers) {
      c.dispose();
    }
    for (final c in _rightControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addPair() {
    if (_leftControllers.length >= 10) return;
    setState(() {
      _leftControllers.add(TextEditingController());
      _rightControllers.add(TextEditingController());
    });
  }

  void _removePair(int index) {
    if (_leftControllers.length <= 2) return;
    setState(() {
      _leftControllers[index].dispose();
      _rightControllers[index].dispose();
      _leftControllers.removeAt(index);
      _rightControllers.removeAt(index);
    });
  }

  void _swapMatchingSides() {
    setState(() {
      for (int i = 0; i < _leftControllers.length; i++) {
        final temp = _leftControllers[i].text;
        _leftControllers[i].text = _rightControllers[i].text;
        _rightControllers[i].text = temp;
      }
    });
  }

  void _showBulkPasteDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final parsedPairs = _parsePastedPairs(textController.text);

            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.bolt, color: AppColors.secondary),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '⚡ Quick Bulk Paste Pairs',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Paste your matching pairs below (one per line). Any delimiter works (=, -, :, tab, or comma):',
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: textController,
                        maxLines: 8,
                        decoration: InputDecoration(
                          hintText: "Example:\nManila = Philippines\nTokyo = Japan\nParis = France\nCanberra = Australia",
                          hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              textController.text =
                                  "Manila = Philippines\nTokyo = Japan\nParis = France\nCanberra = Australia\nWashington = USA";
                              setDialogState(() {});
                            },
                            icon: const Icon(Icons.lightbulb_outline, size: 16),
                            label: const Text('Insert Sample', style: TextStyle(fontSize: 12)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: parsedPairs.isNotEmpty
                                  ? AppColors.success.withValues(alpha: 0.15)
                                  : Colors.grey.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${parsedPairs.length} pairs recognized',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: parsedPairs.isNotEmpty ? AppColors.success : Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: parsedPairs.length >= 2
                      ? () {
                          _applyParsedPairs(parsedPairs);
                          Navigator.pop(ctx);
                        }
                      : null,
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Apply Pairs'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<MapEntry<String, String>> _parsePastedPairs(String raw) {
    final lines = raw.split(RegExp(r'\r?\n'));
    final results = <MapEntry<String, String>>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      String left = '';
      String right = '';

      if (trimmed.contains('=')) {
        final parts = trimmed.split('=');
        left = parts[0].trim();
        right = parts.sublist(1).join('=').trim();
      } else if (trimmed.contains('->')) {
        final parts = trimmed.split('->');
        left = parts[0].trim();
        right = parts.sublist(1).join('->').trim();
      } else if (trimmed.contains('\t')) {
        final parts = trimmed.split('\t');
        left = parts[0].trim();
        right = parts.sublist(1).join('\t').trim();
      } else if (trimmed.contains(':')) {
        final parts = trimmed.split(':');
        left = parts[0].trim();
        right = parts.sublist(1).join(':').trim();
      } else if (trimmed.contains('-')) {
        final parts = trimmed.split('-');
        left = parts[0].trim();
        right = parts.sublist(1).join('-').trim();
      } else if (trimmed.contains(',')) {
        final parts = trimmed.split(',');
        left = parts[0].trim();
        right = parts.sublist(1).join(',').trim();
      }

      if (left.isNotEmpty && right.isNotEmpty) {
        results.add(MapEntry(left, right));
      }
    }

    return results;
  }

  void _applyParsedPairs(List<MapEntry<String, String>> pairs) {
    setState(() {
      for (final c in _leftControllers) {
        c.dispose();
      }
      for (final c in _rightControllers) {
        c.dispose();
      }
      _leftControllers.clear();
      _rightControllers.clear();

      for (final p in pairs.take(10)) {
        _leftControllers.add(TextEditingController(text: p.key));
        _rightControllers.add(TextEditingController(text: p.value));
      }

      while (_leftControllers.length < 2) {
        _leftControllers.add(TextEditingController());
        _rightControllers.add(TextEditingController());
      }
    });
  }

  List<_BulkChoiceItem> _parseBulkChoices(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return [];

    final choiceRegex = RegExp(
      r'^\s*([*]?)\s*\(?([A-Za-z])(?:[\.\)]|\s*-\s*|\s*:\s*|\))\s*(.*)$',
    );

    final lines = trimmed.split(RegExp(r'\r?\n'));
    final items = <_BulkChoiceItem>[];

    final hasLetterMarkers = lines.any((l) => choiceRegex.hasMatch(l.trim()));

    if (hasLetterMarkers) {
      String currentText = '';
      bool currentIsCorrect = false;

      for (final line in lines) {
        final match = choiceRegex.firstMatch(line.trim());
        if (match != null) {
          if (currentText.trim().isNotEmpty) {
            items.add(_BulkChoiceItem(currentText.trim(), isCorrect: currentIsCorrect));
          }
          final asterisk = match.group(1) ?? '';
          final afterPrefix = match.group(3)?.trim() ?? '';
          currentIsCorrect = asterisk.contains('*');
          currentText = afterPrefix;
        } else {
          if (currentText.isEmpty) {
            currentText = line.trimRight();
          } else {
            currentText = '$currentText\n${line.trimRight()}';
          }
        }
      }
      if (currentText.trim().isNotEmpty) {
        items.add(_BulkChoiceItem(currentText.trim(), isCorrect: currentIsCorrect));
      }
    } else {
      if (trimmed.contains('\n\n')) {
        final blocks = trimmed.split(RegExp(r'\n\s*\n+'));
        for (final b in blocks) {
          final bTrim = b.trim();
          if (bTrim.isNotEmpty) {
            items.add(_BulkChoiceItem(bTrim));
          }
        }
      } else {
        for (final l in lines) {
          final lTrim = l.trim();
          if (lTrim.isNotEmpty) {
            items.add(_BulkChoiceItem(lTrim));
          }
        }
      }
    }

    return items.map((item) {
      var txt = item.text;
      var correct = item.isCorrect;
      if (txt.toLowerCase().contains('(correct)')) {
        correct = true;
        txt = txt.replaceAll(RegExp(r'\(correct\)', caseSensitive: false), '').trim();
      } else if (txt.toLowerCase().contains('[correct]')) {
        correct = true;
        txt = txt.replaceAll(RegExp(r'\[correct\]', caseSensitive: false), '').trim();
      } else if (txt.endsWith('*')) {
        correct = true;
        txt = txt.substring(0, txt.length - 1).trim();
      }
      return _BulkChoiceItem(txt, isCorrect: correct);
    }).toList();
  }

  void _showBulkPasteChoicesDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final raw = textController.text;
            final parsedChoices = _parseBulkChoices(raw);

            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.bolt, color: AppColors.secondary),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '⚡ Quick Paste Options',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Paste options below. Supports multi-line code snippets with A), B), C), D) prefixes, or blank lines:',
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: textController,
                        minLines: 5,
                        maxLines: 16,
                        keyboardType: TextInputType.multiline,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.35),
                        decoration: InputDecoration(
                          hintText: "A)\nJavaScript\nclass CustomError extends Error { ... }\n\nB)\nJavaScript\nclass CustomError implements Error { ... }",
                          hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontFamily: 'sans-serif'),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),
                      if (parsedChoices.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          '✓ ${parsedChoices.length} options detected',
                          style: const TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: parsedChoices.isNotEmpty
                      ? () {
                          setState(() {
                            while (_choiceControllers.length < parsedChoices.length && _choiceControllers.length < 8) {
                              _choiceControllers.add(TextEditingController());
                            }
                            for (int i = 0; i < _choiceControllers.length && i < parsedChoices.length; i++) {
                              _choiceControllers[i].text = parsedChoices[i].text;
                              if (parsedChoices[i].isCorrect) {
                                _correctChoiceIndex = i;
                              }
                            }
                          });
                          Navigator.pop(ctx);
                        }
                      : null,
                  child: const Text('Apply Options'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _save() {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a question prompt.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final category = _categoryController.text.trim().isNotEmpty
        ? _categoryController.text.trim()
        : 'General Knowledge';

    final qId = widget.initialQuestion?.id ?? CodeGenerator.generateId('q_custom');
    Question newQuestion;

    if (_selectedType == QuestionType.multipleChoice) {
      final choices = <QuestionChoice>[];
      for (int i = 0; i < _choiceControllers.length; i++) {
        final text = _choiceControllers[i].text.trim();
        if (text.isNotEmpty) {
          choices.add(QuestionChoice(
            id: CodeGenerator.generateId('c'),
            questionId: qId,
            choiceText: text,
            isCorrect: i == _correctChoiceIndex,
            sortOrder: i,
          ));
        }
      }
      if (choices.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please provide at least 2 options for multiple choice.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      newQuestion = Question(
        id: qId,
        topicId: 'custom',
        subjectId: 'custom',
        category: category,
        questionText: prompt,
        questionType: QuestionType.multipleChoice,
        explanation: _expController.text.trim(),
        choices: choices,
      );
    } else if (_selectedType == QuestionType.trueFalse) {
      newQuestion = Question(
        id: qId,
        topicId: 'custom',
        subjectId: 'custom',
        category: category,
        questionText: prompt,
        questionType: QuestionType.trueFalse,
        explanation: _expController.text.trim(),
        choices: [
          QuestionChoice(
            id: CodeGenerator.generateId('c_t'),
            questionId: qId,
            choiceText: 'True',
            isCorrect: _tfCorrectValue,
            sortOrder: 0,
          ),
          QuestionChoice(
            id: CodeGenerator.generateId('c_f'),
            questionId: qId,
            choiceText: 'False',
            isCorrect: !_tfCorrectValue,
            sortOrder: 1,
          ),
        ],
      );
    } else {
      // Matching
      final pairs = <MatchingPair>[];
      for (int i = 0; i < _leftControllers.length; i++) {
        final left = _leftControllers[i].text.trim();
        final right = _rightControllers[i].text.trim();
        if (left.isNotEmpty && right.isNotEmpty) {
          pairs.add(MatchingPair(
            id: CodeGenerator.generateId('m'),
            questionId: qId,
            leftText: left,
            rightText: right,
          ));
        }
      }
      if (pairs.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please provide at least 2 matching pairs.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      newQuestion = Question(
        id: qId,
        topicId: 'custom',
        subjectId: 'custom',
        category: category,
        questionText: prompt,
        questionType: QuestionType.matching,
        explanation: _expController.text.trim(),
        matchingPairs: pairs,
      );
    }

    widget.onQuestionAdded(newQuestion);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.initialQuestion != null
                            ? (widget.lockType ? 'Edit ${_selectedType.label}' : 'Edit Question')
                            : (widget.lockType ? 'Add ${_selectedType.label}' : 'Add Question'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.lockType) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              _selectedType == QuestionType.multipleChoice
                                  ? Icons.radio_button_checked
                                  : _selectedType == QuestionType.trueFalse
                                      ? Icons.check_circle_outline
                                      : Icons.swap_horiz,
                              size: 13,
                              color: AppColors.secondary,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                widget.partNumber != null
                                    ? 'Part ${widget.partNumber}: ${_selectedType.label}'
                                    : _selectedType.label,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.secondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Question Type Selector (only shown when lockType is false)
            if (!widget.lockType) ...[
              Row(
                children: [
                  Expanded(
                    child: SegmentedButton<QuestionType>(
                      segments: const [
                        ButtonSegment(
                          value: QuestionType.multipleChoice,
                          label: Text('MCQ'),
                          icon: Icon(Icons.radio_button_checked, size: 16),
                        ),
                        ButtonSegment(
                          value: QuestionType.trueFalse,
                          label: Text('T/F'),
                          icon: Icon(Icons.check_circle_outline, size: 16),
                        ),
                        ButtonSegment(
                          value: QuestionType.matching,
                          label: Text('Match'),
                          icon: Icon(Icons.compare_arrows, size: 16),
                        ),
                      ],
                      selected: {_selectedType},
                      onSelectionChanged: (set) {
                        setState(() => _selectedType = set.first);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],


            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  child: Text(
                    'QUESTION PROMPT *',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => _isPromptExpanded = !_isPromptExpanded),
                  icon: Icon(_isPromptExpanded ? Icons.unfold_less : Icons.unfold_more, size: 14),
                  label: Text(
                    _isPromptExpanded ? 'Compact' : 'Expand Height',
                    style: const TextStyle(fontSize: 11),
                  ),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _promptController,
              minLines: _isPromptExpanded ? 10 : 3,
              maxLines: _isPromptExpanded ? 24 : 8,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              style: const TextStyle(fontSize: 14, height: 1.45),
              decoration: InputDecoration(
                hintText: 'Enter question text or paste code snippet here...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white38
                      : Colors.black38,
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.all(12),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),

            // MCQ Option Inputs
            if (_selectedType == QuestionType.multipleChoice) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Flexible(
                    child: Text(
                      'OPTIONS (Mark the correct answer)',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _showBulkPasteChoicesDialog,
                    icon: const Icon(Icons.bolt, size: 14),
                    label: const Text('Quick Paste', style: TextStyle(fontSize: 11)),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...List.generate(_choiceControllers.length, (i) {
                final letter = String.fromCharCode(65 + i);
                final isSelectedCorrect = _correctChoiceIndex == i;
                final isDark = Theme.of(context).brightness == Brightness.dark;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSelectedCorrect
                        ? AppColors.success.withValues(alpha: isDark ? 0.12 : 0.06)
                        : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelectedCorrect
                          ? AppColors.success.withValues(alpha: 0.55)
                          : (isDark ? Colors.white12 : Colors.black12),
                      width: isSelectedCorrect ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelectedCorrect
                                  ? AppColors.success
                                  : (isDark ? Colors.white12 : Colors.black12),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              letter,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: isSelectedCorrect
                                    ? Colors.white
                                    : (isDark ? Colors.white70 : Colors.black87),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => setState(() => _correctChoiceIndex = i),
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Radio<int>(
                                    value: i,
                                    // ignore: deprecated_member_use
                                    groupValue: _correctChoiceIndex,
                                    activeColor: AppColors.success,
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    // ignore: deprecated_member_use
                                    onChanged: (val) {
                                      if (val != null) setState(() => _correctChoiceIndex = val);
                                    },
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isSelectedCorrect ? 'Correct Answer' : 'Mark as Correct',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSelectedCorrect ? FontWeight.w700 : FontWeight.w500,
                                      color: isSelectedCorrect
                                          ? AppColors.success
                                          : (isDark ? Colors.white54 : Colors.black54),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (_choiceControllers.length > 2)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18),
                              color: Colors.red.shade400,
                              tooltip: 'Remove Option $letter',
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                setState(() {
                                  _choiceControllers[i].dispose();
                                  _choiceControllers.removeAt(i);
                                  if (_correctChoiceIndex >= _choiceControllers.length) {
                                    _correctChoiceIndex = 0;
                                  }
                                });
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _choiceControllers[i],
                        minLines: 2,
                        maxLines: 12,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          fontFamily: 'monospace',
                        ),
                        decoration: InputDecoration(
                          hintText: 'Option $letter text or code snippet (supports newlines)...',
                          hintStyle: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white38 : Colors.black38,
                            fontFamily: 'sans-serif',
                          ),
                          contentPadding: const EdgeInsets.all(10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              if (_choiceControllers.length < 8)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _choiceControllers.add(TextEditingController());
                      });
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(
                      'Add Option ${String.fromCharCode(65 + _choiceControllers.length)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
            ],

            // True / False Input
            if (_selectedType == QuestionType.trueFalse) ...[
              const Text(
                'CORRECT ANSWER',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('True'),
                    selected: _tfCorrectValue,
                    selectedColor: AppColors.success,
                    onSelected: (val) => setState(() => _tfCorrectValue = true),
                  ),
                  const SizedBox(width: 12),
                  ChoiceChip(
                    label: const Text('False'),
                    selected: !_tfCorrectValue,
                    selectedColor: AppColors.error,
                    onSelected: (val) => setState(() => _tfCorrectValue = false),
                  ),
                ],
              ),
            ],

            // Matching Type Inputs
            if (_selectedType == QuestionType.matching) ...[
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  const Text(
                    'MATCHING PAIRS (Left matches Right)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                  ),
                  Wrap(
                    spacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _showBulkPasteDialog,
                        icon: const Icon(Icons.bolt, size: 14),
                        label: const Text('Quick Paste'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.swap_horiz, size: 18),
                        tooltip: 'Swap Left & Right Columns',
                        onPressed: _swapMatchingSides,
                        visualDensity: VisualDensity.compact,
                      ),
                      TextButton.icon(
                        onPressed: _leftControllers.length < 10 ? _addPair : null,
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text('Add Pair', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...List.generate(_leftControllers.length, (i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _leftControllers[i],
                          decoration: InputDecoration(
                            hintText: 'Item ${i + 1}',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.arrow_forward, size: 16, color: AppColors.secondary),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _rightControllers[i],
                          decoration: InputDecoration(
                            hintText: 'Match ${i + 1}',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                        ),
                      ),
                      if (_leftControllers.length > 2)
                        IconButton(
                          icon: const Icon(Icons.close, size: 18, color: AppColors.error),
                          tooltip: 'Remove Pair',
                          onPressed: () => _removePair(i),
                        ),
                    ],
                  ),
                );
              }),
            ],
            const SizedBox(height: 16),

            TextField(
              controller: _expController,
              decoration: const InputDecoration(
                labelText: 'Explanation (Optional)',
                hintText: 'Explains why the correct answer is right...',
              ),
            ),
            const SizedBox(height: 24),

            CustomButton(
              text: widget.initialQuestion != null ? 'Update Question' : 'Save Question',
              icon: Icons.check,
              variant: ButtonVariant.primaryGradient,
              width: double.infinity,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
