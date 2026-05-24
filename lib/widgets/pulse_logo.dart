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
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.08),
      decoration: BoxDecoration(
        color: const Color(0xFF071B3A),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: const Color(0xFF123A66)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius * 0.72),
        child: Image.asset(
          'assets/icon.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: const Color(0xFF071B3A),
              alignment: Alignment.center,
              child: Icon(
                Icons.graphic_eq_rounded,
                color: Colors.white,
                size: size * 0.52,
              ),
            );
          },
        ),
      ),
    );
  }
}
