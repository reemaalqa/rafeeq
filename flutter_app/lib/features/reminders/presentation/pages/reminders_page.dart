import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get_it/get_it.dart';
import '../../../../core/config/theme_config.dart';
import '../../../../core/services/alarm_service.dart';
import '../../../../core/services/notification_scheduler.dart';
import '../../../../l10n/app_localizations.dart';
import '../cubit/reminder_cubit.dart';
import '../cubit/reminder_state.dart';
import '../pages/add_reminder_page.dart';
import '../widgets/reminder_tile.dart';

class RemindersPage extends StatelessWidget {
  const RemindersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GetIt.instance<ReminderCubit>()..loadReminders(),
      child: const _RemindersView(),
    );
  }
}

class _RemindersView extends StatelessWidget {
  const _RemindersView();

  void _openAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLarge)),
      ),
      builder: (_) => BlocProvider.value(
        value: context.read<ReminderCubit>(),
        child: const AddReminderPage(),
      ),
    );
  }

  void _openDiagnosticsSheet(BuildContext context) {
    final cubit = context.read<ReminderCubit>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      builder: (_) => _NotificationDiagnosticsSheet(cubit: cubit),
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
        title: Text(l10n.reminders),
        actions: [
          IconButton(
            tooltip: 'فحص التنبيهات',
            icon: const Icon(Icons.health_and_safety_outlined, size: 28),
            onPressed: () => _openDiagnosticsSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 32),
            onPressed: () => _openAddSheet(context),
          ),
        ],
      ),
      body: SafeArea(top: false, child: BlocBuilder<ReminderCubit, ReminderState>(
        builder: (context, state) {
          if (state.status == ReminderStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.status == ReminderStatus.error) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
                  const SizedBox(height: AppTheme.spaceMD),
                  Text(state.errorMessage ?? l10n.errorLoadingReminders),
                  const SizedBox(height: AppTheme.spaceMD),
                  ElevatedButton(
                    onPressed: () => context.read<ReminderCubit>().loadReminders(),
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            );
          }

          if (state.reminders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.alarm_off, size: 80, color: AppTheme.textSecondary.withOpacity(0.3)),
                  const SizedBox(height: AppTheme.spaceMD),
                  Text(
                    '${l10n.noRemindersYet}\n${l10n.tapPlusToAdd}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: AppTheme.spaceLG),
                  ElevatedButton.icon(
                    onPressed: () => _openAddSheet(context),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.addReminder),
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(AppTheme.spaceMD),
            children: [
              if (state.todayReminders.isNotEmpty) ...[
                Text(l10n.today, style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: AppTheme.spaceMD),
                ...state.todayReminders.map((r) => ReminderTile(
                  reminder: r,
                  onSnooze: () => context.read<ReminderCubit>().snoozeReminder(r.id),
                  onDelete: () => context.read<ReminderCubit>().deleteReminder(r.id),
                )),
                const SizedBox(height: AppTheme.spaceLG),
              ],
              if (state.upcomingReminders.isNotEmpty) ...[
                Text(l10n.tomorrow, style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: AppTheme.spaceMD),
                ...state.upcomingReminders.map((r) => ReminderTile(
                  reminder: r,
                  onSnooze: () => context.read<ReminderCubit>().snoozeReminder(r.id),
                  onDelete: () => context.read<ReminderCubit>().deleteReminder(r.id),
                )),
              ],
              if (state.todayReminders.isEmpty && state.upcomingReminders.isEmpty) ...[
                const SizedBox(height: AppTheme.spaceLG),
                Center(
                  child: Text(
                    l10n.allRemindersScheduledLater,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceLG),
                ...state.reminders.map((r) => ReminderTile(
                  reminder: r,
                  onSnooze: () => context.read<ReminderCubit>().snoozeReminder(r.id),
                  onDelete: () => context.read<ReminderCubit>().deleteReminder(r.id),
                )),
              ],
            ],
          );
        },
      )), // SafeArea + BlocBuilder
      floatingActionButton: FloatingActionButton.large(
        onPressed: () => _openAddSheet(context),
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, size: 36, color: Colors.white),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Notification diagnostics bottom sheet — shown from the heart icon in the
// app bar. Each "Fix" button launches the exact system settings intent so
// the user never has to hunt through Android's Settings app.
// ────────────────────────────────────────────────────────────────────────────

class _NotificationDiagnosticsSheet extends StatefulWidget {
  final ReminderCubit cubit;
  const _NotificationDiagnosticsSheet({required this.cubit});

  @override
  State<_NotificationDiagnosticsSheet> createState() =>
      _NotificationDiagnosticsSheetState();
}

class _NotificationDiagnosticsSheetState
    extends State<_NotificationDiagnosticsSheet> {
  NotificationDiagnosis? _diag;
  bool _rawRemindersEnabled = true;
  List<PendingNotificationRequest> _pending = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final alarm = GetIt.instance<AlarmService>();
    final d = await alarm.diagnose();
    final raw = await alarm.rawRemindersEnabled();
    final pending = await alarm.pending();
    if (!mounted) return;
    setState(() {
      _diag = d;
      _rawRemindersEnabled = raw;
      _pending = pending;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spaceLG),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AppTheme.spaceMD),
                    decoration: BoxDecoration(
                      color: AppTheme.dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'فحص التنبيهات',
                  style: Theme.of(context).textTheme.displaySmall,
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 4),
                Text(
                  'إذا التذكير ما يشتغل، هذي الأشياء اللي لازم تكون مفعلة:',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
                const SizedBox(height: AppTheme.spaceLG),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(AppTheme.spaceLG),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_diag != null) ...[
                  _DiagRow(
                    ok: _diag!.notificationsEnabled,
                    label: 'إذن الإشعارات',
                    description: 'يسمح للتطبيق بعرض التنبيهات.',
                    fixLabel: 'فتح إعدادات الإشعارات',
                    onFix: () async {
                      await GetIt.instance<AlarmService>()
                          .openNotificationSettings();
                    },
                  ),
                  const SizedBox(height: 8),
                  _DiagRow(
                    ok: _diag!.exactAlarmsAllowed,
                    label: 'المنبهات الدقيقة',
                    description:
                        'لازم التنبيه يجي بالدقيقة الصحيحة بدون تأخير.',
                    fixLabel: 'فتح إعدادات المنبهات الدقيقة',
                    onFix: () async {
                      await GetIt.instance<AlarmService>()
                          .openAlarmSettings();
                    },
                  ),
                  const SizedBox(height: 8),
                  _DiagRow(
                    ok: _rawRemindersEnabled,
                    label: 'التذكيرات مفعّلة من التطبيق',
                    description: 'القيمة المحفوظة حالياً: '
                        '${_rawRemindersEnabled ? "ON ✓" : "OFF ✗"}'
                        '. الزر يضبطها فوراً بدون مشاكل.',
                    fixLabel: 'تفعيل الآن',
                    onFix: _rawRemindersEnabled
                        ? null
                        : () async {
                            await GetIt.instance<AlarmService>()
                                .forceEnableReminders();
                            await _refresh();
                          },
                  ),
                  const SizedBox(height: 8),
                  _DiagRow(
                    ok: _pending.isNotEmpty,
                    label: 'تنبيهات مجدولة الآن',
                    description: _pending.isEmpty
                        ? 'لا يوجد أي منبه في الطابور — حتى لو تظهر تذكيرات '
                            'في الصفحة، هي ما تنتظر إطلاق من نظام التشغيل.'
                        : 'عدد المنبهات في الطابور: ${_pending.length}',
                    fixLabel: null,
                    onFix: null,
                  ),
                  if (_pending.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spaceSM),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.04),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMedium),
                      ),
                      child: Column(
                        children: [
                          for (final p in _pending.take(5))
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  const Icon(Icons.schedule,
                                      size: 16, color: AppTheme.textSecondary),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '${p.title ?? "تذكير"}'
                                      '${p.body != null ? " — ${p.body}" : ""}',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppTheme.spaceLG),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.battery_charging_full),
                          label: const Text('إيقاف توفير البطارية'),
                          onPressed: () async {
                            await GetIt.instance<AlarmService>()
                                .openBatteryOptimisationSettings();
                          },
                        ),
                      ),
                      const SizedBox(width: AppTheme.spaceSM),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.notifications_active),
                          label: const Text('إرسال تنبيه تجريبي'),
                          onPressed: () async {
                            await widget.cubit.sendTestNotification();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'أرسلنا تنبيه الآن. إذا ما ظهر، الإذن مقفل.',
                                  textDirection: TextDirection.rtl,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spaceSM),
                  TextButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('إعادة الفحص'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DiagRow extends StatelessWidget {
  final bool ok;
  final String label;
  final String description;
  final String? fixLabel;
  final VoidCallback? onFix;

  const _DiagRow({
    required this.ok,
    required this.label,
    required this.description,
    required this.fixLabel,
    required this.onFix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        color: ok
            ? AppTheme.successColor.withOpacity(0.08)
            : AppTheme.warningColor.withOpacity(0.10),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: ok
              ? AppTheme.successColor.withOpacity(0.3)
              : AppTheme.warningColor.withOpacity(0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
            color: ok ? AppTheme.successColor : AppTheme.warningColor,
            size: 28,
          ),
          const SizedBox(width: AppTheme.spaceMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          if (!ok && fixLabel != null && onFix != null) ...[
            const SizedBox(width: AppTheme.spaceSM),
            FilledButton(
              onPressed: onFix,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.warningColor,
                minimumSize: const Size(0, 44),
              ),
              child: const Text('إصلاح'),
            ),
          ],
        ],
      ),
    );
  }
}
