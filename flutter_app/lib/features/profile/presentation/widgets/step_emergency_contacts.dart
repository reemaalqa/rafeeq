import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/config/theme_config.dart';
import '../../../../l10n/app_localizations.dart';
import '../cubit/profile_cubit.dart';
import '../cubit/profile_state.dart';
import 'emergency_contact_form.dart';

class StepEmergencyContacts extends StatelessWidget {
  const StepEmergencyContacts({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) {
        final l10n = AppLocalizations.of(context)!;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spaceLG),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.emergencyContacts,
                style: Theme.of(context).textTheme.displaySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spaceSM),
              Text(
                l10n.emergencyContactsInstruction,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spaceLG),

              // Existing contacts
              ...state.emergencyContacts.asMap().entries.map((entry) {
                final contact = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: AppTheme.spaceSM),
                  padding: const EdgeInsets.all(AppTheme.spaceMD),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    border: Border.all(color: AppTheme.dividerColor),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${entry.key + 1}',
                            style: const TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spaceMD),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(contact.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            Text(contact.phone, style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                            if (contact.relationship.isNotEmpty)
                              Text(contact.relationship, style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor, size: 28),
                        onPressed: () => context.read<ProfileCubit>().removeEmergencyContact(contact.id),
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: AppTheme.spaceMD),

              EmergencyContactForm(
                onAdd: (contact) => context.read<ProfileCubit>().addEmergencyContact(contact),
              ),
            ],
          ),
        );
      },
    );
  }
}
