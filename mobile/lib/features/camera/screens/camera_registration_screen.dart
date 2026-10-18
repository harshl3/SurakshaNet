import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../providers/camera_provider.dart';

class CameraRegistrationScreen extends ConsumerStatefulWidget {
  const CameraRegistrationScreen({super.key});

  @override
  ConsumerState<CameraRegistrationScreen> createState() => _CameraRegistrationScreenState();
}

class _CameraRegistrationScreenState extends ConsumerState<CameraRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  final _cameraCodeController = TextEditingController();
  final _cameraNameController = TextEditingController();
  final _serialNumberController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _addressController = TextEditingController();
  final _areaController = TextEditingController();
  final _wardController = TextEditingController();
  final _zoneController = TextEditingController();
  final _cityController = TextEditingController(text: 'Nagpur');
  final _stateController = TextEditingController(text: 'Maharashtra');

  // Lens & Coverage
  double _directionAngle = 0.0;
  double _fovAngle = 60.0;
  double _coverageRadius = 100.0;
  String _cameraType = 'BULLET';

  // Ownership
  final _ownerNameController = TextEditingController();
  final _ownerContactController = TextEditingController();
  final String _ownerType = 'COMMERCIAL';

  File? _pickedImage;
  bool _isGettingLocation = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation();
  }

  @override
  void dispose() {
    _cameraCodeController.dispose();
    _cameraNameController.dispose();
    _serialNumberController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _addressController.dispose();
    _areaController.dispose();
    _wardController.dispose();
    _zoneController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _ownerNameController.dispose();
    _ownerContactController.dispose();
    super.dispose();
  }

  Future<void> _fetchCurrentLocation() async {
    setState(() => _isGettingLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
        setState(() {
          _latitudeController.text = position.latitude.toStringAsFixed(6);
          _longitudeController.text = position.longitude.toStringAsFixed(6);
        });
      } else {
        // Default to Nagpur city center if GPS unavailable
        _latitudeController.text = AppConstants.defaultLatitude.toString();
        _longitudeController.text = AppConstants.defaultLongitude.toString();
      }
    } catch (e) {
      debugPrint('Location error: $e');
      _latitudeController.text = AppConstants.defaultLatitude.toString();
      _longitudeController.text = AppConstants.defaultLongitude.toString();
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 720,
        imageQuality: 85,
      );
      if (file != null) {
        setState(() {
          _pickedImage = File(file.path);
        });
        // Upload immediately via media API
        await ref.read(cameraRegistrationProvider.notifier).uploadPhoto(_pickedImage!);
      }
    } catch (e) {
      debugPrint('Image picker error: $e');
    }
  }

  void _onCodeOrSerialChanged() {
    final code = _cameraCodeController.text.trim();
    final serial = _serialNumberController.text.trim();
    if (code.isNotEmpty || serial.isNotEmpty) {
      ref.read(cameraRegistrationProvider.notifier).checkDuplicate(
        cameraCode: code.isNotEmpty ? code : null,
        serialNumber: serial.isNotEmpty ? serial : null,
      );
    }
  }

  void _onOwnerContactChanged(String val) {
    if (val.trim().length >= 8) {
      ref.read(cameraRegistrationProvider.notifier).lookupOwner(val.trim());
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final regState = ref.read(cameraRegistrationProvider);

    final payload = {
      'cameraCode': _cameraCodeController.text.trim(),
      'cameraName': _cameraNameController.text.trim(),
      if (_serialNumberController.text.trim().isNotEmpty)
        'serialNumber': _serialNumberController.text.trim(),
      'cameraType': _cameraType,
      'latitude': double.parse(_latitudeController.text.trim()),
      'longitude': double.parse(_longitudeController.text.trim()),
      'fullAddress': _addressController.text.trim(),
      'area': _areaController.text.trim(),
      if (_wardController.text.trim().isNotEmpty) 'ward': _wardController.text.trim(),
      if (_zoneController.text.trim().isNotEmpty) 'zone': _zoneController.text.trim(),
      'city': _cityController.text.trim(),
      'state': _stateController.text.trim(),
      'directionAngle': _directionAngle,
      'fovAngle': _fovAngle,
      'coverageRadiusMeters': _coverageRadius,
      'imageUrl': regState.uploadedPhotoUrl,
      if (_ownerNameController.text.trim().isNotEmpty)
        'ownerName': _ownerNameController.text.trim(),
      if (_ownerContactController.text.trim().isNotEmpty)
        'ownerContact': _ownerContactController.text.trim(),
      'ownerType': _ownerType,
    };

    final createdCamera = await ref.read(cameraRegistrationProvider.notifier).submitCamera(payload);

    if (createdCamera != null && mounted) {
      // Invalidate camera list provider so directory refreshes
      ref.invalidate(cameraListProvider);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(
                createdCamera.isApproved ? Icons.verified_rounded : Icons.pending_actions_rounded,
                color: createdCamera.isApproved
                    ? AppColors.statusActiveGreen
                    : AppColors.statusPendingAmber,
              ),
              const SizedBox(width: 8),
              Text(createdCamera.isApproved ? 'Camera Approved' : 'Submitted for Approval'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Camera "${createdCamera.cameraName}" (${createdCamera.cameraCode}) was successfully recorded in the central database.',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              Text(
                'Status: ${createdCamera.verificationStatus}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              },
              child: const Text('Return to Dashboard'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final regState = ref.watch(cameraRegistrationProvider);

    return Scaffold(
      backgroundColor: AppColors.canvasCream,
      appBar: AppBar(
        title: const Text('Field Survey Registration'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Photo Upload Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CCTV Camera Site Photo',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.inkBlack,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Capture clear photo of lens azimuth facing and surrounding landmark.',
                        style: TextStyle(fontSize: 12, color: AppColors.slateGray),
                      ),
                      const SizedBox(height: 12),
                      if (_pickedImage != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Image.file(
                                _pickedImage!,
                                height: 180,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                              if (regState.isUploadingPhoto)
                                Container(
                                  height: 180,
                                  width: double.infinity,
                                  color: Colors.black45,
                                  child: const Center(
                                    child: CircularProgressIndicator(color: AppColors.canvasCream),
                                  ),
                                ),
                            ],
                          ),
                        )
                      else
                        Container(
                          height: 130,
                          decoration: BoxDecoration(
                            color: AppColors.softBone,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.subtleBorder),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.add_a_photo_outlined, size: 36, color: AppColors.slateGray),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () => _pickImage(ImageSource.camera),
                                      icon: const Icon(Icons.camera_alt, size: 16),
                                      label: const Text('Take Photo'),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton.icon(
                                      onPressed: () => _pickImage(ImageSource.gallery),
                                      icon: const Icon(Icons.photo_library, size: 16),
                                      label: const Text('Gallery'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Basic Identification
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Identification & Hardware',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 14),
                      CustomTextField(
                        controller: _cameraCodeController,
                        label: 'Camera Code (Required)',
                        hint: 'e.g. CAM-NAG-402',
                        prefixIcon: Icons.qr_code_rounded,
                        onChanged: (v) => _onCodeOrSerialChanged(),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Camera code is required' : null,
                      ),
                      if (regState.duplicateStatus != null && regState.duplicateStatus!.isDuplicate) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Warning: ${regState.duplicateStatus!.message ?? "Duplicate code/serial detected!"}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.statusOfflineRed,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      CustomTextField(
                        controller: _cameraNameController,
                        label: 'Camera Name / Label',
                        hint: 'e.g. Sitabuldi Main Junction North-Facing',
                        prefixIcon: Icons.label_outline_rounded,
                        validator: (val) => val == null || val.trim().isEmpty ? 'Name is required' : null,
                      ),
                      const SizedBox(height: 12),
                      CustomTextField(
                        controller: _serialNumberController,
                        label: 'Hardware Serial Number',
                        hint: 'e.g. SN-DS-2CD2043G2-019',
                        prefixIcon: Icons.numbers_rounded,
                        onChanged: (v) => _onCodeOrSerialChanged(),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Camera Type',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _cameraType,
                        decoration: const InputDecoration(filled: true, fillColor: AppColors.white),
                        items: const [
                          DropdownMenuItem(value: 'BULLET', child: Text('Bullet (Fixed Focus)')),
                          DropdownMenuItem(value: 'DOME', child: Text('Dome (Ceiling Mount)')),
                          DropdownMenuItem(value: 'PTZ', child: Text('PTZ (Pan-Tilt-Zoom)')),
                          DropdownMenuItem(value: 'ANPR', child: Text('ANPR (Number Plate Reader)')),
                          DropdownMenuItem(value: 'NIGHT_VISION', child: Text('Night Vision Infrared')),
                          DropdownMenuItem(value: 'OTHER', child: Text('Other / Custom')),
                        ],
                        onChanged: (val) => setState(() => _cameraType = val!),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // GPS Positioning
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'GPS Spatial Location',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _isGettingLocation ? null : _fetchCurrentLocation,
                            icon: _isGettingLocation
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.my_location, size: 16),
                            label: const Text('Update GPS'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: CustomTextField(
                              controller: _latitudeController,
                              label: 'Latitude',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (val) => val == null || double.tryParse(val) == null ? 'Valid latitude required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CustomTextField(
                              controller: _longitudeController,
                              label: 'Longitude',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (val) => val == null || double.tryParse(val) == null ? 'Valid longitude required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      CustomTextField(
                        controller: _addressController,
                        label: 'Full Address',
                        hint: 'Road name, landmark, building number',
                        prefixIcon: Icons.place_outlined,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: CustomTextField(
                              controller: _areaController,
                              label: 'Area / Locality',
                              hint: 'e.g. Dharampeth',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CustomTextField(
                              controller: _cityController,
                              label: 'City',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Field of View & Coverage Sliders
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Orientation & Coverage',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Facing Angle (Azimuth):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          Text('${_directionAngle.toInt()}°', style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                      Slider(
                        value: _directionAngle,
                        min: 0,
                        max: 360,
                        divisions: 72,
                        activeColor: AppColors.inkBlack,
                        onChanged: (val) => setState(() => _directionAngle = val),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Field of View (FOV):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          Text('${_fovAngle.toInt()}°', style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                      Slider(
                        value: _fovAngle,
                        min: 15,
                        max: 180,
                        divisions: 33,
                        activeColor: AppColors.signalOrange,
                        onChanged: (val) => setState(() => _fovAngle = val),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Coverage Radius:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          Text('${_coverageRadius.toInt()} m', style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                      Slider(
                        value: _coverageRadius,
                        min: 10,
                        max: 500,
                        divisions: 49,
                        activeColor: AppColors.inkBlack,
                        onChanged: (val) => setState(() => _coverageRadius = val),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Ownership Information
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ownership Details',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 14),
                      CustomTextField(
                        controller: _ownerContactController,
                        label: 'Owner Mobile Contact',
                        hint: 'e.g. 9876543210',
                        keyboardType: TextInputType.phone,
                        prefixIcon: Icons.phone_outlined,
                        onChanged: _onOwnerContactChanged,
                      ),
                      if (regState.ownerSummary != null && regState.ownerSummary!.ownerFound) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.statusActiveGreenLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Owner Match: ${regState.ownerSummary!.ownerName} (${regState.ownerSummary!.totalCameras} existing cameras)',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.statusActiveGreen,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      CustomTextField(
                        controller: _ownerNameController,
                        label: 'Owner / Establishment Name',
                        hint: 'e.g. Reliance Smart Point / Hotel Centre Point',
                        prefixIcon: Icons.person_outline_rounded,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              if (regState.errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.statusOfflineRedLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    regState.errorMessage!,
                    style: const TextStyle(color: AppColors.statusOfflineRed, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Submit Button
              CustomButton(
                text: 'Register Camera with Central Server',
                icon: Icons.cloud_upload_rounded,
                variant: ButtonVariant.primary,
                isLoading: regState.isSubmitting,
                onPressed: _submitForm,
                height: 52,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
