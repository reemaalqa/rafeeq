import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import '../../../../core/config/theme_config.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/prayer_times.dart';
import '../cubit/islamic_cubit.dart';
import '../cubit/islamic_state.dart';

class PrayerTimesPage extends StatelessWidget {
  const PrayerTimesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = GetIt.instance<IslamicCubit>();
        _loadPrayerTimes(cubit);
        return cubit;
      },
      child: const _PrayerTimesView(),
    );
  }

  static Future<void> _loadPrayerTimes(IslamicCubit cubit) async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition();
      cubit.loadPrayerTimes(lat: pos.latitude, lng: pos.longitude);
    } catch (_) {
      // Default to Riyadh if location unavailable
      cubit.loadPrayerTimes(lat: 24.7136, lng: 46.6753);
    }
  }
}

class _PrayerTimesView extends StatelessWidget {
  const _PrayerTimesView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back, size: 32), onPressed: () => Navigator.pop(context)),
        title: Text(l10n.prayerTimes),
      ),
      body: SafeArea(top: false, child: BlocBuilder<IslamicCubit, IslamicState>(
        builder: (context, state) {
          final times = state.prayerTimes;

          return ListView(
            padding: const EdgeInsets.all(AppTheme.spaceLG),
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(AppTheme.spaceLG),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppTheme.islamicColor, AppTheme.islamicLight], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.mosque, size: 64, color: Colors.white),
                    const SizedBox(height: AppTheme.spaceMD),
                    Text(
                      times?.location ?? l10n.locatingYou,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _formatDate(context, DateTime.now()),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withOpacity(0.9)),
                    ),
                    if (times != null) ...[
                      const SizedBox(height: AppTheme.spaceSM),
                      Text(
                        l10n.nextPrayerLabel(times.nextPrayerName),
                        style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spaceLG),

              if (times == null)
                const Center(child: CircularProgressIndicator())
              else ...[
                _PrayerCard(name: l10n.fajr,    time: times.fajr,    icon: Icons.wb_twilight,      isNextPrayer: times.nextPrayerKey == 'fajr'),
                _PrayerCard(name: l10n.dhuhr,   time: times.dhuhr,   icon: Icons.wb_sunny,         isNextPrayer: times.nextPrayerKey == 'dhuhr'),
                _PrayerCard(name: l10n.asr,     time: times.asr,     icon: Icons.wb_sunny_outlined, isNextPrayer: times.nextPrayerKey == 'asr'),
                _PrayerCard(name: l10n.maghrib, time: times.maghrib, icon: Icons.wb_twilight,      isNextPrayer: times.nextPrayerKey == 'maghrib'),
                _PrayerCard(name: l10n.isha,    time: times.isha,    icon: Icons.nightlight,       isNextPrayer: times.nextPrayerKey == 'isha'),
              ],

              const SizedBox(height: AppTheme.spaceLG),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/quran'),
                      icon: const Icon(Icons.book),
                      label: Text(l10n.quran),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.islamicColor, minimumSize: const Size(0, 56)),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceMD),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/islamic-advice'),
                      icon: const Icon(Icons.lightbulb_outline),
                      label: Text(l10n.islamicAdvice),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.islamicColor, minimumSize: const Size(0, 56)),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      )), // SafeArea + BlocBuilder
    );
  }

  String _formatDate(BuildContext context, DateTime date) {
    final locale = Localizations.localeOf(context).toString();
    final isArabic = locale.startsWith('ar');
    final pattern = isArabic ? 'EEEE، d MMMM y' : 'EEEE, d MMMM y';
    return DateFormat(pattern, locale).format(date);
  }
}

class _PrayerCard extends StatefulWidget {
  final String name;
  final DateTime time;
  final IconData icon;
  final bool isNextPrayer;

  const _PrayerCard({
    required this.name,
    required this.time,
    required this.icon,
    this.isNextPrayer = false,
  });

  @override
  State<_PrayerCard> createState() => _PrayerCardState();
}

class _PrayerCardState extends State<_PrayerCard> {
  bool _isCompleted = false;

  bool get _isNext => widget.isNextPrayer;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceMD),
      padding: const EdgeInsets.all(AppTheme.spaceLG),
      decoration: BoxDecoration(
        color: _isNext && !_isCompleted ? AppTheme.islamicColor.withOpacity(0.08) : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: _isNext && !_isCompleted ? AppTheme.islamicColor : _isCompleted ? AppTheme.successColor : AppTheme.dividerColor,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(widget.icon, color: AppTheme.islamicColor, size: 40),
          const SizedBox(width: AppTheme.spaceMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.name, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                Text(
                  _formatTime(widget.time),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(color: AppTheme.islamicColor),
                ),
              ],
            ),
          ),
          if (_isCompleted)
            const Icon(Icons.check_circle, color: AppTheme.successColor, size: 32)
          else
            IconButton(
              icon: const Icon(Icons.check_circle_outline, size: 32),
              onPressed: () => setState(() => _isCompleted = true),
              color: AppTheme.textSecondary,
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final locale = Localizations.localeOf(context).toString();
    return DateFormat('h:mm a', locale).format(time);
  }
}
