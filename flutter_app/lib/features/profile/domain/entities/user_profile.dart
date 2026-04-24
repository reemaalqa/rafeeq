import 'package:equatable/equatable.dart';
import 'allergy.dart';
import '../../../emergency/domain/entities/emergency_contact.dart';

class UserProfile extends Equatable {
  final String id;
  final String name;
  final String age;
  final String sex;
  final double? heightCm;
  final double? weightKg;
  final List<Allergy> allergies;
  final List<EmergencyContact> emergencyContacts;
  final String preferredLanguage;
  final String voiceType;

  const UserProfile({
    required this.id,
    required this.name,
    required this.age,
    this.sex = 'male',
    this.heightCm,
    this.weightKg,
    this.allergies = const [],
    this.emergencyContacts = const [],
    this.preferredLanguage = 'ar',
    this.voiceType = 'female',
  });

  UserProfile copyWith({
    String? id, String? name, String? age, String? sex,
    double? heightCm, double? weightKg,
    List<Allergy>? allergies, List<EmergencyContact>? emergencyContacts,
    String? preferredLanguage, String? voiceType,
  }) {
    return UserProfile(
      id: id ?? this.id, name: name ?? this.name, age: age ?? this.age,
      sex: sex ?? this.sex, heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      allergies: allergies ?? this.allergies,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      voiceType: voiceType ?? this.voiceType,
    );
  }

  @override
  List<Object?> get props => [id, name, age, sex, heightCm, weightKg, allergies, emergencyContacts, preferredLanguage, voiceType];
}
