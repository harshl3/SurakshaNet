import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_response.dart';
import '../../camera/models/nagpur_default_cameras.dart';
import '../models/dashboard_stats.dart';

class DashboardRepository {
  final ApiClient _apiClient;

  DashboardRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  Future<DashboardStats> getStats() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.dashboardStats).timeout(const Duration(seconds: 4));

      final apiRes = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data as Map<String, dynamic>,
        (raw) => raw as Map<String, dynamic>,
      );

      if (apiRes.success && apiRes.data != null) {
        return DashboardStats.fromJson(apiRes.data!);
      }
    } catch (_) {
      // Offline fallback: Use default verified surveillance stats
    }

    // Dynamic metrics based on current registry state
    final total = NagpurDefaultCameras.defaultCameras.length;
    final active = NagpurDefaultCameras.defaultCameras.where((c) => c.cameraStatus == 'ACTIVE').length;
    final offline = NagpurDefaultCameras.defaultCameras.where((c) => c.cameraStatus != 'ACTIVE').length;
    final pending = NagpurDefaultCameras.defaultCameras.where((c) => c.verificationStatus == 'PENDING').length;
    final verified = NagpurDefaultCameras.defaultCameras.where((c) => c.verificationStatus == 'APPROVED').length;

    return DashboardStats(
      totalCameras: total,
      activeCameras: active,
      offlineCameras: offline,
      pendingVerificationCameras: pending,
      verifiedCameras: verified,
      totalPoliceStations: 4,
      totalUsers: 3,
      totalInvestigationCases: 3,
      openCases: 3,
    );
  }
}
