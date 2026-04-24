import 'package:equatable/equatable.dart';
import '../../domain/entities/emergency_contact.dart';

enum EmergencyStatus { idle, loading, calling, smsSent, cancelled, completed }

class EmergencyState extends Equatable {
  final List<EmergencyContact> contacts;
  final bool isTriggered;
  final int currentContactIndex;
  final int countdownSeconds;
  final EmergencyStatus status;
  final String? errorMessage;

  const EmergencyState({
    this.contacts = const [],
    this.isTriggered = false,
    this.currentContactIndex = 0,
    this.countdownSeconds = 30,
    this.status = EmergencyStatus.idle,
    this.errorMessage,
  });

  EmergencyState copyWith({
    List<EmergencyContact>? contacts,
    bool? isTriggered,
    int? currentContactIndex,
    int? countdownSeconds,
    EmergencyStatus? status,
    String? errorMessage,
  }) {
    return EmergencyState(
      contacts: contacts ?? this.contacts,
      isTriggered: isTriggered ?? this.isTriggered,
      currentContactIndex: currentContactIndex ?? this.currentContactIndex,
      countdownSeconds: countdownSeconds ?? this.countdownSeconds,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        contacts,
        isTriggered,
        currentContactIndex,
        countdownSeconds,
        status,
        errorMessage,
      ];
}
