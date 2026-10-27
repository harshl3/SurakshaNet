import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

enum EnvironmentType {
  production,
  androidEmulator,
  localLan,
  custom,
}

class EnvConfig extends ChangeNotifier {
  static final EnvConfig _instance = EnvConfig._internal();
  factory EnvConfig() => _instance;
  EnvConfig._internal();

  static const String defaultProdUrl = 'https://cameramapping-api.onrender.com/api/v1';
  /// Android emulator maps host machine localhost to 10.0.2.2 (same as Vite → localhost:8088 on web).
  static const String defaultEmulatorUrl = 'http://10.0.2.2:8088/api/v1';
  static const String defaultIosSimulatorUrl = 'http://127.0.0.1:8088/api/v1';
  static const String defaultLocalLanUrl = 'http://192.168.1.5:8088/api/v1';

  /// Host-reachable Spring Boot URL for simulators/emulators during local development.
  static String get localDevBackendUrl {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return defaultIosSimulatorUrl;
    }
    return defaultEmulatorUrl;
  }

  EnvironmentType _currentEnv = EnvironmentType.production;
  String _customUrl = '';
  bool _initialized = false;

  EnvironmentType get currentEnv => _currentEnv;
  bool get isInitialized => _initialized;

  String get baseUrl {
    switch (_currentEnv) {
      case EnvironmentType.production:
        return defaultProdUrl;
      case EnvironmentType.androidEmulator:
        return localDevBackendUrl;
      case EnvironmentType.localLan:
        return _customUrl.isNotEmpty ? _customUrl : defaultLocalLanUrl;
      case EnvironmentType.custom:
        return _customUrl.isNotEmpty ? _customUrl : defaultProdUrl;
    }
  }

  String get envLabel {
    switch (_currentEnv) {
      case EnvironmentType.production:
        return 'Production Cloud';
      case EnvironmentType.androidEmulator:
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          return 'iOS Simulator (127.0.0.1)';
        }
        return 'Android Emulator (10.0.2.2)';
      case EnvironmentType.localLan:
        return 'Local Network (LAN)';
      case EnvironmentType.custom:
        return 'Custom Server';
    }
  }

  Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final envIndex = prefs.getInt(AppConstants.keySelectedEnv);
      if (envIndex != null && envIndex >= 0 && envIndex < EnvironmentType.values.length) {
        _currentEnv = EnvironmentType.values[envIndex];
      } else if (kDebugMode) {
        // Match local web dev: Vite proxies /api → http://localhost:8088 (see frontend/vite.config.js).
        _currentEnv = EnvironmentType.androidEmulator;
      }
      _customUrl = prefs.getString(AppConstants.keySavedBaseUrl) ?? '';
    } catch (e) {
      debugPrint('Failed to load saved environment: $e');
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> setEnvironment(EnvironmentType env, {String? customUrl}) async {
    _currentEnv = env;
    if (customUrl != null) {
      _customUrl = _sanitizeUrl(customUrl);
    }
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(AppConstants.keySelectedEnv, env.index);
      if (_customUrl.isNotEmpty) {
        await prefs.setString(AppConstants.keySavedBaseUrl, _customUrl);
      }
    } catch (e) {
      debugPrint('Failed to persist environment preference: $e');
    }
  }

  String _sanitizeUrl(String url) {
    var trimmed = url.trim();
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    if (!trimmed.endsWith('/api/v1')) {
      trimmed = '$trimmed/api/v1';
    }
    return trimmed;
  }

  /// Resolves relative media URLs like "/api/v1/media/filename.jpg" against active host
  String resolveMediaUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.isEmpty) return '';
    if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) {
      return rawUrl;
    }

    final activeBase = baseUrl;
    final uri = Uri.parse(activeBase);
    final origin = '${uri.scheme}://${uri.authority}';

    if (rawUrl.startsWith('/')) {
      return '$origin$rawUrl';
    }
    return '$origin/$rawUrl';
  }
}
