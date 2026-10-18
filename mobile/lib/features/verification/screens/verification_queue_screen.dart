import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/providers/auth_provider.dart';
import '../../camera/models/camera_model.dart';
import '../../camera/providers/camera_provider.dart';
import '../../camera/screens/camera_detail_screen.dart';
import '../providers/verification_provider.dart';

class VerificationQueueScreen extends ConsumerStatefulWidget {
  const VerificationQueueScreen({super.key});

  @override
  ConsumerState<VerificationQueueScreen> createState() => _VerificationQueueScreenState();
}

class _VerificationQueueScreenState extends ConsumerState<VerificationQueueScreen> {
  int? _actioningCameraId;

  Future<void> _handleApproval(CameraModel camera, bool approve) async {
    final reasonController = TextEditingController();

    if (!approve) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Reject Camera Registration'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Specify why "${camera.cameraName}" (${camera.cameraCode}) is being rejected:'),
              const SizedBox(height: 12),
              CustomTextField(
                controller: reasonController,
                label: 'Rejection Reason (Required)',
                hint: 'e.g. Lens obstructed / Inaccurate GPS coordinates',
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.statusOfflineRed),
              onPressed: () {
                if (reasonController.text.trim().isNotEmpty) {
                  Navigator.of(ctx).pop(true);
                }
              },
              child: const Text('Confirm Rejection'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    setState(() => _actioningCameraId = camera.id);

    try {
      await ref.read(cameraRepositoryProvider).approveOrRejectCamera(
            camera.id,
            status: approve ? 'APPROVED' : 'REJECTED',
            reason: approve ? null : reasonController.text.trim(),
          );

      if (mounted) {
        ref.invalidate(verificationQueueProvider);
        ref.invalidate(cameraListProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approve ? 'Camera verified and approved' : 'Camera registration rejected'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification update failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _actioningCameraId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final queueAsync = ref.watch(verificationQueueProvider);

    if (user != null && !user.isAdmin) {
      return Scaffold(
        backgroundColor: AppColors.canvasCream,
        appBar: AppBar(title: const Text('Verification Queue')),
        body: const EmptyStateView(
          title: 'Administrator Access Required',
          message: 'The Verification Queue is restricted to System Administrators (ROLE_ADMIN) for quality assurance and official authorization.',
          icon: Icons.admin_panel_settings_outlined,
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.canvasCream,
      appBar: AppBar(
        title: const Text('Verification Queue'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.refresh(verificationQueueProvider),
          ),
        ],
      ),
      body: queueAsync.when(
        loading: () => const LoadingView(message: 'Loading pending survey submissions...'),
        error: (err, stack) => ErrorStateView(
          message: 'Failed to retrieve pending verification queue',
          details: err.toString(),
          onRetry: () => ref.refresh(verificationQueueProvider),
        ),
        data: (cameras) {
          if (cameras.isEmpty) {
            return const EmptyStateView(
              title: 'Queue is Clear',
              message: 'No CCTV cameras are currently awaiting verification approval.',
              icon: Icons.check_circle_outline_rounded,
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: cameras.length,
            separatorBuilder: (ctx, i) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) {
              final camera = cameras[i];
              final isBusy = _actioningCameraId == camera.id;

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  camera.cameraName,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.inkBlack,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${camera.cameraCode} • ${camera.cameraType}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.signalOrange,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          StatusBadge(status: camera.verificationStatus, isVerification: true),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.person_outline, size: 14, color: AppColors.slateGray),
                          const SizedBox(width: 4),
                          Text(
                            'Surveyor: ${camera.surveyorName ?? "Field Agent"}',
                            style: const TextStyle(fontSize: 12, color: AppColors.slateGray),
                          ),
                          const Spacer(),
                          const Icon(Icons.place_outlined, size: 14, color: AppColors.slateGray),
                          const SizedBox(width: 4),
                          Text(
                            camera.area ?? 'Nagpur',
                            style: const TextStyle(fontSize: 12, color: AppColors.slateGray),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: CustomButton(
                              text: 'Reject',
                              variant: ButtonVariant.danger,
                              height: 40,
                              isLoading: isBusy,
                              onPressed: isBusy ? null : () => _handleApproval(camera, false),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: CustomButton(
                              text: 'Approve',
                              variant: ButtonVariant.primary,
                              height: 40,
                              isLoading: isBusy,
                              onPressed: isBusy ? null : () => _handleApproval(camera, true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (ctx) => CameraDetailScreen(cameraId: camera.id),
                              ),
                            );
                          },
                          child: const Text('Inspect Full Technical Dossier', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
