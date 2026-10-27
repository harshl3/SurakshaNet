import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/env_config.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/state_views.dart';
import 'features/auth/models/auth_state.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/navigation/role_navigation_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EnvConfig().init();

  runApp(
    const ProviderScope(
      child: PoliceCameraApp(),
    ),
  );
}

class PoliceCameraApp extends ConsumerWidget {
  const PoliceCameraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: _buildHome(authState),
    );
  }

  Widget _buildHome(AuthState authState) {
    switch (authState.status) {
      case AuthStatus.initial:
        return const Scaffold(
          backgroundColor: AppColors.canvasCream,
          body: LoadingView(message: 'Restoring police officer session...'),
        );
      case AuthStatus.authenticated:
        return const RoleNavigationShell();
      case AuthStatus.loading:
        // Keep login visible while sign-in runs (button shows spinner).
        if (authState.user == null) {
          return const LoginScreen();
        }
        return const RoleNavigationShell();
      case AuthStatus.unauthenticated:
      case AuthStatus.error:
        return const LoginScreen();
    }
  }
}
