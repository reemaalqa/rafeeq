import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/config/theme_config.dart';

enum MicState { idle, listening, speaking, processing }

/// Premium animated mic button.
///
/// The button itself NEVER moves or resizes — it sits in a fixed-size Stack.
/// Ripple rings are drawn with CustomPaint (paint-only, no layout effect).
/// Color transitions use AnimatedContainer for smooth crossfade.
class MicButtonWidget extends StatefulWidget {
  final MicState state;
  final VoidCallback onTap;

  const MicButtonWidget({
    super.key,
    required this.state,
    required this.onTap,
  });

  @override
  State<MicButtonWidget> createState() => _MicButtonWidgetState();
}

class _MicButtonWidgetState extends State<MicButtonWidget>
    with TickerProviderStateMixin {
  late AnimationController _rippleCtrl;
  late AnimationController _pressCtrl;
  late Animation<double> _pressAnim;

  @override
  void initState() {
    super.initState();

    _rippleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _pressAnim = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeInOut),
    );

    _syncAnimations();
  }

  @override
  void didUpdateWidget(MicButtonWidget old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) _syncAnimations();
  }

  void _syncAnimations() {
    if (widget.state == MicState.listening) {
      if (!_rippleCtrl.isAnimating) _rippleCtrl.repeat();
    } else {
      _rippleCtrl.stop();
      _rippleCtrl.reset();
    }
  }

  @override
  void dispose() {
    _rippleCtrl.dispose();
    _pressCtrl.dispose();
    super.dispose();
  }

  Color get _color {
    switch (widget.state) {
      case MicState.listening:
        return AppTheme.errorColor;
      case MicState.speaking:
        return AppTheme.secondaryColor;
      case MicState.processing:
        return AppTheme.warningColor;
      case MicState.idle:
        return AppTheme.primaryColor;
    }
  }

  IconData get _icon {
    switch (widget.state) {
      case MicState.listening:
        return Icons.stop_rounded;
      case MicState.speaking:
        return Icons.volume_up_rounded;
      case MicState.processing:
        return Icons.hourglass_top_rounded;
      case MicState.idle:
        return Icons.mic_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Fixed outer size — ripple rings paint inside this, never push layout.
    // Kept tight so the mic doesn't leave big whitespace above/below in the
    // bottom voice panel. Ripple max expansion is clamped below.
    const double canvasSize = 140;
    const double buttonSize = 80;

    return GestureDetector(
      onTapDown: (_) => _pressCtrl.forward(),
      onTapUp: (_) {
        _pressCtrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _pressCtrl.reverse(),
      child: SizedBox(
        width: canvasSize,
        height: canvasSize,
        child: AnimatedBuilder(
          animation: Listenable.merge([_rippleCtrl, _pressAnim]),
          builder: (context, _) {
            return Stack(
              alignment: Alignment.center,
              children: [
                // ── Ripple rings painted behind the button ──────────────────
                if (widget.state == MicState.listening)
                  CustomPaint(
                    size: const Size(canvasSize, canvasSize),
                    painter: _RipplePainter(
                      progress: _rippleCtrl.value,
                      color: _color,
                      buttonRadius: buttonSize / 2,
                    ),
                  ),

                // ── The button — fixed size, no movement ────────────────────
                Transform.scale(
                  scale: _pressAnim.value,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    width: buttonSize,
                    height: buttonSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _color,
                      boxShadow: [
                        BoxShadow(
                          color: _color.withValues(alpha: 0.38),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: widget.state == MicState.processing
                        ? const Padding(
                            padding: EdgeInsets.all(22),
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              _icon,
                              key: ValueKey(_icon),
                              size: 36,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── CustomPainter — draws ripple rings purely on canvas, no layout effect ────

class _RipplePainter extends CustomPainter {
  final double progress;
  final Color color;
  final double buttonRadius;

  // Maximum extra radius the rings can reach beyond the button edge.
  // Must stay below (canvasSize/2 - buttonSize/2) so rings don't clip:
  // (140/2 - 80/2) = 30. Using 28 for a 2px safety margin.
  static const double _maxExpansion = 28.0;
  // Number of rings, each offset in phase
  static const int _ringCount = 3;

  _RipplePainter({
    required this.progress,
    required this.color,
    required this.buttonRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.stroke;

    for (int i = 0; i < _ringCount; i++) {
      final phase = i / _ringCount;
      final value = ((progress + phase) % 1.0);

      // Ease-out so rings decelerate as they expand
      final eased = math.pow(value, 0.6).toDouble();

      final radius = buttonRadius + eased * _maxExpansion;
      final opacity = (1.0 - value).clamp(0.0, 1.0) * 0.45;
      final strokeWidth = (1.0 - value) * 2.5 + 0.5;

      paint
        ..color = color.withValues(alpha: opacity)
        ..strokeWidth = strokeWidth;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) =>
      old.progress != progress || old.color != color;
}
