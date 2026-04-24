import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import '../../../../core/config/theme_config.dart';
import '../../../../l10n/app_localizations.dart';
import '../cubit/conversation_cubit.dart';
import '../cubit/conversation_state.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../../../settings/presentation/cubit/settings_state.dart';
import '../widgets/emergency_banner.dart';
import '../widgets/message_bubble.dart';
import '../widgets/mic_button_widget.dart';
import '../widgets/voice_animation_widget.dart';

// ─── Page shell (provides the Cubit) ──────────────────────────────────────────

class ConversationPage extends StatelessWidget {
  const ConversationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => GetIt.instance<SettingsCubit>()..loadSettings(),
        ),
        BlocProvider(
          create: (_) => GetIt.instance<ConversationCubit>()..initialize(),
        ),
      ],
      child: const _ConversationView(),
    );
  }
}

// ─── Main stateful view ────────────────────────────────────────────────────────

class _ConversationView extends StatefulWidget {
  const _ConversationView();

  @override
  State<_ConversationView> createState() => _ConversationViewState();
}

class _ConversationViewState extends State<_ConversationView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Listening is auto-started from ConversationCubit.initialize() after the
    // speech engine and permissions are confirmed ready.
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Scroll to the latest message
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        // Apply voice gender whenever settings load or voice type changes
        BlocListener<SettingsCubit, SettingsState>(
          listenWhen: (prev, curr) =>
              curr.settings != null &&
              prev.settings?.voiceType != curr.settings?.voiceType,
          listener: (context, state) {
            context
                .read<ConversationCubit>()
                .applyVoiceType(state.settings!.voiceType);
          },
        ),
        // Emergency banner — only navigation that remains
        BlocListener<ConversationCubit, ConversationState>(
          listenWhen: (prev, curr) =>
              curr.detectedIntent?.isEmergency == true &&
              prev.detectedIntent?.isEmergency != true,
          listener: (context, state) {
            if (state.detectedIntent?.isEmergency == true) {
              HapticFeedback.heavyImpact();
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => Dialog(
                  backgroundColor: Colors.transparent,
                  child: EmergencyBanner(
                    onNavigate: () {
                      Navigator.of(context).pop();
                      context.read<ConversationCubit>().clearIntent();
                      Navigator.pushNamed(context, '/emergency-active');
                    },
                  ),
                ),
              );
            }
          },
        ),
        // Auto-scroll when messages update
        BlocListener<ConversationCubit, ConversationState>(
          listenWhen: (prev, curr) => curr.messages.length != prev.messages.length,
          listener: (_, __) => _scrollToBottom(),
        ),
      ],
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: SafeArea(
          child: Column(
          children: [
            _TopBar(),
            _StatusCard(),
            Expanded(child: _MessagesList(scrollController: _scrollController)),
            _BottomVoicePanel(),
          ],
        ),
        ),
      ),
    );
  }
}

// ─── Top Bar ──────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surfaceColor,
      padding: const EdgeInsets.only(top: 4, bottom: 8, left: 4, right: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
            onPressed: () => Navigator.pop(context),
            tooltip: 'رجوع',
          ),
          Expanded(
            child: BlocBuilder<ConversationCubit, ConversationState>(
              buildWhen: (p, c) => p.detectedDialect != c.detectedDialect,
              builder: (context, state) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'رفيق',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    switchInCurve: Curves.easeOutBack,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: animation,
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                    child: state.detectedDialect != null
                        ? _DialectBadge(
                            key: ValueKey(state.detectedDialect),
                            dialect: state.detectedDialect!,
                          )
                        : const SizedBox.shrink(key: ValueKey('empty')),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 28, color: AppTheme.errorColor),
            onPressed: () => _confirmResetChat(context),
            tooltip: 'محادثة جديدة',
          ),
        ],
      ),
    );
  }
}

// ─── Dialect badge ────────────────────────────────────────────────────────────

class _DialectBadge extends StatelessWidget {
  final String dialect;
  const _DialectBadge({super.key, required this.dialect});

  static const _labels = {
    'najdi':    'نجدي',
    'janoubi':  'جنوبي',
    'shamali':  'شمالي',
    'sharqawi': 'شرقاوي',
  };

  static const _colors = {
    'najdi':    Color(0xFF00897B), // teal  — central region
    'janoubi':  Color(0xFFE65100), // deep orange — southern region
    'shamali':  Color(0xFF6A1B9A), // purple — northern region
    'sharqawi': Color(0xFF1565C0), // blue   — eastern region
  };

  static const _icons = {
    'najdi':    Icons.location_city_rounded,
    'janoubi':  Icons.terrain_rounded,
    'shamali':  Icons.ac_unit_rounded,
    'sharqawi': Icons.water_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final label = _labels[dialect] ?? dialect;
    final color = _colors[dialect] ?? AppTheme.primaryColor;
    final icon  = _icons[dialect]  ?? Icons.record_voice_over_rounded;

    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.30), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Status Card ─────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConversationCubit, ConversationState>(
      buildWhen: (p, c) =>
          p.isListening != c.isListening ||
          p.isSpeaking != c.isSpeaking ||
          p.status != c.status ||
          p.partialText != c.partialText ||
          p.errorMessage != c.errorMessage,
      builder: (context, state) {
        final l10n = AppLocalizations.of(context)!;

        Color cardColor;
        Color textColor;
        IconData icon;
        String label;

        if (state.status == ConversationStatus.error) {
          cardColor = AppTheme.errorColor.withOpacity(0.09);
          textColor = AppTheme.errorColor;
          icon = Icons.mic_off_rounded;
          label = state.errorMessage ?? 'خطأ في الميكروفون';
        } else if (state.isListening) {
          cardColor = AppTheme.errorColor.withOpacity(0.09);
          textColor = AppTheme.errorColor;
          icon = Icons.mic_rounded;
          label = l10n.listening;
        } else if (state.isSpeaking) {
          cardColor = AppTheme.secondaryColor.withOpacity(0.09);
          textColor = AppTheme.secondaryColor;
          icon = Icons.volume_up_rounded;
          label = l10n.speaking;
        } else if (state.status == ConversationStatus.processing) {
          cardColor = AppTheme.warningColor.withOpacity(0.09);
          textColor = AppTheme.warningColor;
          icon = Icons.hourglass_top_rounded;
          label = l10n.processing;
        } else {
          cardColor = AppTheme.primaryColor.withOpacity(0.07);
          textColor = AppTheme.primaryColor;
          icon = Icons.mic_none_rounded;
          label = l10n.tapToSpeak;
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.fromLTRB(
            AppTheme.spaceMD,
            AppTheme.spaceMD,
            AppTheme.spaceMD,
            AppTheme.spaceSM,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceMD,
            vertical: AppTheme.spaceSM + 2,
          ),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: textColor),
                  const SizedBox(width: AppTheme.spaceXS),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              // Live transcription
              if (state.isListening && state.partialText.isNotEmpty) ...[
                const SizedBox(height: AppTheme.spaceXS),
                Text(
                  state.partialText,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                    height: 1.4,
                  ),
                ),
              ],
              // Voice bars while speaking
              if (state.isSpeaking) ...[
                const SizedBox(height: AppTheme.spaceXS),
                VoiceAnimationWidget(
                  isActive: true,
                  color: AppTheme.secondaryColor,
                  barCount: 9,
                  maxBarHeight: 28,
                  minBarHeight: 4,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ─── Messages list ────────────────────────────────────────────────────────────

class _MessagesList extends StatelessWidget {
  final ScrollController scrollController;
  const _MessagesList({required this.scrollController});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<ConversationCubit, ConversationState>(
      buildWhen: (p, c) => p.messages != c.messages,
      builder: (context, state) {
        if (state.messages.isEmpty) {
          return _EmptyState(l10n: l10n);
        }
        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceMD,
            vertical: AppTheme.spaceSM,
          ),
          itemCount: state.messages.length,
          itemBuilder: (context, i) =>
              MessageBubble(message: state.messages[i]),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final AppLocalizations l10n;
  const _EmptyState({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryColor.withOpacity(0.08),
            ),
            child: Icon(
              Icons.record_voice_over_rounded,
              size: 52,
              color: AppTheme.primaryColor.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: AppTheme.spaceMD),
          Text(
            l10n.startConversation,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: AppTheme.spaceSM),
          Text(
            'قل: "ذكرني" أو "صلاة" أو "أين مسجد"',
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

// ─── Bottom Voice Panel ───────────────────────────────────────────────────────

class _BottomVoicePanel extends StatelessWidget {
  // Quick-command shortcuts for discoverability
  static const _commands = [
    ('🕌', 'صلاة'),
    ('💊', 'دوائي'),
    ('📖', 'قرآن'),
    ('🍽️', 'أكل'),
    ('📍', 'أماكن'),
    ('⏰', 'ذكرني'),
    ('💡', 'نصيحة'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle indicator
          Container(
            margin: const EdgeInsets.only(top: 6, bottom: 4),
            width: 32,
            height: 3,
            decoration: BoxDecoration(
              color: AppTheme.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Quick command chips — اسألني is rendered as the first chip
          // (appears before صلاة in the RTL reading order).
          SizedBox(
            height: 46,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceSM),
              itemCount: _commands.length + 1,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: AppTheme.spaceXS),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return _ActionChip(
                    emoji: '💬',
                    label: 'اسألني',
                    color: const Color(0xFF1A73E8),
                    onTap: () {
                      final cubit = context.read<ConversationCubit>();
                      cubit.stopListening().then((_) {
                        Future.delayed(const Duration(milliseconds: 200), () {
                          cubit.activateGeminiVoice();
                        });
                      });
                    },
                  );
                }
                final (emoji, label) = _commands[i - 1];
                return _CommandChip(
                  emoji: emoji,
                  label: label,
                  onTap: () => _triggerCommand(context, label),
                );
              },
            ),
          ),

          const SizedBox(height: AppTheme.spaceXS),

          // Mic button
          BlocBuilder<ConversationCubit, ConversationState>(
            builder: (context, state) {
              final micState = state.isListening
                  ? MicState.listening
                  : state.isSpeaking
                      ? MicState.speaking
                      : state.status == ConversationStatus.processing
                          ? MicState.processing
                          : MicState.idle;

              return MicButtonWidget(
                state: micState,
                onTap: () {
                  final cubit = context.read<ConversationCubit>();
                  if (state.isListening) {
                    cubit.stopListening();
                  } else if (state.isSpeaking) {
                    cubit.stopSpeaking();
                  } else {
                    cubit.startListening();
                  }
                },
              );
            },
          ),

          // Hint text
          Padding(
            padding: const EdgeInsets.only(
              top: 2,
              bottom: AppTheme.spaceSM,
            ),
            child: BlocBuilder<ConversationCubit, ConversationState>(
              buildWhen: (p, c) =>
                  p.isListening != c.isListening || p.isSpeaking != c.isSpeaking,
              builder: (context, state) => Text(
                state.isListening
                    ? 'اضغط مرة أخرى للإيقاف'
                    : state.isSpeaking
                        ? 'اضغط لإيقاف الصوت'
                        : 'اضغط للتحدث بالعربية',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _triggerCommand(BuildContext context, String command) {
    final cubit = context.read<ConversationCubit>();
    cubit.stopListening().then((_) {
      Future.delayed(const Duration(milliseconds: 200), () {
        cubit.processTappedCommand(command);
      });
    });
  }

}

void _confirmResetChat(BuildContext context) {
  final cubit = context.read<ConversationCubit>();
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      title: const Text(
        'محادثة جديدة',
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: const Text(
        'سيتم حذف جميع الرسائل الحالية. هل أنت متأكد؟',
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء', style: TextStyle(fontSize: 16)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.errorColor,
          ),
          onPressed: () {
            Navigator.pop(context);
            cubit.resetChat();
          },
          child: const Text('تأكيد', style: TextStyle(fontSize: 16)),
        ),
      ],
    ),
  );
}

// ─── Action Chip (New chat / Ask-me) — same visual style as _CommandChip ────

class _ActionChip extends StatelessWidget {
  final String? emoji;
  final IconData? icon;
  final String? label;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({
    this.emoji,
    this.icon,
    this.label,
    required this.color,
    required this.onTap,
  }) : assert(emoji != null || icon != null);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceSM,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusCircular),
          border: Border.all(color: color.withOpacity(0.25), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null)
              Icon(icon, size: 18, color: color)
            else
              Text(emoji!, style: const TextStyle(fontSize: 16)),
            if (label != null && label!.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                label!,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


class _CommandChip extends StatelessWidget {
  final String emoji;
  final String label;
  final VoidCallback onTap;

  const _CommandChip({
    required this.emoji,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceSM,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusCircular),
          border: Border.all(
            color: AppTheme.primaryColor.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
