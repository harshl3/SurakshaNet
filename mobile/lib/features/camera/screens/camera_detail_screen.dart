import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/env_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_badge.dart';
import '../models/camera_model.dart';
import '../providers/camera_provider.dart';

class CameraDetailScreen extends ConsumerWidget {
  final int cameraId;

  const CameraDetailScreen({super.key, required this.cameraId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cameraAsync = ref.watch(singleCameraProvider(cameraId));

    return Scaffold(
      backgroundColor: AppColors.canvasCream,
      appBar: AppBar(
        title: const Text('Camera Dossier'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.refresh(singleCameraProvider(cameraId)),
          ),
        ],
      ),
      body: cameraAsync.when(
        loading: () => const LoadingView(message: 'Loading camera dossier...'),
        error: (err, stack) => ErrorStateView(
          message: 'Failed to load camera dossier',
          details: err.toString(),
          onRetry: () => ref.refresh(singleCameraProvider(cameraId)),
        ),
        data: (camera) => _buildDossierContent(context, camera),
      ),
    );
  }

  Widget _buildDossierContent(BuildContext context, CameraModel camera) {
    final resolvedImageUrl = EnvConfig().resolveMediaUrl(camera.imageUrl);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Camera Photo Card / Stadium Frame
          if (resolvedImageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: CachedNetworkImage(
                  imageUrl: resolvedImageUrl,
                  fit: BoxFit.cover,
                  placeholder: (ctx, url) => Container(
                    color: AppColors.softBone,
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.inkBlack),
                    ),
                  ),
                  errorWidget: (ctx, url, error) => Container(
                    color: AppColors.softBone,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image_outlined, size: 36, color: AppColors.slateGray),
                          SizedBox(height: 6),
                          Text(
                            'Snapshot unavailable',
                            style: TextStyle(fontSize: 12, color: AppColors.slateGray),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            Container(
              height: 140,
              decoration: BoxDecoration(
                color: AppColors.softBone,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.subtleBorder),
              ),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.videocam_outlined, size: 40, color: AppColors.slateGray),
                    SizedBox(height: 6),
                    Text(
                      'No site photo uploaded during survey',
                      style: TextStyle(fontSize: 12, color: AppColors.slateGray),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),

          // Primary Identity Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              camera.cameraName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.inkBlack,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Code: ${camera.cameraCode}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.signalOrange,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          StatusBadge(status: camera.verificationStatus, isVerification: true),
                          const SizedBox(height: 6),
                          StatusBadge(status: camera.cameraStatus),
                        ],
                      ),
                    ],
                  ),
                  if (camera.rejectionReason != null && camera.rejectionReason!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.statusOfflineRedLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 16, color: AppColors.statusOfflineRed),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Rejection Reason: ${camera.rejectionReason}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.statusOfflineRed,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Geospatial Coordinates Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Geospatial Positioning',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkBlack,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    'GPS Latitude',
                    '${camera.latitude.toStringAsFixed(6)}° N',
                    onCopy: () => _copyToClipboard(context, camera.latitude.toString(), 'Latitude'),
                  ),
                  _buildDetailRow(
                    'GPS Longitude',
                    '${camera.longitude.toStringAsFixed(6)}° E',
                    onCopy: () => _copyToClipboard(context, camera.longitude.toString(), 'Longitude'),
                  ),
                  _buildDetailRow('Cardinal Facing', camera.cardinalDirection ?? 'North'),
                  _buildDetailRow('Lens Azimuth Angle', '${camera.directionAngle.toInt()}°'),
                  _buildDetailRow('Field of View (FOV)', '${camera.fovAngle.toInt()}°'),
                  _buildDetailRow('Effective Radius', '${camera.coverageRadiusMeters.toInt()} meters'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Technical & Hardware Specifications
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hardware & Jurisdiction',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkBlack,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow('Camera Type', camera.cameraType),
                  _buildDetailRow('Serial Number', camera.serialNumber ?? 'Not Documented'),
                  _buildDetailRow('Police Station', camera.policeStationName ?? 'Unassigned'),
                  _buildDetailRow('Installation Date', camera.installationDate ?? 'Unknown'),
                  _buildDetailRow('Survey Date', camera.surveyDate ?? 'Unknown'),
                  _buildDetailRow('Surveyor', camera.surveyorName ?? 'Officer'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Location & Owner Information
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Location & Ownership Contact',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkBlack,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow('Full Address', camera.fullAddress ?? 'N/A'),
                  _buildDetailRow('Area / Locality', camera.area ?? 'N/A'),
                  _buildDetailRow('City & State', '${camera.city ?? "Nagpur"}, ${camera.state ?? "Maharashtra"}'),
                  _buildDetailRow('Owner / Business', camera.ownerName ?? 'Public Asset'),
                  _buildDetailRow(
                    'Owner Contact',
                    camera.ownerContact ?? 'N/A',
                    onCopy: camera.ownerContact != null
                        ? () => _copyToClipboard(context, camera.ownerContact!, 'Contact')
                        : null,
                  ),
                  _buildDetailRow('Owner Entity Type', camera.ownerType ?? 'Government'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {VoidCallback? onCopy}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.slateGray,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.inkBlack,
              ),
            ),
          ),
          if (onCopy != null)
            GestureDetector(
              onTap: onCopy,
              child: const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.copy_rounded, size: 16, color: AppColors.slateGray),
              ),
            ),
        ],
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard')),
    );
  }
}
