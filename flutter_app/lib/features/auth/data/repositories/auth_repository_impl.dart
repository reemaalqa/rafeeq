import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remote;
  final AuthLocalDatasource _local;
  final FlutterSecureStorage _storage;
  final FirebaseAuth _auth;

  AuthRepositoryImpl({
    required AuthRemoteDataSource remote,
    required AuthLocalDatasource local,
    required FlutterSecureStorage storage,
    FirebaseAuth? auth,
  })  : _remote = remote,
        _local = local,
        _storage = storage,
        _auth = auth ?? FirebaseAuth.instance;

  @override
  Future<Either<Failure, void>> sendVerificationCode(String email) async {
    try {
      await _remote.sendCode(email);
      return const Right(null);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (_) {
      return const Left(ServerFailure('Failed to send verification code'));
    }
  }

  @override
  Future<Either<Failure, AuthUser>> verifyOtp(String email, String code) async {
    try {
      final user = await _remote.verifyOtp(email, code);
      await _local.setLoggedIn(true);
      return Right(user);
    } on AuthenticationException catch (e) {
      return Left(AuthenticationFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (_) {
      return const Left(AuthenticationFailure('OTP verification failed'));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      await _remote.logout('');
    } catch (_) {}
    try {
      await _local.clearToken();
      await _local.setLoggedIn(false);
      await _storage.delete(key: StorageKeys.accessToken);
      await _storage.delete(key: StorageKeys.refreshToken);
      await _storage.delete(key: StorageKeys.authToken);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, bool>> isLoggedIn() async {
    try {
      return Right(_auth.currentUser != null);
    } catch (_) {
      return const Right(false);
    }
  }
}
