import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/app_settings.dart';
import '../repositories/settings_repository.dart';

/// Use case: persist a full [AppSettings] snapshot.
class UpdateSettings {
  final SettingsRepository repository;

  const UpdateSettings(this.repository);

  Future<Either<Failure, void>> call(AppSettings settings) {
    return repository.saveSettings(settings);
  }
}
