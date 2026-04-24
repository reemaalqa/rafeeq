import 'package:equatable/equatable.dart';

enum ReminderType { medication, prayer, appointment, hydration, custom }
enum RepeatInterval { none, daily, weekly }

class Reminder extends Equatable {
  final String id;
  final String title;
  final String description;
  final DateTime scheduledTime;
  final ReminderType type;
  final bool isActive;
  final int snoozeDurationMinutes;
  final RepeatInterval repeat;

  const Reminder({
    required this.id,
    required this.title,
    this.description = '',
    required this.scheduledTime,
    required this.type,
    this.isActive = true,
    this.snoozeDurationMinutes = 10,
    this.repeat = RepeatInterval.none,
  });

  Reminder copyWith({
    String? id, String? title, String? description,
    DateTime? scheduledTime, ReminderType? type,
    bool? isActive, int? snoozeDurationMinutes, RepeatInterval? repeat,
  }) {
    return Reminder(
      id: id ?? this.id, title: title ?? this.title,
      description: description ?? this.description,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      type: type ?? this.type, isActive: isActive ?? this.isActive,
      snoozeDurationMinutes: snoozeDurationMinutes ?? this.snoozeDurationMinutes,
      repeat: repeat ?? this.repeat,
    );
  }

  @override
  List<Object?> get props => [id, title, description, scheduledTime, type, isActive, snoozeDurationMinutes, repeat];
}
