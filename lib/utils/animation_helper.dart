import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:ma_1/theme/app_theme.dart';
import 'dart:math' as math;

class HudBrackets extends StatelessWidget {
  final Widget child;
  const HudBrackets({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.hudDecoration,
          child: child,
        ),
        Positioned(top: 0, left: 0, child: _buildCorner(top: true, left: true)),
        Positioned(top: 0, right: 0, child: _buildCorner(top: true, left: false)),
        Positioned(bottom: 0, left: 0, child: _buildCorner(top: false, left: true)),
        Positioned(bottom: 0, right: 0, child: _buildCorner(top: false, left: false)),
      ],
    ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(1.05, 1.05), duration: 600.ms, curve: Curves.easeOut);
  }

  Widget _buildCorner({required bool top, required bool left}) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        border: Border(
          top: top ? const BorderSide(color: AppTheme.primary, width: 2) : BorderSide.none,
          bottom: !top ? const BorderSide(color: AppTheme.primary, width: 2) : BorderSide.none,
          left: left ? const BorderSide(color: AppTheme.primary, width: 2) : BorderSide.none,
          right: !left ? const BorderSide(color: AppTheme.primary, width: 2) : BorderSide.none,
        ),
      ),
    );
  }
}

class ScanlineWrapper extends StatefulWidget {
  final Widget child;
  const ScanlineWrapper({super.key, required this.child});

  @override
  State<ScanlineWrapper> createState() => _ScanlineWrapperState();
}

class _ScanlineWrapperState extends State<ScanlineWrapper> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, MediaQuery.of(context).size.height * _controller.value),
                child: Container(
                  height: 4,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.2), blurRadius: 10, spreadRadius: 2)],
                    gradient: LinearGradient(
                      colors: [Colors.transparent, AppTheme.primary.withOpacity(0.5), Colors.transparent],
                      stops: const [0.0, 0.5, 1.0],
                    )
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// NEW: Glitch Text Effect for Errors and Critical Alerts
class GlitchText extends StatelessWidget {
  final String text;
  final TextStyle style;
  const GlitchText(this.text, {super.key, required this.style});

  @override
  Widget build(BuildContext context) {
    return Text(text, style: style)
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .custom(
          duration: 100.ms,
          builder: (context, value, child) {
            final offset = (math.Random().nextDouble() - 0.5) * 4;
            return Transform.translate(
              offset: Offset(math.Random().nextBool() ? offset : 0, 0),
              child: child,
            );
          },
        );
  }
}

// NEW: Waveform Visualizer for Voice Input
class WaveformVisualizer extends StatelessWidget {
  final bool isListening;
  const WaveformVisualizer({super.key, required this.isListening});

  @override
  Widget build(BuildContext context) {
    if (!isListening) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Container(
          width: 4,
          height: 10 + (math.Random().nextDouble() * 20),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(2)),
        ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleY(
          begin: 0.5, end: 1.5, duration: Duration(milliseconds: 200 + (index * 50)),
        );
      }),
    );
  }
}