import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/check_auth_status.dart';
import '../../domain/usecases/logout_use_case.dart';
import '../../domain/usecases/send_verification_code.dart';
import '../../domain/usecases/verify_otp.dart';
import 'auth_state.dart';

/// Manages authentication flow: check status, send code, verify OTP, logout.
class AuthCubit extends Cubit<AuthState> {
  final SendVerificationCode _sendCode;
  final VerifyOtp _verifyOtp;
  final LogoutUseCase _logout;
  final CheckAuthStatus _checkAuth;

  AuthCubit({
    required SendVerificationCode sendCode,
    required VerifyOtp verifyOtp,
    required LogoutUseCase logout,
    required CheckAuthStatus checkAuth,
  })  : _sendCode = sendCode,
        _verifyOtp = verifyOtp,
        _logout = logout,
        _checkAuth = checkAuth,
        super(const AuthState());

  /// Checks stored session state and emits [authenticated] or [unauthenticated].
  Future<void> checkAuthStatus() async {
    final result = await _checkAuth();
    result.fold(
      (failure) => emit(state.copyWith(status: AuthStatus.unauthenticated)),
      (isLoggedIn) => emit(
        state.copyWith(
          status: isLoggedIn ? AuthStatus.authenticated : AuthStatus.unauthenticated,
        ),
      ),
    );
  }

  /// Dispatches a verification code to [email].
  /// Emits [loading] → [codeSent] or [error].
  Future<void> sendVerificationCode(String email) async {
    emit(state.copyWith(status: AuthStatus.loading));
    final result = await _sendCode(email);
    result.fold(
      (failure) => emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: failure.message,
      )),
      (_) => emit(state.copyWith(
        status: AuthStatus.codeSent,
        email: email,
      )),
    );
  }

  /// Verifies [code] entered by the user for [email].
  /// Emits [loading] → [authenticated] or [error].
  Future<void> verifyOtp(String email, String code) async {
    emit(state.copyWith(status: AuthStatus.loading));
    final result = await _verifyOtp(email, code);
    result.fold(
      (failure) => emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: failure.message,
      )),
      (user) => emit(state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
      )),
    );
  }

  /// Clears the session and emits [unauthenticated].
  Future<void> logout() async {
    await _logout();
    emit(state.copyWith(status: AuthStatus.unauthenticated));
  }
}
