import 'camera_model.dart';

class DuplicateCheckModel {
  final bool isDuplicate;
  final String? duplicateField;
  final String? message;
  final CameraModel? existingCamera;

  const DuplicateCheckModel({
    required this.isDuplicate,
    this.duplicateField,
    this.message,
    this.existingCamera,
  });

  factory DuplicateCheckModel.fromJson(Map<String, dynamic> json) {
    final existingRaw = json['existingCamera'] as Map<String, dynamic>?;
    return DuplicateCheckModel(
      isDuplicate: json['duplicate'] as bool? ?? false,
      duplicateField: json['duplicateField'] as String?,
      message: json['message'] as String?,
      existingCamera: existingRaw != null ? CameraModel.fromJson(existingRaw) : null,
    );
  }
}
