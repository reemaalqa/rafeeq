import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_local_datasource.dart';
import '../datasources/profile_remote_datasource.dart';
import '../models/user_profile_model.dart';
import '../../../emergency/domain/entities/emergency_contact.dart';
import '../../../emergency/data/datasources/emergency_local_datasource.dart';
import '../../../emergency/data/models/emergency_contact_model.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileLocalDatasource _local;
  final ProfileRemoteDataSource _remote;
  final EmergencyLocalDatasource _emergencyLocal;

  const ProfileRepositoryImpl(this._local, this._remote, this._emergencyLocal);

  UserProfile _fromMap(Map<String, dynamic> m) => UserProfile(
        id: m['user_id']?.toString() ?? m['id']?.toString() ?? '',
        name: m['full_name'] as String? ?? '',
        age: (m['age'] as int?)?.toString() ?? '',
        sex: m['sex'] as String? ?? 'male',
        heightCm: (m['height_cm'] as num?)?.toDouble(),
        weightKg: (m['weight_kg'] as num?)?.toDouble(),
      );

  Map<String, dynamic> _toMap(UserProfile p) => {
        'full_name': p.name,
        'age': int.tryParse(p.age) ?? 0,
        'sex': p.sex,
        if (p.heightCm != null) 'height_cm': p.heightCm,
        if (p.weightKg != null) 'weight_kg': p.weightKg,
      };

  @override
  Future<Either<Failure, UserProfile?>> getProfile() async {
    // Load local first so allergies are not lost
    UserProfile? cached;
    try { cached = await _local.getProfile(); } catch (_) {}

    try {
      final data = await _remote.getProfile();
      // Load contacts from backend
      List<EmergencyContact> contacts = cached?.emergencyContacts ?? [];
      try {
        final raw = await _remote.getEmergencyContacts();
        contacts = raw.map((c) => EmergencyContact(
          id: c['id'].toString(),
          name: c['contact_name'] as String? ?? '',
          phone: c['phone_number'] as String? ?? '',
          relationship: c['relationship_'] as String? ?? '',
        )).toList();
      } catch (_) {}

      final profile = _fromMap(data).copyWith(
        // Allergies live in local storage only (backend uses integer FK references)
        allergies: cached?.allergies ?? [],
        emergencyContacts: contacts,
      );
      await _local.saveProfile(UserProfileModel.fromEntity(profile));
      // Keep EmergencyLocalDatasource in sync so EmergencyPage works offline too
      try {
        await _emergencyLocal.saveEmergencyContacts(
          contacts.map(EmergencyContactModel.fromEntity).toList(),
        );
      } catch (_) {}
      return Right(profile);
    } on NetworkException {
      // offline — fall through
    } catch (_) {
      // fall through
    }
    // Local fallback
    return Right(cached);
  }

  @override
  Future<Either<Failure, void>> saveProfile(UserProfile profile) async {
    // Sync basic profile to backend
    try {
      await _remote.updateProfile(_toMap(profile));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException {
      // offline — proceed with local only
    } catch (_) {}

    // Emergency contacts are synced in real-time via AddEmergencyContact /
    // DeleteEmergencyContact use cases — no bulk sync needed here.

    // Always save locally (allergies and contacts both persisted here)
    try {
      await _local.saveProfile(UserProfileModel.fromEntity(profile));
      return const Right(null);
    } catch (_) {
      return const Left(CacheFailure('Failed to save profile'));
    }
  }
}
