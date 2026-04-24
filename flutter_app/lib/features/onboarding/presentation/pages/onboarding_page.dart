import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../../../core/config/theme_config.dart';
import '../../../../core/utils/app_state.dart';
import '../../../../l10n/app_localizations.dart';

/// Onboarding flow displayed on first launch.
/// Four sequential cards walk the user through the app's core features,
/// explain required permissions, and direct them to the login screen.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const int _totalPages = 4;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ── Navigation Helpers ────────────────────────────────────────────────────

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _finish() async {
    final appState = Provider.of<AppState>(context, listen: false);
    await appState.markOnboardingSeen();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  Future<void> _skip() async {
    final appState = Provider.of<AppState>(context, listen: false);
    await appState.markOnboardingSeen();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.microphone,
      Permission.location,
    ].request();
    // Permissions are best-effort; the user can grant them later from settings.
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) =>
                        setState(() => _currentPage = index),
                    children: [
                      _WelcomeCard(onNext: _nextPage),
                      _FeaturesCard(onNext: _nextPage),
                      _PermissionsCard(
                        onRequestPermissions: _requestPermissions,
                        onNext: _nextPage,
                      ),
                      _GetStartedCard(onFinish: _finish),
                    ],
                  ),
                ),
                _DotIndicator(
                  total: _totalPages,
                  current: _currentPage,
                ),
                const SizedBox(height: AppTheme.spaceLG),
              ],
            ),
            // Skip button — top-right corner.
            if (_currentPage < _totalPages - 1)
              Positioned(
                top: AppTheme.spaceSM,
                right: AppTheme.spaceMD,
                child: SizedBox(
                  width: 120,
                  child: TextButton(
                    onPressed: _skip,
                    child: Text(
                      AppLocalizations.of(context)!.skip,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Page Cards ────────────────────────────────────────────────────────────────

/// Card 1: Welcome splash screen.
class _WelcomeCard extends StatelessWidget {
  final VoidCallback onNext;
  const _WelcomeCard({required this.onNext});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _OnboardingCardLayout(
      icon: Icons.elderly,
      iconColor: AppTheme.primaryColor,
      title: l10n.welcomeToRafeeq,
      subtitle: l10n.yourCompanion,
      onNext: onNext,
      nextLabel: l10n.next,
      child: const SizedBox.shrink(),
    );
  }
}

/// Card 2: Feature overview — four key capabilities.
class _FeaturesCard extends StatelessWidget {
  final VoidCallback onNext;
  const _FeaturesCard({required this.onNext});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final features = [
      _FeatureRow(icon: Icons.mic, label: l10n.voiceConversation),
      _FeatureRow(icon: Icons.alarm, label: l10n.smartReminders),
      _FeatureRow(icon: Icons.mosque, label: l10n.prayerTimes),
      _FeatureRow(icon: Icons.favorite, label: l10n.healthAndDiet),
    ];
    return _OnboardingCardLayout(
      icon: Icons.star,
      iconColor: AppTheme.warningColor,
      title: l10n.whatRafeeqCanDo,
      subtitle: '',
      onNext: onNext,
      nextLabel: l10n.next,
      child: Column(
        children: features
            .map(
              (f) => Padding(
                padding:
                    const EdgeInsets.only(bottom: AppTheme.spaceMD),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMedium),
                      ),
                      child: Icon(f.icon,
                          color: AppTheme.primaryColor, size: 28),
                    ),
                    const SizedBox(width: AppTheme.spaceMD),
                    Expanded(
                      child: Text(
                        f.label,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _FeatureRow {
  final IconData icon;
  final String label;
  const _FeatureRow({required this.icon, required this.label});
}

/// Card 3: Permission explanation + request button.
class _PermissionsCard extends StatelessWidget {
  final VoidCallback onNext;
  final Future<void> Function() onRequestPermissions;

  const _PermissionsCard({
    required this.onNext,
    required this.onRequestPermissions,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _OnboardingCardLayout(
      icon: Icons.security,
      iconColor: AppTheme.infoColor,
      title: l10n.permissionsRequired,
      subtitle: l10n.rafeeqNeeds,
      onNext: onNext,
      nextLabel: l10n.next,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PermissionItem(
            icon: Icons.mic,
            title: l10n.microphone,
            subtitle: l10n.toListenToVoice,
          ),
          const SizedBox(height: AppTheme.spaceMD),
          _PermissionItem(
            icon: Icons.location_on,
            title: l10n.location,
            subtitle: l10n.forPrayerTimes,
          ),
          const SizedBox(height: AppTheme.spaceLG),
          OutlinedButton.icon(
            onPressed: onRequestPermissions,
            icon: const Icon(Icons.check_circle_outline),
            label: Text(l10n.allowPermissions),
          ),
        ],
      ),
    );
  }
}

class _PermissionItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PermissionItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 28),
          const SizedBox(width: AppTheme.spaceMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Card 4: Get started CTA.
class _GetStartedCard extends StatelessWidget {
  final Future<void> Function() onFinish;
  const _GetStartedCard({required this.onFinish});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _OnboardingCardLayout(
      icon: Icons.check_circle,
      iconColor: AppTheme.successColor,
      title: l10n.youreAllSet,
      subtitle: l10n.startUsing,
      nextLabel: '',
      onNext: () {},
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton(
            onPressed: onFinish,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              minimumSize: const Size(double.infinity, 64),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
            ),
            child: Text(
              l10n.getStarted,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: AppTheme.fontButton,
                    color: Colors.white,
                  ),
            ),
          ),
        ],
      ),
      showNextButton: false,
    );
  }
}

// ── Shared Layout ─────────────────────────────────────────────────────────────

/// Common scaffold for all onboarding cards: icon, title, subtitle, child, and
/// an optional "Next" button at the bottom.
class _OnboardingCardLayout extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback onNext;
  final String nextLabel;
  final bool showNextButton;

  const _OnboardingCardLayout({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.onNext,
    required this.nextLabel,
    this.showNextButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceLG,
        vertical: AppTheme.spaceXXL,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Hero icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 64, color: iconColor),
          ),

          const SizedBox(height: AppTheme.spaceXL),

          // Title
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displaySmall,
          ),

          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spaceMD),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ],

          const SizedBox(height: AppTheme.spaceXL),

          // Page-specific content
          child,

          if (showNextButton) ...[
            const SizedBox(height: AppTheme.spaceLG),
            ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
              ),
              child: Text(nextLabel),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Dot Indicator ─────────────────────────────────────────────────────────────

/// Horizontal row of progress dots, one per page.
class _DotIndicator extends StatelessWidget {
  final int total;
  final int current;

  const _DotIndicator({required this.total, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        total,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: index == current ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: index == current
                ? AppTheme.primaryColor
                : AppTheme.dividerColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusCircular),
          ),
        ),
      ),
    );
  }
}
