import 'dart:io';
import 'package:dio/dio.dart';
import '../../../core/config/env_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_response.dart';
import '../models/camera_model.dart';
import '../models/duplicate_check_model.dart';
import '../models/owner_summary_model.dart';

class CameraRepository {
  final ApiClient _apiClient;

  CameraRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  Future<PaginatedResponse<CameraModel>> getCameras({
    int page = 0,
    int size = 20,
    String sortBy = 'createdAt',
    String sortDir = 'DESC',
  }) async {
    final response = await _apiClient.get(
      ApiEndpoints.cameras,
      queryParameters: {
        'page': page,
        'size': size,
        'sortBy': sortBy,
        'sortDir': sortDir,
      },
    );

    final apiRes = ApiResponse<Map<String, dynamic>>.fromJson(
      response.data as Map<String, dynamic>,
      (raw) => raw as Map<String, dynamic>,
    );

    if (!apiRes.success || apiRes.data == null) {
      throw ApiException(apiRes.message.isNotEmpty ? apiRes.message : 'Failed to load cameras');
    }

    return PaginatedResponse<CameraModel>.fromJson(
      apiRes.data!,
      CameraModel.fromJson,
    );
  }

  Future<PaginatedResponse<CameraModel>> searchCameras({
    String? query,
    String? area,
    String? status,
    String? verificationStatus,
    int page = 0,
    int size = 50,
  }) async {
    final Map<String, dynamic> params = {
      'page': page,
      'size': size,
    };
    if (query != null && query.isNotEmpty) params['query'] = query;
    if (area != null && area.isNotEmpty) params['area'] = area;
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (verificationStatus != null && verificationStatus.isNotEmpty) {
      params['verificationStatus'] = verificationStatus;
    }

    final response = await _apiClient.get(
      ApiEndpoints.cameraSearch,
      queryParameters: params,
    );

    final apiRes = ApiResponse<Map<String, dynamic>>.fromJson(
      response.data as Map<String, dynamic>,
      (raw) => raw as Map<String, dynamic>,
    );

    if (!apiRes.success || apiRes.data == null) {
      throw ApiException(apiRes.message.isNotEmpty ? apiRes.message : 'Camera search failed');
    }

    return PaginatedResponse<CameraModel>.fromJson(
      apiRes.data!,
      CameraModel.fromJson,
    );
  }

  Future<List<CameraModel>> getNearbyCameras({
    required double latitude,
    required double longitude,
    double radiusMeters = 500,
  }) async {
    final response = await _apiClient.get(
      ApiEndpoints.cameraNearby,
      queryParameters: {
        'latitude': latitude,
        'longitude': longitude,
        'radiusMeters': radiusMeters,
      },
    );

    final apiRes = ApiResponse<List<dynamic>>.fromJson(
      response.data as Map<String, dynamic>,
      (raw) => raw as List<dynamic>,
    );

    if (!apiRes.success || apiRes.data == null) {
      throw ApiException(apiRes.message.isNotEmpty ? apiRes.message : 'Proximity search failed');
    }

    return apiRes.data!
        .whereType<Map<String, dynamic>>()
        .map(CameraModel.fromJson)
        .toList();
  }

  Future<CameraModel> getCameraById(int id) async {
    final response = await _apiClient.get(ApiEndpoints.cameraDetail(id));

    final apiRes = ApiResponse<Map<String, dynamic>>.fromJson(
      response.data as Map<String, dynamic>,
      (raw) => raw as Map<String, dynamic>,
    );

    if (!apiRes.success || apiRes.data == null) {
      throw ApiException(apiRes.message.isNotEmpty ? apiRes.message : 'Camera not found');
    }

    return CameraModel.fromJson(apiRes.data!);
  }

  Future<CameraModel> getCameraByCode(String code) async {
    final response = await _apiClient.get(ApiEndpoints.cameraByCode(code.trim()));

    final apiRes = ApiResponse<Map<String, dynamic>>.fromJson(
      response.data as Map<String, dynamic>,
      (raw) => raw as Map<String, dynamic>,
    );

    if (!apiRes.success || apiRes.data == null) {
      throw ApiException(apiRes.message.isNotEmpty ? apiRes.message : 'Camera not found for code: $code');
    }

    return CameraModel.fromJson(apiRes.data!);
  }

  Future<DuplicateCheckModel> checkDuplicate({
    String? serialNumber,
    String? cameraCode,
  }) async {
    final params = <String, dynamic>{};
    if (serialNumber != null && serialNumber.isNotEmpty) {
      params['serialNumber'] = serialNumber.trim();
    }
    if (cameraCode != null && cameraCode.isNotEmpty) {
      params['cameraCode'] = cameraCode.trim();
    }

    final response = await _apiClient.get(
      ApiEndpoints.checkDuplicate,
      queryParameters: params,
    );

    final apiRes = ApiResponse<Map<String, dynamic>>.fromJson(
      response.data as Map<String, dynamic>,
      (raw) => raw as Map<String, dynamic>,
    );

    if (!apiRes.success || apiRes.data == null) {
      throw ApiException(apiRes.message.isNotEmpty ? apiRes.message : 'Duplicate check failed');
    }

    return DuplicateCheckModel.fromJson(apiRes.data!);
  }

  Future<OwnerSummaryModel> lookupOwner(String contact) async {
    final response = await _apiClient.get(
      ApiEndpoints.ownerLookup,
      queryParameters: {'contact': contact.trim()},
    );

    final apiRes = ApiResponse<Map<String, dynamic>>.fromJson(
      response.data as Map<String, dynamic>,
      (raw) => raw as Map<String, dynamic>,
    );

    if (!apiRes.success || apiRes.data == null) {
      throw ApiException(apiRes.message.isNotEmpty ? apiRes.message : 'Owner lookup failed');
    }

    return OwnerSummaryModel.fromJson(apiRes.data!);
  }

  Future<CameraModel> createCamera(Map<String, dynamic> data) async {
    final response = await _apiClient.post(
      ApiEndpoints.cameras,
      data: data,
    );

    final apiRes = ApiResponse<Map<String, dynamic>>.fromJson(
      response.data as Map<String, dynamic>,
      (raw) => raw as Map<String, dynamic>,
    );

    if (!apiRes.success || apiRes.data == null) {
      throw ApiException(apiRes.message.isNotEmpty ? apiRes.message : 'Failed to register camera');
    }

    return CameraModel.fromJson(apiRes.data!);
  }

  Future<String> uploadPhoto(File file) async {
    final fileName = file.path.split(Platform.pathSeparator).last;
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: fileName),
    });

    final response = await _apiClient.post(
      ApiEndpoints.mediaUpload,
      data: formData,
    );

    final apiRes = ApiResponse<Map<String, dynamic>>.fromJson(
      response.data as Map<String, dynamic>,
      (raw) => raw as Map<String, dynamic>,
    );

    if (!apiRes.success || apiRes.data == null) {
      throw ApiException(apiRes.message.isNotEmpty ? apiRes.message : 'Photo upload failed');
    }

    final rawUrl = apiRes.data!['url'] as String? ?? '';
    // Resolve relative URL against active backend base
    return EnvConfig().resolveMediaUrl(rawUrl);
  }

  Future<CameraModel> approveOrRejectCamera(
    int id, {
    required String status,
    String? reason,
  }) async {
    final response = await _apiClient.patch(
      ApiEndpoints.cameraApproval(id),
      data: {
        'verificationStatus': status,
        if (reason != null && reason.isNotEmpty) 'rejectionReason': reason,
      },
    );

    final apiRes = ApiResponse<Map<String, dynamic>>.fromJson(
      response.data as Map<String, dynamic>,
      (raw) => raw as Map<String, dynamic>,
    );

    if (!apiRes.success || apiRes.data == null) {
      throw ApiException(apiRes.message.isNotEmpty ? apiRes.message : 'Approval update failed');
    }

    return CameraModel.fromJson(apiRes.data!);
  }
}
