import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../controllers/auth_controller.dart';
import '../../components/common/custom_button.dart';

class UsernameSetupScreen extends ConsumerStatefulWidget {
  const UsernameSetupScreen({super.key});

  @override
  ConsumerState<UsernameSetupScreen> createState() => _UsernameSetupScreenState();
}

class _UsernameSetupScreenState extends ConsumerState<UsernameSetupScreen> {
  late final TextEditingController _usernameController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // Auto-generate a friendly username, e.g. "User123"
    final randomNum = Random().nextInt(900) + 100;
    _usernameController = TextEditingController(text: 'User$randomNum');
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  void _regenerateUsername() {
    final randomNum = Random().nextInt(900) + 100;
    setState(() {
      _usernameController.text = 'User$randomNum';
    });
  }

  Future<void> _handleContinue() async {
    final name = _usernameController.text.trim();
    if (name.isEmpty) return;

    await ref.read(authControllerProvider.notifier).setUsername(name);

    if (mounted) {
      try {
        context.go('/');
      } catch (_) {
        Navigator.of(context).maybePop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F17) : const Color(0xFFF8F8FC),
      body: SafeArea(
        child: ResponsiveContainer(
          child: Column(
            children: [
              // Top Bar with minimal brand mark
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.auto_stories, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Studay',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),

              // CENTER OF SCREEN: Username Input
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Greeting / Header
                            Text(
                              'What should we call you?',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF1E1E2A),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'You can keep this auto-generated name or change it.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13.5,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                            ),
                            const SizedBox(height: 28),

                            // Centered Username Input Field
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 400),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.08),
                                      blurRadius: 20,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: TextFormField(
                                  controller: _usernameController,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Display Name',
                                    floatingLabelAlignment: FloatingLabelAlignment.center,
                                    hintText: 'e.g. User123 or Maria',
                                    prefixIcon: const Padding(
                                      padding: EdgeInsets.only(left: 14, right: 6),
                                      child: Icon(Icons.person_outline, color: AppColors.secondary),
                                    ),
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.refresh, size: 20, color: AppColors.secondary),
                                      tooltip: 'Generate another name',
                                      onPressed: _regenerateUsername,
                                    ),
                                    filled: true,
                                    fillColor: isDark ? const Color(0xFF181824) : Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                        color: isDark ? const Color(0xFF2C2C3E) : const Color(0xFFE2E2EC),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                        color: isDark ? const Color(0xFF2C2C3E) : const Color(0xFFE2E2EC),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(
                                        color: AppColors.primary,
                                        width: 1.8,
                                      ),
                                    ),
                                  ),
                                  onFieldSubmitted: (_) => _handleContinue(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // BOTTOM OF SCREEN: Continue Button & Join by Code Bypass
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CustomButton(
                        text: 'Continue',
                        icon: Icons.arrow_forward,
                        variant: ButtonVariant.primaryGradient,
                        width: double.infinity,
                        height: 50,
                        onPressed: _handleContinue,
                      ),
                      const SizedBox(height: 14),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => context.push('/exam/join'),
                        icon: const Icon(Icons.pin, size: 16, color: AppColors.secondary),
                        label: const Text(
                          'Taking a quiz? Join by Code',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
