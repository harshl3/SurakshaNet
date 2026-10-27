import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../models/camera_model.dart';
import '../providers/camera_provider.dart';

class CameraRegistrationScreen extends ConsumerStatefulWidget {
  const CameraRegistrationScreen({super.key});

  @override
  ConsumerState<CameraRegistrationScreen> createState() => _CameraRegistrationScreenState();
}

class _CameraRegistrationScreenState extends ConsumerState<CameraRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  // Wizard Step: 1 = Owner Mobile Verification & Review, 2 = Register New Camera
  int _currentStep = 1;

  // Step 1: Owner Verification
  final _ownerSearchController = TextEditingController();
  bool _isSearchingOwner = false;
  bool _ownerVerified = false;
  String _verifiedOwnerName = '';
  String _verifiedOwnerContact = '';
  String _verifiedOwnerType = 'COMMERCIAL';
  List<CameraModel> _existingOwnerCameras = [];
  int _ownerApprovedCount = 0;
  int _ownerPendingCount = 0;

  // Step 2: Camera Hardware & GIS Details
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
  double _directionAngle = 90.0;
  double _fovAngle = 60.0;
  double _coverageRadius = 100.0;
  String _cameraType = 'PTZ';

  File? _pickedImage;
  bool _isGettingLocation = false;
  final ImagePicker _picker = ImagePicker();

  // Demo sample owners from frontend (Image 4)
  final List<Map<String, String>> _sampleOwners = [
    {'label': 'Sitabuldi Traders', 'number': '+91 98711 44444'},
    {'label': 'Apex Retail', 'number': '+91 98711 77777'},
    {'label': 'Shopkeepers Assn', 'number': '+91 98765 11111'},
  ];

  @override
  void initState() {
    super.initState();
    _generateNewCameraCode();
    _fetchCurrentLocation();
  }

  @override
  void dispose() {
    _ownerSearchController.dispose();
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
    super.dispose();
  }

  void _generateNewCameraCode() {
    final randomNum = 1000 + math.Random().nextInt(9000);
    final newCode = 'CAM-$randomNum';
    setState(() {
      _cameraCodeController.text = newCode;
    });
    // Trigger duplicate check immediately
    ref.read(cameraRegistrationProvider.notifier).checkDuplicate(cameraCode: newCode);
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

  Future<void> _verifyOwnerMobile([String? phone]) async {
    final search = phone ?? _ownerSearchController.text.trim();
    if (search.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid owner contact number to verify.')),
      );
      return;
    }

    setState(() {
      _isSearchingOwner = true;
    });

    try {
      final summary = await ref.read(cameraRepositoryProvider).lookupOwner(search);
      setState(() {
        _ownerVerified = true;
        _verifiedOwnerContact = search;
        _verifiedOwnerName = summary.ownerName ?? 'Store / Establishment Owner';
        _verifiedOwnerType = summary.ownerType ?? 'COMMERCIAL';
        _existingOwnerCameras = summary.cameras;
        _ownerApprovedCount = summary.approvedCount;
        _ownerPendingCount = summary.pendingCount;

        if (summary.cameras.isNotEmpty) {
          final first = summary.cameras.first;
          _addressController.text = first.fullAddress ?? _addressController.text;
          _areaController.text = first.area ?? _areaController.text;
          _cityController.text = first.city ?? 'Nagpur';
          _cameraNameController.text = '${summary.ownerName ?? "Store"} Premise Camera ${_existingOwnerCameras.length + 1}';
        } else {
          _cameraNameController.text = '$_verifiedOwnerName Surveillance Node';
        }
      });
    } catch (e) {
      setState(() {
        _ownerVerified = true;
        _verifiedOwnerContact = search;
        _verifiedOwnerName = 'Commercial Owner ($search)';
        _existingOwnerCameras = [];
        _ownerApprovedCount = 0;
        _ownerPendingCount = 0;
        _cameraNameController.text = 'Commercial Owner Camera 1';
      });
    } finally {
      if (mounted) setState(() => _isSearchingOwner = false);
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
      'ownerName': _verifiedOwnerName.isNotEmpty ? _verifiedOwnerName : 'Commercial Owner',
      'ownerContact': _verifiedOwnerContact.isNotEmpty ? _verifiedOwnerContact : _ownerSearchController.text.trim(),
      'ownerType': _verifiedOwnerType,
    };

    final createdCamera = await ref.read(cameraRegistrationProvider.notifier).submitCamera(payload);

    if (createdCamera != null && mounted) {
      ref.invalidate(cameraListProvider);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(
                createdCamera.isApproved ? Icons.verified_rounded : Icons.pending_actions_rounded,
                color: createdCamera.isApproved
                    ? AppColors.statusActiveGreen
                    : AppColors.statusPendingAmber,
              ),
              const SizedBox(width: 8),
              Text(
                createdCamera.isApproved ? 'Camera Approved' : 'Submitted for Verification',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Camera "${createdCamera.cameraName}" (${createdCamera.cameraCode}) was successfully registered in the central police GIS database.',
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF8C6BC)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.shield_outlined, size: 14, color: Color(0xFFCF4500)),
                    const SizedBox(width: 6),
                    Text(
                      'STATUS: ${createdCamera.verificationStatus}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: Color(0xFFCF4500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              },
              child: const Text('Return to Map & Directory', style: TextStyle(fontWeight: FontWeight.bold)),
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
      backgroundColor: const Color(0xFFF7F6F3),
      appBar: AppBar(
        title: const Text('Field Survey Registration'),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ==========================================
            // TOP STEPPER INDICATOR (Image 4)
            // ==========================================
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      if (_currentStep == 2) setState(() => _currentStep = 1);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: _currentStep == 1 ? const Color(0xFF141413) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _currentStep == 1 ? const Color(0xFF141413) : const Color(0xFFE5DFD9),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: _currentStep == 1 ? const Color(0xFFCF4500) : const Color(0xFFE5DFD9),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '1',
                                style: TextStyle(
                                  color: _currentStep == 1 ? Colors.white : const Color(0xFF696969),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Owner Verification',
                                  style: TextStyle(
                                    color: _currentStep == 1 ? Colors.white : const Color(0xFF141413),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Search & verify existing cameras',
                                  style: TextStyle(
                                    color: _currentStep == 1 ? Colors.white70 : const Color(0xFF696969),
                                    fontSize: 8.5,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: _ownerVerified ? () => setState(() => _currentStep = 2) : null,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: _currentStep == 2 ? const Color(0xFF141413) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _currentStep == 2 ? const Color(0xFF141413) : const Color(0xFFE5DFD9),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: _currentStep == 2 ? const Color(0xFFCF4500) : const Color(0xFFE5DFD9),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '2',
                                style: TextStyle(
                                  color: _currentStep == 2 ? Colors.white : const Color(0xFF696969),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Register Camera',
                                  style: TextStyle(
                                    color: _currentStep == 2 ? Colors.white : const Color(0xFF141413),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Photo & duplicate check',
                                  style: TextStyle(
                                    color: _currentStep == 2 ? Colors.white70 : const Color(0xFF696969),
                                    fontSize: 8.5,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ==========================================
            // STEP 1 CONTENT: OWNER MOBILE VERIFICATION
            // ==========================================
            if (_currentStep == 1) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE5DFD9)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.phone_outlined, size: 16, color: Color(0xFFCF4500)),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            'STEP 1: ENTER OWNER MOBILE NUMBER',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF141413),
                              letterSpacing: 0.3,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F0EE),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'GIS Lookup',
                            style: TextStyle(fontSize: 8.5, color: Color(0xFF696969), fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Phone input field + Verify button
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _ownerSearchController,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.phone_rounded, size: 18, color: Color(0xFF696969)),
                              hintText: 'e.g. 9871144444 or +91 98711 44444',
                              hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF8C827A)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              filled: true,
                              fillColor: const Color(0xFFF7F6F3),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: Color(0xFFE5DFD9)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: Color(0xFFE5DFD9)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: _isSearchingOwner ? null : () => _verifyOwnerMobile(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF141413),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          icon: _isSearchingOwner
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.search_rounded, size: 16, color: Color(0xFFFF8555)),
                          label: const Text('Verify Mobile', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Quick Test Buttons (Image 4)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'QUICK TEST:',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF8C827A),
                          ),
                        ),
                        ..._sampleOwners.map((s) {
                          return ActionChip(
                            label: Text(
                              '${s['label']} (${s['number']})',
                              style: const TextStyle(fontSize: 10, color: Color(0xFF141413)),
                            ),
                            backgroundColor: const Color(0xFFF3F0EE),
                            side: const BorderSide(color: Color(0xFFD1CDC7)),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            onPressed: () {
                              _ownerSearchController.text = s['number']!;
                              _verifyOwnerMobile(s['number']);
                            },
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),

              // Owner Verification Result Details (Now in Crisp White Box!)
              if (_ownerVerified) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE5DFD9)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF4E5),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFFF8C6BC)),
                                ),
                                child: const Icon(Icons.business_rounded, color: Color(0xFFCF4500), size: 20),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _verifiedOwnerName,
                                    style: const TextStyle(
                                      color: Color(0xFF141413),
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    _verifiedOwnerContact,
                                    style: const TextStyle(
                                      color: Color(0xFF696969),
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAF7EE),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFBDE8C8)),
                            ),
                            child: const Text(
                              '✓ VERIFIED',
                              style: TextStyle(
                                color: Color(0xFF0A7334),
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Breakdown Pills in Clean White Theme
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF7F6F3),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFE5DFD9)),
                              ),
                              child: Column(
                                children: [
                                  const Text('TOTAL CAMERAS', style: TextStyle(color: Color(0xFF696969), fontSize: 8.5, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_existingOwnerCameras.length}',
                                    style: const TextStyle(color: Color(0xFF141413), fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAF7EE),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFBDE8C8)),
                              ),
                              child: Column(
                                children: [
                                  const Text('APPROVED & LIVE', style: TextStyle(color: Color(0xFF0A7334), fontSize: 8.5, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$_ownerApprovedCount',
                                    style: const TextStyle(color: Color(0xFF0A7334), fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF4E5),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFF8C6BC)),
                              ),
                              child: Column(
                                children: [
                                  const Text('PENDING AUDIT', style: TextStyle(color: Color(0xFFCF4500), fontSize: 8.5, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$_ownerPendingCount',
                                    style: const TextStyle(color: Color(0xFFCF4500), fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Physical Inspection Checklist Alert
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF0EE),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFF8C6BC)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFCF4500)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Surveyor Physical Camera Audit Required: Please inspect all physical hardware on site before adding a new camera. Ensure serial numbers and angles match installed equipment.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF141413), height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Existing cameras list at this premise
                if (_existingOwnerCameras.isNotEmpty) ...[
                  Text(
                    'Previously Registered Cameras at this Premise (${_existingOwnerCameras.length})',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF141413)),
                  ),
                  const SizedBox(height: 8),
                  ..._existingOwnerCameras.map((cam) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5DFD9)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F0EE),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.videocam_rounded, size: 20, color: Color(0xFF141413)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      cam.cameraCode,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'monospace',
                                        color: Color(0xFF3860BE),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: cam.verificationStatus == 'APPROVED'
                                            ? const Color(0xFFEAF7EE)
                                            : const Color(0xFFFFF4E5),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        cam.verificationStatus,
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: cam.verificationStatus == 'APPROVED'
                                              ? const Color(0xFF0A7334)
                                              : const Color(0xFFCF4500),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  cam.cameraName,
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  '${cam.cameraType} | ${cam.coverageRadiusMeters.toInt()}m radius | ${cam.directionAngle.toInt()}°',
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF696969)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 14),

                // Button: Proceed to Camera Registration
                CustomButton(
                  text: 'Proceed to Camera Registration',
                  icon: Icons.arrow_forward_rounded,
                  variant: ButtonVariant.primary,
                  onPressed: () {
                    setState(() => _currentStep = 2);
                  },
                  height: 50,
                ),
              ],
            ],

            // ==========================================
            // STEP 2 CONTENT: REGISTER CAMERA (Image 3)
            // ==========================================
            if (_currentStep == 2) ...[
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Context Owner Banner (Responsive & Non-overflowing)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F0EE),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE5DFD9)),
                      ),
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () => setState(() => _currentStep = 1),
                            borderRadius: BorderRadius.circular(12),
                            child: const Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Icon(Icons.arrow_back, size: 18, color: Color(0xFF141413)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Registering Camera for Owner:',
                                  style: TextStyle(fontSize: 9, color: Color(0xFF696969)),
                                ),
                                Text(
                                  '$_verifiedOwnerName ($_verifiedOwnerContact)',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF141413),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF4E5),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFF8C6BC)),
                            ),
                            child: const Text(
                              'PENDING',
                              style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFFCF4500)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // CAMERA IDENTIFICATION CODE & DUPLICATE CHECK CARD (Non-overflowing)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE5DFD9)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.qr_code_scanner_rounded, size: 16, color: Color(0xFF3860BE)),
                              const SizedBox(width: 6),
                              const Expanded(
                                child: Text(
                                  'CAMERA CODE & DUPLICATE CHECK',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF141413),
                                    letterSpacing: 0.3,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Generate New Code Button (Image 3)
                              InkWell(
                                onTap: _generateNewCameraCode,
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFFD1CDC7)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.04),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.refresh_rounded, size: 12, color: Color(0xFF3860BE)),
                                      SizedBox(width: 4),
                                      Text(
                                        'Generate Code',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF141413),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Code TextField
                          CustomTextField(
                            controller: _cameraCodeController,
                            label: 'Camera Identification Code *',
                            hint: 'e.g. CAM-9645',
                            prefixIcon: Icons.qr_code_2_rounded,
                            onChanged: (_) => _onCodeOrSerialChanged(),
                            validator: (val) => val == null || val.trim().isEmpty ? 'Camera code required' : null,
                          ),
                          const SizedBox(height: 10),

                          // Verified Unique in Police Registry Banner (Image 3)
                          if (regState.duplicateStatus == null || !regState.duplicateStatus!.isDuplicate)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAF7EE),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFBDE8C8)),
                              ),
                              child: Row(
                                children: const [
                                  Icon(Icons.check_circle_outline_rounded, size: 16, color: Color(0xFF0A7334)),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Camera code is unique and verified in police registry database.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF0A7334),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFDF0EE),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFCF4500)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFCF4500)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      regState.duplicateStatus!.message ?? 'Warning: Duplicate code detected in registry!',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFFCF4500),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Identification & Hardware Card (Image 2)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE5DFD9)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Identification & Hardware',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF141413)),
                          ),
                          const SizedBox(height: 12),
                          CustomTextField(
                            controller: _cameraNameController,
                            label: 'Camera Name / Label',
                            hint: 'e.g. Sitabuldi Main Junction North-Facing',
                            prefixIcon: Icons.label_outline_rounded,
                            validator: (val) => val == null || val.trim().isEmpty ? 'Name required' : null,
                          ),
                          const SizedBox(height: 12),
                          CustomTextField(
                            controller: _serialNumberController,
                            label: 'Hardware Serial Number',
                            hint: 'e.g. SN-DS-2CD2043G2-019',
                            prefixIcon: Icons.numbers_rounded,
                            onChanged: (_) => _onCodeOrSerialChanged(),
                          ),
                          const SizedBox(height: 12),
                          const Text('Camera Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: _cameraType,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFFF7F6F3),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: Color(0xFFE5DFD9)),
                              ),
                            ),
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
                    const SizedBox(height: 14),

                    // Site Photo Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE5DFD9)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CCTV Camera Site Photo',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF141413)),
                          ),
                          const SizedBox(height: 10),
                          if (_pickedImage != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.file(_pickedImage!, height: 160, width: double.infinity, fit: BoxFit.cover),
                            ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _pickImage(ImageSource.camera),
                                  icon: const Icon(Icons.camera_alt_outlined, size: 16),
                                  label: const Text('Take Photo', style: TextStyle(fontSize: 12)),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _pickImage(ImageSource.gallery),
                                  icon: const Icon(Icons.photo_library_outlined, size: 16),
                                  label: const Text('Gallery', style: TextStyle(fontSize: 12)),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // GPS Spatial Location (Image 2)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE5DFD9)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'GPS Spatial Location',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF141413)),
                              ),
                              TextButton.icon(
                                onPressed: _isGettingLocation ? null : _fetchCurrentLocation,
                                icon: _isGettingLocation
                                    ? const SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.my_location, size: 14),
                                label: const Text('Update GPS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: CustomTextField(
                                  controller: _latitudeController,
                                  label: 'Latitude',
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  validator: (v) => v == null || double.tryParse(v) == null ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: CustomTextField(
                                  controller: _longitudeController,
                                  label: 'Longitude',
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  validator: (v) => v == null || double.tryParse(v) == null ? 'Required' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          CustomTextField(
                            controller: _addressController,
                            label: 'Full Address',
                            hint: 'Road name, landmark, building number',
                            prefixIcon: Icons.place_outlined,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: CustomTextField(
                                  controller: _areaController,
                                  label: 'Area / Locality',
                                  hint: 'e.g. Sitabuldi',
                                ),
                              ),
                              const SizedBox(width: 10),
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
                    const SizedBox(height: 14),

                    // Lens & Coverage Sliders
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE5DFD9)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Orientation & Coverage',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF141413)),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Facing Angle (Azimuth):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              Text('${_directionAngle.toInt()}°', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Slider(
                            value: _directionAngle,
                            min: 0,
                            max: 360,
                            divisions: 72,
                            activeColor: const Color(0xFF141413),
                            onChanged: (v) => setState(() => _directionAngle = v),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Field of View (FOV):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              Text('${_fovAngle.toInt()}°', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Slider(
                            value: _fovAngle,
                            min: 15,
                            max: 180,
                            divisions: 33,
                            activeColor: const Color(0xFFCF4500),
                            onChanged: (v) => setState(() => _fovAngle = v),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Coverage Radius:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              Text('${_coverageRadius.toInt()} m', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Slider(
                            value: _coverageRadius,
                            min: 10,
                            max: 500,
                            divisions: 49,
                            activeColor: const Color(0xFF141413),
                            onChanged: (v) => setState(() => _coverageRadius = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

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
            ],
          ],
        ),
      ),
    );
  }
}
