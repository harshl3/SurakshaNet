import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../camera/models/camera_model.dart';
import '../../camera/providers/camera_provider.dart';

final verificationQueueProvider = FutureProvider.autoDispose<List<CameraModel>>((ref) async {
  final repo = ref.watch(cameraRepositoryProvider);
  final res = await repo.searchCameras(
    verificationStatus: 'PENDING',
    size: 100,
  );
  return res.items;
});
