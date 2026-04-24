import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/config/theme_config.dart';
import '../../../../core/utils/app_validators.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../l10n/app_localizations.dart';
import '../cubit/profile_cubit.dart';
import '../cubit/profile_state.dart';

class StepPersonalInfo extends StatefulWidget {
  const StepPersonalInfo({super.key});

  @override
  State<StepPersonalInfo> createState() => StepPersonalInfoState();
}

class StepPersonalInfoState extends State<StepPersonalInfo> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _ageCtrl;
  late TextEditingController _heightCtrl;
  late TextEditingController _weightCtrl;

  @override
  void initState() {
    super.initState();
    final state = context.read<ProfileCubit>().state;
    _nameCtrl = TextEditingController(text: state.name);
    _ageCtrl = TextEditingController(text: state.age);
    _heightCtrl = TextEditingController(text: state.heightCm?.toStringAsFixed(0) ?? '');
    _weightCtrl = TextEditingController(text: state.weightKg?.toStringAsFixed(0) ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  /// Called by the parent stepper to validate before advancing.
  bool validate() => _formKey.currentState?.validate() ?? false;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) {
        final l10n = AppLocalizations.of(context)!;
        return Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spaceLG),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.personalInformation,
                  style: Theme.of(context).textTheme.displaySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spaceXL),

                AppTextField(
                  controller: _nameCtrl,
                  label: l10n.fullName,
                  keyboardType: TextInputType.name,
                  prefixIcon: const Icon(Icons.person_outline, size: 28),
                  validator: AppValidators.validateName,
                  onChanged: (v) => context.read<ProfileCubit>().updateName(v),
                ),
                const SizedBox(height: AppTheme.spaceMD),

                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _ageCtrl,
                        label: l10n.age,
                        keyboardType: TextInputType.number,
                        prefixIcon: const Icon(Icons.cake_outlined, size: 28),
                        validator: AppValidators.validateAge,
                        onChanged: (v) => context.read<ProfileCubit>().updateAge(v),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceMD),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMD),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.dividerColor),
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: state.sex,
                            isExpanded: true,
                            style: const TextStyle(fontSize: 18, color: AppTheme.textPrimary),
                            items: [
                              DropdownMenuItem(value: 'male', child: Text(l10n.male)),
                              DropdownMenuItem(value: 'female', child: Text(l10n.female)),
                            ],
                            onChanged: (v) => context.read<ProfileCubit>().updateSex(v!),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceMD),

                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _heightCtrl,
                        label: l10n.height,
                        keyboardType: TextInputType.number,
                        prefixIcon: const Icon(Icons.height, size: 28),
                        validator: AppValidators.validateHeight,
                        onChanged: (v) => context.read<ProfileCubit>().updateHeight(double.tryParse(v)),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceMD),
                    Expanded(
                      child: AppTextField(
                        controller: _weightCtrl,
                        label: l10n.weight,
                        keyboardType: TextInputType.number,
                        prefixIcon: const Icon(Icons.monitor_weight_outlined, size: 28),
                        validator: AppValidators.validateWeight,
                        onChanged: (v) => context.read<ProfileCubit>().updateWeight(double.tryParse(v)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
