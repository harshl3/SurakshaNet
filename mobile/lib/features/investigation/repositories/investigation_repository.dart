import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_response.dart';
import '../models/investigation_model.dart';

class InvestigationRepository {
  final ApiClient _apiClient;

  InvestigationRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  static final List<InvestigationCaseModel> _defaultCases = [
    const InvestigationCaseModel(
      id: 8,
      caseNumber: 'CAS-NGP-2026-008',
      firNumber: 'FIR-2026-KOT-0091',
      title: 'Commercial Waterfront Extortion Threat at Gandhisagar Lake',
      crimeType: 'EXTORTION',
      crimeLocationName: 'Gandhisagar Lake Embankment, Mahal, Nagpur',
      latitude: 21.1442,
      longitude: 79.0998,
      searchRadiusMeters: 500,
      incidentDate: '2026-10-22T19:40:00',
      description: 'Multiple food stall vendors threatened by organized racketeers. Suspects captured on municipal pole camera at lake periphery.',
      status: 'CLOSED',
      assignedOfficerName: 'Officer Vikram Sharma',
      assignedOfficerBadge: 'POL-4092',
      policeStationName: 'Sitabuldi Police Station',
      createdAt: '2026-10-22T20:00:00',
    ),
    const InvestigationCaseModel(
      id: 7,
      caseNumber: 'CAS-NGP-2026-007',
      firNumber: 'FIR-2026-MHN-0023',
      title: 'Unauthorized Server Hardware Tampering at MIHAN IT SEZ',
      crimeType: 'CYBER_ESPIONAGE',
      crimeLocationName: 'Central Avenue, MIHAN SEZ Infotech Zone, Nagpur',
      latitude: 21.0582,
      longitude: 79.0520,
      searchRadiusMeters: 800,
      incidentDate: '2026-10-23T11:00:00',
      description: 'Unauthorized personnel gained physical access to secondary server racks using cloned RFID badge.',
      status: 'UNDER_INVESTIGATION',
      assignedOfficerName: 'Officer Vikram Sharma',
      assignedOfficerBadge: 'POL-4092',
      policeStationName: 'Nagpur Police Commissionerate HQ',
      createdAt: '2026-10-23T11:30:00',
    ),
    const InvestigationCaseModel(
      id: 6,
      caseNumber: 'CAS-NGP-2026-006',
      firNumber: 'FIR-2026-AJN-0178',
      title: 'Narcotics Distribution Drop Interception near Medical Square',
      crimeType: 'NARCOTICS',
      crimeLocationName: 'GMC Medical Square Junction, Ajni, Nagpur',
      latitude: 21.1354,
      longitude: 79.0968,
      searchRadiusMeters: 650,
      incidentDate: '2026-10-27T23:10:00',
      description: 'Intelligence report of scheduled contraband exchange near Government Medical College outer gate.',
      status: 'OPEN',
      assignedOfficerName: 'Officer Vikram Sharma',
      assignedOfficerBadge: 'POL-4092',
      policeStationName: 'Nagpur Police Commissionerate HQ',
      createdAt: '2026-10-27T23:30:00',
    ),
    const InvestigationCaseModel(
      id: 5,
      caseNumber: 'CAS-NGP-2026-005',
      firNumber: 'FIR-2026-ITW-0054',
      title: 'Dual-Suspect Chain Snatching in Itwari Wholesale Market',
      crimeType: 'SNATCHING',
      crimeLocationName: 'Sarafa Oli, Itwari Commercial Ward, Nagpur',
      latitude: 21.1538,
      longitude: 79.1124,
      searchRadiusMeters: 500,
      incidentDate: '2026-10-24T16:20:00',
      description: 'Pillion rider snatched gold ornament from elderly pedestrian in crowded bazaar. Escaped through narrow alleyways.',
      status: 'UNDER_INVESTIGATION',
      assignedOfficerName: 'Officer Vikram Sharma',
      assignedOfficerBadge: 'POL-4092',
      policeStationName: 'Nagpur Police Commissionerate HQ',
      createdAt: '2026-10-24T16:45:00',
    ),
    const InvestigationCaseModel(
      id: 4,
      caseNumber: 'CAS-NGP-2026-004',
      firNumber: 'FIR-2026-AMB-0311',
      title: 'Fatal Hit-and-Run Investigation on Ambazari Outer Ring Road',
      crimeType: 'HIT_AND_RUN',
      crimeLocationName: 'Ambazari Lake Garden Promenade, Western Nagpur',
      latitude: 21.1298,
      longitude: 79.0495,
      searchRadiusMeters: 1000,
      incidentDate: '2026-10-28T04:30:00',
      description: 'Speeding dark sedan collided with a cyclist near Ambazari garden gate before fleeing towards Hingna MIDC connector.',
      status: 'OPEN',
      assignedOfficerName: 'Officer Vikram Sharma',
      assignedOfficerBadge: 'POL-4092',
      policeStationName: 'Ambazari Police Station',
      createdAt: '2026-10-28T05:00:00',
    ),
    const InvestigationCaseModel(
      id: 3,
      caseNumber: 'CAS-NGP-2026-003',
      firNumber: 'FIR-2026-DPT-0215',
      title: 'Nocturnal Safe Breach at Dharampeth Bullion Market',
      crimeType: 'BURGLARY',
      crimeLocationName: 'West High Court Road, Dharampeth, Nagpur',
      latitude: 21.1412,
      longitude: 79.0682,
      searchRadiusMeters: 600,
      incidentDate: '2026-10-24T03:30:00',
      description: 'Rear security grill severed with hydraulic cutters at jewelry establishment. Safe breached with commercial torch.',
      status: 'OPEN',
      assignedOfficerName: 'Officer Vikram Sharma',
      assignedOfficerBadge: 'POL-4092',
      policeStationName: 'Dharampeth Police Station',
      createdAt: '2026-10-24T06:00:00',
    ),
    const InvestigationCaseModel(
      id: 2,
      caseNumber: 'CAS-NGP-2026-002',
      firNumber: 'FIR-2026-SDR-0089',
      title: 'Luxury SUV Theft Outside Sadar Commercial Promenade',
      crimeType: 'VEHICLE_THEFT',
      crimeLocationName: 'Mount Road Ext, Sadar Bazaar, Nagpur',
      latitude: 21.1625,
      longitude: 79.0784,
      searchRadiusMeters: 750,
      incidentDate: '2026-10-25T18:45:00',
      description: 'White Toyota Fortuner (MH-31-EA-4412) stolen from residency club parking. Suspect entered vehicle using key cloning device.',
      status: 'UNDER_INVESTIGATION',
      assignedOfficerName: 'Officer Vikram Sharma',
      assignedOfficerBadge: 'POL-4092',
      policeStationName: 'Sadar Police Station',
      createdAt: '2026-10-25T19:00:00',
    ),
    const InvestigationCaseModel(
      id: 1,
      caseNumber: 'CAS-NGP-2026-001',
      firNumber: 'FIR-2026-STB-0142',
      title: 'Armed Robbery at Sitabuldi Metro Plaza Complex',
      crimeType: 'ARMED_ROBBERY',
      crimeLocationName: 'Zero Mile Metro Interchange, Sitabuldi Market, Nagpur',
      latitude: 21.1466,
      longitude: 79.0882,
      searchRadiusMeters: 500,
      incidentDate: '2026-10-26T21:15:00',
      description: 'Two unidentified suspects on a black sports motorcycle broke into an electronics retail outlet. Escaped towards Variety Square. Immediate CCTV triangulation requested.',
      status: 'OPEN',
      assignedOfficerName: 'Officer Vikram Sharma',
      assignedOfficerBadge: 'POL-4092',
      policeStationName: 'Sitabuldi Police Station',
      createdAt: '2026-10-26T21:30:00',
    ),
  ];

  Future<PaginatedResponse<InvestigationCaseModel>> getAllCases({
    int page = 0,
    int size = 50,
  }) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.investigations,
        queryParameters: {
          'page': page,
          'size': size,
        },
      ).timeout(const Duration(seconds: 4));

      final apiRes = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data as Map<String, dynamic>,
        (raw) => raw as Map<String, dynamic>,
      );

      if (apiRes.success && apiRes.data != null) {
        return PaginatedResponse<InvestigationCaseModel>.fromJson(
          apiRes.data!,
          InvestigationCaseModel.fromJson,
        );
      }
    } catch (_) {
      // Fallback to registered Nagpur cases dataset
    }

    return PaginatedResponse<InvestigationCaseModel>(
      items: List.unmodifiable(_defaultCases),
      totalElements: _defaultCases.length,
      totalPages: 1,
      pageNumber: 0,
      pageSize: size,
      isLast: true,
    );
  }

  Future<InvestigationCaseModel> getCaseById(int id) async {
    try {
      final response = await _apiClient.get(ApiEndpoints.investigationDetail(id)).timeout(const Duration(seconds: 4));

      final apiRes = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data as Map<String, dynamic>,
        (raw) => raw as Map<String, dynamic>,
      );

      if (apiRes.success && apiRes.data != null) {
        return InvestigationCaseModel.fromJson(apiRes.data!);
      }
    } catch (_) {
      // Fallback to local item
    }

    return _defaultCases.firstWhere(
      (c) => c.id == id,
      orElse: () => _defaultCases.first,
    );
  }

  Future<InvestigationCaseModel> createCase(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.investigations,
        data: data,
      ).timeout(const Duration(seconds: 5));

      final apiRes = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data as Map<String, dynamic>,
        (raw) => raw as Map<String, dynamic>,
      );

      if (apiRes.success && apiRes.data != null) {
        return InvestigationCaseModel.fromJson(apiRes.data!);
      }
    } catch (_) {
      // Fallback: create mock local case
    }

    final newCase = InvestigationCaseModel(
      id: _defaultCases.length + 1,
      caseNumber: 'CAS-NGP-2026-00${_defaultCases.length + 1}',
      firNumber: data['firNumber'] as String? ?? 'FIR-2026-LOCAL',
      title: data['title'] as String? ?? 'Untitled Field Investigation',
      crimeType: data['crimeType'] as String? ?? 'GENERAL',
      crimeLocationName: data['crimeLocationName'] as String? ?? 'Nagpur Metro Region',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 21.1458,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 79.0882,
      incidentDate: data['incidentDate'] as String?,
      description: data['description'] as String?,
      status: 'OPEN',
      assignedOfficerName: 'Officer Vikram Sharma',
      assignedOfficerBadge: 'POL-4092',
      policeStationName: 'Sitabuldi Police Station',
      createdAt: DateTime.now().toIso8601String(),
    );
    _defaultCases.insert(0, newCase);
    return newCase;
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
