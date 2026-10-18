import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_badge.dart';
import '../../camera/models/camera_model.dart';
import '../../camera/providers/camera_provider.dart';
import '../../camera/screens/camera_detail_screen.dart';

class CameraMapScreen extends ConsumerStatefulWidget {
  const CameraMapScreen({super.key});

  @override
  ConsumerState<CameraMapScreen> createState() => _CameraMapScreenState();
}

class _CameraMapScreenState extends ConsumerState<CameraMapScreen> {
  final MapController _mapController = MapController();
  LatLng _currentCenter = const LatLng(
    AppConstants.defaultLatitude,
    AppConstants.defaultLongitude,
  );
  CameraModel? _selectedCamera;
  bool _isLocating = false;
  String _selectedStatusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _determinePosition();
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
      _mapController.move(userLatLng, 15.0);
    } catch (e) {
      debugPrint('Location lookup failed: $e');
      setState(() => _isLocating = false);
    }
  }

  Color _getCameraMarkerColor(CameraModel camera) {
    if (camera.verificationStatus == 'PENDING') {
      return AppColors.statusPendingAmber;
    }
    if (camera.cameraStatus == 'OFFLINE' || camera.cameraStatus == 'DAMAGED') {
      return AppColors.statusOfflineRed;
    }
    return AppColors.statusActiveGreen;
  }

  @override
  Widget build(BuildContext context) {
    final cameraListAsync = ref.watch(cameraListProvider);

    return Scaffold(
      backgroundColor: AppColors.canvasCream,
      body: Stack(
        children: [
          cameraListAsync.when(
            loading: () => const LoadingView(message: 'Loading geospatial camera network...'),
            error: (err, stack) => ErrorStateView(
              message: 'Failed to retrieve camera coordinates from backend',
              details: err.toString(),
              onRetry: () => ref.refresh(cameraListProvider),
            ),
            data: (cameras) {
              final filteredCameras = _selectedStatusFilter == 'ALL'
                  ? cameras
                  : cameras.where((c) {
                      if (_selectedStatusFilter == 'PENDING') {
                        return c.verificationStatus == 'PENDING';
                      }
                      return c.cameraStatus == _selectedStatusFilter;
                    }).toList();

              final markers = filteredCameras.map((camera) {
                final markerColor = _getCameraMarkerColor(camera);
                final isSelected = _selectedCamera?.id == camera.id;

                return Marker(
                  point: LatLng(camera.latitude, camera.longitude),
                  width: isSelected ? 48 : 38,
                  height: isSelected ? 48 : 38,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCamera = camera;
                      });
                      _mapController.move(
                        LatLng(camera.latitude, camera.longitude),
                        _mapController.camera.zoom,
                      );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: markerColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? AppColors.inkBlack : AppColors.white,
                          width: isSelected ? 3 : 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: isSelected ? 10 : 4,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.videocam_rounded,
                        color: AppColors.white,
                        size: isSelected ? 24 : 18,
                      ),
                    ),
                  ),
                );
              }).toList();

              return FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _currentCenter,
                  initialZoom: AppConstants.defaultZoom,
                  maxZoom: 18.0,
                  minZoom: 4.0,
                  onTap: (tapPosition, point) {
                    if (_selectedCamera != null) {
                      setState(() => _selectedCamera = null);
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: AppConstants.cartoDbVoyagerTileUrl,
                    subdomains: AppConstants.cartoDbSubdomains,
                    userAgentPackageName: 'com.police.cameramapping',
                  ),
                  MarkerLayer(markers: markers),
                ],
              );
            },
          ),

          // Top Filter Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('All Cameras', 'ALL'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Active (Online)', 'ACTIVE', dotColor: AppColors.statusActiveGreen),
                    const SizedBox(width: 8),
                    _buildFilterChip('Pending Verification', 'PENDING', dotColor: AppColors.statusPendingAmber),
                    const SizedBox(width: 8),
                    _buildFilterChip('Offline', 'OFFLINE', dotColor: AppColors.statusOfflineRed),
                  ],
                ),
              ),
            ),
          ),

          // Floating GPS Center Action
          Positioned(
            right: 16,
            top: 72,
            child: FloatingActionButton.small(
              heroTag: 'map_my_location',
              backgroundColor: AppColors.white,
              foregroundColor: AppColors.inkBlack,
              elevation: 3,
              onPressed: _isLocating ? null : _determinePosition,
              child: _isLocating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.inkBlack),
                    )
                  : const Icon(Icons.my_location_rounded, size: 20),
            ),
          ),

          // Selected Camera Preview Card
          if (_selectedCamera != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: _buildCameraPreviewCard(_selectedCamera!),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, {Color? dotColor}) {
    final isSelected = _selectedStatusFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedStatusFilter = value;
          _selectedCamera = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.inkBlack : AppColors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.inkBlack : AppColors.subtleBorder,
          ),
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
            if (dotColor != null) ...[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.canvasCream : AppColors.inkBlack,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreviewCard(CameraModel camera) {
    return Card(
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.inkBlack,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Code: ${camera.cameraCode} • ${camera.cameraType}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.slateGray,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.slateGray),
                  onPressed: () => setState(() => _selectedCamera = null),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                StatusBadge(status: camera.cameraStatus),
                const SizedBox(width: 8),
                StatusBadge(status: camera.verificationStatus, isVerification: true),
                const Spacer(),
                Text(
                  '${camera.directionAngle.toInt()}° (${camera.cardinalDirection ?? "N"})',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkBlack,
                  ),
                ),
              ],
            ),
            if (camera.fullAddress != null && camera.fullAddress!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.place_outlined, size: 14, color: AppColors.slateGray),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      camera.fullAddress!,
                      style: const TextStyle(fontSize: 12, color: AppColors.slateGray),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: 'View Full Dossier',
                    icon: Icons.assignment_outlined,
                    variant: ButtonVariant.primary,
                    height: 42,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => CameraDetailScreen(cameraId: camera.id),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
