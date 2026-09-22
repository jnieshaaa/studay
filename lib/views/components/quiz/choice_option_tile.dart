import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class ChoiceOptionTile extends StatelessWidget {
  final String? label; // e.g. "A", "B", "True", "False", or null for sleek modern radio dot
  final String text;
  final bool isSelected;
  final bool isRevealed;
  final bool isCorrect;
  final VoidCallback? onTap;

  const ChoiceOptionTile({
    super.key,
    this.label,
    required this.text,
    required this.isSelected,
    this.isRevealed = false,
    this.isCorrect = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color borderColor;
    Color bgColor;
    Color labelBgColor;
    Color labelTextColor;

    if (isRevealed) {
      if (isCorrect) {
        borderColor = AppColors.success;
        bgColor = AppColors.success.withValues(alpha: isDark ? 0.2 : 0.12);
        labelBgColor = AppColors.success;
        labelTextColor = Colors.white;
      } else if (isSelected && !isCorrect) {
        borderColor = AppColors.error;
        bgColor = AppColors.error.withValues(alpha: isDark ? 0.2 : 0.12);
        labelBgColor = AppColors.error;
        labelTextColor = Colors.white;
      } else {
        borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
        bgColor = isDark ? AppColors.darkCard : AppColors.lightCard;
        labelBgColor = Colors.grey.withValues(alpha: 0.2);
        labelTextColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
      }
    } else {
      if (isSelected) {
        borderColor = AppColors.secondary;
        bgColor = AppColors.secondary.withValues(alpha: isDark ? 0.18 : 0.12);
        labelBgColor = AppColors.secondary;
        labelTextColor = Colors.white;
      } else {
        borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
        bgColor = isDark ? AppColors.darkCard : AppColors.lightCard;
        labelBgColor = isDark ? const Color(0xFF2B2B3D) : const Color(0xFFE5E5ED);
        labelTextColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: borderColor,
                width: isSelected || (isRevealed && isCorrect) ? 2 : 1.2,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.secondary.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                _buildIndicator(isDark, labelBgColor, labelTextColor),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                  ),
                ),
                if (isRevealed && isCorrect)
                  const Icon(Icons.check_circle, color: AppColors.success, size: 22)
                else if (isRevealed && isSelected && !isCorrect)
                  const Icon(Icons.cancel, color: AppColors.error, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIndicator(bool isDark, Color labelBgColor, Color labelTextColor) {
    if (label != null && label!.isNotEmpty) {
      return Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: labelBgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label!,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: labelTextColor,
          ),
        ),
      );
    }

    // Modern Radio Selector
    if (isRevealed) {
      if (isCorrect) {
        return Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.success,
          ),
          child: const Icon(Icons.check, size: 16, color: Colors.white),
        );
      } else if (isSelected && !isCorrect) {
        return Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.error,
          ),
          child: const Icon(Icons.close, size: 16, color: Colors.white),
        );
      }
    }

    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? AppColors.secondary : Colors.transparent,
        border: Border.all(
          color: isSelected
              ? AppColors.secondary
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: 2,
        ),
      ),
      child: isSelected
          ? const Icon(Icons.check, size: 16, color: Colors.white)
          : null,
    );
  }
}
