import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/env_config.dart';
import '../storage/secure_storage_service.dart';
import 'api_endpoints.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic errors;

  ApiException(this.message, {this.statusCode, this.errors});

  @override
  String toString() => message;
}

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 25),
        sendTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Always use active environment baseUrl
          options.baseUrl = EnvConfig().baseUrl;

          // Attach JWT token if not an unauthenticated endpoint
          final isAuthEndpoint = options.path.contains('/auth/login') ||
              options.path.contains('/auth/register') ||
              options.path.contains('/auth/refresh') ||
              options.path.contains('/health');

          if (!isAuthEndpoint) {
            final token = await SecureStorageService().getAccessToken();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          // Handle 401 token refresh
          if (error.response?.statusCode == 401) {
            final isAuthPath = error.requestOptions.path.contains('/auth/');
            if (!isAuthPath) {
              final refreshed = await _attemptTokenRefresh();
              if (refreshed) {
                // Retry original request with new token
                final newAccessToken = await SecureStorageService().getAccessToken();
                final retryOpts = Options(
                  method: error.requestOptions.method,
                  headers: {
                    ...error.requestOptions.headers,
                    'Authorization': 'Bearer $newAccessToken',
                  },
                );
                try {
                  final retryResponse = await _dio.request(
                    error.requestOptions.path,
                    data: error.requestOptions.data,
                    queryParameters: error.requestOptions.queryParameters,
                    options: retryOpts,
                  );
                  return handler.resolve(retryResponse);
                } catch (retryError) {
                  return handler.next(error);
                }
              } else {
                // Refresh failed; clear session
                await SecureStorageService().clearSession();
                onSessionExpired?.call();
              }
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  late final Dio _dio;
  Dio get dio => _dio;

  VoidCallback? onSessionExpired;

  bool _isRefreshing = false;
  Completer<bool>? _refreshCompleter;

  Future<bool> _attemptTokenRefresh() async {
    if (_isRefreshing) {
      return _refreshCompleter?.future ?? Future.value(false);
    }

    _isRefreshing = true;
    _refreshCompleter = Completer<bool>();

    try {
      final refreshToken = await SecureStorageService().getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        _isRefreshing = false;
        _refreshCompleter?.complete(false);
        return false;
      }

      final refreshDio = Dio(
        BaseOptions(
          baseUrl: EnvConfig().baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      final response = await refreshDio.post(
        ApiEndpoints.refresh,
        data: {'refreshToken': refreshToken},
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'] as Map<String, dynamic>?;
        final newAccessToken = data?['token'] as String?;
        final newRefreshToken = data?['refreshToken'] as String? ?? refreshToken;

        if (newAccessToken != null && newAccessToken.isNotEmpty) {
          final currentUser = await SecureStorageService().getUser();
          if (currentUser != null) {
            await SecureStorageService().saveSession(
              accessToken: newAccessToken,
              refreshToken: newRefreshToken,
              user: currentUser,
            );
          }
          _isRefreshing = false;
          _refreshCompleter?.complete(true);
          return true;
        }
      }
    } catch (e) {
      debugPrint('Token refresh failed: $e');
    }

    _isRefreshing = false;
    _refreshCompleter?.complete(false);
    return false;
  }

  // Generic Request Handlers with honest exception translation
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Response<dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Response<dynamic>> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Response<dynamic>> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.patch(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Response<dynamic>> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Wakes a sleeping Render instance before auth (production only; local backends skip this).
  Future<void> warmUpBackend({Duration? maxWait}) async {
    if (EnvConfig().currentEnv != EnvironmentType.production) {
      return;
    }
    final wait = maxWait ?? const Duration(seconds: 15);
    try {
      await _dio
          .get(
            ApiEndpoints.health,
            options: Options(
              connectTimeout: wait,
              receiveTimeout: wait,
              sendTimeout: wait,
            ),
          )
          .timeout(wait + const Duration(seconds: 1));
    } on DioException catch (e) {
      debugPrint('Backend warm-up probe: ${e.type} (${e.message})');
    } on TimeoutException catch (e) {
      debugPrint('Backend warm-up timed out: $e');
    }
  }

  // Test Server Health Probe
  Future<Map<String, dynamic>> checkHealth() async {
    try {
      final res = await _dio.get(ApiEndpoints.health);
      if (res.data is Map<String, dynamic>) {
        return res.data as Map<String, dynamic>;
      }
      return {'status': 'UP'};
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  ApiException _handleDioError(DioException error) {
    String message = 'Network connection failed. Please check your internet or server configuration.';
    int? code = error.response?.statusCode;
    dynamic errors;

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      message = 'Request timed out. The server took too long to respond.';
      if (EnvConfig().currentEnv == EnvironmentType.production) {
        message +=
            ' Render Cloud may be waking from sleep (retry in a moment). '
            'For local Spring Boot, switch to Android Emulator (${EnvConfig.defaultEmulatorUrl}) '
            '— same backend the website uses via localhost:8088.';
      } else if (EnvConfig().currentEnv == EnvironmentType.androidEmulator) {
        message +=
            ' Start the Spring Boot backend on your PC (port 8088), then retry. '
            'The website uses the same server through Vite\'s /api proxy.';
      }
    } else if (error.type == DioExceptionType.connectionError) {
      message = 'Unable to reach backend at ${EnvConfig().baseUrl}. Please ensure the server is running.';
      if (EnvConfig().currentEnv == EnvironmentType.androidEmulator) {
        message +=
            ' Run: cd backend && .\\mvnw.cmd spring-boot:run (Windows) or ./mvnw spring-boot:run, '
            'then use environment "${EnvConfig().envLabel}".';
      }
    } else if (error.response?.data != null) {
      final resData = error.response!.data;
      if (resData is Map<String, dynamic>) {
        if (resData['message'] != null) {
          message = resData['message'].toString();
        }
        errors = resData['errors'];
      }
    }

    return ApiException(message, statusCode: code, errors: errors);
  }
}
