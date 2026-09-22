import 'package:flutter/material.dart';

/// Semantic colors based on user's exact warm fire palette:
/// - #ff0000 -> Primary
/// - #ff5a00 -> Secondary
/// - #ff9a00 -> Tertiary
/// - #ffce00 -> Accent
/// - #ffe808 -> Highlight
class AppColors {
  // --- The 5 Core Brand Colors ---
  static const Color primary = Color(0xFFFF0000);
  static const Color secondary = Color(0xFFFF5A00);
  static const Color tertiary = Color(0xFFFF9A00);
  static const Color accent = Color(0xFFFFCE00);
  static const Color highlight = Color(0xFFFFE808);

  // --- Supporting Neutrals & Surfaces (Dark Theme Default) ---
  static const Color darkBg = Color(0xFF0D0D12);
  static const Color darkSurface = Color(0xFF16161F);
  static const Color darkCard = Color(0xFF1F1F2C);
  static const Color darkBorder = Color(0xFF2C2C3E);

  // --- Supporting Neutrals & Surfaces (Light Theme) ---
  static const Color lightBg = Color(0xFFF9F9FC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFF1F1F6);
  static const Color lightBorder = Color(0xFFE2E2EA);

  // --- Feedback & Status Colors ---
  static const Color success = Color(0xFF00C853);
  static const Color warning = Color(0xFFFF9A00);
  static const Color error = Color(0xFFFF0000);
  static const Color info = Color(0xFF2979FF);

  // --- Text Colors ---
  static const Color textPrimaryDark = Color(0xFFF5F5FA);
  static const Color textSecondaryDark = Color(0xFFA0A0B2);
  static const Color textTertiaryDark = Color(0xFF6E6E82);

  static const Color textPrimaryLight = Color(0xFF1A1A24);
  static const Color textSecondaryLight = Color(0xFF6B6B7F);
  static const Color textTertiaryLight = Color(0xFF9E9EB0);

  // --- Gradients ---
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient flameGradient = LinearGradient(
    colors: [secondary, tertiary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [accent, highlight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient fullSpectrumGradient = LinearGradient(
    colors: [primary, secondary, tertiary, accent, highlight],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient cardGlowGradient = LinearGradient(
    colors: [
      Color(0x33FF0000),
      Color(0x22FF5A00),
      Colors.transparent,
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
