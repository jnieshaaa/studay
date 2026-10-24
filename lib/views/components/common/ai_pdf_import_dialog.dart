import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/pdf_extractor.dart';
import '../../../models/question_model.dart';
import '../../../controllers/providers.dart';

/// Modal dialog for uploading a PDF and using Google Gemini AI
/// to generate either exam questions (MCQ, True/False, Matching) or study flashcards.
class AiPdfImportDialog extends ConsumerStatefulWidget {
  final bool isFlashcardMode;
  final String? defaultSubject;
  final Function(List<Question> questions)? onQuestionsGenerated;
  final Function(List<Map<String, String>> flashcards)? onFlashcardsGenerated;

  const AiPdfImportDialog({
    super.key,
    this.isFlashcardMode = false,
    this.defaultSubject,
    this.onQuestionsGenerated,
    this.onFlashcardsGenerated,
  });

  static Future<void> show(
    BuildContext context, {
    bool isFlashcardMode = false,
    String? defaultSubject,
    Function(List<Question> questions)? onQuestionsGenerated,
    Function(List<Map<String, String>> flashcards)? onFlashcardsGenerated,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AiPdfImportDialog(
        isFlashcardMode: isFlashcardMode,
        defaultSubject: defaultSubject,
        onQuestionsGenerated: onQuestionsGenerated,
        onFlashcardsGenerated: onFlashcardsGenerated,
      ),
    );
  }

  @override
  ConsumerState<AiPdfImportDialog> createState() => _AiPdfImportDialogState();
}

class _AiPdfImportDialogState extends ConsumerState<AiPdfImportDialog> {
  ExtractedPdfData? _pdfData;
  bool _isExtractingPdf = false;
  bool _isGenerating = false;
  String _statusMessage = '';
  String? _errorMessage;

  // Settings
  int _itemCount = 10;
  bool _includeMcq = true;
  bool _includeTrueFalse = true;
  bool _includeMatching = true;

  // Cache & Token Saver State
  bool _hasCachedContent = false;

  int get _selectedTypesCount {
    int count = 0;
    if (_includeMcq) count++;
    if (_includeTrueFalse) count++;
    if (_includeMatching) count++;
    return count > 0 ? count : 1;
  }



  Future<void> _checkCachedContent() async {
    if (_pdfData == null || _pdfData!.text.trim().isEmpty) {
      if (_hasCachedContent && mounted) {
        setState(() => _hasCachedContent = false);
      }
      return;
    }

    final aiService = ref.read(aiGeneratorServiceProvider);
    bool cached = false;

    if (widget.isFlashcardMode) {
      cached = await aiService.hasCachedFlashcards(
        _pdfData!.text,
        count: _itemCount,
      );
    } else {
      final types = <QuestionType>[];
      if (_includeMcq) types.add(QuestionType.multipleChoice);
      if (_includeTrueFalse) types.add(QuestionType.trueFalse);
      if (_includeMatching) types.add(QuestionType.matching);
      if (types.isEmpty) types.add(QuestionType.multipleChoice);

      cached = await aiService.hasCachedQuestions(
        _pdfData!.text,
        count: _itemCount,
        types: types,
      );
    }

    if (mounted) {
      setState(() {
        _hasCachedContent = cached;
      });
    }
  }

  Future<void> _pickPdf() async {
    setState(() {
      _isExtractingPdf = true;
      _errorMessage = null;
    });

    try {
      final data = await PdfExtractor.pickAndExtractText();
      if (!mounted) return;

      if (data == null) {
        setState(() => _isExtractingPdf = false);
        return;
      }

      if (data.text.trim().isEmpty) {
        setState(() {
          _isExtractingPdf = false;
          _errorMessage =
              'No readable text could be extracted from "${data.fileName}". Make sure it is not a scanned image PDF without OCR.';
        });
        return;
      }

      setState(() {
        _pdfData = data;
        _isExtractingPdf = false;
      });

      await _checkCachedContent();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isExtractingPdf = false;
        _errorMessage = 'Failed to extract text from PDF: $e';
      });
    }
  }

  Future<void> _startAiGeneration({bool skipCache = false}) async {
    if (_pdfData == null || _pdfData!.text.isEmpty) {
      setState(() => _errorMessage = 'Please select a PDF file first.');
      return;
    }

    // Transparently resolve API key in background without prompting client
    final aiService = ref.read(aiGeneratorServiceProvider);

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
      _statusMessage = (!skipCache && _hasCachedContent)
          ? 'Loading cached results instantly (0 tokens consumed)...'
          : 'Gemini 1.5 Flash is reading document content...';
    });

    try {
      if (widget.isFlashcardMode) {
        if (skipCache || !_hasCachedContent) {
          setState(() => _statusMessage = 'Extracting key concepts & definitions into flashcards...');
        }
        final flashcards = await aiService.generateFlashcardsFromText(
          _pdfData!.text,
          count: _itemCount,
          subject: widget.defaultSubject,
          skipCache: skipCache,
        );

        if (!mounted) return;
        Navigator.pop(context);
        widget.onFlashcardsGenerated?.call(flashcards);
      } else {
        final types = <QuestionType>[];
        if (_includeMcq) types.add(QuestionType.multipleChoice);
        if (_includeTrueFalse) types.add(QuestionType.trueFalse);
        if (_includeMatching) types.add(QuestionType.matching);

        if (types.isEmpty) types.add(QuestionType.multipleChoice);

        if (skipCache || !_hasCachedContent) {
          setState(() => _statusMessage = 'Formulating multiple-choice, true/false & matching questions...');
        }
        final questions = await aiService.generateQuestionsFromText(
          _pdfData!.text,
          count: _itemCount,
          subject: widget.defaultSubject,
          types: types,
          skipCache: skipCache,
        );

        if (!mounted) return;
        Navigator.pop(context);
        widget.onQuestionsGenerated?.call(questions);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isGenerating = false;
        _errorMessage =
            'AI document processing is temporarily unavailable. Please verify your connection or try again shortly.';
      });
      debugPrint('[AiPdfImportDialog] Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isFlashcardMode ? 'Generate Flashcards from PDF' : 'Generate Exam from PDF',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Automated AI Study Assistant',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _isGenerating ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Error Banner
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline, size: 18, color: AppColors.error),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(fontSize: 12.5, color: AppColors.error),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Step 1: Select PDF
                    const Text(
                      '1. SELECT PDF DOCUMENT',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 8),

                    if (_pdfData == null) ...[
                      InkWell(
                        onTap: _isExtractingPdf || _isGenerating ? null : _pickPdf,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkCard : AppColors.lightCard,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: Column(
                            children: [
                              if (_isExtractingPdf) ...[
                                const SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(strokeWidth: 2.5),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Extracting text from PDF...',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ] else ...[
                                Icon(
                                  Icons.upload_file,
                                  size: 36,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Tap to choose PDF from device',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Lecture notes, chapters, slides, or study guides',
                                  style: TextStyle(fontSize: 11.5, color: Colors.grey),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.picture_as_pdf, color: AppColors.primary, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _pdfData!.fileName,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_pdfData!.pageCount} pages • ~${(_pdfData!.text.length / 1000).toStringAsFixed(1)}k characters extracted',
                                    style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: _isGenerating ? null : _pickPdf,
                              child: const Text('Change', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Token-Saver Cache Hit Notification
                    if (_hasCachedContent) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF059669).withValues(alpha: 0.5) : const Color(0xFF6EE7B7),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.bolt, color: Color(0xFF059669), size: 20),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Duplicate Document Detected',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF047857)),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    '0 TOKENS • INSTANT',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF047857)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'This exact document has already been processed with these settings. You can load it immediately without consuming any AI tokens, or request a fresh new batch.',
                              style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey[300] : Colors.grey[800]),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Step 2: Settings (Count & Types)
                    const Text(
                      '2. GENERATION PREFERENCES',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 10),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isFlashcardMode
                              ? 'Number of flashcards: $_itemCount'
                              : 'Questions per type: $_itemCount (${_itemCount * _selectedTypesCount} total)',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [5, 10, 15, 20].map((count) {
                            final isSel = _itemCount == count;
                            return ChoiceChip(
                              label: Text('$count'),
                              selected: isSel,
                              onSelected: _isGenerating
                                  ? null
                                  : (sel) async {
                                      setState(() => _itemCount = count);
                                      await _checkCachedContent();
                                    },
                            );
                          }).toList(),
                        ),
                      ],
                    ),

                    if (!widget.isFlashcardMode) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Question Types:',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: [
                          FilterChip(
                            label: const Text('Multiple Choice'),
                            selected: _includeMcq,
                            onSelected: _isGenerating
                                ? null
                                : (v) async {
                                    setState(() => _includeMcq = v);
                                    await _checkCachedContent();
                                  },
                          ),
                          FilterChip(
                            label: const Text('True / False'),
                            selected: _includeTrueFalse,
                            onSelected: _isGenerating
                                ? null
                                : (v) async {
                                    setState(() => _includeTrueFalse = v);
                                    await _checkCachedContent();
                                  },
                          ),
                          FilterChip(
                            label: const Text('Matching Type'),
                            selected: _includeMatching,
                            onSelected: _isGenerating
                                ? null
                                : (v) async {
                                    setState(() => _includeMatching = v);
                                    await _checkCachedContent();
                                  },
                          ),
                        ],
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          'Exam Total: ${[
                            if (_includeMcq) '$_itemCount MCQ',
                            if (_includeTrueFalse) '$_itemCount T/F',
                            if (_includeMatching) '$_itemCount Matching',
                          ].join(' + ')} = ${_itemCount * _selectedTypesCount} questions',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5)),
                        ),
                      ),
                    ],


                  ],
                ),
              ),
            ),

            // Footer / Actions
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: _isGenerating
                  ? Column(
                      children: [
                        const LinearProgressIndicator(),
                        const SizedBox(height: 12),
                        Text(
                          _statusMessage,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    )
                  : Wrap(
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        if (_hasCachedContent) ...[
                          OutlinedButton.icon(
                            onPressed: _pdfData == null ? null : () => _startAiGeneration(skipCache: true),
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Generate New Batch', style: TextStyle(fontSize: 12.5)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _pdfData == null ? null : () => _startAiGeneration(skipCache: false),
                            icon: const Icon(Icons.bolt, size: 17),
                            label: const Text(
                              'Load Cached (0 Tokens)',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ] else ...[
                          ElevatedButton.icon(
                            onPressed: _pdfData == null ? null : () => _startAiGeneration(skipCache: false),
                            icon: const Icon(Icons.auto_awesome, size: 17),
                            label: Text(
                              widget.isFlashcardMode ? 'Generate Flashcards' : 'Generate Exam Questions',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
