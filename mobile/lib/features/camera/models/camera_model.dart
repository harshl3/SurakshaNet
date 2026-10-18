class CameraModel {
  final int id;
  final String cameraCode;
  final String? serialNumber;
  final String cameraName;
  final String cameraType;
  final double latitude;
  final double longitude;
  final String? fullAddress;
  final String? area;
  final String? ward;
  final String? zone;
  final String? city;
  final String? state;
  final String? cardinalDirection;
  final double directionAngle;
  final double fovAngle;
  final double coverageRadiusMeters;
  final String? installationDate;
  final String? surveyDate;
  final String cameraStatus;
  final String verificationStatus;
  final String? rejectionReason;
  final String? imageUrl;
  final String? qrCodeUrl;
  final String? ownerName;
  final String? ownerContact;
  final String? ownerType;
  final int? surveyorId;
  final String? surveyorName;
  final int? policeStationId;
  final String? policeStationName;
  final String? createdAt;
  final double? distanceMeters;

  const CameraModel({
    required this.id,
    required this.cameraCode,
    this.serialNumber,
    required this.cameraName,
    required this.cameraType,
    required this.latitude,
    required this.longitude,
    this.fullAddress,
    this.area,
    this.ward,
    this.zone,
    this.city,
    this.state,
    this.cardinalDirection,
    this.directionAngle = 0.0,
    this.fovAngle = 60.0,
    this.coverageRadiusMeters = 100.0,
    this.installationDate,
    this.surveyDate,
    this.cameraStatus = 'ACTIVE',
    this.verificationStatus = 'PENDING',
    this.rejectionReason,
    this.imageUrl,
    this.qrCodeUrl,
    this.ownerName,
    this.ownerContact,
    this.ownerType,
    this.surveyorId,
    this.surveyorName,
    this.policeStationId,
    this.policeStationName,
    this.createdAt,
    this.distanceMeters,
  });

  bool get isApproved => verificationStatus == 'APPROVED';
  bool get isPending => verificationStatus == 'PENDING';
  bool get isRejected => verificationStatus == 'REJECTED';
  bool get isActive => cameraStatus == 'ACTIVE';

  factory CameraModel.fromJson(Map<String, dynamic> json) {
    return CameraModel(
      id: json['id'] as int? ?? 0,
      cameraCode: json['cameraCode'] as String? ?? '',
      serialNumber: json['serialNumber'] as String?,
      cameraName: json['cameraName'] as String? ?? 'Unnamed Camera',
      cameraType: json['cameraType'] as String? ?? 'BULLET',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      fullAddress: json['fullAddress'] as String?,
      area: json['area'] as String?,
      ward: json['ward'] as String?,
      zone: json['zone'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      cardinalDirection: json['cardinalDirection'] as String?,
      directionAngle: (json['directionAngle'] as num?)?.toDouble() ?? 0.0,
      fovAngle: (json['fovAngle'] as num?)?.toDouble() ?? 60.0,
      coverageRadiusMeters: (json['coverageRadiusMeters'] as num?)?.toDouble() ?? 100.0,
      installationDate: json['installationDate'] as String?,
      surveyDate: json['surveyDate'] as String?,
      cameraStatus: json['cameraStatus'] as String? ?? 'ACTIVE',
      verificationStatus: json['verificationStatus'] as String? ?? 'PENDING',
      rejectionReason: json['rejectionReason'] as String?,
      imageUrl: json['imageUrl'] as String?,
      qrCodeUrl: json['qrCodeUrl'] as String?,
      ownerName: json['ownerName'] as String?,
      ownerContact: json['ownerContact'] as String?,
      ownerType: json['ownerType'] as String?,
      surveyorId: json['surveyorId'] as int?,
      surveyorName: json['surveyorName'] as String?,
      policeStationId: json['policeStationId'] as int?,
      policeStationName: json['policeStationName'] as String?,
      createdAt: json['createdAt'] as String?,
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'cameraCode': cameraCode,
      if (serialNumber != null) 'serialNumber': serialNumber,
      'cameraName': cameraName,
      'cameraType': cameraType,
      'latitude': latitude,
      'longitude': longitude,
      if (fullAddress != null) 'fullAddress': fullAddress,
      if (area != null) 'area': area,
      if (ward != null) 'ward': ward,
      if (zone != null) 'zone': zone,
      if (city != null) 'city': city,
      if (state != null) 'state': state,
      if (cardinalDirection != null) 'cardinalDirection': cardinalDirection,
      'directionAngle': directionAngle,
      'fovAngle': fovAngle,
      'coverageRadiusMeters': coverageRadiusMeters,
      if (installationDate != null) 'installationDate': installationDate,
      if (policeStationId != null) 'policeStationId': policeStationId,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (ownerName != null) 'ownerName': ownerName,
      if (ownerContact != null) 'ownerContact': ownerContact,
      if (ownerType != null) 'ownerType': ownerType,
    };
  }
}
