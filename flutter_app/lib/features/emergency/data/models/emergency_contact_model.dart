import 'dart:convert';
import '../../domain/entities/emergency_contact.dart';

class EmergencyContactModel extends EmergencyContact {
  const EmergencyContactModel({
    required super.id,
    required super.name,
    required super.phone,
    required super.relationship,
  });

  factory EmergencyContactModel.fromEntity(EmergencyContact entity) {
    return EmergencyContactModel(
      id: entity.id,
      name: entity.name,
      phone: entity.phone,
      relationship: entity.relationship,
    );
  }

  factory EmergencyContactModel.fromJson(Map<String, dynamic> json) {
    return EmergencyContactModel(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      relationship: json['relationship'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'relationship': relationship,
      };

  static List<EmergencyContactModel> listFromJsonString(String jsonString) {
    final List<dynamic> decoded = json.decode(jsonString) as List<dynamic>;
    return decoded
        .map((e) => EmergencyContactModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static String listToJsonString(List<EmergencyContactModel> contacts) {
    return json.encode(contacts.map((c) => c.toJson()).toList());
  }
}
