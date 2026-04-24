import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/allergy.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/usecases/get_profile.dart';
import '../../domain/usecases/save_profile.dart';
import '../../../emergency/domain/entities/emergency_contact.dart';
import '../../../emergency/domain/usecases/add_emergency_contact.dart';
import '../../../emergency/domain/usecases/delete_emergency_contact.dart';
import 'profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  final GetProfile _getProfile;
  final SaveProfile _saveProfile;
  final AddEmergencyContact _addContact;
  final DeleteEmergencyContact _deleteContact;

  ProfileCubit({
    required GetProfile getProfile,
    required SaveProfile saveProfile,
    required AddEmergencyContact addContact,
    required DeleteEmergencyContact deleteContact,
  })  : _getProfile = getProfile,
        _saveProfile = saveProfile,
        _addContact = addContact,
        _deleteContact = deleteContact,
        super(const ProfileState());

  Future<void> loadProfile() async {
    emit(state.copyWith(status: ProfileStatus.loading));
    final result = await _getProfile();
    result.fold(
      (f) => emit(state.copyWith(status: ProfileStatus.error, errorMessage: f.message)),
      (profile) => emit(state.copyWith(
        status: ProfileStatus.loaded,
        profile: profile ?? UserProfile(id: const Uuid().v4(), name: '', age: ''),
      )),
    );
  }

  void updateName(String name) {
    final updated = (state.profile ?? UserProfile(id: const Uuid().v4(), name: '', age: '')).copyWith(name: name);
    emit(state.copyWith(profile: updated));
  }

  void updateAge(String age) {
    emit(state.copyWith(profile: state.profile?.copyWith(age: age)));
  }

  void updateSex(String sex) {
    emit(state.copyWith(profile: state.profile?.copyWith(sex: sex)));
  }

  void updateHeight(double? height) {
    emit(state.copyWith(profile: state.profile?.copyWith(heightCm: height)));
  }

  void updateWeight(double? weight) {
    emit(state.copyWith(profile: state.profile?.copyWith(weightKg: weight)));
  }

  void toggleAllergy(Allergy allergy) {
    final current = List<Allergy>.from(state.allergies);
    final index = current.indexWhere((a) => a.name == allergy.name);
    if (index >= 0) {
      current.removeAt(index);
    } else {
      current.add(allergy);
    }
    emit(state.copyWith(profile: state.profile?.copyWith(allergies: current)));
  }

  /// Persists to backend immediately (same source of truth as EmergencyCubit).
  Future<void> addEmergencyContact(EmergencyContact contact) async {
    final result = await _addContact(contact);
    result.fold(
      (failure) => emit(state.copyWith(
        status: ProfileStatus.error,
        errorMessage: failure.message,
      )),
      (saved) {
        final contacts = [...state.emergencyContacts, saved];
        emit(state.copyWith(profile: state.profile?.copyWith(emergencyContacts: contacts)));
      },
    );
  }

  /// Deletes from backend immediately.
  Future<void> removeEmergencyContact(String id) async {
    final result = await _deleteContact(id);
    result.fold(
      (failure) => emit(state.copyWith(
        status: ProfileStatus.error,
        errorMessage: failure.message,
      )),
      (_) {
        final contacts = state.emergencyContacts.where((c) => c.id != id).toList();
        emit(state.copyWith(profile: state.profile?.copyWith(emergencyContacts: contacts)));
      },
    );
  }

  void setStep(int step) => emit(state.copyWith(currentStep: step));

  Future<bool> saveProfile() async {
    if (state.profile == null) return false;
    emit(state.copyWith(status: ProfileStatus.saving));
    final result = await _saveProfile(state.profile!);
    return result.fold(
      (f) {
        emit(state.copyWith(status: ProfileStatus.error, errorMessage: f.message));
        return false;
      },
      (_) {
        emit(state.copyWith(status: ProfileStatus.saved));
        return true;
      },
    );
  }
}
