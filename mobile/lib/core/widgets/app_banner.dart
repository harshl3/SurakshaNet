import 'package:flutter/material.dart';
import '../config/env_config.dart';
import '../network/api_client.dart';
import '../theme/app_colors.dart';
import 'custom_button.dart';
import 'custom_text_field.dart';

class EnvironmentConfigSheet extends StatefulWidget {
  const EnvironmentConfigSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const EnvironmentConfigSheet(),
    );
  }

  @override
  State<EnvironmentConfigSheet> createState() => _EnvironmentConfigSheetState();
}

class _EnvironmentConfigSheetState extends State<EnvironmentConfigSheet> {
  late EnvironmentType _selectedEnv;
  final TextEditingController _customUrlController = TextEditingController();
  bool _isChecking = false;
  String? _healthResult;
  bool _healthSuccess = false;

  @override
  void initState() {
    super.initState();
    _selectedEnv = EnvConfig().currentEnv;
    _customUrlController.text = EnvConfig().baseUrl;
  }

  @override
  void dispose() {
    _customUrlController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() {
      _isChecking = true;
      _healthResult = null;
    });

    try {
      final res = await ApiClient().checkHealth();
      setState(() {
        _healthSuccess = true;
        _healthResult = 'Connection Healthy: ${res['status'] ?? 'UP'} (Service: ${res['service'] ?? 'Police API'})';
      });
    } catch (e) {
      setState(() {
        _healthSuccess = false;
        _healthResult = 'Health check failed: $e';
      });
    } finally {
      setState(() {
        _isChecking = false;
      });
    }
  }

  Future<void> _saveEnvironment() async {
    await EnvConfig().setEnvironment(
      _selectedEnv,
      customUrl: _selectedEnv == EnvironmentType.custom || _selectedEnv == EnvironmentType.localLan
          ? _customUrlController.text.trim()
          : null,
    );
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Switched to ${EnvConfig().envLabel} (${EnvConfig().baseUrl})'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.liftedCream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.dustTaupe,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Icon(Icons.dns_rounded, size: 22, color: AppColors.inkBlack),
                const SizedBox(width: 10),
                const Text(
                  'Backend Environment',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    color: AppColors.inkBlack,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Select backend target without changing code. Changes take effect immediately.',
              style: TextStyle(fontSize: 13, color: AppColors.slateGray),
            ),
            const SizedBox(height: 16),
            _buildRadioTile(
              type: EnvironmentType.production,
              title: 'Render Cloud Production',
              subtitle: EnvConfig.defaultProdUrl,
            ),
            _buildRadioTile(
              type: EnvironmentType.androidEmulator,
              title: 'Android Emulator',
              subtitle: EnvConfig.defaultEmulatorUrl,
            ),
            _buildRadioTile(
              type: EnvironmentType.localLan,
              title: 'Local Wi-Fi / Physical Device LAN',
              subtitle: 'Connects to your PC running Spring Boot on local network',
            ),
            _buildRadioTile(
              type: EnvironmentType.custom,
              title: 'Custom Base URL',
              subtitle: 'Specify custom host & port with /api/v1',
            ),
            if (_selectedEnv == EnvironmentType.localLan || _selectedEnv == EnvironmentType.custom) ...[
              const SizedBox(height: 12),
              CustomTextField(
                controller: _customUrlController,
                label: 'Base API URL',
                hint: 'http://192.168.1.100:8088/api/v1',
                prefixIcon: Icons.link_rounded,
              ),
            ],
            const SizedBox(height: 16),
            if (_healthResult != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _healthSuccess
                      ? AppColors.statusActiveGreenLight
                      : AppColors.statusOfflineRedLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      _healthSuccess ? Icons.check_circle_rounded : Icons.warning_rounded,
                      size: 18,
                      color: _healthSuccess
                          ? AppColors.statusActiveGreen
                          : AppColors.statusOfflineRed,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _healthResult!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _healthSuccess
                              ? AppColors.statusActiveGreen
                              : AppColors.statusOfflineRed,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: 'Test Health',
                    variant: ButtonVariant.secondary,
                    icon: Icons.speed_rounded,
                    isLoading: _isChecking,
                    onPressed: _testConnection,
                    height: 46,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomButton(
                    text: 'Apply Target',
                    variant: ButtonVariant.primary,
                    icon: Icons.check_rounded,
                    onPressed: _saveEnvironment,
                    height: 46,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadioTile({
    required EnvironmentType type,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _selectedEnv == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedEnv = type;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.white : AppColors.liftedCream,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.inkBlack : AppColors.subtleBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? AppColors.inkBlack : AppColors.slateGray,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: AppColors.inkBlack,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.slateGray,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
