import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../constants/app_config.dart';
import '../storage/token_storage.dart';

/// Thrown for any non-2xx response so the UI layer never has to inspect
/// raw Dio errors. [message] is already user-presentable.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.errors});

  final String message;
  final int? statusCode;
  final List<String>? errors;

  bool get isUnauthorized => statusCode == 401;
  bool get isNetworkError => statusCode == null;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient(this._tokenStorage) {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 60),
        headers: {'Content-Type': 'application/json'},
        // Let the interceptor decide what counts as an error
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onResponse: _onResponse,
        onError: _onError,
      ),
    );

    if (kDebugMode) {
      _dio.interceptors.add(
        PrettyDioLogger(requestBody: true, responseBody: true, error: true),
      );
    }
  }

  late final Dio _dio;
  final TokenStorage _tokenStorage;

  /// Guards the refresh call so a burst of 401s triggers exactly one refresh.
  Completer<String?>? _refreshCompleter;

  /// Invoked when the refresh token itself is rejected, so the app can log out.
  VoidCallback? onSessionExpired;

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final bool skipAuth = options.extra['skipAuth'] == true;

    if (!skipAuth) {
      final String? token = await _tokenStorage.readAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }

    handler.next(options);
  }

  Future<void> _onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    final int status = response.statusCode ?? 0;

    if (status >= 200 && status < 300) {
      handler.next(response);
      return;
    }

    // A 401 on a normal call means the access token expired; try to refresh
    // once and replay the original request transparently.
    if (status == 401 && response.requestOptions.extra['isRetry'] != true) {
      final String? newToken = await _refreshAccessToken();

      if (newToken != null) {
        final RequestOptions retryOptions = response.requestOptions
          ..headers['Authorization'] = 'Bearer $newToken'
          ..extra['isRetry'] = true;

        try {
          final Response retried = await _dio.fetch(retryOptions);
          handler.resolve(retried);
          return;
        } on DioException catch (error) {
          handler.reject(error);
          return;
        }
      }

      onSessionExpired?.call();
    }

    handler.reject(
      DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      ),
    );
  }

  void _onError(DioException error, ErrorInterceptorHandler handler) {
    handler.reject(error);
  }

  /// Exchanges the stored refresh token for a fresh pair. Concurrent callers
  /// all await the same in-flight request.
  Future<String?> _refreshAccessToken() async {
    if (_refreshCompleter != null) return _refreshCompleter!.future;

    final Completer<String?> completer = Completer<String?>();
    _refreshCompleter = completer;

    try {
      final String? refreshToken = await _tokenStorage.readRefreshToken();

      if (refreshToken == null) {
        completer.complete(null);
        return null;
      }

      // A bare Dio instance avoids re-entering this interceptor chain
      final Response response = await Dio(
        BaseOptions(baseUrl: AppConfig.apiBaseUrl),
      ).post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );

      final Map<String, dynamic> data =
          response.data!['data'] as Map<String, dynamic>;

      await _tokenStorage.saveTokens(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      );

      completer.complete(data['accessToken'] as String);
      return data['accessToken'] as String;
    } catch (_) {
      await _tokenStorage.clear();
      completer.complete(null);
      return null;
    } finally {
      _refreshCompleter = null;
    }
  }

  // -------------------------------------------------------
  // VERBS
  // -------------------------------------------------------

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    bool skipAuth = false,
  }) =>
      _request<T>(
        () => _dio.get<Map<String, dynamic>>(
          path,
          queryParameters: query,
          options: Options(extra: {'skipAuth': skipAuth}),
        ),
      );

  Future<T> post<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    bool skipAuth = false,
  }) =>
      _request<T>(
        () => _dio.post<Map<String, dynamic>>(
          path,
          data: body,
          queryParameters: query,
          options: Options(extra: {'skipAuth': skipAuth}),
        ),
      );

  Future<T> patch<T>(String path, {Object? body}) => _request<T>(
        () => _dio.patch<Map<String, dynamic>>(path, data: body),
      );

  Future<T> put<T>(String path, {Object? body}) => _request<T>(
        () => _dio.put<Map<String, dynamic>>(path, data: body),
      );

  Future<T> delete<T>(String path, {Object? body}) => _request<T>(
        () => _dio.delete<Map<String, dynamic>>(path, data: body),
      );

  /// Multipart upload used for avatars, certificates and chat attachments.
  Future<T> upload<T>(
    String path, {
    required String filePath,
    String field = 'file',
    Map<String, dynamic>? fields,
  }) =>
      _request<T>(() async {
        final FormData formData = FormData.fromMap({
          ...?fields,
          field: await MultipartFile.fromFile(filePath),
        });

        return _dio.post<Map<String, dynamic>>(path, data: formData);
      });

  /// Unwraps the `{ success, data }` envelope the API returns and converts
  /// any failure into an [ApiException].
  Future<T> _request<T>(
    Future<Response<Map<String, dynamic>>> Function() send,
  ) async {
    try {
      final Response<Map<String, dynamic>> response = await send();
      return response.data?['data'] as T;
    } on DioException catch (error) {
      throw _toApiException(error);
    }
  }

  ApiException _toApiException(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return ApiException('The connection timed out. Please try again.');
    }

    if (error.type == DioExceptionType.connectionError) {
      return ApiException('No internet connection. Check your network.');
    }

    final dynamic payload = error.response?.data;

    if (payload is Map<String, dynamic>) {
      final dynamic message = payload['message'];

      // class-validator returns an array of field-level messages
      if (message is List) {
        return ApiException(
          message.first.toString(),
          statusCode: error.response?.statusCode,
          errors: message.map((e) => e.toString()).toList(),
        );
      }

      if (message is String) {
        return ApiException(message, statusCode: error.response?.statusCode);
      }
    }

    return ApiException(
      'Something went wrong. Please try again.',
      statusCode: error.response?.statusCode,
    );
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(tokenStorageProvider));
});
