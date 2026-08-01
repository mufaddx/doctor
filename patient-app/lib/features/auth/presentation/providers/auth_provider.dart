import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../data/auth_repository.dart';
import '../../data/user_model.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// Single source of truth for the session. The router listens to [status] to
/// decide whether a route is reachable.
class AuthState {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.isSubmitting = false,
    this.errorMessage,
    this.otpExpiresIn,
    this.pendingPhone,
  });

  final AuthStatus status;
  final UserModel? user;
  final bool isSubmitting;
  final String? errorMessage;
  final int? otpExpiresIn;
  final String? pendingPhone;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    bool? isSubmitting,
    String? errorMessage,
    int? otpExpiresIn,
    String? pendingPhone,
    bool clearError = false,
    bool clearUser = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      otpExpiresIn: otpExpiresIn ?? this.otpExpiresIn,
      pendingPhone: pendingPhone ?? this.pendingPhone,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repository, this._apiClient) : super(const AuthState()) {
    // A rejected refresh token means the session is truly gone
    _apiClient.onSessionExpired = _forceSignOut;
    _restoreSession();
  }

  final AuthRepository _repository;
  final ApiClient _apiClient;

  /// On cold start, a stored refresh token is optimistically trusted and the
  /// profile is fetched. A failure drops the user back to the login screen.
  Future<void> _restoreSession() async {
    if (!await _repository.hasSession()) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return;
    }

    try {
      final UserModel user = await _repository.fetchCurrentUser();
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
      await _syncFcmToken();
    } catch (_) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        clearUser: true,
      );
    }
  }

  Future<bool> sendOtp(String phone) async {
    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      final int expiresIn = await _repository.sendOtp(phone);
      state = state.copyWith(
        isSubmitting: false,
        otpExpiresIn: expiresIn,
        pendingPhone: phone,
      );
      return true;
    } on ApiException catch (error) {
      state = state.copyWith(isSubmitting: false, errorMessage: error.message);
      return false;
    }
  }

  Future<bool> verifyOtp(String otp) async {
    final String? phone = state.pendingPhone;
    if (phone == null) {
      state = state.copyWith(errorMessage: 'Please request an OTP first');
      return false;
    }

    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      final String? fcmToken = await _readFcmToken();

      final UserModel user = await _repository.verifyOtp(
        phone: phone,
        otp: otp,
        fcmToken: fcmToken,
      );

      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        isSubmitting: false,
      );
      return true;
    } on ApiException catch (error) {
      state = state.copyWith(isSubmitting: false, errorMessage: error.message);
      return false;
    }
  }

  Future<bool> signInWithGoogle() =>
      _runSocialSignIn(() => _repository.signInWithGoogle(
            fcmToken: null,
          ));

  Future<bool> signInWithApple() =>
      _runSocialSignIn(() => _repository.signInWithApple(fcmToken: null));

  Future<bool> _runSocialSignIn(Future<UserModel> Function() action) async {
    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      final UserModel user = await action();
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        isSubmitting: false,
      );
      await _syncFcmToken();
      return true;
    } on ApiException catch (error) {
      state = state.copyWith(isSubmitting: false, errorMessage: error.message);
      return false;
    } catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Sign-in could not be completed. Please try again.',
      );
      return false;
    }
  }

  /// Pulls a fresh profile after edits so every screen sees the new values.
  Future<void> refreshUser() async {
    if (!state.isAuthenticated) return;

    try {
      final UserModel user = await _repository.fetchCurrentUser();
      state = state.copyWith(user: user);
    } on ApiException {
      // Keep the cached profile rather than blanking the UI on a transient error
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void clearError() => state = state.copyWith(clearError: true);

  void _forceSignOut() {
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<String?> _readFcmToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      // Push is optional; login must still work without it
      return null;
    }
  }

  Future<void> _syncFcmToken() async {
    final String? token = await _readFcmToken();
    if (token == null) return;

    try {
      await _repository.registerFcmToken(token);
    } on ApiException {
      // Non-fatal
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.watch(authRepositoryProvider),
    ref.watch(apiClientProvider),
  );
});

/// Convenience selector so widgets rebuild only when the user object changes.
final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authProvider.select((state) => state.user));
});
