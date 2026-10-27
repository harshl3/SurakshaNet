import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/env_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/providers/auth_provider.dart';
import '../../camera/screens/camera_registration_screen.dart';
import '../../camera/screens/qr_scanner_screen.dart';
import '../../investigation/screens/investigation_create_screen.dart';
import '../../verification/screens/verification_queue_screen.dart';
import '../models/dashboard_stats.dart';
import '../providers/dashboard_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Officer Session?'),
        content: const Text('You will need to re-authenticate with your police credentials.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.statusOfflineRed),
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(authProvider.notifier).logout();
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final statsAsync = ref.watch(dashboardStatsProvider);

    return Scaffold(
      backgroundColor: AppColors.canvasCream,
      appBar: AppBar(
        title: const Text('Police Operations Command'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'QR Camera Scanner',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (ctx) => const QrScannerScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign Out',
            onPressed: () => _confirmLogout(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(dashboardStatsProvider),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // User Greeting Hero Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: const BoxDecoration(
                              color: AppColors.inkBlack,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.local_police_rounded,
                              color: AppColors.canvasCream,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user?.fullName.isNotEmpty == true
                                      ? user!.fullName
                                      : (user?.username ?? 'Officer'),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.inkBlack,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.softBone,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    user?.roleDisplay ?? 'Authorized Personnel',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.signalOrange,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (user?.policeStationName != null) ...[
                        const Divider(height: 24),
                        Row(
                          children: [
                            const Icon(Icons.account_balance_outlined, size: 16, color: AppColors.slateGray),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Jurisdiction: ${user!.policeStationName}',
                                style: const TextStyle(fontSize: 12, color: AppColors.slateGray),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Server Health Diagnostic Pill
              GestureDetector(
                onTap: () => EnvironmentConfigSheet.show(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.subtleBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_done_outlined, size: 18, color: AppColors.statusActiveGreen),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Backend: ${EnvConfig().envLabel}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.inkBlack),
                        ),
                      ),
                      const Text(
                        'Configure',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.signalOrange),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.signalOrange),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Quick Field Action Grid
              const Text(
                'FIELD OPERATIONS SHORTCUTS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: AppColors.slateGray,
                ),
              ),
              const SizedBox(height: 10),
              if (user?.isSurveyor == true || (user?.isAdmin != true && user?.isOfficer != true)) ...[
                // Surveyor Dashboard: Field Survey & Scan QR
                Row(
                  children: [
                    Expanded(
                      child: _buildActionTile(
                        context,
                        icon: Icons.camera_alt_rounded,
                        title: 'Field Survey',
                        subtitle: 'Register CCTV',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (ctx) => const CameraRegistrationScreen()),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildActionTile(
                        context,
                        icon: Icons.qr_code_scanner_rounded,
                        title: 'Scan QR',
                        subtitle: 'Lookup Code',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (ctx) => const QrScannerScreen()),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // Admin & Officer Dashboard: No camera registration shortcut (done exclusively by Field Surveyors)
                Row(
                  children: [
                    Expanded(
                      child: _buildActionTile(
                        context,
                        icon: Icons.qr_code_scanner_rounded,
                        title: 'Scan QR',
                        subtitle: 'Lookup Code',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (ctx) => const QrScannerScreen()),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildActionTile(
                        context,
                        icon: Icons.radar_rounded,
                        title: 'Open Case',
                        subtitle: 'Auto GIS Match',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (ctx) => const InvestigationCreateScreen()),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                if (user?.isAdmin == true) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionTile(
                          context,
                          icon: Icons.verified_user_outlined,
                          title: 'Verification',
                          subtitle: 'Admin Queue',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (ctx) => const VerificationQueueScreen()),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ],
              const SizedBox(height: 20),

              // Real Server KPI Metrics
              const Text(
                'SYSTEM SURVEILLANCE KPI',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: AppColors.slateGray,
                ),
              ),
              const SizedBox(height: 10),

              statsAsync.when(
                loading: () => const LoadingView(message: 'Querying backend surveillance aggregates...'),
                error: (err, stack) => ErrorStateView(
                  message: 'Dashboard KPI metrics unavailable',
                  details: err.toString(),
                  onRetry: () => ref.refresh(dashboardStatsProvider),
                ),
                data: (stats) => _buildKpiGrid(stats),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.inkBlack,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.canvasCream, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.inkBlack,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 11, color: AppColors.slateGray),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiGrid(DashboardStats stats) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Total Cameras',
                value: stats.totalCameras.toString(),
                icon: Icons.videocam_rounded,
                color: AppColors.inkBlack,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatCard(
                title: 'Active Cameras',
                value: stats.activeCameras.toString(),
                icon: Icons.check_circle_rounded,
                color: AppColors.statusActiveGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Pending Verification',
                value: stats.pendingVerificationCameras.toString(),
                icon: Icons.hourglass_top_rounded,
                color: AppColors.statusPendingAmber,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatCard(
                title: 'Offline / Damaged',
                value: stats.offlineCameras.toString(),
                icon: Icons.videocam_off_rounded,
                color: AppColors.statusOfflineRed,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Investigation Cases',
                value: stats.totalInvestigationCases.toString(),
                icon: Icons.folder_shared_rounded,
                color: AppColors.signalOrange,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatCard(
                title: 'Police Stations',
                value: stats.totalPoliceStations.toString(),
                icon: Icons.account_balance_rounded,
                color: AppColors.linkBlue,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slateGray,
                  ),
                ),
                Icon(icon, size: 18, color: color),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: -0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
