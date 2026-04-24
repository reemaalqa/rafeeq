import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import '../../../../core/config/theme_config.dart';
import '../../../../core/utils/app_validators.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/emergency_contact.dart';
import '../cubit/emergency_cubit.dart';
import '../cubit/emergency_state.dart';

// ── Quick direct-call helper (tel: URI) ──────────────────────────────────────
// Uses url_launcher which is already a declared dependency.
// Importing it here avoids adding a new package.
import 'package:url_launcher/url_launcher.dart';

class EmergencyPage extends StatelessWidget {
  const EmergencyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GetIt.instance<EmergencyCubit>()..loadContacts(),
      child: const _EmergencyView(),
    );
  }
}

class _EmergencyView extends StatelessWidget {
  const _EmergencyView();

  void _triggerEmergency(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmEmergency),
        content: Text(l10n.areYouSure),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, '/emergency-active');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 32),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(l10n.emergency),
      ),
      body: SafeArea(top: false, child: BlocBuilder<EmergencyCubit, EmergencyState>(
        builder: (context, state) {
          return ListView(
            padding: const EdgeInsets.all(AppTheme.spaceLG),
            children: [
              // Emergency trigger button
              Container(
                padding: const EdgeInsets.all(AppTheme.spaceXL),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.errorColor, AppTheme.errorColor.withOpacity(0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.errorColor.withOpacity(0.3),
                      blurRadius: 15,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () => _triggerEmergency(context),
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.emergency,
                          size: 60,
                          color: AppTheme.errorColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceLG),
                    Text(
                      l10n.triggerEmergency,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppTheme.spaceSM),
                    Text(
                      l10n.tapOrSayHelp,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white.withOpacity(0.9),
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spaceXL),

              // Emergency Contacts Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.emergencyContacts,
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle, size: 32),
                    onPressed: () => _showAddContactDialog(context),
                    color: AppTheme.primaryColor,
                  ),
                ],
              ),

              const SizedBox(height: AppTheme.spaceMD),

              if (state.status == EmergencyStatus.loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppTheme.spaceLG),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (state.contacts.isEmpty)
                Container(
                  padding: const EdgeInsets.all(AppTheme.spaceLG),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    border: Border.all(color: AppTheme.warningColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber, color: AppTheme.warningColor, size: 32),
                      const SizedBox(width: AppTheme.spaceMD),
                      Expanded(
                        child: Text(
                          l10n.noEmergencyContacts,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...state.contacts.asMap().entries.map(
                      (entry) => _ContactCard(
                        contact: entry.value,
                        index: entry.key,
                        onCall: () => _callContact(context, entry.value.phone),
                        onDelete: () => _deleteContact(context, entry.value),
                      ),
                    ),

              const SizedBox(height: AppTheme.spaceLG),

              // Info box
              Container(
                padding: const EdgeInsets.all(AppTheme.spaceMD),
                decoration: BoxDecoration(
                  color: AppTheme.infoColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppTheme.infoColor, size: 32),
                    const SizedBox(width: AppTheme.spaceMD),
                    Expanded(
                      child: Text(
                        l10n.contactsWillBeCalled,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      )), // SafeArea + BlocBuilder
    );
  }

  void _deleteContact(BuildContext context, EmergencyContact contact) {
    context.read<EmergencyCubit>().removeContact(contact.id);
  }

  Future<void> _callContact(BuildContext context, String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.callNotSupported),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _showAddContactDialog(BuildContext context) {

    final l10n = AppLocalizations.of(context)!;
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final relationCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.addEmergencyContactTitle),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: InputDecoration(labelText: l10n.nameLabel),
                validator: AppValidators.validateName,
              ),
              const SizedBox(height: AppTheme.spaceSM),
              TextFormField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: l10n.phoneLabel),
                validator: AppValidators.validatePhone,
              ),
              const SizedBox(height: AppTheme.spaceSM),
              TextFormField(
                controller: relationCtrl,
                decoration: InputDecoration(labelText: l10n.relationship),
                validator: (v) => AppValidators.validateRequired(v, fieldName: l10n.relationship),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final newContact = EmergencyContact(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  relationship: relationCtrl.text.trim(),
                );
                context.read<EmergencyCubit>().addContact(newContact);
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.add),
          ),
        ],
      ),
    );
  }
}

// ── Contact card for the emergency page (light background) ───────────────────

class _ContactCard extends StatelessWidget {
  final EmergencyContact contact;
  final int index;
  final VoidCallback onCall;
  final VoidCallback onDelete;

  const _ContactCard({
    required this.contact,
    required this.index,
    required this.onCall,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceMD),
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.errorColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Index bubble
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.errorColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: AppTheme.errorColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spaceMD),

          // Name / phone / relationship
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  contact.phone,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
                if (contact.relationship.isNotEmpty)
                  Text(
                    contact.relationship,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
              ],
            ),
          ),

          // ── Call button ────────────────────────────────────────────────────
          Tooltip(
            message: l10n.callContact,
            child: InkWell(
              onTap: onCall,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.successColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.phone, color: Colors.white, size: 22),
                    const SizedBox(width: 6),
                    Text(
                      l10n.callContact,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: AppTheme.spaceSM),

          // Delete button
          IconButton(
            icon: const Icon(Icons.delete_outline,
                color: AppTheme.errorColor, size: 26),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
