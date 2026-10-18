import '../../camera/models/camera_model.dart';

class InvestigationCaseModel {
  final int id;
  final String caseNumber;
  final String? firNumber;
  final String title;
  final String crimeType;
  final String? crimeLocationName;
  final double latitude;
  final double longitude;
  final String? incidentDate;
  final String? description;
  final String status;
  final int? assignedOfficerId;
  final String? assignedOfficerName;
  final String? assignedOfficerBadge;
  final int? policeStationId;
  final String? policeStationName;
  final List<CameraModel> attachedCameras;
  final String? createdAt;

  const InvestigationCaseModel({
    required this.id,
    required this.caseNumber,
    this.firNumber,
    required this.title,
    required this.crimeType,
    this.crimeLocationName,
    required this.latitude,
    required this.longitude,
    this.incidentDate,
    this.description,
    this.status = 'OPEN',
    this.assignedOfficerId,
    this.assignedOfficerName,
    this.assignedOfficerBadge,
    this.policeStationId,
    this.policeStationName,
    this.attachedCameras = const [],
    this.createdAt,
  });

  bool get isOpen => status == 'OPEN';
  bool get isSolved => status == 'SOLVED';

  factory InvestigationCaseModel.fromJson(Map<String, dynamic> json) {
    final cameraList = json['attachedCameras'] as List<dynamic>? ?? [];
    return InvestigationCaseModel(
      id: json['id'] as int? ?? 0,
      caseNumber: json['caseNumber'] as String? ?? '',
      firNumber: json['firNumber'] as String?,
      title: json['title'] as String? ?? 'Untitled Case',
      crimeType: json['crimeType'] as String? ?? 'Other',
      crimeLocationName: json['crimeLocationName'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      incidentDate: json['incidentDate'] as String?,
      description: json['description'] as String?,
      status: json['status'] as String? ?? 'OPEN',
      assignedOfficerId: json['assignedOfficerId'] as int?,
      assignedOfficerName: json['assignedOfficerName'] as String?,
      assignedOfficerBadge: json['assignedOfficerBadge'] as String?,
      policeStationId: json['policeStationId'] as int?,
      policeStationName: json['policeStationName'] as String?,
      attachedCameras: cameraList
          .whereType<Map<String, dynamic>>()
          .map(CameraModel.fromJson)
          .toList(),
      createdAt: json['createdAt'] as String?,
    );
  }
}
