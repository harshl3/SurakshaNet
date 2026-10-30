import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/dns_fallback_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../../navigation/role_navigation_shell.dart';
import '../../verification/providers/verification_provider.dart';
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
  final _newOwnerNameController = TextEditingController();
  bool _isSearchingOwner = false;
  bool _ownerSearchPerformed = false;
  bool _ownerFound = false;
  bool _ownerVerified = false;
  String _verifiedOwnerName = '';
  String _verifiedOwnerContact = '';
  String _verifiedOwnerType = 'COMMERCIAL';
  String _newOwnerType = 'COMMERCIAL';
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
  String _cardinalDirection = 'EAST';
  String _cameraType = 'PTZ';

  // Interactive Map Picker (Images 1 & 2)
  bool _useMapPicker = false;
  late final MapController _pickerMapController;

  double get _currentSelectedLat {
    return double.tryParse(_latitudeController.text.trim()) ?? AppConstants.defaultLatitude;
  }

  double get _currentSelectedLng {
    return double.tryParse(_longitudeController.text.trim()) ?? AppConstants.defaultLongitude;
  }

  File? _pickedImage;
  bool _isGettingLocation = false;
  final ImagePicker _picker = ImagePicker();

  // Demo sample owners from frontend (Image 4)
  final List<Map<String, String>> _sampleOwners = [
    {'label': 'Sitabuldi Traders', 'number': '9871144444'},
    {'label': 'Apex Retail', 'number': '9871177777'},
    {'label': 'Shopkeepers Assn', 'number': '9876511111'},
  ];

  @override
  void initState() {
    super.initState();
    _pickerMapController = MapController();
    _latitudeController.text = AppConstants.defaultLatitude.toString();
    _longitudeController.text = AppConstants.defaultLongitude.toString();
    _generateNewCameraCode();
    _fetchCurrentLocation();
  }

  @override
  void dispose() {
    _pickerMapController.dispose();
    _ownerSearchController.dispose();
    _newOwnerNameController.dispose();
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
        final lat = position.latitude;
        final lng = position.longitude;

        // If Android emulator default (Mountain View Googleplex: lat ~ 37.42, lng ~ -122.08)
        // or outside India, default to Nagpur police jurisdiction
        final isEmulatorGoogleplex = (lat > 37.0 && lat < 38.0 && lng < -120.0);
        final effectiveLat = isEmulatorGoogleplex ? AppConstants.defaultLatitude : lat;
        final effectiveLng = isEmulatorGoogleplex ? AppConstants.defaultLongitude : lng;

        setState(() {
          _latitudeController.text = effectiveLat.toStringAsFixed(6);
          _longitudeController.text = effectiveLng.toStringAsFixed(6);
        });
        if (_useMapPicker) {
          _pickerMapController.move(LatLng(effectiveLat, effectiveLng), 15.5);
        }
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

  void _onPickerMapTap(LatLng point) {
    setState(() {
      _latitudeController.text = point.latitude.toStringAsFixed(6);
      _longitudeController.text = point.longitude.toStringAsFixed(6);
    });
    _pickerMapController.move(point, _pickerMapController.camera.zoom);
  }

  String _calcCardinal(double deg) {
    final d = (deg % 360 + 360) % 360;
    if (d >= 22.5 && d < 67.5) return 'NORTH-EAST';
    if (d >= 67.5 && d < 112.5) return 'EAST';
    if (d >= 112.5 && d < 157.5) return 'SOUTH-EAST';
    if (d >= 157.5 && d < 202.5) return 'SOUTH';
    if (d >= 202.5 && d < 247.5) return 'SOUTH-WEST';
    if (d >= 247.5 && d < 292.5) return 'WEST';
    if (d >= 292.5 && d < 337.5) return 'NORTH-WEST';
    return 'NORTH';
  }

  Future<void> _verifyOwnerMobile([String? phone]) async {
    final rawSearch = phone ?? _ownerSearchController.text.trim();
    final search = rawSearch.replaceAll(RegExp(r'\D'), '');
    if (search.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 10-digit mobile number to verify.'),
          backgroundColor: Color(0xFFCF4500),
        ),
      );
      return;
    }

    setState(() {
      _isSearchingOwner = true;
    });

    try {
      final summary = await ref.read(cameraRepositoryProvider).lookupOwner(search);
      final hasExistingData = summary.ownerFound &&
          (summary.cameras.isNotEmpty || (summary.ownerName != null && summary.ownerName!.trim().isNotEmpty));

      setState(() {
        _ownerSearchPerformed = true;
        _verifiedOwnerContact = search;

        if (hasExistingData) {
          _ownerFound = true;
          _ownerVerified = true;
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
        } else {
          // New Premise / First-Time Registration (Image 2)
          _ownerFound = false;
          _ownerVerified = false;
          _newOwnerNameController.clear();
          _verifiedOwnerName = '';
          _verifiedOwnerType = 'COMMERCIAL';
          _newOwnerType = 'COMMERCIAL';
          _existingOwnerCameras = [];
          _ownerApprovedCount = 0;
          _ownerPendingCount = 0;
        }
      });
    } catch (e) {
      setState(() {
        _ownerSearchPerformed = true;
        _ownerFound = false;
        _ownerVerified = false;
        _verifiedOwnerContact = search;
        _newOwnerNameController.clear();
        _verifiedOwnerName = '';
        _verifiedOwnerType = 'COMMERCIAL';
        _newOwnerType = 'COMMERCIAL';
        _existingOwnerCameras = [];
        _ownerApprovedCount = 0;
        _ownerPendingCount = 0;
      });
    } finally {
      if (mounted) setState(() => _isSearchingOwner = false);
    }
  }

  void _proceedWithNewOwner() {
    final name = _newOwnerNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter Owner / Establishment name to proceed.'),
          backgroundColor: Color(0xFFCF4500),
        ),
      );
      return;
    }

    setState(() {
      _verifiedOwnerName = name;
      _verifiedOwnerType = _newOwnerType;
      _ownerVerified = true;
      _cameraNameController.text = '$name Camera 1';
      _currentStep = 2;
    });
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

  void _resetForm() {
    setState(() {
      _currentStep = 1;
      _ownerSearchController.clear();
      _newOwnerNameController.clear();
      _isSearchingOwner = false;
      _ownerSearchPerformed = false;
      _ownerFound = false;
      _ownerVerified = false;
      _verifiedOwnerName = '';
      _verifiedOwnerContact = '';
      _existingOwnerCameras = [];
      _ownerApprovedCount = 0;
      _ownerPendingCount = 0;
      _cameraCodeController.clear();
      _cameraNameController.clear();
      _serialNumberController.clear();
      _latitudeController.clear();
      _longitudeController.clear();
      _addressController.clear();
      _areaController.clear();
      _wardController.clear();
      _zoneController.clear();
      _pickedImage = null;
      _useMapPicker = false;
    });
    ref.read(cameraRegistrationProvider.notifier).reset();
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
      'cardinalDirection': _cardinalDirection,
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
      ref.invalidate(verificationQueueProvider);
      ref.invalidate(dashboardStatsProvider);

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
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.signalOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              icon: const Icon(Icons.dashboard_rounded, size: 18),
              onPressed: () {
                Navigator.of(ctx).pop();
                _resetForm();
                ref.read(selectedBottomNavIndexProvider.notifier).state = 0;
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
              label: const Text(
                'Return to Surveyor Dashboard',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
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
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            maxLength: 10,
                            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                            style: const TextStyle(fontSize: 13, fontFamily: 'monospace', letterSpacing: 0.8),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.phone_rounded, size: 18, color: Color(0xFF696969)),
                              hintText: 'e.g. 9871144444 (10 digits)',
                              hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF8C827A), letterSpacing: 0),
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

              // Owner Verification Search Results (Existing Premise vs New Premise)
              if (_ownerSearchPerformed) ...[
                if (_ownerFound) ...[
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
                ] else ...[
                  // New Premise / First-Time Registration Card (Matches Image 2)
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(20),
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
                      children: [
                        // Centered Circular Building/Store Icon
                        Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF3F0EE),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.storefront_rounded, color: Color(0xFFCF4500), size: 24),
                        ),
                        const SizedBox(height: 12),

                        // Card Title
                        const Text(
                          'New Premise / First-Time Registration',
                          style: TextStyle(
                            color: Color(0xFF141413),
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),

                        // Subtitle with searched phone
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF696969), height: 1.4),
                            children: [
                              const TextSpan(text: 'No previously surveyed cameras were found for mobile '),
                              TextSpan(
                                text: _verifiedOwnerContact,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF141413),
                                  fontFamily: 'monospace',
                                ),
                              ),
                              const TextSpan(
                                text: '. You can now register the owner details and map the premise\'s first CCTV camera node.',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Form Inputs
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Owner / Establishment Name *',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF141413)),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _newOwnerNameController,
                              textCapitalization: TextCapitalization.words,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF141413)),
                              decoration: InputDecoration(
                                hintText: 'e.g. ABC Electronic Mart',
                                hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF8C827A)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                filled: true,
                                fillColor: const Color(0xFFF7F6F3),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Color(0xFFE5DFD9)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Color(0xFFE5DFD9)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Color(0xFFCF4500), width: 1.5),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            const Text(
                              'Premise Category',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF141413)),
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: _newOwnerType,
                              style: const TextStyle(fontSize: 12.5, color: Color(0xFF141413)),
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF696969)),
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                filled: true,
                                fillColor: const Color(0xFFF7F6F3),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Color(0xFFE5DFD9)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Color(0xFFE5DFD9)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Color(0xFFCF4500), width: 1.5),
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'COMMERCIAL', child: Text('Commercial Retail / Mall')),
                                DropdownMenuItem(value: 'RESIDENTIAL', child: Text('Residential Society')),
                                DropdownMenuItem(value: 'BANK_ATM', child: Text('Bank / ATM Kiosk')),
                                DropdownMenuItem(value: 'INDUSTRIAL', child: Text('Warehouse / Factory')),
                                DropdownMenuItem(value: 'PUBLIC_COMMUNITY', child: Text('Public Community / Market')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _newOwnerType = val);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Proceed Button
                        CustomButton(
                          text: 'Proceed to Camera Registration',
                          icon: Icons.arrow_forward_rounded,
                          variant: ButtonVariant.primary,
                          onPressed: _proceedWithNewOwner,
                          height: 48,
                        ),
                        const SizedBox(height: 8),

                        // Cancel / Reset option
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _ownerSearchPerformed = false;
                              _ownerFound = false;
                              _ownerVerified = false;
                              _ownerSearchController.clear();
                              _newOwnerNameController.clear();
                            });
                          },
                          icon: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF696969)),
                          label: const Text('Cancel & Enter Different Number', style: TextStyle(fontSize: 11, color: Color(0xFF696969))),
                        ),
                      ],
                    ),
                  ),
                ],
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

                    // Geospatial Coordinates Card with Auto GPS and Pick on Map (Images 1 & 2)
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
                          // Header with Auto GPS and Pick on Map buttons (Non-overflowing)
                          Row(
                            children: [
                              const Icon(Icons.place_outlined, color: Color(0xFFCF4500), size: 16),
                              const SizedBox(width: 4),
                              const Expanded(
                                child: Text(
                                  'GEOSPATIAL COORDINATES',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF141413),
                                    letterSpacing: 0.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Auto GPS Button
                                  OutlinedButton.icon(
                                    onPressed: _isGettingLocation ? null : _fetchCurrentLocation,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF141413),
                                      side: const BorderSide(color: Color(0xFF141413)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    icon: _isGettingLocation
                                        ? const SizedBox(
                                            width: 10,
                                            height: 10,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFCF4500)),
                                          )
                                        : const Icon(Icons.near_me_outlined, size: 12, color: Color(0xFF3860BE)),
                                    label: Text(
                                      _isGettingLocation ? 'GPS...' : 'Auto GPS',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 6),

                                  // Pick on Map / Close Map Button
                                  ElevatedButton(
                                    onPressed: () {
                                      setState(() {
                                        _useMapPicker = !_useMapPicker;
                                      });
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _useMapPicker ? const Color(0xFF141413) : Colors.white,
                                      foregroundColor: _useMapPicker ? Colors.white : const Color(0xFF141413),
                                      side: const BorderSide(color: Color(0xFF141413)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                                      elevation: 0,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    child: Text(
                                      _useMapPicker ? 'Close Map' : 'Pick on Map',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Embedded 2D Street Map Picker (Matching Images 1 & 2)
                          if (_useMapPicker) ...[
                            Container(
                              height: 260,
                              width: double.infinity,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: const Color(0xFFD1CDC7)),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Stack(
                                children: [
                                  FlutterMap(
                                    mapController: _pickerMapController,
                                    options: MapOptions(
                                      initialCenter: LatLng(_currentSelectedLat, _currentSelectedLng),
                                      initialZoom: 15.5,
                                      minZoom: 4.0,
                                      maxZoom: 19.0,
                                      onTap: (tapPosition, point) => _onPickerMapTap(point),
                                    ),
                                    children: [
                                      TileLayer(
                                        urlTemplate: AppConstants.streetTileUrl,
                                        fallbackUrl: AppConstants.streetTileFallbackUrl,
                                                                                userAgentPackageName: 'in.gov.mahapolice.surakshanet',
                                        tileProvider: createResilientTileProvider(),
                                        evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
                                        maxZoom: 18,
                                      ),
                                      MarkerLayer(
                                        markers: [
                                          Marker(
                                            point: LatLng(_currentSelectedLat, _currentSelectedLng),
                                            width: 48,
                                            height: 48,
                                            alignment: Alignment.center,
                                            child: const PickerTargetPinWidget(),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),

                                  // Top floating badges & instructions (Image 1)
                                  Positioned(
                                    top: 8,
                                    left: 8,
                                    right: 8,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        // 2D GRID NAGPUR Pill
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF141413).withValues(alpha: 0.88),
                                            borderRadius: BorderRadius.circular(14),
                                            border: Border.all(color: Colors.white24),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: const [
                                              Icon(Icons.shield_outlined, size: 11, color: Colors.white),
                                              SizedBox(width: 3),
                                              Text('2D GRID', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                              SizedBox(width: 3),
                                              Text('NAGPUR', style: TextStyle(color: Color(0xFFFF8555), fontSize: 8, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                        // Center instruction pill
                                        Flexible(
                                          child: Container(
                                            margin: const EdgeInsets.symmetric(horizontal: 4),
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF141413).withValues(alpha: 0.90),
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(color: Colors.white24),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 5,
                                                  height: 5,
                                                  decoration: const BoxDecoration(
                                                    color: Color(0xFFCF4500),
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                const SizedBox(width: 5),
                                                const Flexible(
                                                  child: Text(
                                                    'Click map to set camera GPS coordinates',
                                                    style: TextStyle(color: Color(0xFFF3F0EE), fontSize: 8.5, fontWeight: FontWeight.w500),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        // Expand pill (Image 1)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.92),
                                            borderRadius: BorderRadius.circular(14),
                                            border: Border.all(color: const Color(0xFFD1CDC7)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: const [
                                              Icon(Icons.open_in_full_rounded, size: 10, color: Color(0xFFCF4500)),
                                              SizedBox(width: 3),
                                              Text('Expand', style: TextStyle(color: Color(0xFF141413), fontSize: 8.5, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],

                          // Latitude & Longitude inputs (Images 1 & 2)
                          Row(
                            children: [
                              Expanded(
                                child: CustomTextField(
                                  controller: _latitudeController,
                                  label: 'Latitude *',
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  validator: (v) => v == null || double.tryParse(v) == null ? 'Required' : null,
                                  onChanged: (v) {
                                    final lat = double.tryParse(v);
                                    if (lat != null && _useMapPicker) {
                                      _pickerMapController.move(LatLng(lat, _currentSelectedLng), _pickerMapController.camera.zoom);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: CustomTextField(
                                  controller: _longitudeController,
                                  label: 'Longitude *',
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  validator: (v) => v == null || double.tryParse(v) == null ? 'Required' : null,
                                  onChanged: (v) {
                                    final lng = double.tryParse(v);
                                    if (lng != null && _useMapPicker) {
                                      _pickerMapController.move(LatLng(_currentSelectedLat, lng), _pickerMapController.camera.zoom);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          CustomTextField(
                            controller: _addressController,
                            label: 'Premise Physical Address',
                            hint: 'e.g. Shop 4, Ground Floor, Central Plaza, Main Market Road',
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

                    // Camera Lens Direction & View Angle Coverage (Matches Image 3)
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
                          // Header with live summary badges
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.explore_outlined, color: Color(0xFF3860BE), size: 18),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'CAMERA LENS DIRECTION & VIEW ANGLE COVERAGE',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF141413),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        // Direction badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF141413),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            '$_cardinalDirection (${_directionAngle.toInt()}°)',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'monospace',
                                            ),
                                          ),
                                        ),
                                        // Arc FOV badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFDF0EE),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: const Color(0xFFF8C6BC)),
                                          ),
                                          child: Text(
                                            'Arc: ${_fovAngle.toInt()}° View',
                                            style: const TextStyle(
                                              color: Color(0xFFCF4500),
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        // Radius badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF3F0EE),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            'Radius: ${_coverageRadius.toInt()}m',
                                            style: const TextStyle(
                                              color: Color(0xFF141413),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Divider(height: 1, color: Color(0xFFE5DFD9)),
                          const SizedBox(height: 12),

                          // 1. Cardinal Facing Direction
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Expanded(
                                child: Text(
                                  '1. Cardinal Facing Direction *',
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF141413)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: 6),
                              Text(
                                '8-Point Compass Bearing',
                                style: TextStyle(fontSize: 9.5, color: Color(0xFF696969)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // 8 Cardinal Direction Buttons (2 rows x 4 columns)
                          Column(
                            children: [
                              Row(
                                children: [
                                  _buildCardinalButton('NORTH', 'N', 0, '⬆'),
                                  const SizedBox(width: 6),
                                  _buildCardinalButton('NORTH-EAST', 'NE', 45, '↗'),
                                  const SizedBox(width: 6),
                                  _buildCardinalButton('EAST', 'E', 90, '➡'),
                                  const SizedBox(width: 6),
                                  _buildCardinalButton('SOUTH-EAST', 'SE', 135, '↘'),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  _buildCardinalButton('SOUTH', 'S', 180, '⬇'),
                                  const SizedBox(width: 6),
                                  _buildCardinalButton('SOUTH-WEST', 'SW', 225, '↙'),
                                  const SizedBox(width: 6),
                                  _buildCardinalButton('WEST', 'W', 270, '⬅'),
                                  const SizedBox(width: 6),
                                  _buildCardinalButton('NORTH-WEST', 'NW', 315, '↖'),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Fine Compass Degree Bearing Slider
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Text(
                                  'Fine Compass Degree Bearing (0° - 360°):',
                                  style: TextStyle(fontSize: 10.5, color: Color(0xFF696969), fontWeight: FontWeight.w500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${_directionAngle.toInt()}° Bearing',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF141413), fontFamily: 'monospace'),
                              ),
                            ],
                          ),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: const Color(0xFF141413),
                              inactiveTrackColor: const Color(0xFFE5DFD9),
                              thumbColor: const Color(0xFF141413),
                              overlayColor: const Color(0xFF141413).withValues(alpha: 0.12),
                              trackHeight: 3,
                            ),
                            child: Slider(
                              value: _directionAngle,
                              min: 0,
                              max: 360,
                              onChanged: (v) {
                                setState(() {
                                  _directionAngle = v;
                                  _cardinalDirection = _calcCardinal(v);
                                });
                              },
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Divider(height: 1, color: Color(0xFFE5DFD9)),
                          const SizedBox(height: 12),

                          // 2. Camera View Covering Angle (Field of View - FOV)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text(
                                      '2. Camera View Covering Angle (Field of View - FOV) *',
                                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF141413)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 1),
                                    Text(
                                      'Spread width of area captured by camera lens',
                                      style: TextStyle(fontSize: 9.5, color: Color(0xFF696969)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFDF0EE),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFF8C6BC)),
                                ),
                                child: Text(
                                  '${_fovAngle.toInt()}° Spread',
                                  style: const TextStyle(color: Color(0xFFCF4500), fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // 6 FOV Preset Cards (3 cols x 2 rows)
                          Column(
                            children: [
                              Row(
                                children: [
                                  _buildFovPresetButton('30° Spot', 30, 'Corridor / Spot'),
                                  const SizedBox(width: 6),
                                  _buildFovPresetButton('60° Std', 60, 'Standard Lens'),
                                  const SizedBox(width: 6),
                                  _buildFovPresetButton('90° Wide', 90, 'Wide Street'),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  _buildFovPresetButton('120° Ultra', 120, 'Junction Arc'),
                                  const SizedBox(width: 6),
                                  _buildFovPresetButton('180° Semi', 180, 'Panoramic'),
                                  const SizedBox(width: 6),
                                  _buildFovPresetButton('360° Pan', 360, 'Full 360° Fisheye'),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Fine View Angle Spread Slider
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Text(
                                  'Fine View Angle Spread (15° - 360°):',
                                  style: TextStyle(fontSize: 10.5, color: Color(0xFF696969), fontWeight: FontWeight.w500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${_fovAngle.toInt()}° View Width',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFCF4500), fontFamily: 'monospace'),
                              ),
                            ],
                          ),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: const Color(0xFFCF4500),
                              inactiveTrackColor: const Color(0xFFE5DFD9),
                              thumbColor: const Color(0xFFCF4500),
                              overlayColor: const Color(0xFFCF4500).withValues(alpha: 0.12),
                              trackHeight: 3,
                            ),
                            child: Slider(
                              value: _fovAngle,
                              min: 15,
                              max: 360,
                              onChanged: (v) => setState(() => _fovAngle = v),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Divider(height: 1, color: Color(0xFFE5DFD9)),
                          const SizedBox(height: 12),

                          // 3. Maximum Optical Coverage Radius
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text(
                                      '3. Maximum Optical Coverage Radius (Distance in meters)',
                                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF141413)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 1),
                                    Text(
                                      'Effective identification & detection range from lens',
                                      style: TextStyle(fontSize: 9.5, color: Color(0xFF696969)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF4FE),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFD3E2FB)),
                                ),
                                child: Text(
                                  '${_coverageRadius.toInt()} meters',
                                  style: const TextStyle(color: Color(0xFF3860BE), fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Slider + Value Box (Matches Image 3)
                          Row(
                            children: [
                              Expanded(
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    activeTrackColor: const Color(0xFF3860BE),
                                    inactiveTrackColor: const Color(0xFFE5DFD9),
                                    thumbColor: const Color(0xFF3860BE),
                                    overlayColor: const Color(0xFF3860BE).withValues(alpha: 0.12),
                                    trackHeight: 3,
                                  ),
                                  child: Slider(
                                    value: _coverageRadius,
                                    min: 10,
                                    max: 500,
                                    onChanged: (v) => setState(() => _coverageRadius = v),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 58,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFD1CDC7)),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${_coverageRadius.toInt()}',
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF141413),
                                  ),
                                ),
                              ),
                            ],
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

  Widget _buildCardinalButton(String label, String short, int angle, String arrow) {
    final isSelected = (_directionAngle.toInt() == angle) || (_cardinalDirection == label);
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _directionAngle = angle.toDouble();
            _cardinalDirection = label;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF141413) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF141413) : const Color(0xFFE5DFD9),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(arrow, style: TextStyle(fontSize: 10, color: isSelected ? Colors.white : const Color(0xFF141413))),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(
                        short,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : const Color(0xFF141413),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$angle°',
                style: TextStyle(
                  fontSize: 8.5,
                  fontFamily: 'monospace',
                  color: isSelected ? const Color(0xFFF37338) : const Color(0xFF696969),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFovPresetButton(String label, int angle, String desc) {
    final isSelected = (_fovAngle.toInt() == angle);
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _fovAngle = angle.toDouble();
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFCF4500) : const Color(0xFFF9F7F5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFFCF4500) : const Color(0xFFE5DFD9),
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : const Color(0xFF141413),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 8.5,
                  color: isSelected ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF696969),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom Target Reticle Marker matching Web App Interactive Picker Pin (Image 1)
class PickerTargetPinWidget extends StatelessWidget {
  const PickerTargetPinWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 48,
      height: 48,
      child: CustomPaint(
        painter: _PickerPinPainter(),
      ),
    );
  }
}

class _PickerPinPainter extends CustomPainter {
  const _PickerPinPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // 1. Outer translucent radar area
    final outerFill = Paint()
      ..color = const Color(0xFFCF4500).withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 18, outerFill);

    final outerRing = Paint()
      ..color = const Color(0xFFCF4500).withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, 18, outerRing);

    // 2. Crosshairs pointing outward in 4 cardinal directions (Image 1)
    final crosshairPaint = Paint()
      ..color = const Color(0xFFCF4500)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // Top
    canvas.drawLine(Offset(center.dx, 2), Offset(center.dx, 9), crosshairPaint);
    // Bottom
    canvas.drawLine(Offset(center.dx, size.height - 9), Offset(center.dx, size.height - 2), crosshairPaint);
    // Left
    canvas.drawLine(Offset(2, center.dy), Offset(9, center.dy), crosshairPaint);
    // Right
    canvas.drawLine(Offset(size.width - 9, center.dy), Offset(size.width - 2, center.dy), crosshairPaint);

    // 3. Black circle with crisp white outline
    final whiteOutline = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 11, whiteOutline);

    final blackCircle = Paint()
      ..color = const Color(0xFF141413)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 8.5, blackCircle);

    // 4. Center signal orange dot
    final centerDot = Paint()
      ..color = const Color(0xFFCF4500)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 3.8, centerDot);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


