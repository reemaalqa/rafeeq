import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/config/theme_config.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/allergy.dart';
import '../cubit/profile_cubit.dart';
import '../cubit/profile_state.dart';
import 'allergy_chip.dart';


class StepAllergies extends StatefulWidget {
  const StepAllergies({super.key});

  @override
  State<StepAllergies> createState() => _StepAllergiesState();
}

class _StepAllergiesState extends State<StepAllergies> {
  final _customCtrl = TextEditingController();

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) {
        final l10n = AppLocalizations.of(context)!;
        final predefinedAllergies = [
          Allergy(name: l10n.gluten, severity: AllergySeverity.moderate),
          Allergy(name: l10n.dairy, severity: AllergySeverity.moderate),
          Allergy(name: l10n.nuts, severity: AllergySeverity.severe),
          Allergy(name: l10n.shellfish, severity: AllergySeverity.severe),
          Allergy(name: l10n.eggs, severity: AllergySeverity.mild),
          Allergy(name: l10n.soy, severity: AllergySeverity.mild),
          Allergy(name: l10n.spicyFood, severity: AllergySeverity.mild),
          Allergy(name: l10n.sesame, severity: AllergySeverity.mild),
          Allergy(name: l10n.wheat, severity: AllergySeverity.moderate),
        ];
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spaceLG),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.allergiesAndIntolerances,
                style: Theme.of(context).textTheme.displaySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spaceSM),
              Text(
                l10n.tapToSelectAllergies,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spaceLG),

              Wrap(
                spacing: AppTheme.spaceSM,
                runSpacing: AppTheme.spaceSM,
                children: predefinedAllergies.map((allergy) {
                  final isSelected = state.allergies.any((a) => a.name == allergy.name);
                  return AllergyChip(
                    allergy: allergy,
                    isSelected: isSelected,
                    onTap: () => context.read<ProfileCubit>().toggleAllergy(allergy),
                  );
                }).toList(),
              ),

              const SizedBox(height: AppTheme.spaceLG),

              // Custom allergy input
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _customCtrl,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        labelText: l10n.addCustomAllergy,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceSM),
                  IconButton(
                    icon: const Icon(Icons.add_circle, size: 40, color: AppTheme.primaryColor),
                    onPressed: () {
                      if (_customCtrl.text.trim().isNotEmpty) {
                        context.read<ProfileCubit>().toggleAllergy(
                          Allergy(name: _customCtrl.text.trim()),
                        );
                        _customCtrl.clear();
                      }
                    },
                  ),
                ],
              ),

              if (state.allergies.isNotEmpty) ...[
                const SizedBox(height: AppTheme.spaceLG),
                Text(
                  l10n.selectedAllergiesLabel,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppTheme.spaceSM),
                Wrap(
                  spacing: AppTheme.spaceSM,
                  children: state.allergies.map((a) => Chip(
                    label: Text(a.name),
                    onDeleted: () => context.read<ProfileCubit>().toggleAllergy(a),
                    backgroundColor: AppTheme.errorColor.withOpacity(0.1),
                  )).toList(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
