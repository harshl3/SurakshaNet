import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../providers/camera_provider.dart';
import 'camera_detail_screen.dart';

class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  final TextEditingController _manualCodeController = TextEditingController();
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void dispose() {
    _scannerController.dispose();
    _manualCodeController.dispose();
    super.dispose();
  }

  Future<void> _lookupCameraCode(String code) async {
    final cleanCode = code.trim();
    if (cleanCode.isEmpty || _isProcessing) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final camera = await ref.read(cameraRepositoryProvider).getCameraByCode(cleanCode);
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (ctx) => CameraDetailScreen(cameraId: camera.id),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'No CCTV camera registered with code: $cleanCode';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvasCream,
      appBar: AppBar(
        title: const Text('Scan Camera QR Code'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on_rounded),
            onPressed: () => _scannerController.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios_rounded),
            onPressed: () => _scannerController.switchCamera(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Camera Viewport
          Expanded(
            flex: 5,
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(
                  controller: _scannerController,
                  onDetect: (capture) {
                    if (_isProcessing) return;
                    for (final barcode in capture.barcodes) {
                      if (barcode.rawValue != null) {
                        _lookupCameraCode(barcode.rawValue!);
                        break;
                      }
                    }
                  },
                ),
                // Scanner Frame Overlay
                Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.signalOrange, width: 3),
                  ),
                ),
                if (_isProcessing)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: AppColors.canvasCream),
                          SizedBox(height: 12),
                          Text(
                            'Fetching camera dossier from central server...',
                            style: TextStyle(color: AppColors.white, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Manual Entry Bottom Sheet
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.liftedCream,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Manual Camera Code Lookup',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.inkBlack,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'If QR is faded or hardware camera is unavailable on emulator, enter code manually.',
                      style: TextStyle(fontSize: 12, color: AppColors.slateGray),
                    ),
                    const SizedBox(height: 14),
                    CustomTextField(
                      controller: _manualCodeController,
                      label: 'Camera Code',
                      hint: 'e.g. CAM-NAG-001',
                      prefixIcon: Icons.qr_code_2_rounded,
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AppColors.statusOfflineRed,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    CustomButton(
                      text: 'Lookup Camera Dossier',
                      icon: Icons.search_rounded,
                      variant: ButtonVariant.primary,
                      isLoading: _isProcessing,
                      onPressed: () => _lookupCameraCode(_manualCodeController.text),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
