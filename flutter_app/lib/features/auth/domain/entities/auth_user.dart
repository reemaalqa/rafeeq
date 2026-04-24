import 'package:equatable/equatable.dart';

/// Domain entity representing an authenticated user.
/// Token is nullable to support unauthenticated/pending states.
class AuthUser extends Equatable {
  final String email;
  final String? token;

  const AuthUser({required this.email, this.token});

  @override
  List<Object?> get props => [email, token];
}
