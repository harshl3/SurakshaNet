import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/state_views.dart';
import '../models/investigation_model.dart';
import '../providers/investigation_provider.dart';
import 'investigation_create_screen.dart';
import 'investigation_detail_screen.dart';

class InvestigationListScreen extends ConsumerWidget {
  const InvestigationListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caseListAsync = ref.watch(investigationListProvider);

    return Scaffold(
      backgroundColor: AppColors.canvasCream,
      appBar: AppBar(
        title: const Text('Investigation Cases'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.refresh(investigationListProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.inkBlack,
        foregroundColor: AppColors.canvasCream,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Case (GIS Match)'),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => const InvestigationCreateScreen(),
            ),
          );
        },
      ),
      body: caseListAsync.when(
        loading: () => const LoadingView(message: 'Loading active investigation cases...'),
        error: (err, stack) => ErrorStateView(
          message: 'Failed to retrieve investigation cases',
          details: err.toString(),
          onRetry: () => ref.refresh(investigationListProvider),
        ),
        data: (cases) {
          if (cases.isEmpty) {
            return EmptyStateView(
              title: 'No Active Cases',
              message: 'No crime investigation cases found. Tap below to create a case with auto-matched radius cameras.',
              icon: Icons.shield_outlined,
              action: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => const InvestigationCreateScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Open Investigation Case'),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 84),
            itemCount: cases.length,
            separatorBuilder: (ctx, i) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) {
              final c = cases[i];
              return _buildCaseCard(context, c);
            },
          );
        },
      ),
    );
  }

  Widget _buildCaseCard(BuildContext context, InvestigationCaseModel c) {
    return Card(
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => InvestigationDetailScreen(caseId: c.id),
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
                      Icons.folder_shared_outlined,
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
                          c.title,
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
                          '${c.caseNumber} • ${c.crimeType}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.signalOrange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: c.isOpen ? AppColors.statusPendingAmberLight : AppColors.statusActiveGreenLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      c.status,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: c.isOpen ? AppColors.statusPendingAmber : AppColors.statusActiveGreen,
                      ),
                    ),
                  ),
                ],
              ),
              if (c.crimeLocationName != null && c.crimeLocationName!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.place_outlined, size: 14, color: AppColors.slateGray),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        c.crimeLocationName!,
                        style: const TextStyle(fontSize: 12, color: AppColors.slateGray),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.videocam_outlined, size: 14, color: AppColors.slateGray),
                  const SizedBox(width: 4),
                  Text(
                    '${c.attachedCameras.length} CCTV Evidence Nodes',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkBlack,
                    ),
                  ),
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
