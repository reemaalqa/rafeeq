import 'package:equatable/equatable.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/allergy.dart';
import '../../../emergency/domain/entities/emergency_contact.dart';

enum ProfileStatus { initial, loading, loaded, saving, saved, error }

class ProfileState extends Equatable {
  final UserProfile? profile;
  final ProfileStatus status;
  final String? errorMessage;
  final int currentStep;

  const ProfileState({
    this.profile,
    this.status = ProfileStatus.initial,
    this.errorMessage,
    this.currentStep = 0,
  });

  // Convenience getters from mutable form fields during editing
  String get name => profile?.name ?? '';
  String get age => profile?.age ?? '';
  String get sex => profile?.sex ?? 'male';
  double? get heightCm => profile?.heightCm;
  double? get weightKg => profile?.weightKg;
  List<Allergy> get allergies => profile?.allergies ?? [];
  List<EmergencyContact> get emergencyContacts => profile?.emergencyContacts ?? [];

  ProfileState copyWith({
    UserProfile? profile,
    ProfileStatus? status,
    String? errorMessage,
    int? currentStep,
  }) {
    return ProfileState(
      profile: profile ?? this.profile,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      currentStep: currentStep ?? this.currentStep,
    );
  }

  @override
  List<Object?> get props => [profile, status, errorMessage, currentStep];
}
