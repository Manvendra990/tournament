import 'dart:io';
import 'package:slotbookingadmin/core/api/api_services.dart';
import 'package:slotbookingadmin/core/api/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:slotbookingadmin/theme/app_colors.dart';

class AddGroundScreen extends StatefulWidget {
  const AddGroundScreen({super.key});

  @override
  State<AddGroundScreen> createState() => _AddGroundScreenState();
}

class _AddGroundScreenState extends State<AddGroundScreen> {
  static const _green = Color(0xFF0D5C3A);
  static const _greenLight = Color(0xFFE8F5EE);

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();

  String _sportType = 'Cricket';
  bool _isLoading = false;
  List<XFile> _pickedImages = [];
  double _uploadProgress = 0;
  String _uploadStatus = '';

  // ── Location state ──────────────────────────────────
  double? _lat;
  double? _lng;
  bool _locationLoading = false;

  final List<String> _sportTypes = [
    'Cricket',
    'Football',
    'Badminton',
    'Volleyball',
    'Basketball',
    'Tennis',
    'Hockey',
  ];

  final List<_AmenityOption> _amenities = [
    _AmenityOption(label: 'Parking', icon: Icons.local_parking_rounded),
    _AmenityOption(label: 'Drinking Water', icon: Icons.water_drop_outlined),
    _AmenityOption(label: 'Floodlights', icon: Icons.light_mode_outlined),
    _AmenityOption(label: 'Washroom', icon: Icons.wc_rounded),
    _AmenityOption(label: 'Cafeteria', icon: Icons.restaurant_outlined),
    _AmenityOption(label: 'First Aid', icon: Icons.medical_services_outlined),
    _AmenityOption(label: 'Free Wi-Fi', icon: Icons.wifi_rounded),
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  List<String> get _selectedAmenities =>
      _amenities.where((a) => a.selected).map((a) => a.label).toList();

  // ── Capture current location ────────────────────────
  Future<void> _captureLocation() async {
    setState(() => _locationLoading = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnack('Location permission denied', Colors.orange[700]!);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _showSnack(
          'Location permission permanently denied. Settings se enable karo.',
          Colors.red[700]!,
        );
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
    } catch (e) {
      _showSnack('Location fetch failed: $e', Colors.red[700]!);
    } finally {
      if (mounted) setState(() => _locationLoading = false);
    }
  }

  // ── Pick images ─────────────────────────────────────
  Future<void> _pickImages() async {
    final remaining = 4 - _pickedImages.length;
    if (remaining <= 0) {
      _showSnack('Maximum 4 images allowed.', Colors.orange[700]!);
      return;
    }
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(
      imageQuality: 70,
      maxWidth: 1280,
      maxHeight: 960,
    );
    if (picked.isEmpty) return;
    setState(() {
      _pickedImages = [..._pickedImages, ...picked].take(4).toList();
    });
  }

  void _removeImage(int index) => setState(() => _pickedImages.removeAt(index));

  // ── Save ground through REST API ─────────────────────────────────────────
  Future<void> _saveGround() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _uploadProgress = 0; _uploadStatus = 'Saving ground details...'; });
    try {
      final user = SessionManager.currentUser ?? const <String,dynamic>{};
      final data = <String,dynamic>{
        'name': _nameCtrl.text.trim(), 'address': _addressCtrl.text.trim(), 'city': _cityCtrl.text.trim(),
        'sportType': _sportType, 'description': _descCtrl.text.trim(), 'rules': _descCtrl.text.trim(),
        'amenities': _selectedAmenities, 'adminId': SessionManager.currentUserId,
        'adminName': (user['name'] ?? 'Ground Owner').toString(), 'status': true,
        'location': _lat != null && _lng != null ? {'lat': _lat, 'lng': _lng} : null,
        'latitude': _lat ?? 0, 'longitude': _lng ?? 0, 'pricing': <String,dynamic>{},
      };
      setState(() => _uploadStatus = _pickedImages.isEmpty ? 'Creating ground...' : 'Uploading images & creating ground...');
      await GroundApi().create(data: data, images: _pickedImages.map((x)=>File(x.path)).toList());
      if (!mounted) return; _showSuccessDialog();
    } catch (e) { if (mounted) _showSnack('Failed to save ground: $e', Colors.red[700]!); }
    finally { if (mounted) setState(() { _isLoading=false; _uploadProgress=0; _uploadStatus=''; }); }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: .10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: _green,
                  size: 42,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Ground Added!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0E1A13),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your ground has been saved successfully.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[500],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.go('/admin/grounds');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
                  child: const Text(
                    'View Grounds',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── App bar ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: AppColors.primary,
                    ),
                    onPressed: () => context.pop(),
                  ),
                  const Text(
                    'Add New\nGround',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      height: 1.2,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.notifications_none_rounded),
                    color: AppColors.primary,
                    onPressed: () {},
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: .12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),

            // ── Upload progress ──────────────────────
            if (_isLoading && _uploadProgress > 0)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _uploadStatus,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _uploadProgress,
                        backgroundColor: Colors.grey[200],
                        valueColor: const AlwaysStoppedAnimation<Color>(_green),
                        minHeight: 5,
                      ),
                    ),
                  ],
                ),
              ),

            // ── Form ─────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel(
                        'GROUND GALLERY',
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      ),
                      _buildGallery(),

                      // ── Location ──────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Location',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                            ),
                            GestureDetector(
                              onTap: _locationLoading ? null : _captureLocation,
                              child: Row(
                                children: [
                                  _locationLoading
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.primary,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.edit_location_alt_outlined,
                                          size: 16,
                                          color: AppColors.primary,
                                        ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _lat != null ? 'Update' : 'Edit',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // ── Map Card ──────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: double.infinity,
                            height: 140,
                            child: _lat != null && _lng != null
                                ? Stack(
                                    children: [
                                      GoogleMap(
                                        initialCameraPosition: CameraPosition(
                                          target: LatLng(_lat!, _lng!),
                                          zoom: 15,
                                        ),
                                        markers: {
                                          Marker(
                                            markerId: const MarkerId('current'),
                                            position: LatLng(_lat!, _lng!),
                                          ),
                                        },
                                        zoomControlsEnabled: false,
                                        myLocationButtonEnabled: false,
                                        liteModeEnabled: true,
                                      ),
                                      // Lat/Lng badge
                                      Positioned(
                                        bottom: 8,
                                        left: 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black54,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            '${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : Container(
                                    color: AppColors.border,
                                    child: const Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.map_outlined,
                                          size: 48,
                                          color: Colors.grey,
                                        ),
                                        SizedBox(height: 6),
                                        Text(
                                          'Tap Edit to capture location',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Address fields
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            _buildField(
                              controller: _addressCtrl,
                              hint: 'Address',
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Address required'
                                  : null,
                            ),
                            const SizedBox(height: 10),
                            _buildField(
                              controller: _cityCtrl,
                              hint: 'City (e.g. Jhansi)',
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'City required'
                                  : null,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),
                      const Divider(height: 1, color: AppColors.divider),
                      const SizedBox(height: 16),

                      // Ground Name + Sport
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _fieldLabel('Ground Name'),
                            const SizedBox(height: 8),
                            _buildField(
                              controller: _nameCtrl,
                              hint: 'DDA Cricket Ground',
                              validator: (v) =>
                                  (v == null || v.trim().length < 3)
                                  ? 'Enter ground name'
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            _fieldLabel('Sport Type'),
                            const SizedBox(height: 8),
                            _buildDropdown(),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                      const Divider(height: 1, color: AppColors.divider),
                      const SizedBox(height: 16),

                      // Amenities
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Amenities',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  'Select all that apply',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _amenities.map((a) {
                                return GestureDetector(
                                  onTap: () =>
                                      setState(() => a.selected = !a.selected),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: a.selected
                                          ? AppColors.primary.withValues(alpha: .10)
                                          : AppColors.card,
                                      borderRadius: BorderRadius.circular(30),
                                      border: Border.all(
                                        color: a.selected
                                            ? AppColors.primary
                                            : AppColors.primary.withValues(
                                                alpha: .12,
                                              ),
                                        width: a.selected ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          a.icon,
                                          size: 16,
                                          color: a.selected
                                              ? AppColors.primary
                                              : AppColors.textSecondary,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          a.label,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: a.selected
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                            color: a.selected
                                                ? AppColors.primary
                                                : AppColors.textSecondary,
                                          ),
                                        ),
                                        if (a.selected) ...[
                                          const SizedBox(width: 6),
                                          const Icon(
                                            Icons.check_circle,
                                            size: 14,
                                            color: AppColors.primary,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),
                      const Divider(height: 1, color: AppColors.divider),
                      const SizedBox(height: 16),

                      // Description
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _fieldLabel('Ground Description'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _descCtrl,
                              maxLines: 4,
                              style: const TextStyle(fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'A premium cricket facility...',
                                hintStyle: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                                filled: true,
                                fillColor: AppColors.surface,
                                contentPadding: const EdgeInsets.all(14),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: AppColors.primary,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Save button
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _saveGround,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Icon(Icons.save_rounded, size: 20),
                            label: Text(
                              _isLoading
                                  ? (_uploadStatus.isNotEmpty
                                        ? _uploadStatus
                                        : 'Saving...')
                                  : 'Save Details',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              disabledBackgroundColor: AppColors.primary
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      Center(
                        child: TextButton(
                          onPressed: _isLoading ? null : () => context.pop(),
                          child: Text(
                            'Discard Changes',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGallery() {
    return Column(
      children: [
        if (_pickedImages.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(_pickedImages[0].path),
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Cover Photo',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => _removeImage(0),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          GestureDetector(
            onTap: _pickImages,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                height: 180,
                decoration: BoxDecoration(
                  color: _greenLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _green.withValues(alpha: 0.2)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 44,
                      color: _green.withValues(alpha: 0.7),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap to add ground photos',
                      style: TextStyle(
                        fontSize: 13,
                        color: _green.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Up to 4 photos · JPG, PNG',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              ...List.generate(_pickedImages.length.clamp(0, 4), (i) {
                if (i == 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_pickedImages[i].path),
                          width: 68,
                          height: 52,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => _removeImage(i),
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 11,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              if (_pickedImages.length < 4)
                GestureDetector(
                  onTap: _pickImages,
                  child: Container(
                    width: 68,
                    height: 52,
                    decoration: BoxDecoration(
                      color: _greenLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _green.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 18,
                          color: _green,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_pickedImages.length}/4',
                          style: TextStyle(
                            fontSize: 10,
                            color: _green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Text(
            _pickedImages.isEmpty
                ? 'Add up to 4 photos of your ground'
                : '${_pickedImages.length} photo${_pickedImages.length > 1 ? 's' : ''} selected',
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
        ),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
    );
  }

  Widget _buildDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _sportType,
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.textSecondary,
          ),
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
          items: _sportTypes
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (v) => setState(() => _sportType = v!),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, {EdgeInsets? padding}) {
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _AmenityOption {
  final String label;
  final IconData icon;
  bool selected;
  _AmenityOption({
    required this.label,
    required this.icon,
  }) : selected = false;
}
