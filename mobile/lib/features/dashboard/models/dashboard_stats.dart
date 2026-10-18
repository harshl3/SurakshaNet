class DashboardStats {
  final int totalCameras;
  final int activeCameras;
  final int offlineCameras;
  final int pendingVerificationCameras;
  final int verifiedCameras;
  final int totalPoliceStations;
  final int totalUsers;
  final int totalInvestigationCases;
  final int openCases;

  const DashboardStats({
    this.totalCameras = 0,
    this.activeCameras = 0,
    this.offlineCameras = 0,
    this.pendingVerificationCameras = 0,
    this.verifiedCameras = 0,
    this.totalPoliceStations = 0,
    this.totalUsers = 0,
    this.totalInvestigationCases = 0,
    this.openCases = 0,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalCameras: (json['totalCameras'] as num?)?.toInt() ?? 0,
      activeCameras: (json['activeCameras'] as num?)?.toInt() ?? 0,
      offlineCameras: (json['offlineCameras'] as num?)?.toInt() ?? 0,
      pendingVerificationCameras: (json['pendingVerificationCameras'] as num?)?.toInt() ?? 0,
      verifiedCameras: (json['verifiedCameras'] as num?)?.toInt() ?? 0,
      totalPoliceStations: (json['totalPoliceStations'] as num?)?.toInt() ?? 0,
      totalUsers: (json['totalUsers'] as num?)?.toInt() ?? 0,
      totalInvestigationCases: (json['totalInvestigationCases'] as num?)?.toInt() ?? 0,
      openCases: (json['openCases'] as num?)?.toInt() ?? 0,
    );
  }
}
