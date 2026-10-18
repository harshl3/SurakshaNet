class ApiEndpoints {
  // Public
  static const String health = '/health';
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String register = '/auth/register';

  // Dashboard KPI
  static const String dashboardStats = '/dashboard/stats';

  // Cameras
  static const String cameras = '/cameras';
  static String cameraDetail(int id) => '/cameras/$id';
  static String cameraByCode(String code) => '/cameras/code/$code';
  static const String cameraSearch = '/cameras/search';
  static const String cameraNearby = '/cameras/nearby';
  static const String ownerLookup = '/cameras/owner-lookup';
  static const String checkDuplicate = '/cameras/check-duplicate';
  static String cameraApproval(int id) => '/cameras/$id/approval';

  // Investigations
  static const String investigations = '/investigations';
  static String investigationDetail(int id) => '/investigations/$id';
  static String attachCameraToCase(int caseId) => '/investigations/$caseId/cameras';

  // Media
  static const String mediaUpload = '/media/upload';
  static String mediaServe(String fileName) => '/media/$fileName';
}
