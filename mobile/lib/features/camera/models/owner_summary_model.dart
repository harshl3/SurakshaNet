import 'camera_model.dart';

class OwnerSummaryModel {
  final bool ownerFound;
  final String? ownerName;
  final String? ownerContact;
  final String? maskedContact;
  final String? ownerType;
  final int totalCameras;
  final int approvedCount;
  final int pendingCount;
  final int rejectedCount;
  final List<CameraModel> cameras;

  const OwnerSummaryModel({
    required this.ownerFound,
    this.ownerName,
    this.ownerContact,
    this.maskedContact,
    this.ownerType,
    this.totalCameras = 0,
    this.approvedCount = 0,
    this.pendingCount = 0,
    this.rejectedCount = 0,
    this.cameras = const [],
  });

  factory OwnerSummaryModel.fromJson(Map<String, dynamic> json) {
    final cameraList = json['cameras'] as List<dynamic>? ?? [];
    return OwnerSummaryModel(
      ownerFound: json['ownerFound'] as bool? ?? false,
      ownerName: json['ownerName'] as String?,
      ownerContact: json['ownerContact'] as String?,
      maskedContact: json['maskedContact'] as String?,
      ownerType: json['ownerType'] as String?,
      totalCameras: json['totalCameras'] as int? ?? 0,
      approvedCount: (json['approvedCount'] as num?)?.toInt() ?? 0,
      pendingCount: (json['pendingCount'] as num?)?.toInt() ?? 0,
      rejectedCount: (json['rejectedCount'] as num?)?.toInt() ?? 0,
      cameras: cameraList
          .whereType<Map<String, dynamic>>()
          .map(CameraModel.fromJson)
          .toList(),
    );
  }
}
