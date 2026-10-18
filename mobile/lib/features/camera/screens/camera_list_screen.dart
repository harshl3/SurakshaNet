import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_badge.dart';
import '../models/camera_model.dart';
import '../providers/camera_provider.dart';
import 'camera_detail_screen.dart';

class CameraListScreen extends ConsumerStatefulWidget {
  const CameraListScreen({super.key});

  @override
  ConsumerState<CameraListScreen> createState() => _CameraListScreenState();
}

class _CameraListScreenState extends ConsumerState<CameraListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    ref.read(cameraFilterProvider.notifier).update(
      (state) => state.copyWith(query: val.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cameraListAsync = ref.watch(cameraListProvider);
    final filter = ref.watch(cameraFilterProvider);

    return Scaffold(
      backgroundColor: AppColors.canvasCream,
      appBar: AppBar(
        title: const Text('Camera Directory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.refresh(cameraListProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search by camera code, area, or name...',
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.slateGray),
                suffixIcon: filter.query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          // Quick Filter Pills
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTypeChip('All Status', null),
                  const SizedBox(width: 8),
                  _buildTypeChip('Active', 'ACTIVE'),
                  const SizedBox(width: 8),
                  _buildTypeChip('Pending Approval', 'PENDING', isVerification: true),
                  const SizedBox(width: 8),
                  _buildTypeChip('Offline', 'OFFLINE'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Camera List
          Expanded(
            child: cameraListAsync.when(
              loading: () => const LoadingView(message: 'Loading verified camera directory...'),
              error: (err, stack) => ErrorStateView(
                message: 'Failed to fetch camera directory',
                details: err.toString(),
                onRetry: () => ref.refresh(cameraListProvider),
              ),
              data: (cameras) {
                if (cameras.isEmpty) {
                  return EmptyStateView(
                    title: 'No Cameras Found',
                    message: filter.query.isNotEmpty
                        ? 'No camera records matching "${filter.query}"'
                        : 'No CCTV cameras have been registered yet.',
                    icon: Icons.videocam_off_outlined,
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: cameras.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final camera = cameras[i];
                    return _buildCameraCard(context, camera);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(String label, String? value, {bool isVerification = false}) {
    final current = isVerification
        ? ref.watch(cameraFilterProvider).verificationStatus
        : ref.watch(cameraFilterProvider).status;
    final isSelected = current == value;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        ref.read(cameraFilterProvider.notifier).update((state) {
          if (isVerification) {
            return state.copyWith(verificationStatus: selected ? value : null);
          } else {
            return state.copyWith(status: selected ? value : null);
          }
        });
      },
      selectedColor: AppColors.inkBlack,
      backgroundColor: AppColors.white,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: isSelected ? AppColors.canvasCream : AppColors.inkBlack,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.subtleBorder),
      ),
      showCheckmark: false,
    );
  }

  Widget _buildCameraCard(BuildContext context, CameraModel camera) {
    return Card(
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => CameraDetailScreen(cameraId: camera.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.softBone,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.videocam_rounded,
                      color: AppColors.inkBlack,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${camera.cameraCode} • ${camera.cameraType}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.slateGray,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(status: camera.verificationStatus, isVerification: true),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  StatusBadge(status: camera.cameraStatus),
                  const SizedBox(width: 10),
                  if (camera.area != null && camera.area!.isNotEmpty) ...[
                    const Icon(Icons.location_city_outlined, size: 14, color: AppColors.slateGray),
                    const SizedBox(width: 4),
                    Text(
                      camera.area!,
                      style: const TextStyle(fontSize: 12, color: AppColors.slateGray),
                    ),
                  ],
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.slateGray),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
