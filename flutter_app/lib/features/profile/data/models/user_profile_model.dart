import 'dart:convert';
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/allergy.dart';
import '../../../emergency/domain/entities/emergency_contact.dart';

class UserProfileModel extends UserProfile {
  const UserProfileModel({
    required super.id, required super.name, required super.age,
    required super.sex, super.heightCm, super.weightKg,
    required super.allergies, required super.emergencyContacts,
    required super.preferredLanguage, required super.voiceType,
  });

  factory UserProfileModel.fromEntity(UserProfile p) => UserProfileModel(
    id: p.id, name: p.name, age: p.age, sex: p.sex,
    heightCm: p.heightCm, weightKg: p.weightKg,
    allergies: p.allergies, emergencyContacts: p.emergencyContacts,
    preferredLanguage: p.preferredLanguage, voiceType: p.voiceType,
  );

  factory UserProfileModel.fromJson(Map<String, dynamic> json) => UserProfileModel(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    age: json['age'] as String? ?? '',
    sex: json['sex'] as String? ?? 'male',
    heightCm: (json['heightCm'] as num?)?.toDouble(),
    weightKg: (json['weightKg'] as num?)?.toDouble(),
    allergies: (json['allergies'] as List<dynamic>? ?? [])
        .map((e) => _allergyFromJson(e as Map<String, dynamic>))
        .toList(),
    emergencyContacts: (json['emergencyContacts'] as List<dynamic>? ?? [])
        .map((e) => _contactFromJson(e as Map<String, dynamic>))
        .toList(),
    preferredLanguage: json['preferredLanguage'] as String? ?? 'ar',
    voiceType: json['voiceType'] as String? ?? 'female',
  );

  static Allergy _allergyFromJson(Map<String, dynamic> j) => Allergy(
    name: j['name'] as String,
    severity: AllergySeverity.values.firstWhere(
      (e) => e.name == j['severity'], orElse: () => AllergySeverity.mild),
    notes: j['notes'] as String? ?? '',
  );

  static EmergencyContact _contactFromJson(Map<String, dynamic> j) => EmergencyContact(
    id: j['id'] as String,
    name: j['name'] as String,
    phone: j['phone'] as String,
    relationship: j['relationship'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'age': age, 'sex': sex,
    'heightCm': heightCm, 'weightKg': weightKg,
    'allergies': allergies.map((a) => {'name': a.name, 'severity': a.severity.name, 'notes': a.notes}).toList(),
    'emergencyContacts': emergencyContacts.map((c) => {'id': c.id, 'name': c.name, 'phone': c.phone, 'relationship': c.relationship}).toList(),
    'preferredLanguage': preferredLanguage,
    'voiceType': voiceType,
  };

  String toJsonString() => json.encode(toJson());
  static UserProfileModel fromJsonString(String s) => UserProfileModel.fromJson(json.decode(s) as Map<String, dynamic>);
}
