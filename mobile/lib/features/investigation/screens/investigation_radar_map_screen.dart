import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/dns_fallback_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../camera/models/camera_model.dart';
import '../../camera/models/nagpur_default_cameras.dart';
import '../../camera/providers/camera_provider.dart';
import '../../camera/screens/camera_detail_screen.dart';
import '../models/investigation_model.dart';

class InvestigationRadarMapScreen extends ConsumerStatefulWidget {
  final InvestigationCaseModel caseItem;

  const InvestigationRadarMapScreen({
    super.key,
    required this.caseItem,
  });

  @override
  ConsumerState<InvestigationRadarMapScreen> createState() => _InvestigationRadarMapScreenState();
}

class _InvestigationRadarMapScreenState extends ConsumerState<InvestigationRadarMapScreen> {
  final MapController _mapController = MapController();
  late double _searchRadius;
  CameraModel? _selectedCamera;
  PoliceStationModel? _selectedStation;

  @override
  void initState() {
    super.initState();
    _searchRadius = widget.caseItem.searchRadiusMeters > 0 ? widget.caseItem.searchRadiusMeters : 500.0;
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  // Haversine Distance in meters
  double _calculateDistanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000.0; // meters
    final double dLat = (lat2 - lat1) * math.pi / 180.0;
    final double dLon = (lon2 - lon1) * math.pi / 180.0;

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  // Generates coordinates for Camera Field of View (FOV) sector wedge
  List<LatLng> _buildFovPoints(double lat, double lon, double dir, double radius, double fov) {
    if (fov <= 0) return [];

    const metersPerLat = 111320.0;
    final metersPerLon = 111320.0 * math.cos(lat * math.pi / 180.0);

    // Full 360-degree omnidirectional coverage
    if (fov >= 360.0) {
      final circlePoints = <LatLng>[];
      for (double deg = 0; deg < 360; deg += 15) {
        final rad = deg * math.pi / 180.0;
        circlePoints.add(LatLng(
          lat + (radius * math.sin(rad)) / metersPerLat,
          lon + (radius * math.cos(rad)) / metersPerLon,
        ));
      }
      circlePoints.add(circlePoints.first);
      return circlePoints;
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

  void _recenterOnCrimeScene() {
    _mapController.move(
      LatLng(widget.caseItem.latitude, widget.caseItem.longitude),
      15.5,
    );
  }

  @override
  Widget build(BuildContext context) {
    final crimeLatLng = LatLng(widget.caseItem.latitude, widget.caseItem.longitude);
    final cameraListAsync = ref.watch(cameraListProvider);

    // Get combined pool of registered CCTV cameras
    final allCameras = cameraListAsync.maybeWhen(
      data: (cams) => cams.isNotEmpty ? cams : NagpurDefaultCameras.defaultCameras,
      orElse: () => NagpurDefaultCameras.defaultCameras,
    );

    // Filter cameras within or near the radar incident radius
    final camerasWithDistance = allCameras.map((cam) {
      final dist = _calculateDistanceMeters(
        widget.caseItem.latitude,
        widget.caseItem.longitude,
        cam.latitude,
        cam.longitude,
      );
      return MapEntry(cam, dist);
    }).toList();

    // Sort by distance from incident
    camerasWithDistance.sort((a, b) => a.value.compareTo(b.value));

    // Get detected nodes within search radius (or fallback to closest 4)
    final inRadiusCameras = camerasWithDistance.where((e) => e.value <= _searchRadius).toList();
    final detectedNodes = inRadiusCameras.isNotEmpty
        ? inRadiusCameras
        : camerasWithDistance.take(4).toList();

    // 1. Build FOV Fan Cones (Polygons)
    final fovPolygons = <Polygon>[];
    for (final entry in detectedNodes) {
      final cam = entry.key;
      final fovPoints = _buildFovPoints(
        cam.latitude,
        cam.longitude,
        cam.directionAngle,
        cam.coverageRadiusMeters > 0 ? cam.coverageRadiusMeters : 90.0,
        cam.fovAngle > 0 ? cam.fovAngle : 60.0,
      );

      if (fovPoints.isNotEmpty) {
        fovPolygons.add(
          Polygon(
            points: fovPoints,
            color: const Color(0xFF10B981).withValues(alpha: 0.16),
            borderColor: const Color(0xFF10B981).withValues(alpha: 0.8),
            borderStrokeWidth: 1.5,
          ),
        );
      }
    }

    // 2. Build Connective Radar Trajectory Lines (Polylines)
    final trajectoryLines = <Polyline>[];
    for (final entry in detectedNodes) {
      final cam = entry.key;
      trajectoryLines.add(
        Polyline(
          points: [
            crimeLatLng,
            LatLng(cam.latitude, cam.longitude),
          ],
          color: const Color(0xFFF37338).withValues(alpha: 0.55),
          strokeWidth: 1.4,
          pattern: StrokePattern.dashed(segments: const [6, 6]),
        ),
      );
    }

    // 3. Build Camera Markers with Orientation Arrows
    final cameraMarkers = detectedNodes.map((entry) {
      final cam = entry.key;
      final isSelected = _selectedCamera?.id == cam.id;
      final size = isSelected ? 48.0 : 38.0;

      return Marker(
        point: LatLng(cam.latitude, cam.longitude),
        width: size,
        height: size,
        child: GestureDetector(
          onTap: () {
            setState(() {
              _selectedCamera = cam;
              _selectedStation = null;
            });
            _mapController.move(LatLng(cam.latitude, cam.longitude), 16.0);
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Direction Arrow Indicator
              Transform.rotate(
                angle: (cam.directionAngle * math.pi / 180.0),
                child: SizedBox(
                  width: size,
                  height: size,
                  child: const Align(
                    alignment: Alignment.topCenter,
                    child: Icon(
                      Icons.navigation,
                      size: 14,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ),
              ),

              // Outer Ring
              Container(
                width: isSelected ? 34 : 26,
                height: isSelected ? 34 : 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF10B981),
                    width: isSelected ? 2.5 : 1.8,
                  ),
                ),
              ),

              // Inner Core
              Container(
                width: isSelected ? 20 : 16,
                height: isSelected ? 20 : 16,
                decoration: BoxDecoration(
                  color: const Color(0xFF141413),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: isSelected ? 9 : 7,
                    height: isSelected ? 9 : 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
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

    // 4. Build Police Station Headquarters Markers
    final stationMarkers = NagpurDefaultCameras.defaultStations.map((station) {
      final isSelected = _selectedStation?.id == station.id;
      final shortName = station.stationName
          .replaceAll(' Police Station', '')
          .replaceAll(' Police Commissionerate', '')
          .replaceAll(' Police Chowki', '');

      return Marker(
        point: LatLng(station.latitude, station.longitude),
        width: isSelected ? 110 : 100,
        height: 58,
        child: GestureDetector(
          onTap: () {
            setState(() {
              _selectedStation = station;
              _selectedCamera = null;
            });
            _mapController.move(LatLng(station.latitude, station.longitude), 15.5);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Black Teardrop Police Badge Pin
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF141413),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.shield_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
              // Name Label underneath
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFE5DFD9)),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1)),
                  ],
                ),
                child: Text(
                  shortName,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF141413),
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();

    // 5. Build Incident Focal Point Marker (Target Reticle)
    final incidentMarker = Marker(
      point: crimeLatLng,
      width: 50,
      height: 50,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer Radar Halo
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFCF4500).withValues(alpha: 0.22),
              border: Border.all(
                color: const Color(0xFFCF4500),
                width: 2,
              ),
            ),
          ),
          // Dark Core
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: const Color(0xFF141413),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Center(
              child: Icon(
                Icons.star_rounded,
                color: Color(0xFFF37338),
                size: 14,
              ),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.canvasCream,
      body: Stack(
        children: [
          // 2D OpenStreetMap Layer with Radar Perimeter
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: crimeLatLng,
              initialZoom: 15.5,
              minZoom: 11.0,
              maxZoom: 18.0,
            ),
            children: [
              TileLayer(
                urlTemplate: AppConstants.streetTileUrl,
                fallbackUrl: AppConstants.streetTileFallbackUrl,
                userAgentPackageName: 'in.gov.mahapolice.surakshanet',
                tileProvider: createResilientTileProvider(),
                evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
                maxZoom: 19,
              ),

              // Circular Radar Perimeter around Incident Location
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: crimeLatLng,
                    radius: _searchRadius,
                    useRadiusInMeter: true,
                    color: const Color(0xFFF37338).withValues(alpha: 0.08),
                    borderColor: const Color(0xFFCF4500),
                    borderStrokeWidth: 2.0,
                  ),
                ],
              ),

              // FOV Wedge Fan Cones
              PolygonLayer(polygons: fovPolygons),

              // Orbital Connective Trajectory Lines
              PolylineLayer(polylines: trajectoryLines),

              // Police Station Markers & Camera Markers
              MarkerLayer(
                markers: [
                  ...stationMarkers,
                  ...cameraMarkers,
                  incidentMarker,
                ],
              ),
            ],
          ),

          // Top Tactical Header & Incident Dossier
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // App Bar Bar Container
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141413).withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 3)),
                      ],
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                          onPressed: () => Navigator.of(context).pop(),
                          tooltip: 'Back to Cases',
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      widget.caseItem.caseNumber,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        fontFamily: 'monospace',
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: widget.caseItem.isOpen
                                          ? const Color(0xFFF79E1B).withValues(alpha: 0.25)
                                          : const Color(0xFF10B981).withValues(alpha: 0.25),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: widget.caseItem.isOpen
                                            ? const Color(0xFFF79E1B)
                                            : const Color(0xFF10B981),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Text(
                                      widget.caseItem.status,
                                      style: TextStyle(
                                        color: widget.caseItem.isOpen
                                            ? const Color(0xFFF79E1B)
                                            : const Color(0xFF10B981),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 9,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                widget.caseItem.title,
                                style: const TextStyle(
                                  color: Color(0xFFD1CDC7),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.my_location_rounded, color: Color(0xFFF37338), size: 20),
                          onPressed: _recenterOnCrimeScene,
                          tooltip: 'Recenter on Incident Focal Point',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Sub-Bar: Radar Nodes Count & Radius Switcher
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
                      ],
                      border: Border.all(color: const Color(0xFFE5DFD9)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF37338),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${detectedNodes.length} CCTV Nodes in Radar',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF141413),
                            ),
                          ),
                        ),
                        // Radius Switcher
                        Text(
                          'Radar Radius: ',
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                        ),
                        ...[250, 500, 1000].map((rad) {
                          final isCurrent = _searchRadius == rad.toDouble();
                          return GestureDetector(
                            onTap: () => setState(() => _searchRadius = rad.toDouble()),
                            child: Container(
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isCurrent ? const Color(0xFF141413) : const Color(0xFFF3F0EE),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${rad}m',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isCurrent ? Colors.white : const Color(0xFF141413),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Detail Sheet when a Camera or Station is selected
          if (_selectedCamera != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 16,
              child: _buildCameraDetailCard(_selectedCamera!),
            )
          else if (_selectedStation != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 16,
              child: _buildStationDetailCard(_selectedStation!),
            )
          else
            // Bottom Detected Cameras Mini Carousel
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: _buildDetectedNodesTray(detectedNodes),
            ),
        ],
      ),
    );
  }

  // Detected CCTV Nodes Horizontal Tray
  Widget _buildDetectedNodesTray(List<MapEntry<CameraModel, double>> nodes) {
    if (nodes.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 100,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        scrollDirection: Axis.horizontal,
        itemCount: nodes.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final cam = nodes[i].key;
          final dist = nodes[i].value;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCamera = cam;
                _selectedStation = null;
              });
              _mapController.move(LatLng(cam.latitude, cam.longitude), 16.0);
            },
            child: Container(
              width: 240,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
                ],
                border: Border.all(color: const Color(0xFFE5DFD9)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.videocam_rounded, color: Color(0xFF10B981), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                cam.cameraCode,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF37338).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${dist.round()}m',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFCF4500),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          cam.cameraName,
                          style: const TextStyle(fontSize: 10.5, color: Color(0xFF696969)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          cam.fullAddress ?? 'Nagpur Metro Region',
                          style: const TextStyle(fontSize: 9.5, color: Color(0xFF9A9A9A)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Selected Camera Pop-up Card
  Widget _buildCameraDetailCard(CameraModel cam) {
    final dist = _calculateDistanceMeters(
      widget.caseItem.latitude,
      widget.caseItem.longitude,
      cam.latitude,
      cam.longitude,
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4)),
        ],
        border: Border.all(color: const Color(0xFFE5DFD9)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF141413),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  cam.cameraCode,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF37338).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${dist.round()}m from Scene',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFCF4500),
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () => setState(() => _selectedCamera = null),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            cam.cameraName,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF141413)),
          ),
          const SizedBox(height: 2),
          Text(
            cam.fullAddress ?? 'Nagpur Metro Region',
            style: const TextStyle(fontSize: 11, color: Color(0xFF696969)),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Type: ${cam.cameraType} • Facing: ${cam.cardinalDirection ?? "EAST"}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF141413)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF141413),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => CameraDetailScreen(cameraId: cam.id),
                    ),
                  );
                },
                icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                label: const Text('View Dossier'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Selected Police Station Pop-up Card
  Widget _buildStationDetailCard(PoliceStationModel st) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4)),
        ],
        border: Border.all(color: const Color(0xFFE5DFD9)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF141413),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.shield_rounded, color: Colors.white, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      st.stationCode,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'CCTNS VERIFIED',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0A7334),
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () => setState(() => _selectedStation = null),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            st.stationName,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF141413)),
          ),
          const SizedBox(height: 2),
          Text(
            '${st.address} • Zone: ${st.jurisdictionZone}',
            style: const TextStyle(fontSize: 11, color: Color(0xFF696969)),
          ),
          const SizedBox(height: 6),
          Text(
            'Helpline: ${st.contactNumber}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFCF4500)),
          ),
        ],
      ),
    );
  }
}
