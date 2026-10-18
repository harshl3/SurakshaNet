class AppConstants {
  static const String appName = 'Police CCTV Mapping';
  static const String appSubtitle = 'Surveillance & Investigation System';

  // Storage Keys
  static const String keyAccessToken = 'auth_access_token';
  static const String keyRefreshToken = 'auth_refresh_token';
  static const String keyUserData = 'auth_user_data';
  static const String keySavedBaseUrl = 'config_base_url';
  static const String keySelectedEnv = 'config_selected_env';

  // Tile URL CartoDB Voyager (matches web app, no key required)
  static const String cartoDbVoyagerTileUrl =
      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';
  static const List<String> cartoDbSubdomains = ['a', 'b', 'c', 'd'];

  // Default Geospatial Center (Nagpur, Maharashtra, India - central police jurisdiction)
  static const double defaultLatitude = 21.1458;
  static const double defaultLongitude = 79.0882;
  static const double defaultZoom = 13.0;
}
