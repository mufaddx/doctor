import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';

/// The signed-in therapist, including the fields the dashboard header needs.
class TherapistUser {
  const TherapistUser({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.role,
    this.email,
    this.avatarUrl,
    this.therapistId,
    this.specialization = const [],
    this.experienceYears = 0,
    this.bio,
    this.clinicFee = 0,
    this.homeVisitFee = 0,
    this.videoFee = 0,
    this.ratingAvg = 0,
    this.ratingCount = 0,
    this.kycStatus = 'NOT_SUBMITTED',
    this.isAvailable = true,
    this.clinicAddress,
    this.walletBalance = 0,
  });

  final String id;
  final String fullName;
  final String phone;
  final String role;
  final String? email;
  final String? avatarUrl;

  final String? therapistId;
  final List<String> specialization;
  final int experienceYears;
  final String? bio;
  final double clinicFee;
  final double homeVisitFee;
  final double videoFee;
  final double ratingAvg;
  final int ratingCount;
  final String kycStatus;
  final bool isAvailable;
  final String? clinicAddress;
  final double walletBalance;

  bool get isVerified => kycStatus == 'APPROVED';

  factory TherapistUser.fromJson(Map<String, dynamic> json) {
    final therapist = json['therapist'] as Map<String, dynamic>?;
    final wallet = json['wallet'] as Map<String, dynamic>?;

    return TherapistUser(
      id: json['id'] as String,
      fullName: json['fullName'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      role: json['role'] as String? ?? 'THERAPIST',
      email: json['email'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      therapistId: therapist?['id'] as String?,
      specialization: (therapist?['specialization'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      experienceYears: therapist?['experienceYears'] as int? ?? 0,
      bio: therapist?['bio'] as String?,
      // Decimals arrive as strings to preserve precision
      clinicFee: double.tryParse('${therapist?['clinicFee'] ?? 0}') ?? 0,
      homeVisitFee: double.tryParse('${therapist?['homeVisitFee'] ?? 0}') ?? 0,
      videoFee: double.tryParse('${therapist?['videoFee'] ?? 0}') ?? 0,
      ratingAvg: (therapist?['ratingAvg'] as num?)?.toDouble() ?? 0,
      ratingCount: therapist?['ratingCount'] as int? ?? 0,
      kycStatus: therapist?['kycStatus'] as String? ?? 'NOT_SUBMITTED',
      isAvailable: therapist?['isAvailable'] as bool? ?? true,
      clinicAddress: therapist?['clinicAddress'] as String?,
      walletBalance: double.tryParse('${wallet?['balance'] ?? 0}') ?? 0,
    );
  }
}

class AuthRepository {
  AuthRepository(this._api, this._tokenStorage);

  final ApiClient _api;
  final TokenStorage _tokenStorage;

  Future<TherapistUser> login({
    required String phone,
    required String password,
    String? fcmToken,
  }) async {
    final data = await _api.post<Map<String, dynamic>>(
      ApiRoutes.login,
      body: {
        'phone': phone,
        'password': password,
        if (fcmToken != null) 'fcmToken': fcmToken,
      },
      skipAuth: true,
    );

    await _tokenStorage.saveTokens(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );

    // The login payload is thin, so the full profile is fetched immediately
    return fetchCurrentUser();
  }

  Future<TherapistUser> signInWithGoogle() async {
    final GoogleSignIn googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
    await googleSignIn.signOut();

    final GoogleSignInAccount? account = await googleSignIn.signIn();
    if (account == null) throw ApiException('Google sign-in was cancelled');

    final GoogleSignInAuthentication auth = await account.authentication;

    final fb.UserCredential credential =
        await fb.FirebaseAuth.instance.signInWithCredential(
      fb.GoogleAuthProvider.credential(
        idToken: auth.idToken,
        accessToken: auth.accessToken,
      ),
    );

    final String? idToken = await credential.user?.getIdToken();
    if (idToken == null) throw ApiException('Could not obtain a Google token');

    final data = await _api.post<Map<String, dynamic>>(
      ApiRoutes.socialLogin,
      body: {'idToken': idToken, 'role': 'THERAPIST'},
      skipAuth: true,
    );

    await _tokenStorage.saveTokens(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );

    return fetchCurrentUser();
  }

  Future<TherapistUser> fetchCurrentUser() async {
    final data = await _api.get<Map<String, dynamic>>(ApiRoutes.me);
    return TherapistUser.fromJson(data);
  }

  Future<void> forgotPassword(String phone) => _api.post(
        ApiRoutes.forgotPassword,
        body: {'phone': phone},
        skipAuth: true,
      );

  Future<void> resetPassword({
    required String phone,
    required String otp,
    required String newPassword,
  }) =>
      _api.post(
        ApiRoutes.resetPassword,
        body: {'phone': phone, 'otp': otp, 'newPassword': newPassword},
        skipAuth: true,
      );

  Future<void> registerFcmToken(String token) =>
      _api.post(ApiRoutes.fcmToken, body: {'token': token});

  /// Flips the "accepting new bookings" switch on the dashboard.
  Future<bool> toggleAvailability(bool isAvailable) async {
    final data = await _api.patch<Map<String, dynamic>>(
      ApiRoutes.availabilityToggle,
      body: {'isAvailable': isAvailable},
    );

    return data['isAvailable'] as bool? ?? isAvailable;
  }

  Future<void> logout() async {
    final String? refreshToken = await _tokenStorage.readRefreshToken();

    try {
      await _api.post(
        ApiRoutes.logout,
        body: {if (refreshToken != null) 'refreshToken': refreshToken},
      );
    } catch (_) {
      // A failed server call must not trap the user in a signed-in state
    }

    await Future.wait([
      _tokenStorage.clear(),
      fb.FirebaseAuth.instance.signOut(),
      GoogleSignIn().signOut(),
    ]);
  }

  Future<bool> hasSession() => _tokenStorage.hasSession();
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(tokenStorageProvider),
  );
});

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.isSubmitting = false,
    this.errorMessage,
  });

  final AuthStatus status;
  final TherapistUser? user;
  final bool isSubmitting;
  final String? errorMessage;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  AuthState copyWith({
    AuthStatus? status,
    TherapistUser? user,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
    bool clearUser = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repository, this._apiClient) : super(const AuthState()) {
    _apiClient.onSessionExpired = () {
      state = const AuthState(status: AuthStatus.unauthenticated);
    };
    _restoreSession();
  }

  final AuthRepository _repository;
  final ApiClient _apiClient;

  Future<void> _restoreSession() async {
    if (!await _repository.hasSession()) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return;
    }

    try {
      final user = await _repository.fetchCurrentUser();
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
      await _syncFcmToken();
    } catch (_) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        clearUser: true,
      );
    }
  }

  Future<bool> login(String phone, String password) async {
    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      final String? fcmToken = await _readFcmToken();
      final user = await _repository.login(
        phone: phone,
        password: password,
        fcmToken: fcmToken,
      );

      // A patient account must never reach the therapist dashboard
      if (user.role != 'THERAPIST') {
        await _repository.logout();
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: 'This account is not registered as a therapist.',
        );
        return false;
      }

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

  Future<bool> signInWithGoogle() async {
    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      final user = await _repository.signInWithGoogle();

      if (user.role != 'THERAPIST') {
        await _repository.logout();
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: 'This account is not registered as a therapist.',
        );
        return false;
      }

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
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Sign-in could not be completed. Please try again.',
      );
      return false;
    }
  }

  /// Optimistically flips the switch, reverting if the server rejects it.
  Future<void> setAvailability(bool isAvailable) async {
    final TherapistUser? current = state.user;
    if (current == null) return;

    state = state.copyWith(user: _copyAvailability(current, isAvailable));

    try {
      final bool confirmed = await _repository.toggleAvailability(isAvailable);
      state = state.copyWith(user: _copyAvailability(current, confirmed));
    } on ApiException catch (error) {
      state = state.copyWith(
        user: _copyAvailability(current, current.isAvailable),
        errorMessage: error.message,
      );
    }
  }

  Future<void> refreshUser() async {
    if (!state.isAuthenticated) return;

    try {
      final user = await _repository.fetchCurrentUser();
      state = state.copyWith(user: user);
    } on ApiException {
      // Keep the cached profile rather than blanking the dashboard
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void clearError() => state = state.copyWith(clearError: true);

  TherapistUser _copyAvailability(TherapistUser user, bool isAvailable) {
    return TherapistUser(
      id: user.id,
      fullName: user.fullName,
      phone: user.phone,
      role: user.role,
      email: user.email,
      avatarUrl: user.avatarUrl,
      therapistId: user.therapistId,
      specialization: user.specialization,
      experienceYears: user.experienceYears,
      bio: user.bio,
      clinicFee: user.clinicFee,
      homeVisitFee: user.homeVisitFee,
      videoFee: user.videoFee,
      ratingAvg: user.ratingAvg,
      ratingCount: user.ratingCount,
      kycStatus: user.kycStatus,
      isAvailable: isAvailable,
      clinicAddress: user.clinicAddress,
      walletBalance: user.walletBalance,
    );
  }

  Future<String?> _readFcmToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  Future<void> _syncFcmToken() async {
    final String? token = await _readFcmToken();
    if (token == null) return;

    try {
      await _repository.registerFcmToken(token);
    } on ApiException {
      // Push is optional; the dashboard still works without it
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.watch(authRepositoryProvider),
    ref.watch(apiClientProvider),
  );
});

final currentTherapistProvider = Provider<TherapistUser?>((ref) {
  return ref.watch(authProvider.select((state) => state.user));
});
