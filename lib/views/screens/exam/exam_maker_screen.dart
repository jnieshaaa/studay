import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../controllers/exam_maker_controller.dart';
import '../../../controllers/auth_controller.dart';
import '../../../models/exam_model.dart';
import '../../../models/question_model.dart';
import '../../../core/utils/code_generator.dart';
import '../../components/common/gradient_card.dart';
import '../../components/common/custom_button.dart';
import '../../components/common/custom_badge.dart';

class ExamMakerScreen extends ConsumerStatefulWidget {
  final Exam? initialExam;
  const ExamMakerScreen({super.key, this.initialExam});

  @override
  ConsumerState<ExamMakerScreen> createState() => _ExamMakerScreenState();
}

class _ExamMakerScreenState extends ConsumerState<ExamMakerScreen> {
  late final TextEditingController _subjectController;
  late final TextEditingController _titleController;
  late final TextEditingController _descController;

  @override
  void initState() {
    super.initState();
    final exam = widget.initialExam;
    _subjectController = TextEditingController(text: exam?.effectiveSubject ?? 'Math');
    _titleController = TextEditingController(text: exam?.title ?? '');
    _descController = TextEditingController(text: exam?.description ?? '');

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
    super.dispose();
  }

  void _showAddQuestionDialog([QuestionType? initialType]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: _AddQuestionSheet(
            defaultCategory: _subjectController.text.trim(),
            initialType: initialType,
            onQuestionAdded: (q) {
              ref.read(examMakerControllerProvider.notifier).addQuestion(q);
            },
          ),
        ),
      ),
    );
  }

  void _showEditQuestionDialog(int index, Question question) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: _AddQuestionSheet(
            defaultCategory: question.effectiveCategory,
            initialQuestion: question,
            onQuestionAdded: (updated) {
              ref.read(examMakerControllerProvider.notifier).updateQuestion(index, updated);
            },
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(examMakerControllerProvider);
    final notifier = ref.read(examMakerControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          state.isEditing ? 'Edit Quiz' : 'Create Exam',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (state.questions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${state.questions.length} Qs',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.secondary),
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
                          style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Basic Info Card
              GradientCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'BASIC DETAILS',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Exam Title *',
                        hintText: 'e.g. Midterm General Science Reviewer',
                      ),
                      onChanged: notifier.setTitle,
                    ),
                    const SizedBox(height: 14),

                    // Subject Input with Quick Chips
                    TextField(
                      controller: _subjectController,
                      decoration: const InputDecoration(
                        labelText: 'Subject Category *',
                        hintText: 'e.g. Math, Science, English, Filipino...',
                      ),
                      onChanged: notifier.setSubject,
                    ),
                    const SizedBox(height: 8),
                    // Quick Subject Chips
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: ['Math', 'English', 'Filipino', 'Science'].map((subj) {
                        final isSelected = _subjectController.text.trim().toLowerCase() == subj.toLowerCase();
                        return FilterChip(
                          label: Text(subj),
                          selected: isSelected,
                          selectedColor: AppColors.secondary.withValues(alpha: 0.25),
                          checkmarkColor: AppColors.secondary,
                          onSelected: (_) {
                            setState(() {
                              _subjectController.text = subj;
                            });
                            notifier.setSubject(subj);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    TextField(
                      controller: _descController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Description / Instructions',
                        hintText: 'Optional instructions for participants...',
                      ),
                      onChanged: notifier.setDescription,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Exam Section Order (Parts) Card
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
                            Icon(Icons.format_list_numbered, size: 18, color: AppColors.secondary),
                            SizedBox(width: 8),
                            Text(
                              'EXAM SECTION ORDER',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8),
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
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.secondary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Question types are grouped into separate parts. Choose which type takers answer first, second, or third.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
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
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
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

                    // Reorderable parts list
                    ...state.sectionOrder.asMap().entries.map((entry) {
                      final partIdx = entry.key;
                      final type = entry.value;
                      final count = state.questions.where((q) => q.questionType == type).length;
                      final isFirst = partIdx == 0;
                      final isLast = partIdx == state.sectionOrder.length - 1;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCard : AppColors.lightCard,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isFirst
                                ? AppColors.secondary.withValues(alpha: 0.5)
                                : (isDark ? const Color(0xFF2B2B3D) : const Color(0xFFE4E4EC)),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: isFirst ? AppColors.secondary : (isDark ? Colors.white12 : Colors.black12),
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
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Part ${partIdx + 1}: ${type.label}',
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: count > 0
                                          ? AppColors.primary.withValues(alpha: 0.15)
                                          : (isDark ? Colors.white10 : Colors.black12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '$count Qs',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: count > 0 ? AppColors.primary : Colors.grey,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.arrow_upward, size: 18),
                              tooltip: 'Move Up',
                              onPressed: !isFirst ? () => notifier.moveSectionUp(type) : null,
                              visualDensity: VisualDensity.compact,
                            ),
                            IconButton(
                              icon: const Icon(Icons.arrow_downward, size: 18),
                              tooltip: 'Move Down',
                              onPressed: !isLast ? () => notifier.moveSectionDown(type) : null,
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Overall Questions Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'QUESTIONS BY SECTION (${state.questions.length} TOTAL)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showAddQuestionDialog(),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Question'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Separated Sections List
              ...state.sectionOrder.asMap().entries.map((sectionEntry) {
                final sectionIndex = sectionEntry.key;
                final type = sectionEntry.value;
                final sectionQuestions = state.questions
                    .asMap()
                    .entries
                    .where((e) => e.value.questionType == type)
                    .toList();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF161624) : const Color(0xFFF9F9FC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF28283B) : const Color(0xFFE2E2EA),
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section Header
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
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'PART ${sectionIndex + 1}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.secondary,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${type.label.toUpperCase()} (${sectionQuestions.length})',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            ElevatedButton.icon(
                              onPressed: () => _showAddQuestionDialog(type),
                              icon: const Icon(Icons.add, size: 14),
                              label: Text('Add ${type == QuestionType.matching ? "Matching" : (type == QuestionType.trueFalse ? "T/F" : "MCQ")}'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.secondary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),


                        if (sectionQuestions.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? Colors.white10 : Colors.black12,
                              ),
                            ),
                            child: Center(
                              child: Column(
                                children: [
                                  Text(
                                    'No ${type.label} questions in Part ${sectionIndex + 1} yet',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextButton.icon(
                                    onPressed: () => _showAddQuestionDialog(type),
                                    icon: const Icon(Icons.add, size: 15),
                                    label: Text('Add ${type.label} Question', style: const TextStyle(fontSize: 12)),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ...sectionQuestions.asMap().entries.map((qEntry) {
                            final inSectionIndex = qEntry.key;
                            final originalIndex = qEntry.value.key;
                            final q = qEntry.value.value;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: GradientCard(
                                padding: const EdgeInsets.all(12),
                                onTap: () => _showEditQuestionDialog(originalIndex, q),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 26,
                                      height: 26,
                                      decoration: BoxDecoration(
                                        color: AppColors.secondary.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(7),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '${inSectionIndex + 1}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.secondary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            children: [
                                              CustomBadge.questionType(q.questionType),
                                              CustomBadge.difficulty(q.difficulty),
                                              if (q.questionType == QuestionType.matching)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primary.withValues(alpha: 0.15),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    '${q.matchingPairs.length} Pairs',
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w700,
                                                      color: AppColors.primary,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            q.questionText,
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, color: AppColors.secondary, size: 18),
                                      tooltip: 'Edit question',
                                      onPressed: () => _showEditQuestionDialog(originalIndex, q),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 18),
                                      tooltip: 'Delete question',
                                      onPressed: () => notifier.removeQuestion(originalIndex),
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
                );
              }),

              const SizedBox(height: 24),

              // Exam Settings Card
              GradientCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'EXAM SETTINGS',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1),
                    ),
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 12),
                    const Text('Show Answers to Participants', style: TextStyle(fontWeight: FontWeight.w700)),
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
                    const SizedBox(height: 16),
                    const Text('Time Limit (Countdown Timer)', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [null, 5, 10, 15, 30, 45, 60].map((mins) {
                        final isSelected = state.durationMinutes == mins;
                        return ChoiceChip(
                          label: Text(mins == null ? 'Untimed' : '${mins}m'),
                          selected: isSelected,
                          selectedColor: AppColors.secondary,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : null,
                            fontWeight: FontWeight.w700,
                          ),
                          onSelected: (_) => notifier.setDurationMinutes(mins),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Publish or Save Changes Button
              CustomButton(
                text: state.isEditing
                    ? 'Save Changes (Code: ${state.editingExamCode})'
                    : 'Publish Exam & Get 6-Char Code',
                icon: state.isEditing ? Icons.check_circle_outline : Icons.rocket_launch,
                isLoading: state.isPublishing,
                variant: state.isEditing ? ButtonVariant.secondary : ButtonVariant.primaryGradient,
                width: double.infinity,
                onPressed: () async {
                  final authState = ref.read(authControllerProvider);
                  if (!authState.isAuthenticated) {
                    context.push('/setup-username');
                    return;
                  }
                  notifier.setSubject(_subjectController.text.trim());
                  notifier.setTitle(_titleController.text.trim());
                  notifier.setDescription(_descController.text.trim());
                  final router = GoRouter.of(context);
                  final saved = await notifier.publish();
                  if (saved != null && context.mounted) {
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
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddQuestionSheet extends StatefulWidget {
  final String? defaultCategory;
  final QuestionType? initialType;
  final Question? initialQuestion;
  final Function(Question q) onQuestionAdded;
  const _AddQuestionSheet({
    this.defaultCategory,
    this.initialType,
    this.initialQuestion,
    required this.onQuestionAdded,
  });

  @override
  State<_AddQuestionSheet> createState() => _AddQuestionSheetState();
}

class _AddQuestionSheetState extends State<_AddQuestionSheet> {
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

  @override
  void initState() {
    super.initState();
    final init = widget.initialQuestion;
    _selectedType = init?.questionType ?? widget.initialType ?? QuestionType.multipleChoice;
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

  void _showBulkPasteChoicesDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final lines = textController.text
                .split(RegExp(r'\r?\n'))
                .map((l) => l.trim())
                .where((l) => l.isNotEmpty)
                .toList();

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
                width: 450,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Paste up to 4 options (one per line):', style: TextStyle(fontSize: 12)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: textController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: "Option 1\nOption 2\nOption 3\nOption 4",
                        hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: lines.isNotEmpty
                      ? () {
                          setState(() {
                            for (int i = 0; i < _choiceControllers.length && i < lines.length; i++) {
                              _choiceControllers[i].text = lines[i];
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
    if (prompt.isEmpty) return;

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
                Text(
                  widget.initialQuestion != null ? 'Edit Question' : 'Add Question',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Question Type Selector
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

            TextField(
              controller: _categoryController,
              decoration: const InputDecoration(
                labelText: 'Question Category (Optional)',
                hintText: 'e.g. Vocabulary, Algebra, Constitution...',
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _promptController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Question Prompt *',
                hintText: 'Enter your question here...',
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
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...List.generate(_choiceControllers.length, (i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Radio<int>(
                        value: i,
                        // ignore: deprecated_member_use
                        groupValue: _correctChoiceIndex,
                        activeColor: AppColors.success,
                        // ignore: deprecated_member_use
                        onChanged: (val) {
                          if (val != null) setState(() => _correctChoiceIndex = val);
                        },
                      ),
                      Expanded(
                        child: TextField(
                          controller: _choiceControllers[i],
                          decoration: InputDecoration(
                            hintText: 'Option ${i + 1}',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
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
