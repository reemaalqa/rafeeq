import 'dart:convert';
import '../../domain/entities/reminder.dart';

class ReminderModel extends Reminder {
  const ReminderModel({
    required super.id, required super.title, required super.description,
    required super.scheduledTime, required super.type, required super.isActive,
    required super.snoozeDurationMinutes, required super.repeat,
  });

  factory ReminderModel.fromEntity(Reminder r) => ReminderModel(
    id: r.id, title: r.title, description: r.description,
    scheduledTime: r.scheduledTime, type: r.type, isActive: r.isActive,
    snoozeDurationMinutes: r.snoozeDurationMinutes, repeat: r.repeat,
  );

  factory ReminderModel.fromJson(Map<String, dynamic> json) => ReminderModel(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String? ?? '',
    scheduledTime: DateTime.parse(json['scheduledTime'] as String),
    type: ReminderType.values.firstWhere((e) => e.name == json['type'], orElse: () => ReminderType.custom),
    isActive: json['isActive'] as bool? ?? true,
    snoozeDurationMinutes: json['snoozeDurationMinutes'] as int? ?? 10,
    repeat: RepeatInterval.values.firstWhere((e) => e.name == json['repeat'], orElse: () => RepeatInterval.none),
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'description': description,
    'scheduledTime': scheduledTime.toIso8601String(),
    'type': type.name, 'isActive': isActive,
    'snoozeDurationMinutes': snoozeDurationMinutes, 'repeat': repeat.name,
  };

  static List<ReminderModel> listFromJsonString(String s) {
    final list = json.decode(s) as List;
    return list.map((e) => ReminderModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  static String listToJsonString(List<ReminderModel> items) =>
      json.encode(items.map((e) => e.toJson()).toList());
}
