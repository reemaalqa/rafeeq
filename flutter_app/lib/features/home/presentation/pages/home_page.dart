import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../../../../core/config/theme_config.dart';
import '../../../../core/widgets/quick_action_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../islamic/presentation/cubit/islamic_cubit.dart';
import '../../../islamic/presentation/cubit/islamic_state.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  AnimationController? _pulseController;
  AnimationController? _scaleController;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _loadPrayerTimes();
  }

  Future<void> _loadPrayerTimes() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition();
      if (mounted) {
        context.read<IslamicCubit>().loadPrayerTimes(lat: pos.latitude, lng: pos.longitude);
      }
    } catch (_) {
      // Default to Riyadh
      if (mounted) {
        context.read<IslamicCubit>().loadPrayerTimes(lat: 24.7136, lng: 46.6753);
      }
    }
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    _scaleController?.dispose();
    super.dispose();
  }

  void _toggleVoiceAssistant() {
    _scaleController?.forward().then((_) => _scaleController?.reverse());
    setState(() => _isListening = !_isListening);
    if (_isListening) {
      Navigator.pushNamed(context, '/conversation');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    AppTheme.darkBackground,
                    AppTheme.darkSurface,
                  ]
                : [
                    AppTheme.primaryColor.withOpacity(0.03),
                    Colors.white,
                  ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppTheme.spaceMD),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurface : Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.person, size: 28),
                        onPressed: () => Navigator.pushNamed(context, '/profile-setup'),
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    Text(
                      l10n.appName,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurface : Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.settings, size: 28),
                        onPressed: () => Navigator.pushNamed(context, '/settings'),
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                flex: 2,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _pulseController ?? AnimationController(vsync: this, duration: Duration.zero),
                        builder: (context, child) {
                          final value = _pulseController?.value ?? 0.0;
                          return Container(
                            width: 120 + (value * 16),
                            height: 120 + (value * 16),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  AppTheme.primaryColor.withOpacity(0.2),
                                  AppTheme.primaryColor.withOpacity(0.0),
                                ],
                              ),
                            ),
                            child: child,
                          );
                        },
                        child: _scaleController == null ? const SizedBox.shrink() : ScaleTransition(
                          scale: Tween<double>(begin: 1.0, end: 0.95).animate(_scaleController!),
                          child: GestureDetector(
                            onTap: _toggleVoiceAssistant,
                            child: Container(
                              width: 104,
                              height: 104,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.primaryColor,
                                    AppTheme.primaryLight,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryColor.withOpacity(0.4),
                                    blurRadius: 14,
                                    spreadRadius: 2,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.mic,
                                size: 52,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spaceMD),
                      Text(
                        l10n.tapToSpeak,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

              Expanded(
                flex: 5,
                child: Container(
                  padding: const EdgeInsets.all(AppTheme.spaceLG),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppTheme.radiusLarge * 2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.quickActions,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: AppTheme.spaceMD),
                      GridView.count(
                          crossAxisCount: 3,
                          mainAxisSpacing: AppTheme.spaceMD,
                          crossAxisSpacing: AppTheme.spaceMD,
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          children: [
                            QuickActionButton(
                              icon: Icons.medication,
                              label: l10n.medication,
                              onTap: () => Navigator.pushNamed(context, '/reminders'),
                            ),
                            QuickActionButton(
                              icon: Icons.mosque,
                              label: l10n.prayer,
                              onTap: () => Navigator.pushNamed(context, '/prayer-times'),
                              color: AppTheme.islamicColor,
                            ),
                            QuickActionButton(
                              icon: Icons.location_on,
                              label: l10n.locations,
                              onTap: () => Navigator.pushNamed(context, '/locations'),
                            ),
                            QuickActionButton(
                              icon: Icons.restaurant,
                              label: l10n.diet,
                              onTap: () => Navigator.pushNamed(context, '/diet'),
                            ),
                            QuickActionButton(
                              icon: Icons.alarm,
                              label: l10n.reminders,
                              onTap: () => Navigator.pushNamed(context, '/reminders'),
                            ),
                            QuickActionButton(
                              icon: Icons.emergency,
                              label: l10n.emergency,
                              onTap: () => Navigator.pushNamed(context, '/emergency'),
                              color: AppTheme.errorColor,
                            ),
                          ],
                        ),
                      const SizedBox(height: AppTheme.spaceMD),
                      BlocBuilder<IslamicCubit, IslamicState>(
                        builder: (context, islamicState) {
                          final times = islamicState.prayerTimes;
                          final nextName = times?.nextPrayerName ?? l10n.prayer;
                          final nextTime = times?.nextPrayerTime;
                          final timeStr = nextTime != null
                              ? DateFormat('h:mm a', 'ar').format(nextTime)
                              : '...';
                          return Container(
                            padding: const EdgeInsets.all(AppTheme.spaceMD),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.islamicColor.withOpacity(0.1),
                                  AppTheme.islamicLight.withOpacity(0.1),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                              border: Border.all(
                                color: AppTheme.islamicColor.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(AppTheme.spaceSM),
                                  decoration: BoxDecoration(
                                    color: AppTheme.islamicColor.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                  ),
                                  child: const Icon(Icons.mosque, color: AppTheme.islamicColor, size: 28),
                                ),
                                const SizedBox(width: AppTheme.spaceMD),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${l10n.nextPrayer}: $nextName',
                                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      Text(
                                        '${l10n.at} $timeStr',
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              color: AppTheme.textSecondary,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
