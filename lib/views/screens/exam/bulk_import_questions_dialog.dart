import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/bulk_question_parser.dart';
import '../../../models/question_model.dart';
import '../../../controllers/exam_maker_controller.dart';

void showBulkImportQuestionsSheet(
  BuildContext context, {
  QuestionType initialType = QuestionType.multipleChoice,
  bool lockType = false,
  int? partNumber,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: BulkImportQuestionsSheet(
          initialType: initialType,
          lockType: lockType,
          partNumber: partNumber,
        ),
      ),
    ),
  );
}

class BulkImportQuestionsSheet extends ConsumerStatefulWidget {
  final QuestionType initialType;
  final bool lockType;
  final int? partNumber;

  const BulkImportQuestionsSheet({
    super.key,
    this.initialType = QuestionType.multipleChoice,
    this.lockType = false,
    this.partNumber,
  });

  @override
  ConsumerState<BulkImportQuestionsSheet> createState() => _BulkImportQuestionsSheetState();
}

class _BulkImportQuestionsSheetState extends ConsumerState<BulkImportQuestionsSheet> {
  late final TextEditingController _textController;
  late QuestionType _selectedType;
  bool _showPreview = false;

  static const String _sampleText = '''1. Which keyword declares a block-scoped variable that cannot be reassigned?
A) var
B) let
C) const
D) static

2. Which of the following is the correct syntax for a single-line comment in JavaScript?
A) <!-- comment -->
B) # comment
C) // comment
D) /* comment */

3. Which HTML tag and attribute combination correctly links an external JavaScript file called main.js?
A) <script href="main.js"></script>
B) <script src="main.js"></script>
C) <javascript link="main.js"></javascript>
D) <link rel="script" href="main.js">

4. Which of the following represents a valid JSON string?
A) "{ 'name': 'John', 'age': 30 }"
B) '{ "name": "John", "age": 30 }'
C) '{ name: "John", age: 30 }'
D) '{ "name": "John", "age": 30, }'

5. How do you access the first element of an array named colors?
A) colors[0]
B) colors[1]
C) colors.first()
D) colors(0)''';

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    _textController = TextEditingController();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _loadSample() {
    setState(() {
      _textController.text = _sampleText;
      _showPreview = true;
    });
  }

  void _clearText() {
    setState(() {
      _textController.clear();
      _showPreview = false;
    });
  }

  void _importQuestions(List<ParsedQuestion> parsed) {
    if (parsed.isEmpty) return;

    final state = ref.read(examMakerControllerProvider);
    final questions = parsed
        .map((p) => p.toQuestion(subject: state.subject))
        .toList();

    ref.read(examMakerControllerProvider.notifier).addQuestions(questions);

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Successfully imported ${questions.length} questions! You can tap any question to edit the correct answer and explanation.',
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final parsed = BulkQuestionParser.parse(
      _textController.text,
      targetType: _selectedType,
    );

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomInset),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161622) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Grab Bar
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.playlist_add, color: AppColors.secondary, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.partNumber != null
                            ? 'Bulk Import Questions (Part ${widget.partNumber})'
                            : 'Bulk Import Questions',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Paste multiple questions at once to save time.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Question Type Selector (if not locked)
            if (!widget.lockType) ...[
              Row(
                children: [
                  const Text(
                    'Target Section: ',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Multiple Choice (MCQ)', style: TextStyle(fontSize: 12)),
                    selected: _selectedType == QuestionType.multipleChoice,
                    onSelected: (val) {
                      if (val) setState(() => _selectedType = QuestionType.multipleChoice);
                    },
                    selectedColor: AppColors.secondary.withValues(alpha: 0.2),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('True / False', style: TextStyle(fontSize: 12)),
                    selected: _selectedType == QuestionType.trueFalse,
                    onSelected: (val) {
                      if (val) setState(() => _selectedType = QuestionType.trueFalse);
                    },
                    selectedColor: AppColors.secondary.withValues(alpha: 0.2),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Action Toolbar (Insert Sample / Clear)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Paste your questions below:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _loadSample,
                      icon: const Icon(Icons.format_quote, size: 15),
                      label: const Text('Load Sample', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: AppColors.secondary,
                      ),
                    ),
                    if (_textController.text.isNotEmpty)
                      TextButton.icon(
                        onPressed: _clearText,
                        icon: const Icon(Icons.clear, size: 15),
                        label: const Text('Clear', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: AppColors.error,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Text input area
            TextField(
              controller: _textController,
              maxLines: 10,
              minLines: 7,
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace', height: 1.4),
              decoration: InputDecoration(
                hintText: "1. Which keyword declares a block-scoped variable?\nA) var\nB) let\nC) const\nD) static\n\n2. Next question prompt?\nA) Option A\nB) Option B\nC) Option C\nD) Option D",
                hintStyle: TextStyle(
                  color: isDark ? Colors.white30 : Colors.black26,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF2E2E3E) : const Color(0xFFD6D6E2),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.secondary, width: 2),
                ),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F0F18) : const Color(0xFFFAFAFE),
                contentPadding: const EdgeInsets.all(14),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),

            // Live status & Preview Toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: parsed.isNotEmpty
                    ? AppColors.success.withValues(alpha: 0.12)
                    : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04)),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: parsed.isNotEmpty
                      ? AppColors.success.withValues(alpha: 0.3)
                      : (isDark ? Colors.white12 : Colors.black12),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    parsed.isNotEmpty ? Icons.check_circle_outline : Icons.info_outline,
                    color: parsed.isNotEmpty ? AppColors.success : (isDark ? Colors.white54 : Colors.black45),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      parsed.isNotEmpty
                          ? '✓ ${parsed.length} questions recognized and ready to import'
                          : 'Questions should be separated by a blank line with options (A, B, C, D).',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: parsed.isNotEmpty ? FontWeight.w700 : FontWeight.w500,
                        color: parsed.isNotEmpty
                            ? (isDark ? Colors.greenAccent : const Color(0xFF1E7E34))
                            : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                  ),
                  if (parsed.isNotEmpty)
                    TextButton(
                      onPressed: () => setState(() => _showPreview = !_showPreview),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: Text(
                        _showPreview ? 'Hide Preview' : 'Review (${parsed.length})',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
            ),

            // Preview Accordion
            if (_showPreview && parsed.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF12121D) : const Color(0xFFF3F3FA),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(10),
                  itemCount: parsed.length,
                  separatorBuilder: (_, __) => const Divider(height: 12),
                  itemBuilder: (ctx, idx) {
                    final item = parsed[idx];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${idx + 1}. ${item.questionText}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: item.choices.asMap().entries.map((c) {
                            final letter = String.fromCharCode(65 + c.key);
                            final isDefaultCorrect = c.key == item.correctChoiceIndex;
                            return Container(
                              constraints: const BoxConstraints(maxWidth: 160),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDefaultCorrect
                                    ? AppColors.secondary.withValues(alpha: 0.15)
                                    : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '$letter) ${c.value}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isDefaultCorrect ? FontWeight.w700 : FontWeight.w500,
                                  color: isDefaultCorrect ? AppColors.secondary : null,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Creator notice / instruction
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1B1B26) : const Color(0xFFF7F7FD),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.edit_note, size: 16, color: AppColors.secondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Default answer is choice A. You can tap on any question in your exam builder after importing to set the correct answer and add an explanation.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: parsed.isNotEmpty ? () => _importQuestions(parsed) : null,
                    icon: const Icon(Icons.download_done, size: 18),
                    label: Text(
                      parsed.isNotEmpty
                          ? 'Import ${parsed.length} Questions'
                          : 'Import Questions',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
