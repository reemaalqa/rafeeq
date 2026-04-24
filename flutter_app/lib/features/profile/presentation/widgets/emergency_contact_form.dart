import 'package:flutter/material.dart';
import '../../../../core/config/theme_config.dart';
import '../../../../core/utils/app_validators.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../emergency/domain/entities/emergency_contact.dart';

class EmergencyContactForm extends StatefulWidget {
  final ValueChanged<EmergencyContact> onAdd;

  const EmergencyContactForm({super.key, required this.onAdd});

  @override
  State<EmergencyContactForm> createState() => _EmergencyContactFormState();
}

class _EmergencyContactFormState extends State<EmergencyContactForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _relCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _relCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      widget.onAdd(EmergencyContact(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        relationship: _relCtrl.text.trim(),
      ));
      _nameCtrl.clear();
      _phoneCtrl.clear();
      _relCtrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.addContact,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppTheme.spaceSM),
            AppTextField(
              controller: _nameCtrl,
              label: l10n.nameLabel,
              prefixIcon: const Icon(Icons.person_outline),
              validator: AppValidators.validateName,
            ),
            const SizedBox(height: AppTheme.spaceSM),
            AppTextField(
              controller: _phoneCtrl,
              label: l10n.phoneLabel,
              keyboardType: TextInputType.phone,
              prefixIcon: const Icon(Icons.phone_outlined),
              validator: AppValidators.validatePhone,
            ),
            const SizedBox(height: AppTheme.spaceSM),
            AppTextField(
              controller: _relCtrl,
              label: l10n.relationship,
              prefixIcon: const Icon(Icons.people_outline),
              validator: (v) => AppValidators.validateRequired(v, fieldName: l10n.relationship),
            ),
            const SizedBox(height: AppTheme.spaceMD),
            ElevatedButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.person_add),
              label: Text(l10n.add),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
            ),
          ],
        ),
      ),
    );
  }
}
