import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_response.dart';
import '../models/investigation_model.dart';

class InvestigationRepository {
  final ApiClient _apiClient;

  InvestigationRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  Future<PaginatedResponse<InvestigationCaseModel>> getAllCases({
    int page = 0,
    int size = 50,
  }) async {
    final response = await _apiClient.get(
      ApiEndpoints.investigations,
      queryParameters: {
        'page': page,
        'size': size,
      },
    );

    final apiRes = ApiResponse<Map<String, dynamic>>.fromJson(
      response.data as Map<String, dynamic>,
      (raw) => raw as Map<String, dynamic>,
    );

    if (!apiRes.success || apiRes.data == null) {
      throw ApiException(apiRes.message.isNotEmpty ? apiRes.message : 'Failed to fetch investigation cases');
    }

    return PaginatedResponse<InvestigationCaseModel>.fromJson(
      apiRes.data!,
      InvestigationCaseModel.fromJson,
    );
  }

  Future<InvestigationCaseModel> getCaseById(int id) async {
    final response = await _apiClient.get(ApiEndpoints.investigationDetail(id));

    final apiRes = ApiResponse<Map<String, dynamic>>.fromJson(
      response.data as Map<String, dynamic>,
      (raw) => raw as Map<String, dynamic>,
    );

    if (!apiRes.success || apiRes.data == null) {
      throw ApiException(apiRes.message.isNotEmpty ? apiRes.message : 'Investigation case not found');
    }

    return InvestigationCaseModel.fromJson(apiRes.data!);
  }

  Future<InvestigationCaseModel> createCase(Map<String, dynamic> data) async {
    final response = await _apiClient.post(
      ApiEndpoints.investigations,
      data: data,
    );

    final apiRes = ApiResponse<Map<String, dynamic>>.fromJson(
      response.data as Map<String, dynamic>,
      (raw) => raw as Map<String, dynamic>,
    );

    if (!apiRes.success || apiRes.data == null) {
      throw ApiException(apiRes.message.isNotEmpty ? apiRes.message : 'Failed to create investigation case');
    }

    return InvestigationCaseModel.fromJson(apiRes.data!);
  }

  Future<InvestigationCaseModel> attachCameraEvidence(
    int caseId, {
    required int cameraId,
    String? notes,
    String? startTime,
    String? endTime,
    bool isKeyEvidence = false,
  }) async {
    final dataMap = <String, dynamic>{
      'cameraId': cameraId,
      'isKeyEvidence': isKeyEvidence,
    };
    if (notes != null) dataMap['evidenceNotes'] = notes;
    if (startTime != null) dataMap['footageStartTime'] = startTime;
    if (endTime != null) dataMap['footageEndTime'] = endTime;

    final response = await _apiClient.post(
      ApiEndpoints.attachCameraToCase(caseId),
      data: dataMap,
    );

    final apiRes = ApiResponse<Map<String, dynamic>>.fromJson(
      response.data as Map<String, dynamic>,
      (raw) => raw as Map<String, dynamic>,
    );

    if (!apiRes.success || apiRes.data == null) {
      throw ApiException(apiRes.message.isNotEmpty ? apiRes.message : 'Failed to attach camera evidence');
    }

    return InvestigationCaseModel.fromJson(apiRes.data!);
  }
}
