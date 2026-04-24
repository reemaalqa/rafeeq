import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/config/theme_config.dart';
import '../cubit/islamic_cubit.dart';
import '../cubit/islamic_state.dart';

/// Bottom-anchored Quran player with reciter label, progress scrubbing,
/// ayah counter, repeat-mode toggle, and speed control. Designed to match
/// the feel of dedicated Quran apps rather than a generic TTS control.
class TtsControlBar extends StatelessWidget {
  const TtsControlBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<IslamicCubit, IslamicState>(
      buildWhen: (a, b) =>
          a.isTtsPlaying != b.isTtsPlaying ||
          a.isBuffering != b.isBuffering ||
          a.audioPosition != b.audioPosition ||
          a.audioDuration != b.audioDuration ||
          a.currentAyahIndex != b.currentAyahIndex ||
          a.repeatMode != b.repeatMode ||
          a.selectedSurah != b.selectedSurah,
      builder: (context, state) {
        final cubit = context.read<IslamicCubit>();
        final surah = state.selectedSurah;
        final totalAyahs = surah?.ayahs.length ?? 0;
        final currentAyah = totalAyahs == 0
            ? 0
            : (state.currentAyahIndex + 1).clamp(1, totalAyahs);

        return Material(
          elevation: 16,
          color: Colors.transparent,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0F3D1E),
                  AppTheme.islamicColor,
                ],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MetaRow(
                      reciter: IslamicCubit.reciterName,
                      currentAyah: currentAyah,
                      totalAyahs: totalAyahs,
                    ),
                    const SizedBox(height: 6),
                    _ProgressBar(
                      position: state.audioPosition,
                      duration: state.audioDuration,
                      onSeek: cubit.seekTo,
                    ),
                    const SizedBox(height: 4),
                    _ControlsRow(
                      state: state,
                      cubit: cubit,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Top meta row: reciter + ayah counter ────────────────────────────────────

class _MetaRow extends StatelessWidget {
  final String reciter;
  final int currentAyah;
  final int totalAyahs;

  const _MetaRow({
    required this.reciter,
    required this.currentAyah,
    required this.totalAyahs,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.mic_none, color: Colors.white70, size: 16),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            reciter,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (totalAyahs > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.25)),
            ),
            child: Text(
              'الآية $currentAyah من $totalAyahs',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Scrubbable progress bar ────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;

  const _ProgressBar({
    required this.position,
    required this.duration,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    final total = duration.inMilliseconds;
    final pos = position.inMilliseconds.clamp(0, total == 0 ? 1 : total);
    final value = total == 0 ? 0.0 : pos / total;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white.withOpacity(0.25),
            thumbColor: Colors.white,
            overlayColor: Colors.white.withOpacity(0.18),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: value.clamp(0.0, 1.0),
            onChanged: total == 0
                ? null
                : (v) => onSeek(Duration(milliseconds: (v * total).round())),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Text(_fmt(position),
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
              const Spacer(),
              Text(_fmt(duration),
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ─── Main transport controls ─────────────────────────────────────────────────

class _ControlsRow extends StatelessWidget {
  final IslamicState state;
  final IslamicCubit cubit;

  const _ControlsRow({required this.state, required this.cubit});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _RepeatButton(
          mode: state.repeatMode,
          onTap: cubit.cycleRepeatMode,
        ),
        _IconControl(
          icon: Icons.skip_previous_rounded,
          size: 34,
          onTap: cubit.prevAyah,
        ),
        _PlayPauseButton(
          isPlaying: state.isTtsPlaying,
          isBuffering: state.isBuffering,
          onTap: () {
            if (state.isTtsPlaying) {
              cubit.pauseTts();
            } else {
              cubit.playCurrentAyah();
            }
          },
        ),
        _IconControl(
          icon: Icons.skip_next_rounded,
          size: 34,
          onTap: cubit.nextAyah,
        ),
        _IconControl(
          icon: Icons.stop_rounded,
          size: 28,
          onTap: cubit.pauseTts,
        ),
      ],
    );
  }
}

class _IconControl extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;

  const _IconControl({
    required this.icon,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      splashRadius: 24,
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white, size: size),
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  final bool isPlaying;
  final bool isBuffering;
  final VoidCallback onTap;

  const _PlayPauseButton({
    required this.isPlaying,
    required this.isBuffering,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: isBuffering
            ? const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.islamicColor),
                ),
              )
            : Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: AppTheme.islamicColor,
                size: 38,
              ),
      ),
    );
  }
}

class _RepeatButton extends StatelessWidget {
  final RepeatMode mode;
  final VoidCallback onTap;

  const _RepeatButton({required this.mode, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (icon, active) = switch (mode) {
      RepeatMode.none => (Icons.repeat_rounded, false),
      RepeatMode.singleAyah => (Icons.repeat_one_rounded, true),
      RepeatMode.surah => (Icons.repeat_rounded, true),
    };
    return IconButton(
      onPressed: onTap,
      splashRadius: 24,
      icon: Icon(
        icon,
        color: active ? const Color(0xFFFFD54F) : Colors.white70,
        size: 26,
      ),
      tooltip: switch (mode) {
        RepeatMode.none => 'تشغيل عادي',
        RepeatMode.singleAyah => 'تكرار الآية',
        RepeatMode.surah => 'تكرار السورة',
      },
    );
  }
}

