import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import '../../../../core/config/theme_config.dart';
import '../../../../core/utils/app_state.dart';
import '../../../../l10n/app_localizations.dart';
import '../cubit/emergency_cubit.dart';
import '../cubit/emergency_state.dart';
import '../widgets/emergency_contact_tile.dart';

class EmergencyActivePage extends StatefulWidget {
  const EmergencyActivePage({super.key});

  @override
  State<EmergencyActivePage> createState() => _EmergencyActivePageState();
}

class _EmergencyActivePageState extends State<EmergencyActivePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = Provider.of<AppState>(context, listen: false);
      context.read<EmergencyCubit>().triggerEmergency(appState.userName);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: BlocConsumer<EmergencyCubit, EmergencyState>(
        listener: (context, state) {
          if (state.status == EmergencyStatus.cancelled ||
              state.status == EmergencyStatus.completed) {
            Navigator.of(context).pop();
          }
        },
        builder: (context, state) {
          return Scaffold(
            backgroundColor: AppTheme.errorColor,
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spaceLG),
                child: Column(
                  children: [
                    // Header
                    const Icon(
                      Icons.emergency,
                      size: 80,
                      color: Colors.white,
                    ),
                    const SizedBox(height: AppTheme.spaceMD),
                    Text(
                      AppLocalizations.of(context)!.emergencyDetected,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppTheme.spaceMD),

                    // Countdown
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.2),
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: Center(
                        child: Text(
                          '${state.countdownSeconds}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceMD),

                    // Status message
                    Text(
                      _getStatusMessage(state, AppLocalizations.of(context)!),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 18,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: AppTheme.spaceLG),

                    // Contacts list
                    Expanded(
                      child: state.contacts.isEmpty
                          ? Center(
                              child: Text(
                                AppLocalizations.of(context)!.noContactsConfigured,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 18,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : ListView.builder(
                              itemCount: state.contacts.length,
                              itemBuilder: (context, index) {
                                return EmergencyContactTile(
                                  contact: state.contacts[index],
                                  index: index,
                                  isActive: state.currentContactIndex == index &&
                                      state.status == EmergencyStatus.calling,
                                  isDone: index < state.currentContactIndex ||
                                      state.status == EmergencyStatus.completed,
                                );
                              },
                            ),
                    ),

                    const SizedBox(height: AppTheme.spaceLG),

                    // Cancel button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () =>
                            context.read<EmergencyCubit>().cancelEmergency(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.errorColor,
                          minimumSize: const Size(double.infinity, 64),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMedium),
                          ),
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.cancel,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _getStatusMessage(EmergencyState state, AppLocalizations l10n) {
    switch (state.status) {
      case EmergencyStatus.calling:
        if (state.contacts.isNotEmpty &&
            state.currentContactIndex < state.contacts.length) {
          return l10n.callingContact(state.contacts[state.currentContactIndex].name);
        }
        return l10n.callingForHelp;
      case EmergencyStatus.smsSent:
        return l10n.smsSent;
      case EmergencyStatus.completed:
        return l10n.allContactsNotified;
      case EmergencyStatus.cancelled:
        return l10n.cancelled;
      case EmergencyStatus.idle:
      case EmergencyStatus.loading:
        return l10n.preparing;
    }
  }
}
