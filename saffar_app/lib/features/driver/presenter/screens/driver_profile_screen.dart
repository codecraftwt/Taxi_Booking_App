import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:saffar_app/core/constants/nums.dart';
import 'package:saffar_app/core/models/driver.dart';
import 'package:saffar_app/core/palette.dart';
import 'package:saffar_app/features/driver/presenter/cubits/driver_cubit.dart';
import 'package:saffar_app/features/driver/presenter/screens/driver_vehicles_screen.dart';
import 'package:saffar_app/features/authentication/presenter/screens/role_selection_screen.dart';

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({Key? key}) : super(key: key);

  static const String routeName = '/driver_profile';

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DriverCubit>().refreshProfile();
    });
  }

  void _showPhotoOptionsDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    'Update Profile Photo',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Palette.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.photo_camera_rounded, color: Palette.primary),
                  ),
                  title: const Text('Take Photo with Camera', style: TextStyle(fontWeight: FontWeight.w700)),
                  onTap: () {
                    Navigator.pop(bottomSheetCtx);
                    _pickAndUploadPhoto(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C63FF).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.photo_library_rounded, color: Color(0xFF6C63FF)),
                  ),
                  title: const Text('Choose from Gallery / Files', style: TextStyle(fontWeight: FontWeight.w700)),
                  onTap: () {
                    Navigator.pop(bottomSheetCtx);
                    _pickAndUploadPhoto(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    setState(() => _isUploadingPhoto = true);
    try {
      XFile? file;
      try {
        file = await _picker.pickImage(
          source: source,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 85,
        );
      } catch (err) {
        if (source == ImageSource.camera) {
          file = await _picker.pickImage(source: ImageSource.gallery);
        } else {
          rethrow;
        }
      }

      if (file == null) {
        setState(() => _isUploadingPhoto = false);
        return;
      }

      final bytes = await file.readAsBytes();
      final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';

      if (!mounted) return;
      await context.read<DriverCubit>().uploadPhoto(base64Image);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated successfully!'),
            backgroundColor: Color(0xFF219653),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update photo: $e'),
            backgroundColor: Palette.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  void _showEditProfileModal(BuildContext context, Driver driver) {
    final nameCtrl = TextEditingController(text: driver.name);
    final emailCtrl = TextEditingController(text: driver.email ?? '');
    final ageCtrl = TextEditingController(text: driver.age?.toString() ?? '');
    final addressCtrl = TextEditingController(text: driver.address ?? '');
    final vehicleNameCtrl = TextEditingController(text: driver.vehicleName);
    final vehicleModelCtrl = TextEditingController(text: driver.vehicleModel ?? '');
    final vehicleNumberCtrl = TextEditingController(text: driver.vehicleNumber);
    String selectedGender = driver.gender ?? 'Male';

    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.88,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Drag Handle & Header
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 4),
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Edit Driver Profile',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(modalCtx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // Form Fields
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Form(
                        key: formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ─── Personal Info ───
                            const Text(
                              'PERSONAL DETAILS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF64748B),
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Name
                            _buildInputField(
                              controller: nameCtrl,
                              label: 'Full Name',
                              hint: 'Enter your full name',
                              icon: Icons.person_outline_rounded,
                              validator: (v) => v == null || v.trim().isEmpty ? 'Name cannot be empty' : null,
                            ),
                            const SizedBox(height: 14),

                            // Email
                            _buildInputField(
                              controller: emailCtrl,
                              label: 'Email Address',
                              hint: 'e.g. driver@saffar.com',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 14),

                            // Age & Gender Row
                            Row(
                              children: [
                                // Age
                                Expanded(
                                  flex: 1,
                                  child: _buildInputField(
                                    controller: ageCtrl,
                                    label: 'Age',
                                    hint: 'e.g. 30',
                                    icon: Icons.calendar_today_outlined,
                                    keyboardType: TextInputType.number,
                                    validator: (v) {
                                      if (v != null && v.trim().isNotEmpty) {
                                        final age = int.tryParse(v.trim());
                                        if (age == null || age < 18 || age > 90) {
                                          return '18 - 90';
                                        }
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 14),

                                // Gender Selector
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Gender',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF173B67),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: selectedGender,
                                            isExpanded: true,
                                            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                                            items: const [
                                              DropdownMenuItem(value: 'Male', child: Text('Male')),
                                              DropdownMenuItem(value: 'Female', child: Text('Female')),
                                              DropdownMenuItem(value: 'Other', child: Text('Other')),
                                            ],
                                            onChanged: (val) {
                                              if (val != null) {
                                                setModalState(() => selectedGender = val);
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Address
                            _buildInputField(
                              controller: addressCtrl,
                              label: 'Permanent Address',
                              hint: 'Enter your permanent residential address',
                              icon: Icons.home_outlined,
                              maxLines: 2,
                            ),
                            const SizedBox(height: 24),

                            // ─── Vehicle Info ───
                            const Text(
                              'VEHICLE DETAILS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF64748B),
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Vehicle Name
                            _buildInputField(
                              controller: vehicleNameCtrl,
                              label: 'Vehicle Name',
                              hint: 'e.g. Bajaj RE Auto / Honda City',
                              icon: Icons.directions_car_outlined,
                              validator: (v) => v == null || v.trim().isEmpty ? 'Vehicle name cannot be empty' : null,
                            ),
                            const SizedBox(height: 14),

                            // Vehicle Model
                            _buildInputField(
                              controller: vehicleModelCtrl,
                              label: 'Vehicle Model',
                              hint: 'e.g. 2024 CNG / Compact 4S',
                              icon: Icons.category_outlined,
                            ),
                            const SizedBox(height: 14),

                            // Vehicle Number
                            _buildInputField(
                              controller: vehicleNumberCtrl,
                              label: 'Vehicle / Plate Number',
                              hint: 'e.g. KA 03 EQ 8842',
                              icon: Icons.confirmation_number_outlined,
                              validator: (v) => v == null || v.trim().isEmpty ? 'Vehicle number cannot be empty' : null,
                            ),
                            const SizedBox(height: 26),

                            // Save Button
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: isSaving
                                    ? null
                                    : () async {
                                        if (!formKey.currentState!.validate()) return;
                                        setModalState(() => isSaving = true);
                                        try {
                                          final fields = <String, dynamic>{
                                            'name': nameCtrl.text.trim(),
                                            'email': emailCtrl.text.trim(),
                                            'age': ageCtrl.text.trim().isNotEmpty
                                                ? int.tryParse(ageCtrl.text.trim())
                                                : null,
                                            'gender': selectedGender,
                                            'address': addressCtrl.text.trim(),
                                            'vehicle_name': vehicleNameCtrl.text.trim(),
                                            'vehicle_model': vehicleModelCtrl.text.trim(),
                                            'vehicle_number': vehicleNumberCtrl.text.trim(),
                                          };

                                          await context.read<DriverCubit>().updateProfile(fields);

                                          if (context.mounted) {
                                            Navigator.pop(modalCtx);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Profile updated successfully!'),
                                                backgroundColor: Color(0xFF219653),
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          setModalState(() => isSaving = false);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(e.toString()),
                                                backgroundColor: Palette.error,
                                              ),
                                            );
                                          }
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Palette.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: isSaving
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                      )
                                    : const Text(
                                        'Save Changes',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF173B67),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A2E),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade400,
            ),
            prefixIcon: Icon(icon, size: 20, color: const Color(0xFF64748B)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Palette.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Driver Profile',
          style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          BlocBuilder<DriverCubit, DriverState>(
            builder: (context, state) {
              final driver = state.currentDriver;
              if (driver == null) return const SizedBox.shrink();
              return TextButton.icon(
                onPressed: () => _showEditProfileModal(context, driver),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text(
                  'Edit',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: BlocBuilder<DriverCubit, DriverState>(
          builder: (context, state) {
            final driver = state.currentDriver;
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: Nums.horizontalPadding,
                vertical: 18,
              ),
              child: Column(
                children: [
                  // Avatar with Photo Upload Button
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: Palette.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                            border: Border.all(color: Palette.primary.withValues(alpha: 0.3), width: 3),
                          ),
                          child: ClipOval(
                            child: driver?.imageUrl != null && driver!.imageUrl!.isNotEmpty
                                ? Image.network(
                                    driver.imageUrl!,
                                    fit: BoxFit.cover,
                                    width: 96,
                                    height: 96,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 52, color: Palette.primary),
                                  )
                                : const Icon(Icons.person, size: 52, color: Palette.primary),
                          ),
                        ),
                        if (_isUploadingPhoto)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.4),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () => _showPhotoOptionsDialog(context),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Palette.primary,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Name
                  Text(
                    driver?.name ?? 'Driver Name',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Phone with Verified Pill
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '+91 ${driver?.phone ?? ''}',
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.verified, size: 16, color: Color(0xFF219653)),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Active / Online Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: (driver?.active == true ? const Color(0xFF219653) : Colors.grey.shade600)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: (driver?.active == true ? const Color(0xFF219653) : Colors.grey.shade500)
                            .withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: driver?.active == true ? const Color(0xFF219653) : Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          driver?.active == true ? 'Online & Active' : 'Offline',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: driver?.active == true ? const Color(0xFF219653) : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ─── 1. Personal Details Card ───
                  _buildSectionCard(
                    title: 'Personal Information',
                    onEdit: driver != null ? () => _showEditProfileModal(context, driver) : null,
                    items: [
                      _infoRow(Icons.person_outline, 'Full Name', driver?.name ?? 'Not set'),
                      const Divider(),
                      _infoRow(Icons.phone_android_outlined, 'Phone', '+91 ${driver?.phone ?? 'Not set'}'),
                      const Divider(),
                      _infoRow(Icons.email_outlined, 'Email', driver?.email != null && driver!.email!.isNotEmpty ? driver.email! : 'Not set'),
                      const Divider(),
                      _infoRow(Icons.calendar_today_outlined, 'Age', driver?.age != null ? '${driver!.age} years' : 'Not set'),
                      const Divider(),
                      _infoRow(Icons.wc_outlined, 'Gender', driver?.gender ?? 'Not set'),
                      const Divider(),
                      _infoRow(Icons.home_outlined, 'Address', driver?.address != null && driver!.address!.isNotEmpty ? driver.address! : 'Not set'),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ─── 2. Vehicle Details Card ───
                  _buildSectionCard(
                    title: 'Active Vehicle & Fleet',
                    onEdit: () {
                      Navigator.pushNamed(context, DriverVehiclesScreen.routeName).then((_) {
                        context.read<DriverCubit>().refreshProfile();
                      });
                    },
                    items: [
                      _infoRow(Icons.directions_car_outlined, 'Active Vehicle', driver?.vehicleName ?? 'Not set'),
                      const Divider(),
                      _infoRow(Icons.category_outlined, 'Model', driver?.vehicleModel ?? 'Not set'),
                      const Divider(),
                      _infoRow(Icons.confirmation_number_outlined, 'Plate Number', driver?.vehicleNumber ?? 'Not set'),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(context, DriverVehiclesScreen.routeName).then((_) {
                              context.read<DriverCubit>().refreshProfile();
                            });
                          },
                          icon: const Icon(Icons.manage_accounts_outlined, size: 18),
                          label: const Text('Manage Vehicles & Documents', style: TextStyle(fontWeight: FontWeight.w700)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Palette.primary,
                            side: const BorderSide(color: Palette.primary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ─── 3. Account & Settings Card ───
                  _buildSectionCard(
                    title: 'Account & Verification',
                    items: [
                      _settingRow(
                        context,
                        Icons.verified_user_rounded,
                        'Verification Status',
                        driver?.verificationStatus ?? 'Approved',
                        isHighlight: true,
                      ),
                      const Divider(),
                      _settingRow(
                        context,
                        Icons.toggle_on_rounded,
                        'Driver Account Status',
                        driver?.active == true ? 'Active' : 'Standby',
                        isHighlight: driver?.active == true,
                      ),
                      const Divider(),
                      _settingRow(
                        context,
                        Icons.swap_horiz_rounded,
                        'Switch to Passenger App',
                        null,
                        onTap: () {
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            RoleSelectionScreen.routeName,
                            (route) => false,
                          );
                        },
                      ),
                      const Divider(),
                      _settingRow(context, Icons.help_outline, 'Help & Support', null),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Log Out Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _showLogoutDialog(context);
                      },
                      icon: const Icon(Icons.logout, color: Color(0xFFE5484D)),
                      label: const Text(
                        'Log Out',
                        style: TextStyle(
                          color: Color(0xFFE5484D),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE5484D)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(Nums.roundedCornerRadius),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> items,
    VoidCallback? onEdit,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              if (onEdit != null)
                GestureDetector(
                  onTap: onEdit,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(
                      'Edit',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Palette.primary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          ...items,
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 19, color: Colors.grey.shade600),
          ),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingRow(BuildContext context, IconData icon, String label, String? trailing, {bool isHighlight = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey.shade600),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const Spacer(),
            if (trailing != null)
              Text(
                trailing,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isHighlight ? const Color(0xFF219653) : Colors.grey.shade600,
                ),
              )
            else
              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out of your Driver account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await context.read<DriverCubit>().logout();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  RoleSelectionScreen.routeName,
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE5484D)),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }
}
