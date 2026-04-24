import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/app_settings.dart';
import '../repositories/settings_repository.dart';

/// Use case: load all persisted application settings.
class GetSettings {
  final SettingsRepository repository;

  const GetSettings(this.repository);

  Future<Either<Failure, AppSettings>> call() {
    return repository.getSettings();
  }
}
