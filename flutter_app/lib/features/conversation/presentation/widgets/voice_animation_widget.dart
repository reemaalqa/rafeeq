import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Animated equalizer bars shown while the assistant is speaking.
/// Each bar has a unique phase offset giving a natural wave appearance.
class VoiceAnimationWidget extends StatefulWidget {
  final bool isActive;
  final Color color;
  final int barCount;
  final double barWidth;
  final double maxBarHeight;
  final double minBarHeight;

  const VoiceAnimationWidget({
    super.key,
    required this.isActive,
    required this.color,
    this.barCount = 9,
    this.barWidth = 5,
    this.maxBarHeight = 44,
    this.minBarHeight = 6,
  });

  @override
  State<VoiceAnimationWidget> createState() => _VoiceAnimationWidgetState();
}

class _VoiceAnimationWidgetState extends State<VoiceAnimationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.isActive) _controller.repeat();
  }

  @override
  void didUpdateWidget(VoiceAnimationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isActive && _controller.isAnimating) {
      _controller.animateTo(0, duration: const Duration(milliseconds: 300));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(widget.barCount, (i) {
            // Unique sine phase per bar — center bar peaks highest
            final phase = (i / widget.barCount) * 2 * math.pi;
            final amplitude = i == widget.barCount ~/ 2
                ? 1.0
                : 1.0 - ((i - widget.barCount / 2).abs() / (widget.barCount / 2)) * 0.4;

            final sineValue = widget.isActive
                ? (math.sin(_controller.value * 2 * math.pi + phase) + 1) / 2
                : 0.0;
            final height = widget.minBarHeight +
                sineValue * (widget.maxBarHeight - widget.minBarHeight) * amplitude;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              width: widget.barWidth,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(widget.barWidth / 2),
              ),
            );
          }),
        );
      },
    );
  }
}
