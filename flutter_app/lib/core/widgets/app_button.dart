import 'package:flutter/material.dart';
import '../config/theme_config.dart';

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final ButtonType type;
  final IconData? icon;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.type = ButtonType.primary,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (type == ButtonType.primary) {
      return ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : icon != null
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 24),
                      const SizedBox(width: AppTheme.spaceSM),
                      Text(text),
                    ],
                  )
                : Text(text),
      );
    } else if (type == ButtonType.outlined) {
      return OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        child: icon != null
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 24),
                  const SizedBox(width: AppTheme.spaceSM),
                  Text(text),
                ],
              )
            : Text(text),
      );
    } else {
      return TextButton(
        onPressed: isLoading ? null : onPressed,
        child: Text(text),
      );
    }
  }
}

enum ButtonType { primary, outlined, text }
