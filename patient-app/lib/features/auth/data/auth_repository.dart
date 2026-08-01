import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import 'user_model.dart';

class AuthRepository {
  AuthRepository(this._api, this._tokenStorage);

  final ApiClient _api;
  final TokenStorage _tokenStorage;

  Future<int> sendOtp(String phone) async {
    final data = await _api.post<Map<String, dynamic>>(
      ApiRoutes.sendOtp,
      body: {'phone': phone, 'countryCode': '+91'},
      skipAuth: true,
    );
    return data['expiresIn'] as int? ?? 300;
  }

  Future<UserModel> verifyOtp({
    required String phone,
    required String otp,
    String? fcmToken,
  }) async {
    final data = await _api.post<Map<String, dynamic>>(
      ApiRoutes.verifyOtp,
      body: {
        'phone': phone,
        'otp': otp,
        if (fcmToken != null) 'fcmToken': fcmToken,
      },
      skipAuth: true,
    );

    return _persistSession(data);
  }

  /// Runs the Google flow, exchanges the Google credential for a Firebase ID
  /// token, then hands that token to our API which verifies it server-side.
  Future<UserModel> signInWithGoogle({String? fcmToken}) async {
    final GoogleSignIn googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

    // Signing out first forces the account chooser instead of silently
    // reusing the last account, which users find confusing.
    await googleSignIn.signOut();

    final GoogleSignInAccount? account = await googleSignIn.signIn();
    if (account == null) {
      throw ApiException('Google sign-in was cancelled');
    }

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

    return _socialLogin(idToken, fcmToken);
  }

  Future<UserModel> signInWithApple({String? fcmToken}) async {
    final AuthorizationCredentialAppleID appleCredential =
        await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    final fb.UserCredential credential =
        await fb.FirebaseAuth.instance.signInWithCredential(
      fb.OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      ),
    );

    final String? idToken = await credential.user?.getIdToken();
    if (idToken == null) throw ApiException('Could not obtain an Apple token');

    return _socialLogin(idToken, fcmToken);
  }

  Future<UserModel> _socialLogin(String idToken, String? fcmToken) async {
    final data = await _api.post<Map<String, dynamic>>(
      ApiRoutes.socialLogin,
      body: {
        'idToken': idToken,
        'role': 'PATIENT',
        if (fcmToken != null) 'fcmToken': fcmToken,
      },
      skipAuth: true,
    );

    return _persistSession(data);
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

  Future<UserModel> fetchCurrentUser() async {
    final data = await _api.get<Map<String, dynamic>>(ApiRoutes.me);
    return UserModel.fromJson(data);
  }

  Future<void> registerFcmToken(String token) =>
      _api.post(ApiRoutes.fcmToken, body: {'token': token});

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

  Future<UserModel> _persistSession(Map<String, dynamic> data) async {
    await _tokenStorage.saveTokens(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );

    return UserModel.fromJson(data['user'] as Map<String, dynamic>);
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(tokenStorageProvider),
  );
});
