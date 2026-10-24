import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/question_model.dart';

class MatchingQuestionWidget extends StatefulWidget {
  final List<MatchingPair> pairs;
  final Map<String, String> userPairs; // leftText -> rightText
  final String? activeLeft;
  final Function(String leftText)? onSelectLeft;
  final Function(String rightText)? onConnectRight;
  final Function(String leftText)? onRemovePair;
  final Function(String leftText, String? rightText)? onPairChanged;
  final bool isRevealed;

  const MatchingQuestionWidget({
    super.key,
    required this.pairs,
    required this.userPairs,
    this.activeLeft,
    this.onSelectLeft,
    this.onConnectRight,
    this.onRemovePair,
    this.onPairChanged,
    this.isRevealed = false,
  });

  @override
  State<MatchingQuestionWidget> createState() => _MatchingQuestionWidgetState();
}

class _MatchingQuestionWidgetState extends State<MatchingQuestionWidget> {
  late List<String> _shuffledRight;
  final Map<String, String> _lettersMap = {}; // rightText -> 'A', 'B', ...
  String _lastPairsKey = '';

  @override
  void initState() {
    super.initState();
    _initShuffled();
  }

  @override
  void didUpdateWidget(covariant MatchingQuestionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final key = widget.pairs.map((p) => '${p.id}:${p.leftText}:${p.rightText}').join(',');
    if (key != _lastPairsKey) {
      _initShuffled();
    }
  }

  void _initShuffled() {
    _lastPairsKey = widget.pairs.map((p) => '${p.id}:${p.leftText}:${p.rightText}').join(',');
    final uniqueRights = widget.pairs.map((p) => p.rightText).toSet().toList();
    // Shuffle right-side definitions so they don't align 1-to-1 with terms
    uniqueRights.shuffle();
    if (uniqueRights.length > 1 && widget.pairs.length > 1) {
      bool isIdentical = true;
      for (int i = 0; i < uniqueRights.length && i < widget.pairs.length; i++) {
        if (uniqueRights[i] != widget.pairs[i].rightText) {
          isIdentical = false;
          break;
        }
      }
      if (isIdentical) {
        final first = uniqueRights.removeAt(0);
        uniqueRights.add(first);
      }
    }
    _shuffledRight = uniqueRights;

    _lettersMap.clear();
    for (int i = 0; i < _shuffledRight.length; i++) {
      _lettersMap[_shuffledRight[i]] = _letterForIndex(i);
    }
  }

  String _letterForIndex(int idx) {
    if (idx < 26) {
      return String.fromCharCode(65 + idx);
    }
    return '${idx + 1}';
  }

  void _handlePairChange(String leftText, String? rightText) {
    if (widget.isRevealed) return;
    if (widget.onPairChanged != null) {
      widget.onPairChanged!(leftText, rightText);
      return;
    }
    if (rightText == null || rightText.isEmpty) {
      widget.onRemovePair?.call(leftText);
    } else {
      widget.onSelectLeft?.call(leftText);
      widget.onConnectRight?.call(rightText);
    }
  }

  void _clearAllPairs() {
    if (widget.isRevealed) return;
    for (final pair in widget.pairs) {
      if (widget.userPairs.containsKey(pair.leftText)) {
        _handlePairChange(pair.leftText, null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final matchedCount = widget.userPairs.length;
    final totalCount = widget.pairs.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Instructions & Progress
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.secondary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.secondary.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              const Icon(Icons.rule, size: 20, color: AppColors.secondary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Select the matching answer for each question from the dropdown.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: matchedCount == totalCount && totalCount > 0
                      ? AppColors.success.withValues(alpha: 0.15)
                      : AppColors.secondary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: matchedCount == totalCount && totalCount > 0
                        ? AppColors.success.withValues(alpha: 0.4)
                        : AppColors.secondary.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  '$matchedCount / $totalCount matched',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: matchedCount == totalCount && totalCount > 0
                        ? AppColors.success
                        : AppColors.secondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Available Choices Pool
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.list_alt,
                    size: 16,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'CHOICES POOL',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _shuffledRight.map((choice) {
                  final letter = _lettersMap[choice] ?? '';
                  final isUsed = widget.userPairs.values.contains(choice);

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isUsed
                          ? (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05))
                          : AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isUsed
                            ? (isDark ? Colors.white24 : Colors.black12)
                            : AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isUsed
                                ? (isDark ? Colors.white24 : Colors.black26)
                                : AppColors.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            letter,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          choice,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isUsed ? FontWeight.w400 : FontWeight.w600,
                            color: isUsed
                                ? (isDark ? Colors.white38 : Colors.black38)
                                : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                            decoration: isUsed ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Questions List: 1. Question -> Dropdown
        ...widget.pairs.asMap().entries.map((entry) {
          final idx = entry.key;
          final pair = entry.value;
          final selectedRight = widget.userPairs[pair.leftText];
          final hasAnswer = selectedRight != null && selectedRight.isNotEmpty;
          final isCorrect = selectedRight == pair.rightText;

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: widget.isRevealed
                    ? (isCorrect
                        ? AppColors.success.withValues(alpha: 0.6)
                        : AppColors.error.withValues(alpha: 0.6))
                    : (hasAnswer
                        ? AppColors.primary.withValues(alpha: 0.4)
                        : (isDark ? AppColors.darkBorder : AppColors.lightBorder)),
                width: widget.isRevealed || hasAnswer ? 1.5 : 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Text question (Premise)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: hasAnswer
                            ? AppColors.primary
                            : (isDark ? Colors.white12 : Colors.black12),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${idx + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: hasAnswer
                              ? Colors.white
                              : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        pair.leftText,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Dropdown Options
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: hasAnswer
                          ? AppColors.primary.withValues(alpha: 0.5)
                          : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: selectedRight,
                            hint: Row(
                              children: [
                                Icon(
                                  Icons.unfold_more,
                                  size: 18,
                                  color: isDark ? Colors.white38 : Colors.black38,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Select matching answer...',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: isDark ? Colors.white38 : Colors.black38,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                            dropdownColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                            borderRadius: BorderRadius.circular(14),
                            icon: const SizedBox.shrink(),
                            items: [
                              if (hasAnswer && !widget.isRevealed)
                                DropdownMenuItem<String>(
                                  value: '__CLEAR__',
                                  child: Row(
                                    children: const [
                                      Icon(Icons.close, size: 18, color: AppColors.error),
                                      SizedBox(width: 8),
                                      Text(
                                        '-- Clear / Remove Answer --',
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          color: AppColors.error,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ..._shuffledRight.map((choice) {
                                final letter = _lettersMap[choice] ?? '';
                                final isSelectedForThis = selectedRight == choice;
                                final usedInOtherIdx = widget.userPairs.entries
                                    .where((e) => e.value == choice && e.key != pair.leftText)
                                    .map((e) => widget.pairs.indexWhere((p) => p.leftText == e.key) + 1)
                                    .firstOrNull;

                                return DropdownMenuItem<String>(
                                  value: choice,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 24,
                                        height: 24,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: isSelectedForThis
                                              ? AppColors.primary
                                              : (isDark ? Colors.white10 : Colors.black12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          letter,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: isSelectedForThis
                                                ? Colors.white
                                                : (isDark ? Colors.white70 : Colors.black87),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          choice,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: isSelectedForThis ? FontWeight.w700 : FontWeight.w400,
                                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 2,
                                        ),
                                      ),
                                      if (usedInOtherIdx != null && usedInOtherIdx > 0)
                                        Container(
                                          margin: const EdgeInsets.only(left: 6),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'Used in #$usedInOtherIdx',
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.amber,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                            onChanged: widget.isRevealed
                                ? null
                                : (val) {
                                    if (val == null || val == '__CLEAR__') {
                                      _handlePairChange(pair.leftText, null);
                                    } else {
                                      _handlePairChange(pair.leftText, val);
                                    }
                                  },
                          ),
                        ),
                      ),
                      if (hasAnswer && !widget.isRevealed)
                        IconButton(
                          icon: const Icon(Icons.cancel, size: 20, color: AppColors.textSecondaryDark),
                          tooltip: 'Remove answer',
                          splashRadius: 18,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          onPressed: () => _handlePairChange(pair.leftText, null),
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.arrow_drop_down, color: AppColors.primary),
                        ),
                    ],
                  ),
                ),

                // Revealed feedback (Practice mode / Review)
                if (widget.isRevealed) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isCorrect
                          ? AppColors.success.withValues(alpha: 0.1)
                          : AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isCorrect
                            ? AppColors.success.withValues(alpha: 0.4)
                            : AppColors.error.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isCorrect ? Icons.check_circle : Icons.cancel,
                          size: 16,
                          color: isCorrect ? AppColors.success : AppColors.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isCorrect
                                ? 'Correct Match!'
                                : 'Correct Answer: [${_lettersMap[pair.rightText] ?? ''}] ${pair.rightText}',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: isCorrect ? AppColors.success : AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        }),

        // Clear All Button
        if (matchedCount > 0 && !widget.isRevealed) ...[
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _clearAllPairs,
              icon: const Icon(Icons.restart_alt, size: 16, color: AppColors.error),
              label: const Text(
                'Clear All Answers',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
