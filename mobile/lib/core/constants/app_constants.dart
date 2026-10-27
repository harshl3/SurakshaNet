class AppConstants {
  static const String appName = 'Police CCTV Mapping';
  static const String appSubtitle = 'Surveillance & Investigation System';

  // Storage Keys
  static const String keyAccessToken = 'auth_access_token';
  static const String keyRefreshToken = 'auth_refresh_token';
  static const String keyUserData = 'auth_user_data';
  static const String keySavedBaseUrl = 'config_base_url';
  static const String keySelectedEnv = 'config_selected_env';

  // High-Resolution Aerial Satellite Imagery (ESRI World Imagery - No API key required)
  static const String satelliteTileUrl =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
  static const String satelliteLabelsTileUrl =
      'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}';

  // 2D Street Map (CartoDB Voyager; OpenStreetMap data, no API key required)
  static const String streetTileUrl =
      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';
  static const String osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  // Default Geospatial Center (Nagpur, Maharashtra, India - central police jurisdiction)
  static const double defaultLatitude = 21.1458;
  static const double defaultLongitude = 79.0882;
  static const double defaultZoom = 14.2;
}
