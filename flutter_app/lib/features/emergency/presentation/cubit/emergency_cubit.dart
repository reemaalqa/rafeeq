import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/tts_service.dart';
import '../../domain/entities/emergency_contact.dart';
import '../../domain/usecases/get_emergency_contacts.dart';
import '../../domain/usecases/add_emergency_contact.dart';
import '../../domain/usecases/delete_emergency_contact.dart';
import '../../domain/usecases/trigger_emergency_call.dart';
import '../../domain/usecases/send_emergency_sms.dart';
import 'emergency_state.dart';

class EmergencyCubit extends Cubit<EmergencyState> {
  final GetEmergencyContacts _getContacts;
  final AddEmergencyContact _addContact;
  final DeleteEmergencyContact _deleteContact;
  final TriggerEmergencyCall _triggerCall;
  final SendEmergencySms _sendSms;
  final TtsService _tts;

  Timer? _countdownTimer;
  Timer? _contactTimer;

  EmergencyCubit({
    required GetEmergencyContacts getContacts,
    required AddEmergencyContact addContact,
    required DeleteEmergencyContact deleteContact,
    required TriggerEmergencyCall triggerCall,
    required SendEmergencySms sendSms,
    required TtsService tts,
  })  : _getContacts = getContacts,
        _addContact = addContact,
        _deleteContact = deleteContact,
        _triggerCall = triggerCall,
        _sendSms = sendSms,
        _tts = tts,
        super(const EmergencyState());

  Future<void> loadContacts() async {
    emit(state.copyWith(status: EmergencyStatus.loading));
    final result = await _getContacts();
    result.fold(
      (failure) => emit(state.copyWith(
        status: EmergencyStatus.idle,
        errorMessage: failure.message,
      )),
      (contacts) => emit(state.copyWith(
        status: EmergencyStatus.idle,
        contacts: contacts,
      )),
    );
  }

  Future<void> triggerEmergency(String senderName) async {
    if (state.contacts.isEmpty) return;

    emit(state.copyWith(
      isTriggered: true,
      countdownSeconds: 30,
      currentContactIndex: 0,
      status: EmergencyStatus.calling,
    ));

    await _tts.setLanguage('ar-SA');
    await _tts.speak('جاري الاتصال طلباً للمساعدة');

    _startCountdown();
    _startContactIteration(senderName);
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.countdownSeconds <= 0) {
        timer.cancel();
        return;
      }
      emit(state.copyWith(countdownSeconds: state.countdownSeconds - 1));
    });
  }

  void _startContactIteration(String senderName) async {
    for (int i = 0; i < state.contacts.length; i++) {
      if (state.status == EmergencyStatus.cancelled) return;

      emit(state.copyWith(currentContactIndex: i, status: EmergencyStatus.calling));
      await _triggerCall(state.contacts[i].phone);
      await Future.delayed(const Duration(seconds: 3));

      if (state.status == EmergencyStatus.cancelled) return;

      emit(state.copyWith(status: EmergencyStatus.smsSent));
      await _sendSms(
        phoneNumber: state.contacts[i].phone,
        senderName: senderName,
      );
      await Future.delayed(const Duration(seconds: 2));
    }

    if (state.status != EmergencyStatus.cancelled) {
      emit(state.copyWith(status: EmergencyStatus.completed));
    }
  }

  void cancelEmergency() {
    _countdownTimer?.cancel();
    _contactTimer?.cancel();
    _tts.stop();
    emit(state.copyWith(
      isTriggered: false,
      status: EmergencyStatus.cancelled,
    ));
  }

  Future<void> addContact(EmergencyContact contact) async {
    final result = await _addContact(contact);
    result.fold(
      (failure) => emit(state.copyWith(errorMessage: failure.message)),
      (saved) => emit(state.copyWith(contacts: [...state.contacts, saved])),
    );
  }

  /// Directly call a single contact without triggering the full emergency flow.
  Future<void> callContact(String phone) async {
    await _triggerCall(phone);
  }

  Future<void> removeContact(String id) async {
    final result = await _deleteContact(id);
    result.fold(
      (failure) => emit(state.copyWith(errorMessage: failure.message)),
      (_) => emit(state.copyWith(
        contacts: state.contacts.where((c) => c.id != id).toList(),
      )),
    );
  }

  @override
  Future<void> close() {
    _countdownTimer?.cancel();
    _contactTimer?.cancel();
    return super.close();
  }
}
