import 'package:dartz/dartz.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/emergency_contact.dart';
import '../../domain/repositories/emergency_repository.dart';
import '../datasources/emergency_local_datasource.dart';
import '../datasources/emergency_remote_datasource.dart';
import '../models/emergency_contact_model.dart';
import '../../../profile/data/datasources/profile_local_datasource.dart';

class EmergencyRepositoryImpl implements EmergencyRepository {
  final EmergencyLocalDatasource _local;
  final EmergencyRemoteDataSource _remote;
  final ProfileLocalDatasource _profileLocal;

  const EmergencyRepositoryImpl(this._local, this._remote, this._profileLocal);

  EmergencyContact _fromMap(Map<String, dynamic> m) => EmergencyContact(
        id: m['id'].toString(),
        name: m['contact_name'] as String,
        phone: m['phone_number'] as String,
        relationship: m['relationship_'] as String? ?? '',
      );

  @override
  Future<Either<Failure, List<EmergencyContact>>> getEmergencyContacts() async {
    // Remote first
    try {
      final data = await _remote.getContacts();
      final contacts = data.map(_fromMap).toList();
      await _local.saveEmergencyContacts(
        contacts.map(EmergencyContactModel.fromEntity).toList(),
      );
      return Right(contacts);
    } on NetworkException {
      // offline — fall through
    } catch (_) {
      // remote error — fall through
    }
    // Local fallback — emergency cache
    try {
      final cached = await _local.getEmergencyContacts();
      if (cached.isNotEmpty) return Right(cached);
    } catch (_) {}

    // Secondary fallback — extract contacts from profile cache
    try {
      final profile = await _profileLocal.getProfile();
      if (profile != null && profile.emergencyContacts.isNotEmpty) {
        final contacts = profile.emergencyContacts
            .map((c) => EmergencyContactModel.fromEntity(c))
            .toList();
        // Populate emergency cache so next access is direct
        await _local.saveEmergencyContacts(contacts);
        return Right(List<EmergencyContact>.from(contacts));
      }
    } catch (_) {}

    return const Right([]);
  }

  @override
  Future<Either<Failure, EmergencyContact>> addEmergencyContact(
    EmergencyContact contact,
  ) async {
    try {
      final result = await _remote.createContact({
        'contact_name': contact.name,
        'phone_number': contact.phone,
        if (contact.relationship.isNotEmpty) 'relationship_': contact.relationship,
        'priority': 1,
      });
      // Use backend-assigned integer id
      final saved = EmergencyContact(
        id: result['id'].toString(),
        name: result['contact_name'] as String,
        phone: result['phone_number'] as String,
        relationship: result['relationship_'] as String? ?? '',
      );
      // Update local cache
      final current = await _local.getEmergencyContacts();
      await _local.saveEmergencyContacts(
        [...current, EmergencyContactModel.fromEntity(saved)],
      );
      return Right(saved);
    } on NetworkException {
      // offline — save locally with temp id
      try {
        final current = await _local.getEmergencyContacts();
        await _local.saveEmergencyContacts(
          [...current, EmergencyContactModel.fromEntity(contact)],
        );
        return Right(contact);
      } catch (_) {
        return const Left(CacheFailure('Failed to save contact'));
      }
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteEmergencyContact(String id) async {
    try {
      await _remote.deleteContact(id);
    } catch (_) {
      // best-effort
    }
    // Always remove locally
    try {
      final current = await _local.getEmergencyContacts();
      final updated = current.where((c) => c.id != id).toList();
      await _local.saveEmergencyContacts(updated);
      return const Right(null);
    } catch (_) {
      return const Left(CacheFailure('Failed to delete contact'));
    }
  }

  @override
  Future<Either<Failure, void>> triggerCall(String phoneNumber) async {
    try {
      final uri = Uri.parse('tel:${phoneNumber.replaceAll(' ', '')}');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        try {
          await _remote.triggerEmergency({'notes': 'Voice call triggered'});
        } catch (_) {}
        return const Right(null);
      }
      return const Left(ServerFailure('Cannot launch phone dialer'));
    } catch (_) {
      return const Left(ServerFailure('Failed to initiate call'));
    }
  }

  @override
  Future<Either<Failure, void>> sendEmergencySms({
    required String phoneNumber,
    required String senderName,
  }) async {
    try {
      final body = Uri.encodeComponent(
        'SOS: $senderName needs urgent help! / طوارئ: $senderName بحاجة لمساعدة عاجلة!',
      );
      final uri =
          Uri.parse('sms:${phoneNumber.replaceAll(' ', '')}?body=$body');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        try {
          await _remote.triggerEmergency({
            'notes': 'SMS sent to $phoneNumber',
            'trigger_phrase': 'emergency_sms',
          });
        } catch (_) {}
        return const Right(null);
      }
      return const Left(ServerFailure('Cannot launch SMS'));
    } catch (_) {
      return const Left(ServerFailure('Failed to send SMS'));
    }
  }
}
