import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';
import '../../../../core/config/theme_config.dart';
import '../../../../core/utils/app_state.dart';
import '../../../../l10n/app_localizations.dart';
import '../cubit/profile_cubit.dart';
import '../cubit/profile_state.dart';
import '../widgets/step_personal_info.dart';
import '../widgets/step_allergies.dart';
import '../widgets/step_emergency_contacts.dart';
import '../widgets/step_indicator.dart';

class ProfileSetupPage extends StatelessWidget {
  final int initialStep;

  const ProfileSetupPage({super.key, this.initialStep = 0});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GetIt.instance<ProfileCubit>()..loadProfile(),
      child: _ProfileSetupView(initialStep: initialStep),
    );
  }
}

class _ProfileSetupView extends StatefulWidget {
  final int initialStep;
  const _ProfileSetupView({required this.initialStep});

  @override
  State<_ProfileSetupView> createState() => _ProfileSetupViewState();
}

class _ProfileSetupViewState extends State<_ProfileSetupView> {
  late PageController _pageController;
  int _currentStep = 0;
  final _personalInfoKey = GlobalKey<StepPersonalInfoState>();

  static const int _totalSteps = 3;

  @override
  void initState() {
    super.initState();
    _currentStep = widget.initialStep;
    _pageController = PageController(initialPage: widget.initialStep);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    // Validate step 0 (personal info) before advancing
    if (_currentStep == 0) {
      final valid = _personalInfoKey.currentState?.validate() ?? true;
      if (!valid) return;
    }
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _save();
    }
  }

  void _prev() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _save() async {
    final cubit = context.read<ProfileCubit>();
    final success = await cubit.saveProfile();
    if (success && mounted) {
      // Sync AppState for backward compat
      final appState = Provider.of<AppState>(context, listen: false);
      await appState.saveUserProfile(
        name: cubit.state.name,
        age: cubit.state.age,
        heightCm: cubit.state.heightCm,
        weightKg: cubit.state.weightKg,
      );
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final stepLabels = [l10n.infoTab, l10n.allergiesTab, l10n.contactsTab];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profile),
        actions: [
          TextButton(
            onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(l10n.skip),
          ),
        ],
      ),
      body: SafeArea(top: false, child: BlocConsumer<ProfileCubit, ProfileState>(
        listener: (context, state) {
          if (state.status == ProfileStatus.error && state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!), backgroundColor: AppTheme.errorColor),
            );
          }
        },
        builder: (context, state) {
          if (state.status == ProfileStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              // Step indicator
              Padding(
                padding: const EdgeInsets.all(AppTheme.spaceLG),
                child: StepIndicator(
                  totalSteps: _totalSteps,
                  currentStep: _currentStep,
                  labels: stepLabels,
                ),
              ),
              const Divider(height: 1),

              // Page content
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    StepPersonalInfo(key: _personalInfoKey),
                    const StepAllergies(),
                    const StepEmergencyContacts(),
                  ],
                ),
              ),

              // Navigation buttons
              Container(
                padding: const EdgeInsets.all(AppTheme.spaceLG),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    if (_currentStep > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _prev,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 56),
                            backgroundColor: Colors.white,
                            foregroundColor: AppTheme.primaryColor,
                            side: const BorderSide(color: AppTheme.primaryColor, width: 2),
                          ),
                          child: Text(l10n.back),
                        ),
                      ),
                    if (_currentStep > 0) const SizedBox(width: AppTheme.spaceMD),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: state.status == ProfileStatus.saving ? null : _next,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 56),
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                        ),
                        child: state.status == ProfileStatus.saving
                            ? const SizedBox(
                                width: 24, height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(_currentStep < _totalSteps - 1
                                ? l10n.next
                                : l10n.saveProfile),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      )), // SafeArea + BlocConsumer
    );
  }
}
