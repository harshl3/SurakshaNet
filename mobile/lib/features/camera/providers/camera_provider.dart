import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/camera_model.dart';
import '../models/duplicate_check_model.dart';
import '../models/owner_summary_model.dart';
import '../repositories/camera_repository.dart';

final cameraRepositoryProvider = Provider<CameraRepository>((ref) {
  return CameraRepository();
});

// Camera search/filter state
class CameraFilterState {
  final String query;
  final String? area;
  final String? status;
  final String? verificationStatus;

  const CameraFilterState({
    this.query = '',
    this.area,
    this.status,
    this.verificationStatus,
  });

  CameraFilterState copyWith({
    String? query,
    String? area,
    String? status,
    String? verificationStatus,
  }) {
    return CameraFilterState(
      query: query ?? this.query,
      area: area ?? this.area,
      status: status ?? this.status,
      verificationStatus: verificationStatus ?? this.verificationStatus,
    );
  }
}

final cameraFilterProvider = StateProvider<CameraFilterState>((ref) {
  return const CameraFilterState();
});

// Camera list FutureProvider
final cameraListProvider = FutureProvider.autoDispose<List<CameraModel>>((ref) async {
  final repo = ref.watch(cameraRepositoryProvider);
  final filter = ref.watch(cameraFilterProvider);

  if (filter.query.isNotEmpty ||
      filter.area != null ||
      filter.status != null ||
      filter.verificationStatus != null) {
    final res = await repo.searchCameras(
      query: filter.query.isNotEmpty ? filter.query : null,
      area: filter.area,
      status: filter.status,
      verificationStatus: filter.verificationStatus,
      size: 100,
    );
    return res.items;
  }

  final res = await repo.getCameras(size: 100);
  return res.items;
});

// Single camera detail
final singleCameraProvider = FutureProvider.family.autoDispose<CameraModel, int>((ref, id) async {
  final repo = ref.watch(cameraRepositoryProvider);
  return repo.getCameraById(id);
});

// Proximity search parameters
class ProximityParams {
  final double latitude;
  final double longitude;
  final double radiusMeters;

  const ProximityParams({
    required this.latitude,
    required this.longitude,
    this.radiusMeters = 500,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProximityParams &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          radiusMeters == other.radiusMeters;

  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode ^ radiusMeters.hashCode;
}

final nearbyCamerasProvider = FutureProvider.family
    .autoDispose<List<CameraModel>, ProximityParams>((ref, params) async {
  final repo = ref.watch(cameraRepositoryProvider);
  return repo.getNearbyCameras(
    latitude: params.latitude,
    longitude: params.longitude,
    radiusMeters: params.radiusMeters,
  );
});

// Registration & Survey State
class CameraRegistrationState {
  final bool isSubmitting;
  final bool isUploadingPhoto;
  final String? uploadedPhotoUrl;
  final DuplicateCheckModel? duplicateStatus;
  final OwnerSummaryModel? ownerSummary;
  final String? errorMessage;
  final CameraModel? registeredCamera;

  const CameraRegistrationState({
    this.isSubmitting = false,
    this.isUploadingPhoto = false,
    this.uploadedPhotoUrl,
    this.duplicateStatus,
    this.ownerSummary,
    this.errorMessage,
    this.registeredCamera,
  });

  CameraRegistrationState copyWith({
    bool? isSubmitting,
    bool? isUploadingPhoto,
    String? uploadedPhotoUrl,
    DuplicateCheckModel? duplicateStatus,
    OwnerSummaryModel? ownerSummary,
    String? errorMessage,
    CameraModel? registeredCamera,
  }) {
    return CameraRegistrationState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isUploadingPhoto: isUploadingPhoto ?? this.isUploadingPhoto,
      uploadedPhotoUrl: uploadedPhotoUrl ?? this.uploadedPhotoUrl,
      duplicateStatus: duplicateStatus ?? this.duplicateStatus,
      ownerSummary: ownerSummary ?? this.ownerSummary,
      errorMessage: errorMessage,
      registeredCamera: registeredCamera ?? this.registeredCamera,
    );
  }
}

class CameraRegistrationNotifier extends StateNotifier<CameraRegistrationState> {
  final CameraRepository _repository;

  CameraRegistrationNotifier(this._repository)
      : super(const CameraRegistrationState());

  Future<void> checkDuplicate({String? serialNumber, String? cameraCode}) async {
    try {
      final res = await _repository.checkDuplicate(
        serialNumber: serialNumber,
        cameraCode: cameraCode,
      );
      state = state.copyWith(duplicateStatus: res);
    } catch (e) {
      // Non-blocking duplicate check error
    }
  }

  Future<void> lookupOwner(String contact) async {
    if (contact.trim().length < 8) return;
    try {
      final res = await _repository.lookupOwner(contact);
      state = state.copyWith(ownerSummary: res);
    } catch (e) {
      // Non-blocking owner lookup error
    }
  }

  Future<String?> uploadPhoto(File file) async {
    state = state.copyWith(isUploadingPhoto: true, errorMessage: null);
    try {
      final url = await _repository.uploadPhoto(file);
      state = state.copyWith(
        isUploadingPhoto: false,
        uploadedPhotoUrl: url,
      );
      return url;
    } catch (e) {
      state = state.copyWith(
        isUploadingPhoto: false,
        errorMessage: 'Photo upload failed: $e',
      );
      return null;
    }
  }

  Future<CameraModel?> submitCamera(Map<String, dynamic> data) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      final camera = await _repository.createCamera(data);
      state = state.copyWith(
        isSubmitting: false,
        registeredCamera: camera,
      );
      return camera;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString(),
      );
      return null;
    }
  }

  void reset() {
    state = const CameraRegistrationState();
  }
}

final cameraRegistrationProvider =
    StateNotifierProvider.autoDispose<CameraRegistrationNotifier, CameraRegistrationState>(
  (ref) {
    final repo = ref.watch(cameraRepositoryProvider);
    return CameraRegistrationNotifier(repo);
  },
);
