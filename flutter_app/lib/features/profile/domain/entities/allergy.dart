import 'package:equatable/equatable.dart';

enum AllergySeverity { mild, moderate, severe }

class Allergy extends Equatable {
  final String name;
  final AllergySeverity severity;
  final String notes;

  const Allergy({
    required this.name,
    this.severity = AllergySeverity.mild,
    this.notes = '',
  });

  Allergy copyWith({String? name, AllergySeverity? severity, String? notes}) {
    return Allergy(
      name: name ?? this.name,
      severity: severity ?? this.severity,
      notes: notes ?? this.notes,
    );
  }

  @override
  List<Object?> get props => [name, severity, notes];
}
