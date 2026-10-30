import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/providers/auth_provider.dart';
import '../../camera/providers/camera_provider.dart';
import '../../camera/screens/camera_list_screen.dart';
import '../../camera/screens/camera_registration_screen.dart';
import '../../camera/screens/qr_scanner_screen.dart';
import '../../investigation/screens/investigation_create_screen.dart';
import '../../investigation/screens/investigation_list_screen.dart';
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 24,
              height: 24,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.shield_rounded, size: 20),
            ),
            const SizedBox(width: 8),
            const Text('SurakshaNet Command'),
          ],
        ),
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
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                  side: const BorderSide(color: Color(0xFFE5DFD9)),
                ),
                child: InkWell(
                  onTap: () => _showOfficerProfileSheet(context, user, ref),
                  borderRadius: BorderRadius.circular(22),
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: const BoxDecoration(
                                color: AppColors.inkBlack,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.local_police_rounded,
                                color: AppColors.canvasCream,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          user?.fullName.isNotEmpty == true
                                              ? user!.fullName
                                              : (user?.username ?? 'Officer'),
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.inkBlack,
                                            letterSpacing: -0.4,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                        decoration: BoxDecoration(
                                          color: AppColors.softBone,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: const Color(0xFFE5DFD9)),
                                        ),
                                        child: Text(
                                          user?.roleDisplay ?? 'Authorized Personnel',
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.signalOrange,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEAF7EE),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: const Color(0xFFBDE8C8)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 6,
                                              height: 6,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFF0A7334),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            const Text(
                                              'ACTIVE',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF0A7334),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14,
                              color: AppColors.slateGray,
                            ),
                          ],
                        ),
                        if (user?.policeStationName != null) ...[
                          const Divider(height: 22, color: Color(0xFFE5DFD9)),
                          Row(
                            children: [
                              const Icon(Icons.account_balance_outlined, size: 15, color: AppColors.slateGray),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Jurisdiction: ${user!.policeStationName}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.slateGray, fontWeight: FontWeight.w500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Text(
                                'Profile Info',
                                style: TextStyle(fontSize: 11, color: AppColors.signalOrange, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'SYSTEM SURVEILLANCE KPI',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: AppColors.slateGray,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F0EE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Tap any card to view',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF8C827A)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              statsAsync.when(
                loading: () => const LoadingView(message: 'Querying backend surveillance aggregates...'),
                error: (err, stack) => ErrorStateView(
                  message: 'Dashboard KPI metrics unavailable',
                  details: err.toString(),
                  onRetry: () => ref.refresh(dashboardStatsProvider),
                ),
                data: (stats) => _buildKpiGrid(context, ref, stats),
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
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE5DFD9)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.inkBlack,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 11, color: AppColors.slateGray),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12,
                color: Color(0xFFB5AFA7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiGrid(BuildContext context, WidgetRef ref, DashboardStats stats) {
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
                hintText: 'Inspect directory',
                onTap: () {
                  ref.read(cameraFilterProvider.notifier).state = const CameraFilterState();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (ctx) => const CameraListScreen()),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatCard(
                title: 'Active Cameras',
                value: stats.activeCameras.toString(),
                icon: Icons.check_circle_rounded,
                color: AppColors.statusActiveGreen,
                hintText: 'Online & live feeds',
                onTap: () {
                  ref.read(cameraFilterProvider.notifier).state = const CameraFilterState(status: 'ACTIVE');
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (ctx) => const CameraListScreen()),
                  );
                },
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
                hintText: 'Review audit queue',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (ctx) => const VerificationQueueScreen()),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatCard(
                title: 'Offline / Damaged',
                value: stats.offlineCameras.toString(),
                icon: Icons.videocam_off_rounded,
                color: AppColors.statusOfflineRed,
                hintText: 'Requires inspection',
                onTap: () {
                  ref.read(cameraFilterProvider.notifier).state = const CameraFilterState(status: 'OFFLINE');
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (ctx) => const CameraListScreen()),
                  );
                },
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
                hintText: 'Active spatial cases',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (ctx) => const InvestigationListScreen()),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatCard(
                title: 'Police Stations',
                value: stats.totalPoliceStations.toString(),
                icon: Icons.account_balance_rounded,
                color: AppColors.linkBlue,
                hintText: 'Nagpur precincts',
                onTap: () => _showPoliceStationsSheet(context),
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
    required String hintText,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE5DFD9)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slateGray,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 16, color: color),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    hintText,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.slateGray,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 10,
                    color: color.withValues(alpha: 0.7),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOfficerProfileSheet(BuildContext context, dynamic user, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(22),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1CDC7),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE5DFD9), width: 1.5),
                  ),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.shield_rounded, size: 28, color: AppColors.signalOrange),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.fullName.isNotEmpty == true ? user!.fullName : (user?.username ?? 'Police Officer'),
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF141413)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Badge No: SURAKSHA-${user?.id ?? "01"}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF696969), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF7EE),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFBDE8C8)),
                  ),
                  child: const Text('VERIFIED', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF0A7334))),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(color: Color(0xFFE5DFD9)),
            const SizedBox(height: 12),
            _buildProfileRow('Role Authority', user?.roleDisplay ?? 'Authorized Personnel', Icons.badge_outlined),
            const SizedBox(height: 10),
            _buildProfileRow('Jurisdiction Hub', user?.policeStationName ?? 'Nagpur Police Commissionerate', Icons.account_balance_outlined),
            const SizedBox(height: 10),
            _buildProfileRow('System Access', 'CCTV Mapping • Geospatial GIS Reconnaissance', Icons.security_rounded),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _confirmLogout(context, ref);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFDF0EE),
                  foregroundColor: const Color(0xFFCF4500),
                  elevation: 0,
                  side: const BorderSide(color: Color(0xFFF8C6BC)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Sign Out of Police Session', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  static Widget _buildProfileRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF696969)),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10.5, color: Color(0xFF8C827A), fontWeight: FontWeight.w600)),
            Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF141413))),
          ],
        ),
      ],
    );
  }

  void _showPoliceStationsSheet(BuildContext context) {
    final stations = [
      {'name': 'Sitabuldi Police Station', 'zone': 'Central Precinct Hub', 'cameras': '18 Nodes', 'phone': '+91 712 256 0100', 'road': 'Wardha Road, Sitabuldi'},
      {'name': 'Sadar Police Station', 'zone': 'North Commercial Precinct', 'cameras': '14 Nodes', 'phone': '+91 712 253 0200', 'road': 'Mount Road, Sadar'},
      {'name': 'Dhantoli Police Station', 'zone': 'South Urban Precinct', 'cameras': '11 Nodes', 'phone': '+91 712 242 0300', 'road': 'Congress Nagar, Dhantoli'},
      {'name': 'Ambazari Police Station', 'zone': 'West Civic Precinct', 'cameras': '9 Nodes', 'phone': '+91 712 222 0400', 'road': 'Ambazari Road, Nagpur'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(22),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1CDC7),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Nagpur Police Precincts',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF141413)),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Mapped Police Stations & GIS Surveillance Coverage',
                      style: TextStyle(fontSize: 11, color: Color(0xFF696969)),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F0EE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('4 STATIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF141413))),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFFE5DFD9)),
            const SizedBox(height: 8),
            ...stations.map((st) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F6F3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5DFD9)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF141413),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.local_police_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(st['name']!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF141413))),
                          const SizedBox(height: 2),
                          Text('${st['zone']} • ${st['road']}', style: const TextStyle(fontSize: 10.5, color: Color(0xFF696969))),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFD1CDC7)),
                      ),
                      child: Text(
                        st['cameras']!,
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFCF4500)),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
