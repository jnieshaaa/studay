import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../controllers/providers.dart';
import '../../../controllers/exam_participant_controller.dart';
import '../../components/common/gradient_card.dart';
import '../../components/common/custom_button.dart';

class ExamJoinScreen extends ConsumerStatefulWidget {
  final String? initialCode;

  const ExamJoinScreen({super.key, this.initialCode});

  @override
  ConsumerState<ExamJoinScreen> createState() => _ExamJoinScreenState();
}

class _ExamJoinScreenState extends ConsumerState<ExamJoinScreen> {
  late final TextEditingController _codeController;
  final TextEditingController _nicknameController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.initialCode ?? '');
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _onJoin() async {
    final code = _codeController.text.trim().toUpperCase();
    final nickname = _nicknameController.text.trim();

    if (code.length != 6) {
      setState(() => _errorMessage = 'Please enter a valid 6-character exam code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final examService = ref.read(examServiceProvider);
      final exam = await examService.getOrFetchExamByCode(code);
      if (exam == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'No exam found with code "$code". Check with your exam maker.';
          });
        }
        return;
      }

      if (exam.isExpired) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'This exam has closed or expired.';
          });
        }
        return;
      }

      final participant = examService.joinExam(
        code: code,
        nickname: nickname.isEmpty ? 'Participant_${code.substring(0, 3)}' : nickname,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        context.pushReplacement(
          '/exam/play',
          extra: ExamParticipantParam(exam, participant),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Exam', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SingleChildScrollView(
        child: ResponsiveContainer(
          maxWidth: 550,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(Icons.vpn_key, color: Colors.white, size: 36),
              ),
            ),
            const SizedBox(height: 20),
            const Center(
              child: Text(
                'Enter 6-Character Join Code',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                'No account or password needed. Fast & anonymous guest access.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Form Fields Card
            GradientCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'EXAM CODE',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 6,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                      color: AppColors.secondary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. 4F9K2Q',
                      hintStyle: TextStyle(
                        letterSpacing: 2,
                        color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                      ),
                      prefixIcon: const Icon(Icons.tag, color: AppColors.secondary),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    'YOUR NICKNAME',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nicknameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: 'e.g. juanb, alex, or student_01',
                      prefixIcon: const Icon(Icons.person_outline, color: AppColors.tertiary),
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  CustomButton(
                    text: 'Join & Start Exam',
                    icon: Icons.play_arrow,
                    isLoading: _isLoading,
                    variant: ButtonVariant.primaryGradient,
                    width: double.infinity,
                    onPressed: _onJoin,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }
}
