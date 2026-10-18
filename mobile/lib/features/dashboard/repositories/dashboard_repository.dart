import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_response.dart';
import '../models/dashboard_stats.dart';

class DashboardRepository {
  final ApiClient _apiClient;

  DashboardRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  Future<DashboardStats> getStats() async {
    final response = await _apiClient.get(ApiEndpoints.dashboardStats);

    final apiRes = ApiResponse<Map<String, dynamic>>.fromJson(
      response.data as Map<String, dynamic>,
      (raw) => raw as Map<String, dynamic>,
    );

    if (!apiRes.success || apiRes.data == null) {
      throw ApiException(apiRes.message.isNotEmpty ? apiRes.message : 'Failed to fetch dashboard statistics');
    }

    return DashboardStats.fromJson(apiRes.data!);
  }
}
