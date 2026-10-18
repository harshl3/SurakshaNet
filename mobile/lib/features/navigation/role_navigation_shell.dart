import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../auth/providers/auth_provider.dart';
import '../camera/screens/camera_list_screen.dart';
import '../camera/screens/camera_registration_screen.dart';
import '../dashboard/screens/dashboard_screen.dart';
import '../investigation/screens/investigation_list_screen.dart';
import '../map/screens/camera_map_screen.dart';
import '../verification/screens/verification_queue_screen.dart';

class RoleNavigationShell extends ConsumerStatefulWidget {
  const RoleNavigationShell({super.key});

  @override
  ConsumerState<RoleNavigationShell> createState() => _RoleNavigationShellState();
}

class _RoleNavigationShellState extends ConsumerState<RoleNavigationShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    final List<Widget> screens;
    final List<BottomNavigationBarItem> navItems;

    if (user != null && user.isAdmin) {
      // ADMIN: Full access (Dashboard, Map, Cameras, Cases, Verification)
      screens = const [
        DashboardScreen(),
        CameraMapScreen(),
        CameraListScreen(),
        InvestigationListScreen(),
        VerificationQueueScreen(),
      ];
      navItems = const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_outlined),
          activeIcon: Icon(Icons.dashboard_rounded),
          label: 'Command',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.map_outlined),
          activeIcon: Icon(Icons.map_rounded),
          label: 'GIS Map',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.videocam_outlined),
          activeIcon: Icon(Icons.videocam_rounded),
          label: 'Cameras',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.folder_shared_outlined),
          activeIcon: Icon(Icons.folder_shared_rounded),
          label: 'Cases',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.verified_user_outlined),
          activeIcon: Icon(Icons.verified_user_rounded),
          label: 'Verify',
        ),
      ];
    } else if (user != null && user.isOfficer) {
      // POLICE OFFICER: Operations, Map, Cameras, Cases
      screens = const [
        DashboardScreen(),
        CameraMapScreen(),
        CameraListScreen(),
        InvestigationListScreen(),
      ];
      navItems = const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_outlined),
          activeIcon: Icon(Icons.dashboard_rounded),
          label: 'Command',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.map_outlined),
          activeIcon: Icon(Icons.map_rounded),
          label: 'GIS Map',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.videocam_outlined),
          activeIcon: Icon(Icons.videocam_rounded),
          label: 'Cameras',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.folder_shared_outlined),
          activeIcon: Icon(Icons.folder_shared_rounded),
          label: 'Cases',
        ),
      ];
    } else {
      // SURVEYOR (or generic user): Operations, Map, Cameras, Survey Form
      screens = const [
        DashboardScreen(),
        CameraMapScreen(),
        CameraListScreen(),
        CameraRegistrationScreen(),
      ];
      navItems = const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home_rounded),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.map_outlined),
          activeIcon: Icon(Icons.map_rounded),
          label: 'GIS Map',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.videocam_outlined),
          activeIcon: Icon(Icons.videocam_rounded),
          label: 'Cameras',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.add_a_photo_outlined),
          activeIcon: Icon(Icons.add_a_photo_rounded),
          label: 'Survey',
        ),
      ];
    }

    final safeIndex = _currentIndex < screens.length ? _currentIndex : 0;

    return Scaffold(
      body: IndexedStack(
        index: safeIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.subtleBorder, width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: safeIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          items: navItems,
        ),
      ),
    );
  }
}
