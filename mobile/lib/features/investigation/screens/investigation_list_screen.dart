import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/state_views.dart';
import '../models/investigation_model.dart';
import '../providers/investigation_provider.dart';
import 'investigation_create_screen.dart';
import 'investigation_detail_screen.dart';
import 'investigation_radar_map_screen.dart';

class InvestigationListScreen extends ConsumerStatefulWidget {
  const InvestigationListScreen({super.key});

  @override
  ConsumerState<InvestigationListScreen> createState() => _InvestigationListScreenState();
}

class _InvestigationListScreenState extends ConsumerState<InvestigationListScreen> {
  bool _isTableView = false;

  @override
  Widget build(BuildContext context) {
    final caseListAsync = ref.watch(investigationListProvider);

    return Scaffold(
      backgroundColor: AppColors.canvasCream,
      appBar: AppBar(
        title: const Text('Investigation Cases'),
        actions: [
          IconButton(
            icon: Icon(_isTableView ? Icons.view_agenda_outlined : Icons.table_chart_outlined),
            tooltip: _isTableView ? 'Switch to Card View' : 'Switch to Table View',
            onPressed: () {
              setState(() => _isTableView = !_isTableView);
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Cases',
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

          if (_isTableView) {
            return _buildOfficerCasesTable(context, cases);
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

  // Officer Investigation Table View (matching Image 2)
  Widget _buildOfficerCasesTable(BuildContext context, List<InvestigationCaseModel> cases) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 84),
      scrollDirection: Axis.vertical,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5DFD9)),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF3F0EE)),
            dataRowMinHeight: 70,
            dataRowMaxHeight: 85,
            horizontalMargin: 16,
            columnSpacing: 24,
            columns: const [
              DataColumn(
                label: Text(
                  'CASE & FIR',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF696969)),
                ),
              ),
              DataColumn(
                label: Text(
                  'TITLE & INCIDENT LOCATION',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF696969)),
                ),
              ),
              DataColumn(
                label: Text(
                  'POLICE STATION',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF696969)),
                ),
              ),
              DataColumn(
                label: Text(
                  'ASSIGNED OFFICER',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF696969)),
                ),
              ),
              DataColumn(
                label: Text(
                  'STATUS',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF696969)),
                ),
              ),
              DataColumn(
                label: Text(
                  'FOCUS',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF696969)),
                ),
              ),
            ],
            rows: cases.map((c) {
              return DataRow(
                cells: [
                  // Case & FIR
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          c.caseNumber,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF141413)),
                        ),
                        if (c.firNumber != null)
                          Text(
                            c.firNumber!,
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFFCF4500)),
                          ),
                      ],
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => InvestigationDetailScreen(caseId: c.id),
                        ),
                      );
                    },
                  ),
                  // Title & Incident Location
                  DataCell(
                    SizedBox(
                      width: 250,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            c.title,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFF141413)),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (c.crimeLocationName != null) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.place_outlined, size: 12, color: Color(0xFFCF4500)),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    c.crimeLocationName!,
                                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF696969)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  // Police Station
                  DataCell(
                    Text(
                      c.policeStationName ?? 'Nagpur Police HQ',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF141413), fontWeight: FontWeight.w500),
                    ),
                  ),
                  // Assigned Officer
                  DataCell(
                    Text(
                      c.assignedOfficerName ?? 'Duty Officer',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF141413), fontWeight: FontWeight.w500),
                    ),
                  ),
                  // Status Badge
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: c.isOpen
                            ? const Color(0xFFF79E1B).withValues(alpha: 0.15)
                            : (c.status == 'CLOSED'
                                ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                : const Color(0xFF3860BE).withValues(alpha: 0.15)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        c.status,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: c.isOpen
                              ? const Color(0xFFF79E1B)
                              : (c.status == 'CLOSED' ? const Color(0xFF0A7334) : const Color(0xFF3860BE)),
                        ),
                      ),
                    ),
                  ),
                  // Focus Radar Button (matching Image 2)
                  DataCell(
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF141413),
                        side: const BorderSide(color: Color(0xFF141413), width: 1.2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (ctx) => InvestigationRadarMapScreen(caseItem: c),
                          ),
                        );
                      },
                      icon: const Icon(Icons.radar_rounded, size: 14, color: Color(0xFFCF4500)),
                      label: const Text(
                        'Focus Radar',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
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
                  const Icon(Icons.shield_outlined, size: 14, color: AppColors.slateGray),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      c.policeStationName ?? 'Nagpur Police Precinct',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.slateGray, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${c.attachedCameras.length} CCTV Evidence Nodes',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkBlack,
                    ),
                  ),
                  // Focus Radar Action Button (matching Image 2)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.inkBlack,
                      side: const BorderSide(color: Color(0xFF141413), width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => InvestigationRadarMapScreen(caseItem: c),
                        ),
                      );
                    },
                    icon: const Icon(Icons.radar_rounded, size: 15, color: Color(0xFFCF4500)),
                    label: const Text(
                      'Focus Radar',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
