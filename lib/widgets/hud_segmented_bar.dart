import 'package:flutter/material.dart';

class HudSegmentedBar extends StatelessWidget {
  final double percentage; // 0.0 to 1.0
  final Color color;
  final int segments;

  const HudSegmentedBar({
    super.key,
    required this.percentage,
    required this.color,
    this.segments = 20,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: percentage),
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        int filledSegments = (value * segments).round();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(segments, (index) {
            bool isFilled = index < filledSegments;
            return Container(
              margin: const EdgeInsets.only(right: 2),
              width: 8,
              height: 12,
              decoration: BoxDecoration(
                color: isFilled ? color : Colors.white10,
                boxShadow: isFilled ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 4)] : null,
              ),
            );
          }),
        );
      },
    );
  }
}