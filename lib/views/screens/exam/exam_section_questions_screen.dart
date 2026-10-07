import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../models/question_model.dart';
import '../../../controllers/exam_maker_controller.dart';
import '../../components/common/gradient_card.dart';
import 'exam_maker_screen.dart';
import 'bulk_import_questions_dialog.dart';

class ExamSectionQuestionsScreen extends ConsumerWidget {
  final QuestionType sectionType;

  const ExamSectionQuestionsScreen({
    super.key,
    required this.sectionType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(examMakerControllerProvider);
    final notifier = ref.read(examMakerControllerProvider.notifier);

    final partIndex = state.sectionOrder.indexOf(sectionType);
    final partNumber = partIndex >= 0 ? partIndex + 1 : 1;

    // Filter questions belonging to this section
    final sectionQuestions = state.questions
        .asMap()
        .entries
        .where((e) => e.value.questionType == sectionType)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Part $partNumber: ${sectionType.label}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (sectionType != QuestionType.matching)
            TextButton.icon(
              onPressed: () {
                showBulkImportQuestionsSheet(
                  context,
                  initialType: sectionType,
                  lockType: true,
                  partNumber: partNumber,
                );
              },
              icon: const Icon(Icons.bolt, size: 16, color: AppColors.secondary),
              label: const Text(
                'Bulk Paste',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.secondary,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${sectionQuestions.length} Qs',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.secondary,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: ResponsiveContainer(
          maxWidth: 800,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [


              // Questions List or Empty State
              if (sectionQuestions.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF14141E) : const Color(0xFFF9F9FC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF242436) : const Color(0xFFE6E6EE),
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          sectionType == QuestionType.matching
                              ? Icons.swap_horiz
                              : (sectionType == QuestionType.trueFalse
                                  ? Icons.check_circle_outline
                                  : Icons.radio_button_checked),
                          size: 40,
                          color: isDark ? Colors.white24 : Colors.black26,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No ${sectionType.label} questions added yet',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Questions added here will only appear in Part $partNumber.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          alignment: WrapAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                showAddQuestionSheet(
                                  context,
                                  defaultCategory: state.subject,
                                  initialType: sectionType,
                                  lockType: true,
                                  partNumber: partNumber,
                                  onQuestionAdded: (q) => notifier.addQuestion(q),
                                );
                              },
                              icon: const Icon(Icons.add, size: 16),
                              label: Text('Add First ${sectionType.label} Question'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.secondary,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            if (sectionType != QuestionType.matching)
                              OutlinedButton.icon(
                                onPressed: () {
                                  showBulkImportQuestionsSheet(
                                    context,
                                    initialType: sectionType,
                                    lockType: true,
                                    partNumber: partNumber,
                                  );
                                },
                                icon: const Icon(Icons.bolt, size: 16, color: AppColors.secondary),
                                label: const Text('Bulk Paste Questions'),
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
                  itemCount: sectionQuestions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, index) {
                    final originalIndex = sectionQuestions[index].key;
                    final q = sectionQuestions[index].value;

                    return GradientCard(
                      padding: const EdgeInsets.all(14),
                      onTap: () {
                        showAddQuestionSheet(
                          context,
                          defaultCategory: state.subject,
                          initialType: q.questionType,
                          initialQuestion: q,
                          lockType: true,
                          partNumber: partNumber,
                          onQuestionAdded: (updated) => notifier.updateQuestion(originalIndex, updated),
                        );
                      },
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.secondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (q.questionType == QuestionType.matching) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${q.matchingPairs.length} pairs',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                ],
                                Text(
                                  q.questionText,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                ),
                                const SizedBox(height: 6),
                                if (q.questionType == QuestionType.multipleChoice) ...[
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: q.choices.map((c) {
                                      final isCorrect = c.isCorrect;
                                      return Container(
                                        constraints: const BoxConstraints(maxWidth: 160),
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isCorrect
                                              ? AppColors.success.withValues(alpha: 0.15)
                                              : (isDark ? Colors.white10 : Colors.black12),
                                          borderRadius: BorderRadius.circular(6),
                                          border: isCorrect
                                              ? Border.all(color: AppColors.success.withValues(alpha: 0.4))
                                              : null,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (isCorrect) ...[
                                              const Icon(Icons.check, size: 11, color: AppColors.success),
                                              const SizedBox(width: 3),
                                            ],
                                            Flexible(
                                              child: Text(
                                                c.choiceText,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: isCorrect ? FontWeight.w700 : FontWeight.w500,
                                                  color: isCorrect ? AppColors.success : null,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ] else if (q.questionType == QuestionType.trueFalse) ...[
                                  Builder(builder: (context) {
                                    final isTrueCorrect = q.choices.any((c) => c.choiceText.toLowerCase() == 'true' && c.isCorrect);
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: (isTrueCorrect ? AppColors.success : AppColors.error)
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Answer: ${isTrueCorrect ? "True" : "False"}',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: isTrueCorrect ? AppColors.success : AppColors.error,
                                        ),
                                      ),
                                    );
                                  }),
                                ] else if (q.questionType == QuestionType.matching) ...[
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: q.matchingPairs.map((pair) {
                                      return Container(
                                        constraints: const BoxConstraints(maxWidth: 180),
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.white10 : Colors.black12,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '${pair.leftText} ➔ ${pair.rightText}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                                if (q.explanation.trim().isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    '💡 ${q.explanation.trim()}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.secondary),
                            tooltip: 'Edit question',
                            onPressed: () {
                              showAddQuestionSheet(
                                context,
                                defaultCategory: state.subject,
                                initialType: q.questionType,
                                initialQuestion: q,
                                lockType: true,
                                partNumber: partNumber,
                                onQuestionAdded: (updated) => notifier.updateQuestion(originalIndex, updated),
                              );
                            },
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
                    );
                  },
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        onPressed: () {
          showAddQuestionSheet(
            context,
            defaultCategory: state.subject,
            initialType: sectionType,
            lockType: true,
            partNumber: partNumber,
            onQuestionAdded: (q) => notifier.addQuestion(q),
          );
        },
        icon: const Icon(Icons.add),
        label: Text('Add ${sectionType == QuestionType.matching ? "Matching" : (sectionType == QuestionType.trueFalse ? "T/F" : "MCQ")}'),
      ),
    );
  }
}
