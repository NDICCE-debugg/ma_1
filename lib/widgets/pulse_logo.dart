import 'package:flutter/material.dart';

class PulseLogo extends StatelessWidget {
  final double size;
  final double borderRadius;

  const PulseLogo({
    super.key,
    this.size = 40,
    this.borderRadius = 10,
  });

  @override
  Widget build(BuildContext context) {
    final double iconSize = size * 0.56;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F766E), // teal-700
            Color(0xFF0D9488), // teal-600
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: const Color(0xFF14B8A6).withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF14B8A6).withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * 0.72,
            height: size * 0.72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
          Icon(
            Icons.monitor_heart_rounded,
            color: Colors.white,
            size: iconSize,
          ),
        ],
      ),
    );
  }
}

