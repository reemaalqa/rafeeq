import 'package:equatable/equatable.dart';
import '../../domain/entities/auth_user.dart';

/// Exhaustive set of states the auth flow can be in.
enum AuthStatus {
  /// Default state before any action is taken.
  initial,

  /// An async operation is in progress.
  loading,

  /// A verification code has been dispatched to the user's email.
  codeSent,

  /// The user has been successfully authenticated.
  authenticated,

  /// No valid session exists.
  unauthenticated,

  /// An operation failed; see [AuthState.errorMessage] for details.
  error,
}

/// Immutable state object for [AuthCubit].
class AuthState extends Equatable {
  final AuthStatus status;
  final String? email;
  final String? errorMessage;
  final AuthUser? user;

  const AuthState({
    this.status = AuthStatus.initial,
    this.email,
    this.errorMessage,
    this.user,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? email,
    String? errorMessage,
    AuthUser? user,
  }) {
    return AuthState(
      status: status ?? this.status,
      email: email ?? this.email,
      errorMessage: errorMessage ?? this.errorMessage,
      user: user ?? this.user,
    );
  }

  @override
  List<Object?> get props => [status, email, errorMessage, user];
}
