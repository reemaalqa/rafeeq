import 'package:flutter/material.dart';
import '../config/theme_config.dart';

/// Scrolling marquee text for labels that overflow their container.
class _MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;

  const _MarqueeText({required this.text, this.style});

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText>
    with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;
  double? _lastWidth;
  double _extraWidth = 0;

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  void _setup(double availWidth) {
    if (_lastWidth == availWidth) return;
    _lastWidth = availWidth;

    final tp = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: double.infinity);

    _ctrl?.dispose();
    _ctrl = null;

    if (tp.width > availWidth) {
      _extraWidth = tp.width - availWidth + 8;
      _ctrl = AnimationController(
        vsync: this,
        duration: Duration(
          milliseconds: (_extraWidth / 40 * 1000).round().clamp(1000, 4000),
        ),
      )..addStatusListener((s) {
          if (!mounted) return;
          if (s == AnimationStatus.completed) {
            Future.delayed(const Duration(milliseconds: 700),
                () { if (mounted) _ctrl?.reverse(); });
          } else if (s == AnimationStatus.dismissed) {
            Future.delayed(const Duration(milliseconds: 700),
                () { if (mounted) _ctrl?.forward(); });
          }
        });
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {});
          _ctrl?.forward();
        }
      });
    } else {
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return LayoutBuilder(
      builder: (context, constraints) {
        final availWidth = constraints.maxWidth;
        if (_lastWidth != availWidth) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _setup(availWidth));
        }

        if (_ctrl == null) {
          return Text(
            widget.text,
            style: widget.style,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }

        return ClipRect(
          child: AnimatedBuilder(
            animation: _ctrl!,
            builder: (_, child) {
              final dx = isRtl
                  ? _ctrl!.value * _extraWidth
                  : -_ctrl!.value * _extraWidth;
              return Transform.translate(
                offset: Offset(dx, 0),
                child: child,
              );
            },
            child: Text(
              widget.text,
              style: widget.style,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
            ),
          ),
        );
      },
    );
  }
}

class QuickActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const QuickActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  State<QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<QuickActionButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final buttonColor = widget.color ?? Theme.of(context).colorScheme.primary;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: InkWell(
        onTap: () {
          _controller.forward().then((_) => _controller.reverse());
          widget.onTap();
        },
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spaceMD),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                buttonColor.withOpacity(0.1),
                buttonColor.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(
              color: buttonColor.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: buttonColor.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.icon,
                  size: 56,
                  color: buttonColor,
                ),
                const SizedBox(height: AppTheme.spaceSM),
                _MarqueeText(
                  text: widget.label,
                  style: const TextStyle(
                    fontSize: AppTheme.fontQuickAction,
                    fontWeight: FontWeight.w600,
                  ).copyWith(color: buttonColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
