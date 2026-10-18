import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';
import '../../features/auth/models/user_model.dart';

class SecureStorageService {
  static final SecureStorageService _instance = SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // In-memory fallback if native keystore fails
  final Map<String, String> _memoryCache = {};

  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required UserModel user,
  }) async {
    _memoryCache[AppConstants.keyAccessToken] = accessToken;
    _memoryCache[AppConstants.keyRefreshToken] = refreshToken;
    _memoryCache[AppConstants.keyUserData] = jsonEncode(user.toJson());

    try {
      await _storage.write(key: AppConstants.keyAccessToken, value: accessToken);
      await _storage.write(key: AppConstants.keyRefreshToken, value: refreshToken);
      await _storage.write(
        key: AppConstants.keyUserData,
        value: jsonEncode(user.toJson()),
      );
    } catch (e) {
      debugPrint('Warning: secure storage write failed, using cache: $e');
    }
  }

  Future<String?> getAccessToken() async {
    if (_memoryCache.containsKey(AppConstants.keyAccessToken)) {
      return _memoryCache[AppConstants.keyAccessToken];
    }
    try {
      final token = await _storage.read(key: AppConstants.keyAccessToken);
      if (token != null) _memoryCache[AppConstants.keyAccessToken] = token;
      return token;
    } catch (e) {
      debugPrint('Failed to read access token: $e');
      return null;
    }
  }

  Future<String?> getRefreshToken() async {
    if (_memoryCache.containsKey(AppConstants.keyRefreshToken)) {
      return _memoryCache[AppConstants.keyRefreshToken];
    }
    try {
      final token = await _storage.read(key: AppConstants.keyRefreshToken);
      if (token != null) _memoryCache[AppConstants.keyRefreshToken] = token;
      return token;
    } catch (e) {
      debugPrint('Failed to read refresh token: $e');
      return null;
    }
  }

  Future<UserModel?> getUser() async {
    if (_memoryCache.containsKey(AppConstants.keyUserData)) {
      try {
        final map = jsonDecode(_memoryCache[AppConstants.keyUserData]!);
        return UserModel.fromJson(map);
      } catch (_) {}
    }
    try {
      final raw = await _storage.read(key: AppConstants.keyUserData);
      if (raw != null) {
        _memoryCache[AppConstants.keyUserData] = raw;
        final map = jsonDecode(raw);
        return UserModel.fromJson(map);
      }
    } catch (e) {
      debugPrint('Failed to read user data: $e');
    }
    return null;
  }

  Future<void> clearSession() async {
    _memoryCache.clear();
    try {
      await _storage.delete(key: AppConstants.keyAccessToken);
      await _storage.delete(key: AppConstants.keyRefreshToken);
      await _storage.delete(key: AppConstants.keyUserData);
    } catch (e) {
      debugPrint('Failed to clear secure storage: $e');
    }
  }

  Future<bool> hasSession() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }
}
