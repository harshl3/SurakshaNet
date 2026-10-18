class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;
  final dynamic errors;
  final String? timestamp;

  const ApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.errors,
    this.timestamp,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic rawData)? fromJsonT,
  ) {
    final rawData = json['data'];
    T? parsedData;
    if (rawData != null && fromJsonT != null) {
      try {
        parsedData = fromJsonT(rawData);
      } catch (_) {
        parsedData = null;
      }
    } else if (rawData is T) {
      parsedData = rawData;
    }

    return ApiResponse<T>(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: parsedData,
      errors: json['errors'],
      timestamp: json['timestamp'] as String?,
    );
  }
}

class PaginatedResponse<T> {
  final List<T> items;
  final int totalElements;
  final int totalPages;
  final int pageNumber;
  final int pageSize;
  final bool isLast;

  const PaginatedResponse({
    required this.items,
    required this.totalElements,
    required this.totalPages,
    required this.pageNumber,
    required this.pageSize,
    required this.isLast,
  });

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemMapper,
  ) {
    final contentList = json['content'] as List<dynamic>? ?? [];
    final items = contentList
        .whereType<Map<String, dynamic>>()
        .map(itemMapper)
        .toList();

    return PaginatedResponse<T>(
      items: items,
      totalElements: json['totalElements'] as int? ?? items.length,
      totalPages: json['totalPages'] as int? ?? 1,
      pageNumber: json['number'] as int? ?? 0,
      pageSize: json['size'] as int? ?? items.length,
      isLast: json['last'] as bool? ?? true,
    );
  }
}
