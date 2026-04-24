import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import '../../../../core/config/theme_config.dart';
import '../../domain/entities/surah.dart';
import '../cubit/islamic_cubit.dart';
import '../cubit/islamic_state.dart';
import '../widgets/ayah_card.dart';
import '../widgets/tts_control_bar.dart';

/// At-Tawbah is the only surah that doesn't start with Bismillah.
const int _surahAtTawbah = 9;

class SurahDetailPage extends StatelessWidget {
  final String surahId;
  final bool autoplay;

  const SurahDetailPage({
    super.key,
    required this.surahId,
    this.autoplay = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = GetIt.instance<IslamicCubit>();
        cubit.loadSurahs().then((_) {
          final surah = cubit.state.surahs.firstWhere(
            (s) => s.id == surahId,
            orElse: () => cubit.state.surahs.first,
          );
          cubit.selectSurah(surah);
          if (autoplay) {
            // Small delay gives the route transition time to settle so the
            // buffering indicator renders on the already-visible page.
            Future.delayed(const Duration(milliseconds: 350), () {
              cubit.playCurrentAyah();
            });
          }
        });
        return cubit;
      },
      child: const _SurahDetailView(),
    );
  }
}

class _SurahDetailView extends StatefulWidget {
  const _SurahDetailView();

  @override
  State<_SurahDetailView> createState() => _SurahDetailViewState();
}

class _SurahDetailViewState extends State<_SurahDetailView> {
  final ScrollController _scroll = ScrollController();
  final Map<int, GlobalKey> _ayahKeys = {};
  int _lastScrolledIndex = -1;

  GlobalKey _keyFor(int index) =>
      _ayahKeys.putIfAbsent(index, () => GlobalKey());

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Auto-scrolls the list so the currently-recited ayah stays visible.
  void _scrollToAyah(int index) {
    if (index == _lastScrolledIndex) return;
    _lastScrolledIndex = index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _ayahKeys[index];
      final ctx = key?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 400),
          alignment: 0.1,
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<IslamicCubit, IslamicState>(
      listenWhen: (a, b) => a.currentAyahIndex != b.currentAyahIndex,
      listener: (_, state) {
        if (state.isTtsPlaying) _scrollToAyah(state.currentAyahIndex);
      },
      builder: (context, state) {
        final surah = state.selectedSurah;
        // Force RTL for the whole reader regardless of inherited locale —
        // list scroll direction, app-bar leading/actions, and all Row
        // children flip correctly under this wrapper.
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            extendBody: true,
            backgroundColor: const Color(0xFFF9F6F0),
            appBar: AppBar(
              title: Text(surah?.arabicName ?? '...'),
              backgroundColor: AppTheme.islamicColor,
              foregroundColor: Colors.white,
              elevation: 0,
              actions: [
                if (surah != null)
                  IconButton(
                    tooltip: 'من البداية',
                    icon: const Icon(Icons.first_page_rounded),
                    onPressed: () => context.read<IslamicCubit>().playAyahAt(0),
                  ),
              ],
            ),
            body: surah == null
                ? const Center(child: CircularProgressIndicator())
                : _buildBody(context, surah, state),
            bottomNavigationBar: const TtsControlBar(),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, Surah surah, IslamicState state) {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 220),
      // 2 fixed items at the top (header + bismillah), then one per ayah.
      itemCount: surah.ayahs.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) return _SurahHeader(surah: surah);
        if (index == 1) return _BismillahBanner(surahNumber: surah.number);
        final ayahIndex = index - 2;
        final ayah = surah.ayahs[ayahIndex];
        return KeyedSubtree(
          key: _keyFor(ayahIndex),
          child: AyahCard(
            ayah: ayah,
            isCurrentlyPlaying:
                state.currentAyahIndex == ayahIndex && state.isTtsPlaying,
            onTap: () => context.read<IslamicCubit>().playAyahAt(ayahIndex),
          ),
        );
      },
    );
  }
}

// ─── Surah header card ───────────────────────────────────────────────────────

class _SurahHeader extends StatelessWidget {
  final Surah surah;
  const _SurahHeader({required this.surah});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.islamicColor,
            Color(0xFF0F3D1E),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.islamicColor.withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _SurahNumberCircle(number: surah.number),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      surah.arabicName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      surah.transliteration,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: Colors.white.withOpacity(0.25)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _HeaderChip(
                icon: Icons.menu_book_rounded,
                label: '${surah.verseCount} آية',
              ),
              _HeaderChip(
                icon: Icons.tag_rounded,
                label: 'سورة رقم ${surah.number}',
              ),
              _HeaderChip(
                icon: Icons.headphones_rounded,
                label: 'العفاسي',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SurahNumberCircle extends StatelessWidget {
  final int number;
  const _SurahNumberCircle({required this.number});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.12),
        border: Border.all(color: Colors.white.withOpacity(0.45), width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        '$number',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _HeaderChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.85), size: 16),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─── Bismillah banner ────────────────────────────────────────────────────────

class _BismillahBanner extends StatelessWidget {
  final int surahNumber;
  const _BismillahBanner({required this.surahNumber});

  @override
  Widget build(BuildContext context) {
    // At-Tawbah (9) is the only surah without Bismillah.
    if (surahNumber == _surahAtTawbah) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF2),
        border: Border.all(color: const Color(0xFFBFA254).withOpacity(0.45), width: 1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            Text(
              'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
              style: AppTheme.quranText(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0D3F12),
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
