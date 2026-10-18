import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/state_views.dart';
import '../../camera/screens/camera_detail_screen.dart';
import '../models/investigation_model.dart';
import '../providers/investigation_provider.dart';

class InvestigationDetailScreen extends ConsumerStatefulWidget {
  final int caseId;

  const InvestigationDetailScreen({super.key, required this.caseId});

  @override
  ConsumerState<InvestigationDetailScreen> createState() => _InvestigationDetailScreenState();
}

class _InvestigationDetailScreenState extends ConsumerState<InvestigationDetailScreen> {
  void _showAttachEvidenceDialog(BuildContext context, int caseId) {
    final cameraIdController = TextEditingController();
    final notesController = TextEditingController();
    final startTimeController = TextEditingController(text: '14:00:00');
    final endTimeController = TextEditingController(text: '14:30:00');
    bool isKey = false;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Attach Camera Evidence'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(
                  controller: cameraIdController,
                  label: 'Camera Database ID (Numeric)',
                  hint: 'e.g. 1',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                CustomTextField(
                  controller: notesController,
                  label: 'Evidence Notes / Suspect Observations',
                  hint: 'Suspect spotted moving eastbound on motorcycle',
                  maxLines: 2,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: startTimeController,
                        label: 'Footage Start',
                        hint: 'HH:mm:ss',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: CustomTextField(
                        controller: endTimeController,
                        label: 'Footage End',
                        hint: 'HH:mm:ss',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                CheckboxListTile(
                  title: const Text('Mark as Key Case Evidence', style: TextStyle(fontSize: 13)),
                  value: isKey,
                  activeColor: AppColors.signalOrange,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setDialogState(() => isKey = v ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final camId = int.tryParse(cameraIdController.text.trim());
                      if (camId == null) return;

                      setDialogState(() => isSubmitting = true);
                      try {
                        await ref.read(investigationRepositoryProvider).attachCameraEvidence(
                              caseId,
                              cameraId: camId,
                              notes: notesController.text.trim(),
                              startTime: startTimeController.text.trim(),
                              endTime: endTimeController.text.trim(),
                              isKeyEvidence: isKey,
                            );
                        if (context.mounted) {
                          ref.invalidate(singleInvestigationProvider(caseId));
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Camera evidence attached to case')),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSubmitting = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Attach Evidence'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final caseAsync = ref.watch(singleInvestigationProvider(widget.caseId));

    return Scaffold(
      backgroundColor: AppColors.canvasCream,
      appBar: AppBar(
        title: const Text('Case Workspace'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.refresh(singleInvestigationProvider(widget.caseId)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.signalOrange,
        foregroundColor: AppColors.white,
        icon: const Icon(Icons.add_link_rounded),
        label: const Text('Attach Evidence'),
        onPressed: () => _showAttachEvidenceDialog(context, widget.caseId),
      ),
      body: caseAsync.when(
        loading: () => const LoadingView(message: 'Loading case evidence dossier...'),
        error: (err, stack) => ErrorStateView(
          message: 'Failed to retrieve case details',
          details: err.toString(),
          onRetry: () => ref.refresh(singleInvestigationProvider(widget.caseId)),
        ),
        data: (c) => _buildCaseContent(context, c),
      ),
    );
  }

  Widget _buildCaseContent(BuildContext context, InvestigationCaseModel c) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 84),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Case Overview Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.inkBlack,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: c.isOpen
                              ? AppColors.statusPendingAmberLight
                              : AppColors.statusActiveGreenLight,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          c.status,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: c.isOpen
                                ? AppColors.statusPendingAmber
                                : AppColors.statusActiveGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Case: ${c.caseNumber} • FIR: ${c.firNumber ?? "N/A"}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.signalOrange,
                    ),
                  ),
                  const Divider(height: 24),
                  _buildMetaRow('Crime Type', c.crimeType),
                  _buildMetaRow('Incident Date', c.incidentDate ?? 'Unknown'),
                  _buildMetaRow('Location', c.crimeLocationName ?? 'N/A'),
                  _buildMetaRow('Coordinates', '${c.latitude.toStringAsFixed(4)}°, ${c.longitude.toStringAsFixed(4)}°'),
                  _buildMetaRow('Assigned Officer', c.assignedOfficerName ?? 'Station Duty Officer'),
                  _buildMetaRow('Police Station', c.policeStationName ?? 'Central Precinct'),
                  if (c.description != null && c.description!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Brief Summary:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      c.description!,
                      style: const TextStyle(fontSize: 13, color: AppColors.slateGray),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Attached PostGIS Cameras Section Header
          Row(
            children: [
              const Icon(Icons.videocam_rounded, size: 20, color: AppColors.inkBlack),
              const SizedBox(width: 8),
              Text(
                'Linked CCTV Evidence Nodes (${c.attachedCameras.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkBlack,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (c.attachedCameras.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.location_searching_rounded, size: 36, color: AppColors.slateGray),
                      const SizedBox(height: 10),
                      const Text(
                        'No Spatial Cameras Linked',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Tap the "Attach Evidence" button below to link relevant cameras.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: AppColors.slateGray),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: c.attachedCameras.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final cam = c.attachedCameras[i];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.softBone,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.videocam_outlined, color: AppColors.inkBlack),
                    ),
                    title: Text(
                      cam.cameraName,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${cam.cameraCode} • ${cam.cameraType} • ${cam.distanceMeters != null ? "${cam.distanceMeters!.toInt()}m away" : ""}',
                      style: const TextStyle(fontSize: 12, color: AppColors.slateGray),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => CameraDetailScreen(cameraId: cam.id),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.slateGray, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.inkBlack),
            ),
          ),
        ],
      ),
    );
  }
}
