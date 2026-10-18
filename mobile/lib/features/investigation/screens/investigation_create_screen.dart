import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
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

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _caseNumberController.text = 'CASE-${now.year}-${now.millisecondsSinceEpoch.toString().substring(8)}';
  }

  @override
  void dispose() {
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
      }
    } catch (e) {
      debugPrint('Location error: $e');
    } finally {
      if (mounted) setState(() => _isGettingGps = false);
    }
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
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _isGettingGps ? null : _fetchCurrentLocation,
                            icon: _isGettingGps
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.my_location, size: 16),
                            label: const Text('Device GPS'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
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
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CustomTextField(
                              controller: _longitudeController,
                              label: 'Longitude',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (val) => val == null || double.tryParse(val) == null ? 'Valid coordinate required' : null,
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
