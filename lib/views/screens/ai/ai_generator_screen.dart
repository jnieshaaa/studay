import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/pdf_extractor.dart';
import '../../../core/utils/responsive.dart';
import '../../../models/question_model.dart';
import '../../../models/exam_model.dart';
import '../../../controllers/providers.dart';
import '../../../services/ai_generator_service.dart';
import '../study/create_flashcard_sheet.dart';

/// Navigation arguments for [AiGeneratorScreen].
class AiGeneratorArgs {
  final String? defaultSubject;
  final String initialMode; // 'exam' or 'flashcard'

  const AiGeneratorArgs({
    this.defaultSubject,
    this.initialMode = 'exam',
  });
}

/// Full screen interface for generating exam questions or flashcard study decks
/// from lecture notes, slides, or PDF documents using Gemini AI.
class AiGeneratorScreen extends ConsumerStatefulWidget {
  final String? defaultSubject;
  final String initialMode;

  const AiGeneratorScreen({
    super.key,
    this.defaultSubject,
    this.initialMode = 'exam',
  });

  @override
  ConsumerState<AiGeneratorScreen> createState() => _AiGeneratorScreenState();
}

class _AiGeneratorScreenState extends ConsumerState<AiGeneratorScreen> {
  late String _mode; // 'exam' or 'flashcard'
  late final TextEditingController _subjectController;

  ExtractedPdfData? _pdfData;
  bool _isExtractingPdf = false;
  bool _isGenerating = false;
  String _statusMessage = '';
  String? _errorMessage;

  // Preferences
  int _itemCount = 10;
  bool _includeMcq = true;
  bool _includeTrueFalse = true;
  bool _includeMatching = true;

  // Token-saver Cache State
  bool _hasCachedContent = false;

  int get _selectedTypesCount {
    int count = 0;
    if (_includeMcq) count++;
    if (_includeTrueFalse) count++;
    if (_includeMatching) count++;
    return count > 0 ? count : 1;
  }

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _subjectController = TextEditingController(text: widget.defaultSubject ?? '');
    if (_mode == 'flashcard') {
      _itemCount = 15;
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    super.dispose();
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

    if (_mode == 'flashcard') {
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
              'No readable text could be extracted from "${data.fileName}". Make sure it is not an image-only scanned PDF.';
        });
        return;
      }

      setState(() {
        _pdfData = data;
        _isExtractingPdf = false;
        if (_subjectController.text.trim().isEmpty) {
          final cleanTitle = data.fileName
              .replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '')
              .replaceAll(RegExp(r'[_-]'), ' ')
              .trim();
          if (cleanTitle.isNotEmpty) {
            _subjectController.text = cleanTitle;
          }
        }
      });

      await _checkCachedContent();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isExtractingPdf = false;
        _errorMessage = 'Failed to extract text from document: $e';
      });
    }
  }

  Future<void> _generate() async {
    if (_pdfData == null || _pdfData!.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please select a PDF document first.');
      return;
    }

    if (_mode == 'exam' && !_includeMcq && !_includeTrueFalse && !_includeMatching) {
      setState(() => _errorMessage = 'Please select at least one question type.');
      return;
    }

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
      _statusMessage = _hasCachedContent
          ? 'Loading saved questions from local cache...'
          : 'Analyzing document and generating with AI...';
    });

    final aiService = ref.read(aiGeneratorServiceProvider);
    final subject = _subjectController.text.trim().isNotEmpty
        ? _subjectController.text.trim()
        : 'General Study';

    try {
      if (_mode == 'flashcard') {
        final flashcards = await aiService.generateFlashcardsFromText(
          _pdfData!.text,
          count: _itemCount,
          subject: subject,
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _hasCachedContent
                  ? 'Loaded ${flashcards.length} flashcards from instant cache!'
                  : 'Generated ${flashcards.length} flashcards from document!',
            ),
            backgroundColor: AppColors.success,
          ),
        );

        // Navigate to full-screen flashcard editor
        context.pushReplacement(
          '/study/create-flashcard',
          extra: CreateFlashcardArgs(
            initialFlashcards: flashcards,
            initialSubject: subject,
          ),
        );
      } else {
        final types = <QuestionType>[];
        if (_includeMcq) types.add(QuestionType.multipleChoice);
        if (_includeTrueFalse) types.add(QuestionType.trueFalse);
        if (_includeMatching) types.add(QuestionType.matching);

        final questions = await aiService.generateQuestionsFromText(
          _pdfData!.text,
          count: _itemCount,
          subject: subject,
          types: types,
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _hasCachedContent
                  ? 'Loaded ${questions.length} questions from instant cache!'
                  : 'Generated ${questions.length} questions from document!',
            ),
            backgroundColor: AppColors.success,
          ),
        );

        // Navigate to full-screen exam builder
        context.pushReplacement(
          '/exam/maker',
          extra: ExamMakerArgs(
            initialQuestions: questions,
            initialSubject: subject,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (e is AiApiKeyMissingException) {
        debugPrint('[AiGeneratorScreen] No API key configured. Running Smart On-Device Extractor directly...');
        if (_mode == 'flashcard') {
          final localCards = aiService.generateFlashcardsLocally(
            _pdfData!.text,
            count: _itemCount,
            subject: subject,
          );
          if (localCards.isNotEmpty) {
            final key = aiService.computeCacheKey(_pdfData!.text, mode: 'flashcard', count: _itemCount);
            await ref.read(localStorageServiceProvider).saveCachedAiResult(key, jsonEncode(localCards));
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Extracted ${localCards.length} flashcards on-device (Offline / Fallback)!'),
                backgroundColor: AppColors.success,
              ),
            );
            context.pushReplacement(
              '/study/create-flashcard',
              extra: CreateFlashcardArgs(
                initialFlashcards: localCards,
                initialSubject: subject,
              ),
            );
            return;
          }
        } else {
          final types = <QuestionType>[];
          if (_includeMcq) types.add(QuestionType.multipleChoice);
          if (_includeTrueFalse) types.add(QuestionType.trueFalse);
          if (_includeMatching) types.add(QuestionType.matching);
          if (types.isEmpty) types.add(QuestionType.multipleChoice);

          final localQs = aiService.generateQuestionsLocally(
            _pdfData!.text,
            count: _itemCount,
            subject: subject,
            types: types,
          );
          if (localQs.isNotEmpty) {
            final key = aiService.computeCacheKey(_pdfData!.text, mode: 'exam', count: _itemCount, types: types);
            await ref.read(localStorageServiceProvider).saveCachedAiResult(
              key,
              jsonEncode(localQs.map((q) => q.toJson()).toList()),
            );
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Extracted ${localQs.length} questions on-device (Offline / Fallback)!'),
                backgroundColor: AppColors.success,
              ),
            );
            context.pushReplacement(
              '/exam/maker',
              extra: ExamMakerArgs(
                initialQuestions: localQs,
                initialSubject: subject,
              ),
            );
            return;
          }
        }
      }

      setState(() {
        _isGenerating = false;
        _errorMessage =
            'AI document processing is temporarily unavailable. Please verify your connection or try again shortly.';
      });
      debugPrint('[AiGeneratorScreen] Generation failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF161622) : Colors.white;
    final borderColor = isDark ? const Color(0xFF28283C) : const Color(0xFFE2E2EC);
    final textPrimary = isDark ? const Color(0xFFF3F3F7) : const Color(0xFF1B1B24);
    final textSecondary = isDark ? const Color(0xFF8E8EA2) : const Color(0xFF707084);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'AI Document Generator',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SingleChildScrollView(
        child: ResponsiveContainer(
          maxWidth: 780,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Mode Selector (Exam Questions vs Flashcards)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1B1B27) : const Color(0xFFEFEFF6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildModeTab(
                        label: 'Exam Questions',
                        icon: Icons.quiz_outlined,
                        isSelected: _mode == 'exam',
                        isDark: isDark,
                        onTap: () {
                          if (_mode != 'exam') {
                            setState(() {
                              _mode = 'exam';
                              _itemCount = 10;
                            });
                            _checkCachedContent();
                          }
                        },
                      ),
                    ),
                    Expanded(
                      child: _buildModeTab(
                        label: 'Flashcard Deck',
                        icon: Icons.style_outlined,
                        isSelected: _mode == 'flashcard',
                        isDark: isDark,
                        onTap: () {
                          if (_mode != 'flashcard') {
                            setState(() {
                              _mode = 'flashcard';
                              _itemCount = 15;
                            });
                            _checkCachedContent();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Upload Document Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.picture_as_pdf, color: Color(0xFF6366F1), size: 20),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Upload Lecture Notes or PDF',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    if (_pdfData == null) ...[
                      InkWell(
                        onTap: _isExtractingPdf ? null : _pickPdf,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1B1B26) : const Color(0xFFF9F9FC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                              style: BorderStyle.solid,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              _isExtractingPdf
                                  ? const SizedBox(
                                      width: 36,
                                      height: 36,
                                      child: CircularProgressIndicator(strokeWidth: 3),
                                    )
                                  : Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.cloud_upload_rounded,
                                        size: 32,
                                        color: Color(0xFF6366F1),
                                      ),
                                    ),
                              const SizedBox(height: 12),
                              Text(
                                _isExtractingPdf ? 'Extracting text from PDF...' : 'Tap to Choose PDF Document',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Supports syllabus, slides, textbook chapters, and review notes (.pdf)',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      // File Attached Container
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _pdfData!.fileName,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_pdfData!.pageCount} pages • ${_pdfData!.text.length} characters',
                                    style: TextStyle(fontSize: 12, color: textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _pickPdf,
                              icon: const Icon(Icons.change_circle_outlined, size: 16),
                              label: const Text('Change'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Generation Preferences Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.tune, color: AppColors.secondary, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Generation Preferences',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Subject Name Field
                    Text(
                      'Subject / Topic Name',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _subjectController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Science, Biology, Philippine History',
                        hintStyle: TextStyle(color: textSecondary, fontSize: 13.5),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1B1B26) : const Color(0xFFF9F9FC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Number of Items Selector
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _mode == 'exam' ? 'Questions per Question Type' : 'Number of Flashcards',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _mode == 'exam'
                                ? '$_itemCount per type (${_itemCount * _selectedTypesCount} total)'
                                : '$_itemCount items',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _itemCount.toDouble(),
                      min: 5,
                      max: 30,
                      divisions: 5,
                      activeColor: const Color(0xFF6366F1),
                      onChanged: (val) {
                        setState(() => _itemCount = val.toInt());
                        _checkCachedContent();
                      },
                    ),

                    if (_mode == 'exam') ...[
                      const SizedBox(height: 12),
                      Text(
                        'Include Question Types',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilterChip(
                            label: const Text('Multiple Choice'),
                            selected: _includeMcq,
                            onSelected: (val) {
                              setState(() => _includeMcq = val);
                              _checkCachedContent();
                            },
                          ),
                          FilterChip(
                            label: const Text('True / False'),
                            selected: _includeTrueFalse,
                            onSelected: (val) {
                              setState(() => _includeTrueFalse = val);
                              _checkCachedContent();
                            },
                          ),
                          FilterChip(
                            label: const Text('Matching Type'),
                            selected: _includeMatching,
                            onSelected: (val) {
                              setState(() => _includeMatching = val);
                              _checkCachedContent();
                            },
                          ),
                        ],
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.playlist_add_check_rounded, size: 20, color: Color(0xFF6366F1)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Exam Composition: ${_itemCount * _selectedTypesCount} Total Questions',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF4F46E5),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    [
                                      if (_includeMcq) '$_itemCount Multiple Choice',
                                      if (_includeTrueFalse) '$_itemCount True/False',
                                      if (_includeMatching) '$_itemCount Matching Type',
                                    ].join(' • '),
                                    style: TextStyle(
                                      fontSize: 11.5,
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
                    ],

                    if (_hasCachedContent) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.bolt, color: AppColors.success, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Document already analyzed! Ready to load with zero delay.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.success,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Error Banner
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Primary Action Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                onPressed: (_isGenerating || _isExtractingPdf) ? null : _generate,
                icon: _isGenerating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : Icon(_mode == 'exam' ? Icons.auto_awesome : Icons.style_rounded, size: 18),
                label: Text(
                  _isGenerating
                      ? _statusMessage
                      : (_mode == 'exam' ? 'Generate Exam Questions' : 'Generate Flashcard Deck'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeTab({
    required String label,
    required IconData icon,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? (isDark ? const Color(0xFF28283C) : Colors.white) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? const Color(0xFF6366F1) : (isDark ? Colors.white60 : Colors.black45),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? (isDark ? Colors.white : Colors.black87)
                    : (isDark ? Colors.white60 : Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
