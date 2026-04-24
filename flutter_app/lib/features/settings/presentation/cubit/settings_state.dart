import 'package:equatable/equatable.dart';
import '../../domain/entities/app_settings.dart';

/// Lifecycle states for settings loading and persistence.
enum SettingsStatus {
  initial,
  loading,
  loaded,
  error,
}

/// Immutable state object for [SettingsCubit].
class SettingsState extends Equatable {
  final AppSettings? settings;
  final SettingsStatus status;

  const SettingsState({
    this.settings,
    this.status = SettingsStatus.initial,
  });

  SettingsState copyWith({
    AppSettings? settings,
    SettingsStatus? status,
  }) {
    return SettingsState(
      settings: settings ?? this.settings,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [settings, status];
}
