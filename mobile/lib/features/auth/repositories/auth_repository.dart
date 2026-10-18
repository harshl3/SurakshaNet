import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_response.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../models/user_model.dart';

class AuthRepository {
  final ApiClient _apiClient;
  final SecureStorageService _storage;

  AuthRepository({
    ApiClient? apiClient,
    SecureStorageService? storage,
  })  : _apiClient = apiClient ?? ApiClient(),
        _storage = storage ?? SecureStorageService();

  Future<UserModel> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.login,
        data: {
          'username': username.trim(),
          'password': password,
        },
      );

      final apiRes = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data as Map<String, dynamic>,
        (raw) => raw as Map<String, dynamic>,
      );

      if (!apiRes.success || apiRes.data == null) {
        throw ApiException(apiRes.message.isNotEmpty ? apiRes.message : 'Authentication failed');
      }

      final data = apiRes.data!;
      final accessToken = data['token'] as String? ?? '';
      final refreshToken = data['refreshToken'] as String? ?? '';
      final user = UserModel.fromJson(data);

      if (accessToken.isEmpty) {
        throw ApiException('Server returned an empty authentication token');
      }

      await _storage.saveSession(
        accessToken: accessToken,
        refreshToken: refreshToken,
        user: user,
      );

      return user;
    } catch (e) {
      debugPrint('Login error in AuthRepository: $e');
      rethrow;
    }
  }

  Future<UserModel?> restoreSession() async {
    try {
      final hasToken = await _storage.hasSession();
      if (!hasToken) return null;
      return await _storage.getUser();
    } catch (e) {
      debugPrint('Failed to restore session: $e');
      return null;
    }
  }

  Future<void> logout() async {
    await _storage.clearSession();
  }
}
