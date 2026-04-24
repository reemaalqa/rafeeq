import 'package:flutter/material.dart';
import '../../../../core/config/theme_config.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/islamic_advice.dart';

class AdviceCard extends StatelessWidget {
  final IslamicAdvice advice;
  final VoidCallback onListen;

  const AdviceCard({super.key, required this.advice, required this.onListen});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.all(AppTheme.spaceLG),
      padding: const EdgeInsets.all(AppTheme.spaceXL),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.islamicColor, AppTheme.islamicLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: [BoxShadow(color: AppTheme.islamicColor.withOpacity(0.3), blurRadius: 15, spreadRadius: 2)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Category badge
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMD, vertical: AppTheme.spaceSM),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _categoryLabel(advice.category, l10n),
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spaceLG),

          // Arabic text
          Text(
            advice.arabicText,
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, height: 2.0),
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: AppTheme.spaceMD),

          // Transliteration
          Text(
            advice.transliteration,
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14, fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spaceMD),

          // Divider
          Divider(color: Colors.white.withOpacity(0.3), thickness: 1),
          const SizedBox(height: AppTheme.spaceMD),

          // English text
          Text(
            advice.englishText,
            style: const TextStyle(color: Colors.white, fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spaceSM),

          // Source
          Text(
            '— ${advice.source}',
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spaceLG),

          // Listen button
          OutlinedButton.icon(
            onPressed: onListen,
            icon: const Icon(Icons.volume_up, color: Colors.white),
            label: Text(l10n.listen, style: const TextStyle(color: Colors.white, fontSize: 18)),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white, width: 2),
              minimumSize: const Size(double.infinity, 52),
            ),
          ),
        ],
      ),
    );
  }

  String _categoryLabel(AdviceCategory cat, AppLocalizations l10n) {
    switch (cat) {
      case AdviceCategory.dhikr: return l10n.dhikr;
      case AdviceCategory.hadith: return l10n.hadith;
      case AdviceCategory.dua: return l10n.dua;
      case AdviceCategory.quranVerse: return l10n.quranVerse;
    }
  }
}
