import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import '../../../../core/config/theme_config.dart';
import '../../../../core/utils/app_state.dart';
import '../../../../l10n/app_localizations.dart';
import '../cubit/settings_cubit.dart';
import '../cubit/settings_state.dart';
import '../../domain/entities/app_settings.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SettingsView();
  }
}

class _SettingsView extends StatelessWidget {
  const _SettingsView();

  @override
  Widget build(BuildContext context) {
    final l10n     = AppLocalizations.of(context)!;
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 32),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(l10n.settings),
      ),
      body: SafeArea(
        top: false,
        child: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          final settings = state.settings ?? AppSettings.defaults();

          return ListView(
            padding: const EdgeInsets.all(AppTheme.spaceLG),
            children: [
              // ── Profile ──────────────────────────────────────────────────
              _sectionTitle(context, l10n.profile),
              _profileCard(context, appState, l10n),
              const SizedBox(height: AppTheme.spaceMD),
              _prefCard(
                context,
                icon: Icons.edit,
                title: l10n.editProfile,
                value: '',
                onTap: () => Navigator.pushNamed(context, '/profile-setup', arguments: 0),
              ),
              _prefCard(
                context,
                icon: Icons.monitor_heart,
                title: l10n.updateHealthInfo,
                value: '',
                onTap: () => Navigator.pushNamed(context, '/profile-setup', arguments: 1),
              ),
              _prefCard(
                context,
                icon: Icons.contacts,
                title: l10n.manageEmergencyContacts,
                value: '',
                onTap: () => Navigator.pushNamed(context, '/profile-setup', arguments: 2),
              ),

              const SizedBox(height: AppTheme.spaceLG),

              // ── Preferences ──────────────────────────────────────────────
              _sectionTitle(context, l10n.preferences),

              // Theme — AppState drives MaterialApp; cubit persists for reload
              _prefCard(
                context,
                icon: Icons.palette,
                title: l10n.theme,
                value: appState.themeMode == ThemeMode.dark ? l10n.dark : l10n.light,
                onTap: () => _themeDialog(context, appState, l10n),
              ),

              // Font Size — same dual-write approach
              _prefCard(
                context,
                icon: Icons.text_fields,
                title: l10n.fontSize,
                value: _fontSizeLabel(appState.fontSize, l10n),
                onTap: () => _fontSizeDialog(context, appState, l10n),
              ),

              const SizedBox(height: AppTheme.spaceLG),

              // ── Notifications ────────────────────────────────────────────
              _sectionTitle(context, l10n.notifications),
              _switchCard(
                context,
                icon: Icons.alarm,
                title: l10n.reminders,
                value: settings.remindersEnabled,
                onChanged: (v) => context.read<SettingsCubit>().toggleReminders(v),
              ),
              _switchCard(
                context,
                icon: Icons.mosque,
                title: l10n.prayerTimes,
                value: settings.prayerTimesEnabled,
                onChanged: (v) => context.read<SettingsCubit>().togglePrayerTimes(v),
              ),
              _switchCard(
                context,
                icon: Icons.volume_up,
                title: l10n.voiceFeedback,
                value: settings.voiceFeedbackEnabled,
                onChanged: (v) => context.read<SettingsCubit>().toggleVoiceFeedback(v),
              ),
              _switchCard(
                context,
                icon: Icons.vibration,
                title: l10n.hapticFeedback,
                value: settings.hapticFeedbackEnabled,
                onChanged: (v) => context.read<SettingsCubit>().toggleHapticFeedback(v),
              ),

              const SizedBox(height: AppTheme.spaceXL),

              // ── Logout ───────────────────────────────────────────────────
              ElevatedButton(
                onPressed: () => _logoutDialog(context, appState, l10n),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.errorColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                ),
                child: Text(l10n.logout),
              ),
            ],
          );
        },
      ),
      ), // SafeArea
    );
  }

  // ── Section helpers ──────────────────────────────────────────────────────────

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spaceMD),
      child: Text(title, style: Theme.of(context).textTheme.displaySmall),
    );
  }

  Widget _profileCard(BuildContext context, AppState appState, AppLocalizations l10n) {
    final displayName = appState.userName.isNotEmpty
        ? (appState.userAge.isNotEmpty
            ? '${appState.userName}, ${appState.userAge}'
            : appState.userName)
        : '—';

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/profile-setup', arguments: 0),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spaceLG),
        margin: const EdgeInsets.only(bottom: AppTheme.spaceMD),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, size: 40, color: AppTheme.primaryColor),
            ),
            const SizedBox(width: AppTheme.spaceMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(l10n.editProfile,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.primaryColor)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _prefCard(BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceMD),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spaceMD),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(color: AppTheme.dividerColor),
          ),
          child: Row(
            children: [
              Icon(icon, size: 28, color: AppTheme.primaryColor),
              const SizedBox(width: AppTheme.spaceMD),
              Expanded(child: Text(title, style: Theme.of(context).textTheme.bodyLarge)),
              if (value.isNotEmpty)
                Text(value,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary)),
              const SizedBox(width: AppTheme.spaceSM),
              const Icon(Icons.arrow_forward_ios, size: 20, color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _switchCard(BuildContext context, {
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceMD),
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Row(
        children: [
          Icon(icon, size: 28, color: AppTheme.primaryColor),
          const SizedBox(width: AppTheme.spaceMD),
          Expanded(child: Text(title, style: Theme.of(context).textTheme.bodyLarge)),
          Switch(value: value, onChanged: onChanged, activeColor: AppTheme.primaryColor),
        ],
      ),
    );
  }

  // ── Dialogs ──────────────────────────────────────────────────────────────────

  void _themeDialog(BuildContext context, AppState appState, AppLocalizations l10n) {
    final current = appState.themeMode == ThemeMode.dark ? 'dark' : 'light';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.theme),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: Text(l10n.light),
              value: 'light',
              groupValue: current,
              onChanged: (_) {
                Navigator.pop(ctx);
                appState.setThemeMode(ThemeMode.light);
                context.read<SettingsCubit>().updateThemeMode(ThemeMode.light);
              },
            ),
            RadioListTile<String>(
              title: Text(l10n.dark),
              value: 'dark',
              groupValue: current,
              onChanged: (_) {
                Navigator.pop(ctx);
                appState.setThemeMode(ThemeMode.dark);
                context.read<SettingsCubit>().updateThemeMode(ThemeMode.dark);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _fontSizeDialog(BuildContext context, AppState appState, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.fontSize),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<AppFontSize>(
              title: Text(l10n.fontSizeSmall),
              value: AppFontSize.small,
              groupValue: appState.fontSize,
              onChanged: (_) {
                Navigator.pop(ctx);
                appState.setFontSize(AppFontSize.small);
                context.read<SettingsCubit>().updateFontSize(FontSize.normal);
              },
            ),
            RadioListTile<AppFontSize>(
              title: Text(l10n.fontSizeLarge),
              value: AppFontSize.large,
              groupValue: appState.fontSize,
              onChanged: (_) {
                Navigator.pop(ctx);
                appState.setFontSize(AppFontSize.large);
                context.read<SettingsCubit>().updateFontSize(FontSize.large);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _logoutDialog(BuildContext context, AppState appState, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.logout),
        content: Text(l10n.logoutConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await appState.logout();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.logout),
          ),
        ],
      ),
    );
  }

  String _fontSizeLabel(AppFontSize size, AppLocalizations l10n) {
    return size == AppFontSize.small ? l10n.fontSizeSmall : l10n.fontSizeLarge;
  }
}
