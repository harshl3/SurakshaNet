import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/dns_fallback_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/picker_target_pin.dart';
import '../providers/investigation_provider.dart';
import 'investigation_detail_screen.dart';

class InvestigationCreateScreen extends ConsumerStatefulWidget {
  const InvestigationCreateScreen({super.key});

  @override
  ConsumerState<InvestigationCreateScreen> createState() => _InvestigationCreateScreenState();
}

class _InvestigationCreateScreenState extends ConsumerState<InvestigationCreateScreen> {
  final _formKey = GlobalKey<FormState>();

  final _caseNumberController = TextEditingController();
  final _firNumberController = TextEditingController();
  final _titleController = TextEditingController();
  final _locationNameController = TextEditingController();
  final _latitudeController = TextEditingController(text: AppConstants.defaultLatitude.toString());
  final _longitudeController = TextEditingController(text: AppConstants.defaultLongitude.toString());
  final _descriptionController = TextEditingController();

  String _crimeType = 'THEFT';
  double _searchRadiusMeters = 500.0;
  bool _isGettingGps = false;

  // Interactive 2D Map Picker
  bool _useMapPicker = false;
  late final MapController _pickerMapController;

  double get _currentSelectedLat => double.tryParse(_latitudeController.text) ?? AppConstants.defaultLatitude;
  double get _currentSelectedLng => double.tryParse(_longitudeController.text) ?? AppConstants.defaultLongitude;

  @override
  void initState() {
    super.initState();
    _pickerMapController = MapController();
    final now = DateTime.now();
    _caseNumberController.text = 'CASE-${now.year}-${now.millisecondsSinceEpoch.toString().substring(8)}';
  }

  @override
  void dispose() {
    _pickerMapController.dispose();
    _caseNumberController.dispose();
    _firNumberController.dispose();
    _titleController.dispose();
    _locationNameController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _fetchCurrentLocation() async {
    setState(() => _isGettingGps = true);
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
        if (_useMapPicker) {
          _pickerMapController.move(LatLng(position.latitude, position.longitude), 15.5);
        }
      }
    } catch (e) {
      debugPrint('Location error: $e');
    } finally {
      if (mounted) setState(() => _isGettingGps = false);
    }
  }

  void _onPickerMapTap(LatLng point) {
    setState(() {
      _latitudeController.text = point.latitude.toStringAsFixed(6);
      _longitudeController.text = point.longitude.toStringAsFixed(6);
    });
    _pickerMapController.move(point, _pickerMapController.camera.zoom);
  }

  Future<void> _submitCase() async {
    if (!_formKey.currentState!.validate()) return;

    final payload = {
      'caseNumber': _caseNumberController.text.trim(),
      if (_firNumberController.text.trim().isNotEmpty)
        'firNumber': _firNumberController.text.trim(),
      'title': _titleController.text.trim(),
      'crimeType': _crimeType,
      'crimeLocationName': _locationNameController.text.trim(),
      'latitude': double.parse(_latitudeController.text.trim()),
      'longitude': double.parse(_longitudeController.text.trim()),
      'incidentDate': DateTime.now().toIso8601String(),
      if (_descriptionController.text.trim().isNotEmpty)
        'description': _descriptionController.text.trim(),
      'searchRadiusMeters': _searchRadiusMeters,
    };

    final createdCase = await ref.read(createInvestigationProvider.notifier).submitCase(payload);

    if (createdCase != null && mounted) {
      ref.invalidate(investigationListProvider);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (ctx) => InvestigationDetailScreen(caseId: createdCase.id),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final createState = ref.watch(createInvestigationProvider);

    return Scaffold(
      backgroundColor: AppColors.canvasCream,
      appBar: AppBar(
        title: const Text('Open Investigation Case'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Case Information',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      CustomTextField(
                        controller: _caseNumberController,
                        label: 'Case Reference Number',
                        hint: 'e.g. CASE-2026-081',
                        prefixIcon: Icons.badge_outlined,
                        validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      CustomTextField(
                        controller: _firNumberController,
                        label: 'FIR Number (Optional)',
                        hint: 'e.g. FIR/402/2026',
                        prefixIcon: Icons.description_outlined,
                      ),
                      const SizedBox(height: 12),
                      CustomTextField(
                        controller: _titleController,
                        label: 'Case Title / Incident Heading',
                        hint: 'e.g. Armed robbery at jewellery store on Wardha Road',
                        prefixIcon: Icons.title_rounded,
                        validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      const Text('Crime Category', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _crimeType,
                        decoration: const InputDecoration(filled: true, fillColor: AppColors.white),
                        items: const [
                          DropdownMenuItem(value: 'THEFT', child: Text('Theft / Larceny')),
                          DropdownMenuItem(value: 'ROBBERY', child: Text('Robbery / Dacoity')),
                          DropdownMenuItem(value: 'BURGLARY', child: Text('Burglary / Break-in')),
                          DropdownMenuItem(value: 'HIT_AND_RUN', child: Text('Hit and Run Traffic Incident')),
                          DropdownMenuItem(value: 'ASSAULT', child: Text('Assault / Violent Crime')),
                          DropdownMenuItem(value: 'MISSING_PERSON', child: Text('Missing Person')),
                          DropdownMenuItem(value: 'OTHER', child: Text('Other Offense')),
                        ],
                        onChanged: (val) => setState(() => _crimeType = val!),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

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
                              'Crime Scene Spatial Coordinates',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _isGettingGps ? null : _fetchCurrentLocation,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF141413),
                                  side: const BorderSide(color: Color(0xFF141413)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                  visualDensity: VisualDensity.compact,
                                ),
                                icon: _isGettingGps
                                    ? const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFCF4500)))
                                    : const Icon(Icons.my_location, size: 12, color: Color(0xFF3860BE)),
                                label: Text(_isGettingGps ? 'GPS...' : 'Device GPS', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 6),
                              ElevatedButton.icon(
                                onPressed: () => setState(() => _useMapPicker = !_useMapPicker),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _useMapPicker ? const Color(0xFF141413) : Colors.white,
                                  foregroundColor: _useMapPicker ? Colors.white : const Color(0xFF141413),
                                  side: const BorderSide(color: Color(0xFF141413)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                                  elevation: 0,
                                  visualDensity: VisualDensity.compact,
                                ),
                                icon: Icon(_useMapPicker ? Icons.close_rounded : Icons.map_outlined, size: 12, color: _useMapPicker ? Colors.white : const Color(0xFFCF4500)),
                                label: Text(_useMapPicker ? 'Close Map' : 'Pick on Map', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Embedded 2D Street Map Picker (Matching Camera Registration)
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
                                  CircleLayer(
                                    circles: [
                                      CircleMarker(
                                        point: LatLng(_currentSelectedLat, _currentSelectedLng),
                                        radius: _searchRadiusMeters,
                                        useRadiusInMeter: true,
                                        color: const Color(0xFFF37338).withValues(alpha: 0.15),
                                        borderColor: const Color(0xFFCF4500),
                                        borderStrokeWidth: 1.8,
                                      ),
                                    ],
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

                              // Top floating badges & instructions
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
                                                'Tap map to set crime scene coordinates',
                                                style: TextStyle(color: Color(0xFFF3F0EE), fontSize: 8.5, fontWeight: FontWeight.w500),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    // Radius indicator pill
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.92),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: const Color(0xFFD1CDC7)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.radar_rounded, size: 10, color: Color(0xFFCF4500)),
                                          const SizedBox(width: 3),
                                          Text('${_searchRadiusMeters.toInt()}m', style: const TextStyle(color: Color(0xFF141413), fontSize: 8.5, fontWeight: FontWeight.bold)),
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
                      CustomTextField(
                        controller: _locationNameController,
                        label: 'Crime Location / Landmark Name',
                        hint: 'e.g. Near Sitabuldi Metro Station Gate 2',
                        prefixIcon: Icons.place_outlined,
                        validator: (val) => val == null || val.trim().isEmpty ? 'Location name is required' : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: CustomTextField(
                              controller: _latitudeController,
                              label: 'Latitude',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (val) => val == null || double.tryParse(val) == null ? 'Valid coordinate required' : null,
                              onChanged: (v) {
                                final lat = double.tryParse(v);
                                if (lat != null && _useMapPicker) {
                                  _pickerMapController.move(LatLng(lat, _currentSelectedLng), _pickerMapController.camera.zoom);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CustomTextField(
                              controller: _longitudeController,
                              label: 'Longitude',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (val) => val == null || double.tryParse(val) == null ? 'Valid coordinate required' : null,
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
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Auto-Discovery Radius:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          Text(
                            '${_searchRadiusMeters.toInt()} meters',
                            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.signalOrange),
                          ),
                        ],
                      ),
                      Slider(
                        value: _searchRadiusMeters,
                        min: 100,
                        max: 2000,
                        divisions: 19,
                        activeColor: AppColors.signalOrange,
                        onChanged: (val) => setState(() => _searchRadiusMeters = val),
                      ),
                      const Text(
                        'Backend PostGIS will execute ST_DWithin and link all cameras in this perimeter as evidence nodes.',
                        style: TextStyle(fontSize: 11, color: AppColors.slateGray),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Incident Notes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      CustomTextField(
                        controller: _descriptionController,
                        label: 'Initial Description & Timelines',
                        hint: 'Provide modus operandi, escape direction, or suspect descriptions...',
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              if (createState.errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.statusOfflineRedLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    createState.errorMessage!,
                    style: const TextStyle(color: AppColors.statusOfflineRed, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              CustomButton(
                text: 'Create Case & Auto-Match Cameras',
                icon: Icons.radar_rounded,
                variant: ButtonVariant.primary,
                isLoading: createState.isSubmitting,
                onPressed: _submitCase,
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
