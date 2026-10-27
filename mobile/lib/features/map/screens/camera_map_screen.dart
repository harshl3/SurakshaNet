import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/status_badge.dart';
import '../../camera/models/camera_model.dart';
import '../../camera/models/nagpur_default_cameras.dart';
import '../../camera/providers/camera_provider.dart';
import '../../camera/screens/camera_detail_screen.dart';

enum MapMode { mode2d, mode3d }
enum MapStyle { satellite, daylight, tacticalNight }

class CameraMapScreen extends ConsumerStatefulWidget {
  const CameraMapScreen({super.key});

  @override
  ConsumerState<CameraMapScreen> createState() => _CameraMapScreenState();
}

class _CameraMapScreenState extends ConsumerState<CameraMapScreen> {
  final MapController _mapController = MapController();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _registrySearchController = TextEditingController();

  LatLng _currentCenter = const LatLng(
    AppConstants.defaultLatitude,
    AppConstants.defaultLongitude,
  );
  CameraModel? _selectedCamera;
  PoliceStationModel? _selectedStation;
  bool _isLocating = false;
  bool _isFullscreen = false;
  String _selectedStatusFilter = 'ALL';

  String _registryHardwareFilter = 'ALL';
  String _registryStatusFilter = 'ALL';
  String _registryViewMode = 'table'; // 'table' or 'cards'

  MapMode _currentMode = MapMode.mode3d; // Defaults to 3D Recon Mode
  MapStyle _currentStyle = MapStyle.satellite; // Defaults to Satellite Imagery
  double _currentRotation = 0.0;
  Timer? _clockTimer;
  String _istClock = '';

  @override
  void initState() {
    super.initState();
    _startClock();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _scrollController.dispose();
    _registrySearchController.dispose();
    super.dispose();
  }

  void _startClock() {
    _updateClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());
  }

  void _updateClock() {
    // Current Indian Standard Time (UTC+5:30)
    final nowUtc = DateTime.now().toUtc();
    final nowIst = nowUtc.add(const Duration(hours: 5, minutes: 30));
    final h = nowIst.hour.toString().padLeft(2, '0');
    final m = nowIst.minute.toString().padLeft(2, '0');
    final s = nowIst.second.toString().padLeft(2, '0');
    if (mounted) {
      setState(() {
        _istClock = '$h:$m:$s IST';
      });
    }
  }

  Future<void> _determinePosition() async {
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLocating = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLocating = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLocating = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final userLatLng = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentCenter = userLatLng;
        _isLocating = false;
      });
      _mapController.move(userLatLng, 15.5);
    } catch (e) {
      debugPrint('Location lookup failed: $e');
      setState(() => _isLocating = false);
    }
  }

  void _resetToNagpurHq() {
    final hq = const LatLng(AppConstants.defaultLatitude, AppConstants.defaultLongitude);
    setState(() {
      _currentCenter = hq;
      _selectedCamera = null;
      _selectedStation = null;
      _currentRotation = 0.0;
    });
    _mapController.moveAndRotate(hq, AppConstants.defaultZoom, 0.0);
  }

  void _resetNorthBearing() {
    setState(() => _currentRotation = 0.0);
    _mapController.rotate(0.0);
  }

  void _toggleTilt() {
    final newRot = _currentRotation == 0.0 ? -15.0 : 0.0;
    setState(() => _currentRotation = newRot);
    _mapController.rotate(newRot);
  }

  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    if (currentZoom < 18.0) {
      _mapController.move(_mapController.camera.center, currentZoom + 1.0);
    }
  }

  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    if (currentZoom > 4.0) {
      _mapController.move(_mapController.camera.center, currentZoom - 1.0);
    }
  }

  String _formatBearing(double rotation) {
    final deg = ((-rotation % 360) + 360) % 360;
    final cardinals = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((deg + 22.5) % 360 / 45.0).floor() % 8;
    return '${deg.toInt().toString().padLeft(3, '0')}° ${cardinals[index]}';
  }

  Color _getCameraMarkerColor(CameraModel camera) {
    if (camera.verificationStatus == 'PENDING') {
      return const Color(0xFFF79E1B); // Amber
    }
    if (camera.cameraStatus == 'OFFLINE' ||
        camera.cameraStatus == 'DAMAGED' ||
        camera.verificationStatus == 'REJECTED') {
      return const Color(0xFFCF4500); // Signal Orange / Red
    }
    return const Color(0xFF10B981); // Emerald Green
  }

  // Generates Field-of-View (FOV) sector wedge coordinates for every registered camera
  List<LatLng> _getFovPolygon(CameraModel camera) {
    final lat = camera.latitude;
    final lon = camera.longitude;
    final dir = camera.directionAngle;
    final fov = camera.fovAngle > 0 ? camera.fovAngle : 60.0;
    final radius = camera.coverageRadiusMeters > 0 ? camera.coverageRadiusMeters : 110.0;

    const metersPerLat = 111320.0;
    final metersPerLon = 111320.0 * math.cos(lat * math.pi / 180.0);

    if (fov >= 360) {
      final points = <LatLng>[];
      for (int deg = 0; deg <= 360; deg += 15) {
        final rad = deg * math.pi / 180.0;
        points.add(LatLng(
          lat + (radius * math.sin(rad)) / metersPerLat,
          lon + (radius * math.cos(rad)) / metersPerLon,
        ));
      }
      return points;
    }

    final startAngle = dir - fov / 2.0;
    final endAngle = dir + fov / 2.0;
    final step = math.max(1.0, (endAngle - startAngle) / 8.0);

    final points = <LatLng>[LatLng(lat, lon)];
    for (double a = startAngle; a <= endAngle + 0.001; a += step) {
      final rad = (90.0 - a) * math.pi / 180.0;
      points.add(LatLng(
        lat + (radius * math.sin(rad)) / metersPerLat,
        lon + (radius * math.cos(rad)) / metersPerLon,
      ));
    }
    points.add(LatLng(lat, lon));
    return points;
  }

  @override
  Widget build(BuildContext context) {
    final cameraListAsync = ref.watch(cameraListProvider);

    // Retrieve loaded cameras or seamlessly fall back to default registered cameras
    final allCameras = cameraListAsync.maybeWhen(
      data: (cams) => cams.isNotEmpty ? cams : NagpurDefaultCameras.defaultCameras,
      orElse: () => NagpurDefaultCameras.defaultCameras,
    );

    final filteredCameras = _selectedStatusFilter == 'ALL'
        ? allCameras
        : allCameras.where((c) {
            if (_selectedStatusFilter == 'PENDING') {
              return c.verificationStatus == 'PENDING';
            }
            return c.cameraStatus == _selectedStatusFilter;
          }).toList();

    final activeCount = allCameras.where((c) => c.cameraStatus == 'ACTIVE').length;
    final pendingCount = allCameras.where((c) => c.verificationStatus == 'PENDING').length;
    final offlineCount = allCameras.where((c) => c.cameraStatus == 'OFFLINE' || c.cameraStatus == 'DAMAGED').length;

    // 1. Build Camera Markers with Target Reticles & Directional Arrow
    final cameraMarkers = filteredCameras.map((camera) {
      final markerColor = _getCameraMarkerColor(camera);
      final isSelected = _selectedCamera?.id == camera.id;
      final size = isSelected ? 48.0 : 38.0;

      return Marker(
        point: LatLng(camera.latitude, camera.longitude),
        width: size,
        height: size,
        child: GestureDetector(
          onTap: () {
            setState(() {
              _selectedCamera = camera;
              _selectedStation = null;
            });
            _mapController.move(
              LatLng(camera.latitude, camera.longitude),
              math.max(_mapController.camera.zoom, 15.0),
            );
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Direction Arrow Indicator
              Transform.rotate(
                angle: (camera.directionAngle * math.pi / 180.0),
                child: SizedBox(
                  width: size,
                  height: size,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Icon(
                      Icons.navigation,
                      size: isSelected ? 17 : 13,
                      color: markerColor,
                    ),
                  ),
                ),
              ),

              // Outer Circular Target Ring
              Container(
                width: isSelected ? 34 : 26,
                height: isSelected ? 34 : 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: markerColor.withValues(alpha: isSelected ? 0.95 : 0.75),
                    width: isSelected ? 2.5 : 1.8,
                  ),
                ),
              ),

              // Center Hub
              Container(
                width: isSelected ? 20 : 16,
                height: isSelected ? 20 : 16,
                decoration: BoxDecoration(
                  color: const Color(0xFF141413),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: isSelected ? 8 : 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: isSelected ? 9 : 7,
                    height: isSelected ? 9 : 7,
                    decoration: BoxDecoration(
                      color: markerColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();

    // 2. Build Police Station Precinct Markers
    final stationMarkers = NagpurDefaultCameras.defaultStations.map((station) {
      final isSelected = _selectedStation?.id == station.id;
      return Marker(
        point: LatLng(station.latitude, station.longitude),
        width: 44,
        height: 52,
        child: GestureDetector(
          onTap: () {
            setState(() {
              _selectedStation = station;
              _selectedCamera = null;
            });
            _mapController.move(
              LatLng(station.latitude, station.longitude),
              math.max(_mapController.camera.zoom, 15.0),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFCF4500) : const Color(0xFF141413),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.local_police_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const Icon(
                Icons.arrow_drop_down,
                color: Color(0xFF141413),
                size: 16,
              ),
            ],
          ),
        ),
      );
    }).toList();

    // 3. FOV Cones for ALL Cameras visible by default on the map!
    final polygons = filteredCameras.map((camera) {
      final fovPoints = _getFovPolygon(camera);
      final color = _getCameraMarkerColor(camera);
      final isSelected = _selectedCamera?.id == camera.id;

      return Polygon(
        points: fovPoints,
        color: isSelected
            ? color.withValues(alpha: 0.38)
            : color.withValues(alpha: _currentMode == MapMode.mode3d ? 0.22 : 0.26),
        borderColor: isSelected ? color : color.withValues(alpha: 0.75),
        borderStrokeWidth: isSelected ? 2.5 : 1.3,
      );
    }).toList();

    // Map content component (reused in normal card & fullscreen mode)
    final mapWidget = Stack(
      children: [
        // ==========================================
        // FLUTTER_MAP CANVAS (No API Key Required)
        // ==========================================
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _currentCenter,
            initialZoom: AppConstants.defaultZoom,
            initialRotation: _currentRotation,
            maxZoom: 18.0,
            minZoom: 4.0,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
            onPositionChanged: (pos, hasGesture) {
              if (pos.rotation != _currentRotation) {
                setState(() => _currentRotation = pos.rotation);
              }
            },
            onTap: (tapPosition, point) {
              if (_selectedCamera != null || _selectedStation != null) {
                setState(() {
                  _selectedCamera = null;
                  _selectedStation = null;
                });
              }
            },
          ),
          children: [
            // 2D MODE: Street map with OpenStreetMap as a network-error fallback.
            if (_currentMode == MapMode.mode2d) ...[
              TileLayer(
                key: const ValueKey('tile_layer_2d_street'),
                urlTemplate: AppConstants.streetTileUrl,
                fallbackUrl: AppConstants.osmTileUrl,
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.police.cameramapping',
                maxZoom: 19,
              ),
            ],

            // 3D MODE: Aerial Satellite Terrain Imagery + Place Labels / Night Shading
            if (_currentMode == MapMode.mode3d) ...[
              if (_currentStyle == MapStyle.satellite || _currentStyle == MapStyle.tacticalNight) ...[
                TileLayer(
                  key: const ValueKey('tile_layer_3d_satellite'),
                  urlTemplate: AppConstants.satelliteTileUrl,
                  userAgentPackageName: 'com.police.cameramapping',
                  maxZoom: 18,
                ),
                TileLayer(
                  key: const ValueKey('tile_layer_3d_labels'),
                  urlTemplate: AppConstants.satelliteLabelsTileUrl,
                  userAgentPackageName: 'com.police.cameramapping',
                  maxZoom: 18,
                ),
              ] else ...[
                TileLayer(
                  key: const ValueKey('tile_layer_3d_daylight'),
                  urlTemplate: AppConstants.streetTileUrl,
                  fallbackUrl: AppConstants.osmTileUrl,
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.police.cameramapping',
                  maxZoom: 19,
                ),
              ],
            ],

            // Tactical Night Mode Shading
            if (_currentMode == MapMode.mode3d && _currentStyle == MapStyle.tacticalNight)
              IgnorePointer(
                child: Container(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.40),
                ),
              ),

            // All Camera FOV Sector Wedges
            PolygonLayer(polygons: polygons),

            // All Camera Nodes & Police Stations
            MarkerLayer(markers: [...stationMarkers, ...cameraMarkers]),
          ],
        ),

        // ==========================================
        // TOP IN-MAP TACTICAL HEADER CONTROLS
        // ==========================================
        Positioned(
          top: 10,
          left: 10,
          right: 10,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Row 1: Left Mode Badge & Right Mode Switcher + Expand
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Badge Left: 2D GRID or 3D RECON
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141413).withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_currentMode == MapMode.mode2d) ...[
                          const Icon(Icons.shield_rounded, color: Color(0xFFCF4500), size: 13),
                          const SizedBox(width: 5),
                          const Text(
                            '2D GRID',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFCF4500).withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'NAGPUR',
                              style: TextStyle(
                                color: Color(0xFFFF8555),
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ] else ...[
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            '3D RECON',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFCF4500).withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'NAGPUR',
                              style: TextStyle(
                                color: Color(0xFFFF8555),
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Right Controls: [2D | 3D] Switcher + Expand Button
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 2D | 3D Switcher
                      Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141413).withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildModeToggle(
                              label: '2D',
                              active: _currentMode == MapMode.mode2d,
                              activeColor: Colors.white,
                              textColor: const Color(0xFF141413),
                              onTap: () {
                                setState(() {
                                  _currentMode = MapMode.mode2d;
                                  _currentRotation = 0.0;
                                });
                                _mapController.rotate(0.0);
                              },
                            ),
                            _buildModeToggle(
                              label: '3D',
                              hasDot: _currentMode == MapMode.mode2d,
                              active: _currentMode == MapMode.mode3d,
                              activeColor: const Color(0xFFCF4500),
                              textColor: Colors.white,
                              onTap: () {
                                setState(() {
                                  _currentMode = MapMode.mode3d;
                                  _currentStyle = MapStyle.satellite;
                                  _currentRotation = -15.0;
                                });
                                _mapController.rotate(-15.0);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 5),

                      // Expand / Fullscreen Button
                      InkWell(
                        onTap: () => setState(() => _isFullscreen = !_isFullscreen),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: _isFullscreen
                                ? const Color(0xFFCF4500)
                                : Colors.white.withValues(alpha: 0.96),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _isFullscreen
                                  ? const Color(0xFFCF4500)
                                  : const Color(0xFFE5DFD9),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isFullscreen ? Icons.close_fullscreen_rounded : Icons.open_in_full_rounded,
                                size: 11,
                                color: _isFullscreen ? Colors.white : const Color(0xFFCF4500),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _isFullscreen ? 'Exit' : 'Expand',
                                style: TextStyle(
                                  color: _isFullscreen ? Colors.white : const Color(0xFF141413),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Row 2 (in 3D Mode): Live IST Clock (Left) + Style Switcher (Right)
              if (_currentMode == MapMode.mode3d) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Live IST Clock Badge
                    if (_istClock.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141413).withValues(alpha: 0.90),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.access_time_rounded, color: Colors.white70, size: 10),
                            const SizedBox(width: 4),
                            Text(
                              _istClock,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      const SizedBox.shrink(),

                    // 3D Style Controls (Satellite, Daylight, Tactical Night)
                    Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141413).withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildStyleButton(
                            icon: Icons.public_rounded,
                            label: 'Satellite',
                            active: _currentStyle == MapStyle.satellite,
                            onTap: () => setState(() => _currentStyle = MapStyle.satellite),
                          ),
                          _buildStyleButton(
                            icon: Icons.wb_sunny_outlined,
                            label: 'Daylight',
                            active: _currentStyle == MapStyle.daylight,
                            onTap: () => setState(() => _currentStyle = MapStyle.daylight),
                          ),
                          _buildStyleButton(
                            icon: Icons.nightlight_round,
                            label: 'Night',
                            active: _currentStyle == MapStyle.tacticalNight,
                            onTap: () => setState(() => _currentStyle = MapStyle.tacticalNight),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // ==========================================
        // BOTTOM-LEFT ACTIONS (HQ, Live GPS, Tilt)
        // ==========================================
        Positioned(
          left: 10,
          bottom: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF141413).withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildActionPill(
                  icon: Icons.refresh_rounded,
                  label: 'HQ',
                  onTap: _resetToNagpurHq,
                ),
                _buildActionPill(
                  icon: Icons.navigation_rounded,
                  label: 'Live GPS',
                  iconColor: const Color(0xFF10B981),
                  isLoading: _isLocating,
                  onTap: _determinePosition,
                ),
                if (_currentMode == MapMode.mode3d)
                  _buildActionPill(
                    icon: Icons.screen_rotation_rounded,
                    label: _currentRotation != 0.0 ? 'Tilt 55°' : 'Tilt 0°',
                    onTap: _toggleTilt,
                  ),
              ],
            ),
          ),
        ),

        // ==========================================
        // WORKING COMPASS & ZOOM CONTROLS (Bottom-Right)
        // ==========================================
        Positioned(
          right: 10,
          bottom: 10,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Working Tactical Compass Widget
              GestureDetector(
                onTap: _resetNorthBearing,
                child: Container(
                  width: 54,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141413).withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Rotating Compass Dial
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Static Outer Dial Marks
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  width: 1.2,
                                ),
                              ),
                            ),

                            // Dynamic Rotating Needle (Rotates inversely with map bearing)
                            Transform.rotate(
                              angle: (-_currentRotation * math.pi / 180.0),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // North Arrow (Red)
                                  Align(
                                    alignment: Alignment.topCenter,
                                    child: Container(
                                      width: 4,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFCF4500),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ),
                                  // South Arrow (White)
                                  Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Container(
                                      width: 4,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: Colors.white70,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ),
                                  // Center Pivot Pin
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 3),

                      // Live Bearing Display (e.g. "345° N")
                      Text(
                        _formatBearing(_currentRotation),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'RESET N',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 6.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Zoom In / Zoom Out (+ / -)
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF141413).withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: _zoomIn,
                      child: const Padding(
                        padding: EdgeInsets.all(7.0),
                        child: Icon(Icons.add, color: Colors.white, size: 18),
                      ),
                    ),
                    Container(
                      width: 20,
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                    InkWell(
                      onTap: _zoomOut,
                      child: const Padding(
                        padding: EdgeInsets.all(7.0),
                        child: Icon(Icons.remove, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ==========================================
        // SELECTED CAMERA DOSSIER PREVIEW CARD
        // ==========================================
        if (_selectedCamera != null)
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: _buildCameraPreviewCard(_selectedCamera!),
          ),

        // ==========================================
        // SELECTED POLICE PRECINCT CARD
        // ==========================================
        if (_selectedStation != null)
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: _buildStationPreviewCard(_selectedStation!),
          ),
      ],
    );

    // ==========================================
    // FULLSCREEN EXPAND VIEW
    // ==========================================
    if (_isFullscreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: ClipRRect(
            borderRadius: BorderRadius.zero,
            child: mapWidget,
          ),
        ),
      );
    }

    // ==========================================
    // STANDARD PAGE EMBEDDED CARD VIEW
    // ==========================================
    // Registry Search & Filter Calculation
    final regQuery = _registrySearchController.text.trim().toLowerCase();
    final registryCameras = allCameras.where((c) {
      if (regQuery.isNotEmpty) {
        final matches = c.cameraCode.toLowerCase().contains(regQuery) ||
            c.cameraName.toLowerCase().contains(regQuery) ||
            (c.area?.toLowerCase().contains(regQuery) ?? false) ||
            (c.fullAddress?.toLowerCase().contains(regQuery) ?? false) ||
            (c.ownerName?.toLowerCase().contains(regQuery) ?? false) ||
            (c.ownerContact?.toLowerCase().contains(regQuery) ?? false);
        if (!matches) return false;
      }
      if (_registryHardwareFilter != 'ALL' && c.cameraType != _registryHardwareFilter) {
        return false;
      }
      if (_registryStatusFilter != 'ALL') {
        if (_registryStatusFilter == 'ACTIVE' && c.cameraStatus != 'ACTIVE') return false;
        if (_registryStatusFilter == 'PENDING' && c.verificationStatus != 'PENDING') return false;
        if (_registryStatusFilter == 'OFFLINE' && c.cameraStatus != 'OFFLINE' && c.cameraStatus != 'DAMAGED') return false;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F6F3),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Top Header Row: [2D GRID NAGPUR] & [52 nodes plotted 🔄]
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141413),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.shield_outlined,
                          color: Color(0xFFCF4500),
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          '2D GRID',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFCF4500).withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'NAGPUR',
                            style: TextStyle(
                              color: Color(0xFFFF8555),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE5DFD9)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          '${allCameras.length} nodes plotted',
                          style: const TextStyle(
                            color: Color(0xFF141413),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => ref.refresh(cameraListProvider),
                          child: const Icon(
                            Icons.refresh_rounded,
                            size: 14,
                            color: Color(0xFF696969),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 2. Horizontal Filter Chips: All, Active, Pending, Offline
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(
                      label: 'All Cameras',
                      value: 'ALL',
                      icon: Icons.videocam_outlined,
                      count: allCameras.length,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'Active (Online)',
                      value: 'ACTIVE',
                      dotColor: const Color(0xFF10B981),
                      count: activeCount,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'Pending Verification',
                      value: 'PENDING',
                      dotColor: const Color(0xFFF79E1B),
                      count: pendingCount,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'Offline',
                      value: 'OFFLINE',
                      dotColor: const Color(0xFFCF4500),
                      count: offlineCount,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 3. Embedded Tactical Stadium Card
              Container(
                height: 400,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFFE5DFD9)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Card Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFCF4500),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'LIVE GEOSPATIAL CCTV RECONNAISSANCE',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                  color: Color(0xFF141413),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${filteredCameras.length} nodes plotted',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF696969),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Card Inner Map
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: mapWidget,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ==========================================
              // 4. BELOW MAP: SURVEILLANCE NODES DIRECTORY (Image 1)
              // ==========================================
              const SizedBox(height: 18),

              // Search Bar (Image 1)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE5DFD9)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _registrySearchController,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Search by camera code, area, landmark, owner name...',
                    hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF8C827A)),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF696969)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    suffixIcon: _registrySearchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 16),
                            onPressed: () {
                              _registrySearchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Filters Row: [All Hardware ∨] [All Statuses ∨] [ ⊞ | 𝌆 ] (Image 1)
              Row(
                children: [
                  // Hardware Dropdown
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE5DFD9)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _registryHardwareFilter,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF696969)),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF141413)),
                          items: const [
                            DropdownMenuItem(value: 'ALL', child: Text('All Hardware')),
                            DropdownMenuItem(value: 'ANPR', child: Text('ANPR')),
                            DropdownMenuItem(value: 'DOME', child: Text('Dome')),
                            DropdownMenuItem(value: 'PTZ', child: Text('PTZ')),
                            DropdownMenuItem(value: 'BULLET', child: Text('Bullet')),
                            DropdownMenuItem(value: 'NIGHT_VISION', child: Text('Night Vision')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _registryHardwareFilter = val);
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Status Dropdown
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE5DFD9)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _registryStatusFilter,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF696969)),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF141413)),
                          items: const [
                            DropdownMenuItem(value: 'ALL', child: Text('All Statuses')),
                            DropdownMenuItem(value: 'ACTIVE', child: Text('Online / Active')),
                            DropdownMenuItem(value: 'PENDING', child: Text('Pending Approval')),
                            DropdownMenuItem(value: 'OFFLINE', child: Text('Offline')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _registryStatusFilter = val);
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // View Toggle [ ⊞ | 𝌆 ]
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE5DFD9)),
                    ),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () => setState(() => _registryViewMode = 'cards'),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: _registryViewMode == 'cards' ? const Color(0xFF141413) : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.grid_view_rounded,
                              size: 14,
                              color: _registryViewMode == 'cards' ? Colors.white : const Color(0xFF696969),
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => setState(() => _registryViewMode = 'table'),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: _registryViewMode == 'table' ? const Color(0xFF141413) : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.table_rows_rounded,
                              size: 14,
                              color: _registryViewMode == 'table' ? Colors.white : const Color(0xFF696969),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Counter Text (Image 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  'Showing ${registryCameras.length} registered police surveillance nodes',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF696969),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Cameras List / Table View (Image 1)
              if (registryCameras.isEmpty)
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE5DFD9)),
                  ),
                  child: Column(
                    children: const [
                      Icon(Icons.videocam_off_outlined, size: 36, color: Color(0xFF8C827A)),
                      SizedBox(height: 8),
                      Text('No CCTV cameras match your search parameters', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    ],
                  ),
                )
              else
                ...registryCameras.map((cam) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _selectedCamera?.id == cam.id
                            ? const Color(0xFFCF4500)
                            : const Color(0xFFE5DFD9),
                        width: _selectedCamera?.id == cam.id ? 1.8 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedCamera = cam;
                          _selectedStation = null;
                          _currentCenter = LatLng(cam.latitude, cam.longitude);
                        });
                        _mapController.move(LatLng(cam.latitude, cam.longitude), 15.5);
                        _scrollController.animateTo(
                          0,
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut,
                        );
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top Row: Code + Type + Status + Verification
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      cam.cameraCode,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF141413),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF3F0EE),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFE5DFD9)),
                                      ),
                                      child: Text(
                                        cam.cameraType,
                                        style: const TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF141413),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    // Status Pill
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: cam.cameraStatus == 'ACTIVE'
                                            ? const Color(0xFFEAF7EE)
                                            : const Color(0xFFFDF0EE),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: cam.cameraStatus == 'ACTIVE'
                                                  ? const Color(0xFF10B981)
                                                  : const Color(0xFFCF4500),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            cam.cameraStatus == 'ACTIVE' ? 'Online' : 'Offline',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                              color: cam.cameraStatus == 'ACTIVE'
                                                  ? const Color(0xFF0A7334)
                                                  : const Color(0xFFCF4500),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),

                                    // Verification Pill
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: cam.verificationStatus == 'APPROVED'
                                            ? const Color(0xFFEAF7EE)
                                            : const Color(0xFFFFF4E5),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        cam.verificationStatus == 'APPROVED' ? '✓ Approved' : '◷ Pending',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: cam.verificationStatus == 'APPROVED'
                                              ? const Color(0xFF0A7334)
                                              : const Color(0xFFCF4500),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Name & Location (Image 1)
                            Text(
                              cam.cameraName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF141413),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(Icons.place_outlined, size: 12, color: Color(0xFFCF4500)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    cam.fullAddress ?? '${cam.area ?? "Nagpur Central"}, Nagpur',
                                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF696969)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Divider(height: 1, color: Color(0xFFF3F0EE)),
                            const SizedBox(height: 10),

                            // Bottom Row: Owner & Contact + Radius/Angle + Details Action (Image 1)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Owner & Contact
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.person_outline_rounded, size: 12, color: Color(0xFF3860BE)),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              cam.ownerName ?? 'Police Department',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF141413),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (cam.ownerContact != null) ...[
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            const Icon(Icons.phone_outlined, size: 11, color: Color(0xFF696969)),
                                            const SizedBox(width: 4),
                                            Text(
                                              cam.ownerContact!,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontFamily: 'monospace',
                                                color: Color(0xFF696969),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),

                                // Radius / Angle
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF7F6F3),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${cam.coverageRadiusMeters.toInt()}m radius',
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF141413)),
                                      ),
                                      Text(
                                        '${cam.directionAngle.toInt()}° (${cam.cardinalDirection ?? "N"})',
                                        style: const TextStyle(fontSize: 9, color: Color(0xFF696969)),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Actions: [ 👁 Details ] Button (Image 1)
                                OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => CameraDetailScreen(cameraId: cam.id),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.visibility_outlined, size: 13, color: Color(0xFF141413)),
                                  label: const Text('Details', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF141413))),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    side: const BorderSide(color: Color(0xFFD1CDC7)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 70), // Bottom padding for FAB
            ],
          ),
        ),
      ),
    );
  }

  // 2D / 3D Mode Toggle Pill Button
  Widget _buildModeToggle({
    required String label,
    bool hasDot = false,
    required bool active,
    required Color activeColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: active ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasDot) ...[
              Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: active ? textColor : Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Style button with icon & text (Satellite, Daylight, Tactical Night)
  Widget _buildStyleButton({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFCF4500) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 12,
              color: active ? Colors.white : Colors.white70,
            ),
            if (active) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Action pill item (HQ, Live GPS, Tilt)
  Widget _buildActionPill({
    required IconData icon,
    required String label,
    Color iconColor = Colors.white,
    bool isLoading = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              const SizedBox(
                width: 11,
                height: 11,
                child: CircularProgressIndicator(strokeWidth: 1.8, color: Colors.white),
              )
            else
              Icon(icon, size: 12, color: iconColor),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String value,
    IconData? icon,
    Color? dotColor,
    required int count,
  }) {
    final isSelected = _selectedStatusFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedStatusFilter = value;
          _selectedCamera = null;
          _selectedStation = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF141413) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF141413) : const Color(0xFFE5DFD9),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: isSelected ? Colors.white : const Color(0xFF141413)),
              const SizedBox(width: 6),
            ] else if (dotColor != null) ...[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              '$label ($count)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF141413),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreviewCard(CameraModel camera) {
    return Card(
      elevation: 10,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        camera.cameraName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF141413),
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Node: ${camera.cameraCode} • ${camera.cameraType}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF696969),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF696969)),
                  onPressed: () => setState(() => _selectedCamera = null),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                StatusBadge(status: camera.cameraStatus),
                const SizedBox(width: 8),
                StatusBadge(status: camera.verificationStatus, isVerification: true),
                const Spacer(),
                Text(
                  '${camera.directionAngle.toInt()}° (${camera.cardinalDirection ?? "N"}) • ${camera.coverageRadiusMeters.toInt()}m',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF141413),
                  ),
                ),
              ],
            ),
            if (camera.fullAddress != null && camera.fullAddress!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.place_outlined, size: 13, color: Color(0xFF696969)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      camera.fullAddress!,
                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF696969)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            CustomButton(
              text: 'View Camera Dossier',
              icon: Icons.assignment_outlined,
              variant: ButtonVariant.primary,
              height: 38,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => CameraDetailScreen(cameraId: camera.id),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStationPreviewCard(PoliceStationModel station) {
    return Card(
      elevation: 10,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFF141413),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.local_police_rounded, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        station.stationName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF141413),
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Precinct: ${station.stationCode} • ${station.jurisdictionZone}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF696969),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF696969)),
                  onPressed: () => setState(() => _selectedStation = null),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.place_outlined, size: 13, color: Color(0xFF696969)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    station.address,
                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF696969)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.phone_outlined, size: 13, color: Color(0xFF696969)),
                const SizedBox(width: 4),
                Text(
                  station.contactNumber,
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF141413)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
