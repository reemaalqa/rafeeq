import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';
import 'core/config/theme_config.dart';
import 'core/utils/navigation_service.dart';
import 'features/auth/presentation/cubit/auth_cubit.dart';
import 'features/settings/presentation/cubit/settings_cubit.dart';
import 'features/islamic/presentation/cubit/islamic_cubit.dart';
import 'core/utils/app_state.dart';
import 'l10n/app_localizations.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/verification_page.dart';
import 'features/profile/presentation/pages/profile_setup_page.dart';
import 'features/home/presentation/pages/home_page.dart';
import 'features/conversation/presentation/pages/conversation_page.dart';
import 'features/reminders/presentation/pages/reminders_page.dart';
import 'features/diet/presentation/pages/diet_page.dart';
import 'features/islamic/presentation/pages/prayer_times_page.dart';
import 'features/islamic/presentation/pages/quran_page.dart';
import 'features/islamic/presentation/pages/surah_detail_page.dart';
import 'features/islamic/presentation/pages/islamic_advice_page.dart';
import 'features/locations/domain/entities/place.dart';
import 'features/locations/presentation/pages/locations_page.dart';
import 'features/emergency/presentation/cubit/emergency_cubit.dart';
import 'features/emergency/presentation/pages/emergency_page.dart';
import 'features/emergency/presentation/pages/emergency_active_page.dart';
import 'features/settings/presentation/pages/settings_page.dart';
import 'features/onboarding/presentation/pages/onboarding_page.dart';
import 'features/onboarding/presentation/pages/preferences_onboarding_page.dart';

class RafeeqApp extends StatelessWidget {
  const RafeeqApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: Consumer<AppState>(
        builder: (context, appState, _) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            title: 'Rafeeq',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme(),
            darkTheme: AppTheme.darkTheme(),
            themeMode: appState.themeMode,
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(appState.textScaleFactor),
                ),
                child: child!,
              );
            },
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('ar', ''),
            ],
            locale: const Locale('ar', ''),
            initialRoute: '/',
            onGenerateRoute: (settings) {
              switch (settings.name) {
                case '/':
                  return MaterialPageRoute(builder: (_) => const SplashScreen());
                case '/onboarding':
                  return MaterialPageRoute(builder: (_) => const OnboardingPage());
                case '/preferences-onboarding':
                  return MaterialPageRoute(
                      builder: (_) => const PreferencesOnboardingPage());
                case '/login':
                  return MaterialPageRoute(
                    builder: (_) => BlocProvider(
                      create: (_) => GetIt.instance<AuthCubit>(),
                      child: const LoginPage(),
                    ),
                  );
                case '/verification':
                  final email = settings.arguments as String? ?? '';
                  return MaterialPageRoute(
                    builder: (_) => BlocProvider(
                      create: (_) => GetIt.instance<AuthCubit>(),
                      child: VerificationPage(email: email),
                    ),
                  );
                case '/profile-setup':
                  final step = settings.arguments as int? ?? 0;
                  return MaterialPageRoute(
                      builder: (_) => ProfileSetupPage(initialStep: step));
                case '/home':
                  return MaterialPageRoute(
                    builder: (_) => BlocProvider(
                      create: (_) => GetIt.instance<IslamicCubit>(),
                      child: const HomePage(),
                    ),
                  );
                case '/conversation':
                  return MaterialPageRoute(
                      builder: (_) => const ConversationPage());
                case '/reminders':
                  return MaterialPageRoute(
                      builder: (_) => const RemindersPage());
                case '/diet':
                  return MaterialPageRoute(builder: (_) => const DietPage());
                case '/prayer-times':
                  return MaterialPageRoute(
                      builder: (_) => const PrayerTimesPage());
                case '/quran':
                  return MaterialPageRoute(builder: (_) => const QuranPage());
                case '/surah-detail':
                  // Accept two arg shapes:
                  //   - plain String surahId (manual navigation from the list)
                  //   - Map {'surahId': ..., 'autoplay': bool} (voice flow)
                  final args = settings.arguments;
                  String surahId = '';
                  bool autoplay = false;
                  if (args is String) {
                    surahId = args;
                  } else if (args is Map) {
                    surahId = (args['surahId'] as String?) ?? '';
                    autoplay = (args['autoplay'] as bool?) ?? false;
                  }
                  return MaterialPageRoute(
                      builder: (_) => SurahDetailPage(
                            surahId: surahId,
                            autoplay: autoplay,
                          ));
                case '/islamic-advice':
                  return MaterialPageRoute(
                      builder: (_) => const IslamicAdvicePage());
                case '/locations':
                  final category = settings.arguments as PlaceCategory?;
                  return MaterialPageRoute(
                      builder: (_) => LocationsPage(initialCategory: category));
                case '/emergency':
                  return MaterialPageRoute(
                      builder: (_) => const EmergencyPage());
                case '/emergency-active':
                  return MaterialPageRoute(
                    builder: (_) => BlocProvider(
                      create: (_) => GetIt.instance<EmergencyCubit>(),
                      child: const EmergencyActivePage(),
                    ),
                  );
                case '/settings':
                  return MaterialPageRoute(
                    builder: (_) => BlocProvider(
                      create: (_) => GetIt.instance<SettingsCubit>()..loadSettings(),
                      child: const SettingsPage(),
                    ),
                  );
                default:
                  return MaterialPageRoute(builder: (_) => const HomePage());
              }
            },
          );
        },
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _controller.forward();
    _navigateNext();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _navigateNext() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    final appState = Provider.of<AppState>(context, listen: false);
    if (!appState.hasSeenOnboarding) {
      Navigator.pushReplacementNamed(context, '/onboarding');
    } else if (appState.isLoggedIn) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryColor,
              AppTheme.primaryLight,
            ],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spaceXL),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.elderly,
                      size: 100,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceXL),
                  Text(
                    AppLocalizations.of(context)?.appName ?? 'Rafeeq',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 48,
                        ),
                  ),
                  const SizedBox(height: AppTheme.spaceSM),
                  Text(
                    AppLocalizations.of(context)?.yourCompanion ?? '',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                        ),
                  ),
                  const SizedBox(height: AppTheme.spaceXL),
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
