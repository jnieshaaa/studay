import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/question_model.dart';

class MatchingQuestionWidget extends StatefulWidget {
  final List<MatchingPair> pairs;
  final Map<String, String> userPairs; // leftText -> rightText
  final String? activeLeft;
  final Function(String leftText) onSelectLeft;
  final Function(String rightText) onConnectRight;
  final Function(String leftText) onRemovePair;
  final bool isRevealed;

  const MatchingQuestionWidget({
    super.key,
    required this.pairs,
    required this.userPairs,
    this.activeLeft,
    required this.onSelectLeft,
    required this.onConnectRight,
    required this.onRemovePair,
    this.isRevealed = false,
  });

  @override
  State<MatchingQuestionWidget> createState() => _MatchingQuestionWidgetState();
}

class _MatchingQuestionWidgetState extends State<MatchingQuestionWidget> {
  late List<String> _shuffledRight;
  String _lastPairsKey = '';

  // Palette colors for matched pairs (cycling cleanly up to 10 pairs)
  static const List<Color> _pairColors = [
    AppColors.secondary,
    AppColors.tertiary,
    AppColors.accent,
    AppColors.primary,
    Color(0xFFFFB300),
    Color(0xFFFF7043),
    Color(0xFFFFCA28),
    Color(0xFFE64A19),
    Color(0xFFFFA000),
    Color(0xFFD84315),
  ];

  @override
  void initState() {
    super.initState();
    _initShuffled();
  }

  @override
  void didUpdateWidget(covariant MatchingQuestionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final key = widget.pairs.map((p) => p.id).join(',');
    if (key != _lastPairsKey) {
      _initShuffled();
    }
  }

  void _initShuffled() {
    _lastPairsKey = widget.pairs.map((p) => p.id).join(',');
    final list = widget.pairs.map((p) => p.rightText).toList();
    // Shuffle right-side definitions so they don't align 1-to-1 with terms
    list.shuffle();
    if (list.length > 1 && widget.pairs.length > 1) {
      bool isIdentical = true;
      for (int i = 0; i < list.length; i++) {
        if (list[i] != widget.pairs[i].rightText) {
          isIdentical = false;
          break;
        }
      }
      if (isIdentical) {
        // Rotate so no item sits directly opposite its matching term
        final first = list.removeAt(0);
        list.add(first);
      }
    }
    _shuffledRight = list;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Get all left items
    final leftItems = widget.pairs.map((p) => p.leftText).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.secondary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.touch_app, size: 18, color: AppColors.secondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.activeLeft == null
                      ? 'Tap an item on the left, then tap its match on the right.'
                      : 'Now tap the matching definition on the right.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Two columns side-by-side with responsive flex distribution
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column (Terms) - flex 2
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: leftItems.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final left = entry.value;
                  final isSelected = widget.activeLeft == left;
                  final isPaired = widget.userPairs.containsKey(left);
                  final pairColor = _pairColors[idx % _pairColors.length];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: widget.isRevealed ? null : () => widget.onSelectLeft(left),
                      borderRadius: BorderRadius.circular(14),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? pairColor.withValues(alpha: 0.25)
                              : (isPaired
                                  ? pairColor.withValues(alpha: 0.12)
                                  : (isDark ? AppColors.darkCard : AppColors.lightCard)),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? pairColor
                                : (isPaired
                                    ? pairColor.withValues(alpha: 0.7)
                                    : (isDark ? AppColors.darkBorder : AppColors.lightBorder)),
                            width: isSelected ? 2 : (isPaired ? 1.5 : 1),
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: pairColor.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isPaired || isSelected
                                    ? pairColor
                                    : Colors.grey.withValues(alpha: 0.2),
                              ),
                              child: Text(
                                '${idx + 1}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: isPaired || isSelected
                                      ? Colors.white
                                      : (isDark ? Colors.white70 : Colors.black87),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                left,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSelected || isPaired ? FontWeight.w700 : FontWeight.w500,
                                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(width: 10),
            // Right Column (Definitions) - flex 3 for longer definition text
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _shuffledRight.map((right) {
                  // Check if any left is paired with this right
                  final pairedLeft = widget.userPairs.entries
                      .where((e) => e.value == right)
                      .map((e) => e.key)
                      .firstOrNull;
                  final leftIdx = pairedLeft != null ? leftItems.indexOf(pairedLeft) : -1;
                  final pairColor = leftIdx >= 0 ? _pairColors[leftIdx % _pairColors.length] : null;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: widget.isRevealed ? null : () => widget.onConnectRight(right),
                      borderRadius: BorderRadius.circular(14),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: pairColor != null
                              ? pairColor.withValues(alpha: 0.12)
                              : (isDark ? AppColors.darkCard : AppColors.lightCard),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: pairColor != null
                                ? pairColor.withValues(alpha: 0.7)
                                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                            width: pairColor != null ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            if (pairColor != null) ...[
                              Container(
                                width: 20,
                                height: 20,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: pairColor,
                                ),
                                child: Text(
                                  '${leftIdx + 1}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Text(
                                right,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: pairColor != null ? FontWeight.w600 : FontWeight.w400,
                                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),

        // Pairs Summary / Undo Chips
        if (widget.userPairs.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Connected Pairs (${widget.userPairs.length}/${widget.pairs.length}):',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.userPairs.entries.map((entry) {
              final leftIdx = leftItems.indexOf(entry.key);
              final pairColor = leftIdx >= 0 ? _pairColors[leftIdx % _pairColors.length] : AppColors.secondary;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: pairColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: pairColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${entry.key} ↔ ${entry.value.length > 20 ? '${entry.value.substring(0, 20)}...' : entry.value}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: pairColor,
                      ),
                    ),
                    if (!widget.isRevealed) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => widget.onRemovePair(entry.key),
                        child: Icon(Icons.close, size: 14, color: pairColor),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
