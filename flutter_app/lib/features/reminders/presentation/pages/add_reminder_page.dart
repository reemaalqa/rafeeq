import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/config/theme_config.dart';
import '../../../../core/utils/app_validators.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/reminder.dart';
import '../cubit/reminder_cubit.dart';
import '../cubit/reminder_state.dart';
import '../widgets/reminder_type_selector.dart';

class AddReminderPage extends StatefulWidget {
  const AddReminderPage({super.key});

  @override
  State<AddReminderPage> createState() => _AddReminderPageState();
}

class _AddReminderPageState extends State<AddReminderPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  ReminderType _type = ReminderType.medication;
  RepeatInterval _repeat = RepeatInterval.none;
  TimeOfDay _time = TimeOfDay.now();
  bool _isSaving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);

    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day, _time.hour, _time.minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    final reminder = Reminder(
      id: const Uuid().v4(),
      title: _titleCtrl.text.trim(),
      scheduledTime: scheduled,
      type: _type,
      repeat: _repeat,
    );

    await context.read<ReminderCubit>().addReminder(reminder);
    if (!mounted) return;

    // If the OS can't fire exact alarms, show a one-time dialog so the user
    // knows to grant permission — then close the sheet.
    final needsPerm =
        context.read<ReminderCubit>().state.needsExactAlarmPermission;
    if (needsPerm) {
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text(
            'تفعيل المنبه الدقيق',
            textDirection: TextDirection.rtl,
          ),
          content: const Text(
            'لضمان رنين التذكير في الوقت الصحيح تماماً،\n'
            'يحتاج التطبيق إذن "المنبهات والتذكيرات" من الإعدادات.',
            textDirection: TextDirection.rtl,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('لاحقاً'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                context.read<ReminderCubit>().openAlarmSettings();
              },
              child: const Text('فتح الإعدادات'),
            ),
          ],
        ),
      );
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    // Wrap the sheet in a BlocListener so if the permission flag fires
    // while still on this page (edge case), the dialog appears correctly.
    return BlocListener<ReminderCubit, ReminderState>(
      listenWhen: (prev, curr) =>
          !prev.needsExactAlarmPermission && curr.needsExactAlarmPermission,
      listener: (ctx, _) {
        // Dialog is already handled in _save(); this listener is a safety net.
      },
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.only(
        left: AppTheme.spaceLG,
        right: AppTheme.spaceLG,
        top: AppTheme.spaceLG,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppTheme.spaceLG,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spaceMD),
            Text(
              l10n.newReminder,
              style: Theme.of(context).textTheme.displaySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spaceLG),

            // Title
            TextFormField(
              controller: _titleCtrl,
              style: const TextStyle(fontSize: 14),
              validator: AppValidators.validateReminderTitle,
              decoration: InputDecoration(
                labelText: l10n.titleLabel,
                prefixIcon: const Icon(Icons.title, size: 28),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spaceLG),

            // Type selector
            Text(l10n.typeLabel, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppTheme.spaceSM),
            ReminderTypeSelector(
              selected: _type,
              onChanged: (t) => setState(() => _type = t),
            ),
            const SizedBox(height: AppTheme.spaceLG),

            // Time picker
            InkWell(
              onTap: _pickTime,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              child: Container(
                padding: const EdgeInsets.all(AppTheme.spaceMD),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.dividerColor),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time, size: 28, color: AppTheme.primaryColor),
                    const SizedBox(width: AppTheme.spaceMD),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.setReminder,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          Text(
                            _time.format(context),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_left, color: AppTheme.textSecondary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spaceLG),

            // Repeat
            Text(l10n.repeatLabel, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppTheme.spaceSM),
            Wrap(
              spacing: AppTheme.spaceSM,
              children: RepeatInterval.values.map((r) {
                return ChoiceChip(
                  label: Text(_repeatLabel(r, l10n), style: const TextStyle(fontSize: 14)),
                  selected: _repeat == r,
                  onSelected: (_) => setState(() => _repeat = r),
                  selectedColor: AppTheme.primaryColor,
                  labelStyle: TextStyle(
                    color: _repeat == r ? Colors.white : AppTheme.textPrimary,
                    fontSize: 14,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppTheme.spaceXL),

            ElevatedButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check),
              label: Text(_isSaving ? l10n.savingDots : l10n.saveReminder),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 60),
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
      ), // Form
    );
  }

  String _repeatLabel(RepeatInterval r, AppLocalizations l10n) {
    switch (r) {
      case RepeatInterval.none: return l10n.once;
      case RepeatInterval.daily: return l10n.daily;
      case RepeatInterval.weekly: return l10n.weekly;
    }
  }
}
