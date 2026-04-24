import 'package:flutter/material.dart';
import '../../../../core/config/theme_config.dart';
import '../../domain/entities/conversation_message.dart';

class MessageBubble extends StatelessWidget {
  final ConversationMessage message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spaceSM),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!message.isUser) ...[
            _Avatar(),
            const SizedBox(width: AppTheme.spaceXS),
          ],
          Flexible(child: _Bubble(message: message)),
          if (message.isUser) ...[
            const SizedBox(width: AppTheme.spaceXS),
            _UserAvatar(),
          ],
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(Icons.smart_toy_rounded, size: 18, color: Colors.white),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.primaryColor.withOpacity(0.15),
      ),
      child: const Icon(Icons.person_rounded, size: 18, color: AppTheme.primaryColor),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ConversationMessage message;
  const _Bubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final time = _formatTime(message.timestamp);

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.72,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMD,
        vertical: AppTheme.spaceSM + 2,
      ),
      decoration: BoxDecoration(
        gradient: isUser
            ? const LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isUser ? null : AppTheme.surfaceColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(AppTheme.radiusLarge),
          topRight: const Radius.circular(AppTheme.radiusLarge),
          bottomLeft: isUser
              ? const Radius.circular(AppTheme.radiusLarge)
              : const Radius.circular(4),
          bottomRight: isUser
              ? const Radius.circular(4)
              : const Radius.circular(AppTheme.radiusLarge),
        ),
        border: isUser
            ? null
            : Border.all(color: AppTheme.dividerColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message.text,
            textDirection: TextDirection.rtl,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: isUser ? Colors.white : AppTheme.textPrimary,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            time,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: isUser
                      ? Colors.white.withOpacity(0.65)
                      : AppTheme.textSecondary,
                ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
