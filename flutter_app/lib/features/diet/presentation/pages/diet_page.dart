import 'dart:convert' show jsonDecode;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/config/theme_config.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/utils/app_state.dart';
import '../../../../l10n/app_localizations.dart';
import '../cubit/diet_cubit.dart';
import '../cubit/diet_state.dart';
import '../widgets/bmi_gauge_widget.dart';
import '../widgets/meal_card.dart';
import '../widgets/food_preference_chip.dart';
import '../widgets/calorie_progress_bar.dart';

class DietPage extends StatelessWidget {
  const DietPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);
    return BlocProvider(
      create: (_) {
        final cubit = GetIt.instance<DietCubit>();
        _loadProfileAllergiesAndInit(cubit, appState);
        return cubit;
      },
      child: const _DietView(),
    );
  }

  /// Pulls allergies saved in the profile and forwards them to the cubit so
  /// the generated plan excludes dishes containing them.
  static Future<void> _loadProfileAllergiesAndInit(
    DietCubit cubit,
    AppState appState,
  ) async {
    List<String> allergies = const [];
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(StorageKeys.userAllergies);
      if (raw != null && raw.isNotEmpty) {
        allergies = (jsonDecode(raw) as List).cast<String>();
      }
    } catch (_) {/* ignore malformed cache */}
    await cubit.init(
      heightCm: appState.heightCm,
      weightKg: appState.weightKg,
      allergies: allergies,
    );
  }
}

class _DietView extends StatelessWidget {
  const _DietView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(l10n.diet),
      ),
      body: SafeArea(top: false, child: BlocBuilder<DietCubit, DietState>(
        builder: (context, state) {
          if (state.status == DietStatus.loading || state.status == DietStatus.initial) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.status == DietStatus.error) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
                  const SizedBox(height: AppTheme.spaceMD),
                  Text(
                    state.errorMessage ?? l10n.anErrorOccurred,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.errorColor),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          if (state.needsProfileSetup) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spaceLG),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_outline, size: 80, color: AppTheme.primaryColor.withOpacity(0.5)),
                    const SizedBox(height: AppTheme.spaceLG),
                    Text(
                      l10n.setHeightWeightHint,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppTheme.spaceLG),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/profile-setup', arguments: 0),
                      icon: const Icon(Icons.edit),
                      label: Text(l10n.updateProfile),
                      style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 56)),
                    ),
                  ],
                ),
              ),
            );
          }

          final plan = state.dietPlan;
          final bmi = state.bmiResult;

          return ListView(
            padding: const EdgeInsets.all(AppTheme.spaceLG),
            children: [
              // BMI Gauge
              if (bmi != null) ...[
                Text(
                  l10n.yourBmi,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppTheme.spaceSM),
                BmiGaugeWidget(bmiResult: bmi),
                const SizedBox(height: AppTheme.spaceMD),
              ],

              // Calorie Summary
              if (plan != null) ...[
                CalorieProgressBar(
                  target: plan.targetCalories,
                  consumed: plan.consumedCalories,
                ),
                const SizedBox(height: AppTheme.spaceLG),
              ],

              // Food Preferences
              _FoodPreferencesSection(dislikedFoods: state.dislikedFoods),
              const SizedBox(height: AppTheme.spaceLG),

              // Meals
              if (plan != null) ...[
                Text(
                  l10n.todaysMeals,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppTheme.spaceSM),
                ...plan.meals.map(
                  (meal) => MealCard(
                    meal: meal,
                    onToggleEaten: () => context.read<DietCubit>().markMealEaten(meal.id),
                  ),
                ),
              ],
            ],
          );
        },
      )), // SafeArea + BlocBuilder
    );
  }
}

class _FoodPreferencesSection extends StatelessWidget {
  final List<String> dislikedFoods;

  const _FoodPreferencesSection({required this.dislikedFoods});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final allFoods = [
      l10n.gluten, l10n.dairy, l10n.nuts, l10n.shellfish,
      l10n.eggs, l10n.spicyFood, l10n.sugar, l10n.sesame, l10n.wheat,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.allergiesAndIntolerances,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          l10n.tapToSelectAllergies,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: AppTheme.spaceSM),
        Wrap(
          spacing: AppTheme.spaceSM,
          runSpacing: AppTheme.spaceSM,
          children: allFoods
              .map((food) => FoodPreferenceChip(
                    food: food,
                    isDisliked: dislikedFoods.contains(food),
                    onToggle: () => context.read<DietCubit>().toggleFoodPreference(food),
                  ))
              .toList(),
        ),
      ],
    );
  }
}
