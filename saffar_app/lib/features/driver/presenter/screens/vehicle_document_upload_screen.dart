import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:saffar_app/core/constants/nums.dart';
import 'package:saffar_app/core/models/vehicle.dart';
import 'package:saffar_app/core/palette.dart';
import 'package:saffar_app/features/driver/presenter/cubits/driver_cubit.dart';
import 'package:saffar_app/features/driver/presenter/cubits/vehicle_cubit.dart';

class VehicleDocumentUploadScreen extends StatefulWidget {
  const VehicleDocumentUploadScreen({Key? key, required this.vehicle}) : super(key: key);

  static const String routeName = '/vehicle_document_upload';

  final Vehicle vehicle;

  @override
  State<VehicleDocumentUploadScreen> createState() => _VehicleDocumentUploadScreenState();
}

class _VehicleDocumentUploadScreenState extends State<VehicleDocumentUploadScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  late TextEditingController _dlNumberCtrl;
  late TextEditingController _dlExpiryCtrl;
  late TextEditingController _rcNumberCtrl;
  late TextEditingController _insurancePolicyCtrl;
  late TextEditingController _insuranceExpiryCtrl;

  String? _dlBase64;
  String? _rcBase64;
  String? _insuranceBase64;

  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    _dlNumberCtrl = TextEditingController(text: v.drivingLicenseNumber ?? '');
    _dlExpiryCtrl = TextEditingController(text: v.drivingLicenseExpiry ?? '');
    _rcNumberCtrl = TextEditingController(text: v.rcNumber ?? v.registrationNumber);
    _insurancePolicyCtrl = TextEditingController(text: v.insurancePolicyNumber ?? '');
    _insuranceExpiryCtrl = TextEditingController(text: v.insuranceExpiry ?? '');
  }

  @override
  void dispose() {
    _dlNumberCtrl.dispose();
    _dlExpiryCtrl.dispose();
    _rcNumberCtrl.dispose();
    _insurancePolicyCtrl.dispose();
    _insuranceExpiryCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(Function(String base64) onPicked) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Select Document Source',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E)),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Palette.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: Palette.primary),
                  ),
                  title: const Text('Capture with Camera', style: TextStyle(fontWeight: FontWeight.w700)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _executeImagePick(ImageSource.camera, onPicked);
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
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _executeImagePick(ImageSource.gallery, onPicked);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _executeImagePick(ImageSource source, Function(String base64) onPicked) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 80,
      );

      if (file == null) return;

      final bytes = await file.readAsBytes();
      final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      onPicked(base64String);
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not access image: $e'),
            backgroundColor: Palette.error,
          ),
        );
      }
    }
  }

  Future<void> _selectDate(TextEditingController controller) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 365)),
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 15)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Palette.primary,
              onPrimary: Colors.white,
              onSurface: Color(0xFF1A1A2E),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final formatted = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      setState(() => controller.text = formatted);
    }
  }

  Future<void> _onUpload() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final token = context.read<DriverCubit>().state.token;
    if (token == null) return;

    setState(() => _isUploading = true);

    final payload = <String, dynamic>{
      if (_dlNumberCtrl.text.trim().isNotEmpty) 'driving_license_number': _dlNumberCtrl.text.trim(),
      if (_dlExpiryCtrl.text.trim().isNotEmpty) 'driving_license_expiry': _dlExpiryCtrl.text.trim(),
      if (_dlBase64 != null) 'driving_license_doc': _dlBase64,
      if (_rcNumberCtrl.text.trim().isNotEmpty) 'rc_number': _rcNumberCtrl.text.trim(),
      if (_rcBase64 != null) 'rc_doc': _rcBase64,
      if (_insurancePolicyCtrl.text.trim().isNotEmpty) 'insurance_policy_number': _insurancePolicyCtrl.text.trim(),
      if (_insuranceExpiryCtrl.text.trim().isNotEmpty) 'insurance_expiry': _insuranceExpiryCtrl.text.trim(),
      if (_insuranceBase64 != null) 'insurance_doc': _insuranceBase64,
    };

    final success = await context.read<VehicleCubit>().uploadDocuments(
      token,
      widget.vehicle.id,
      payload,
    );

    setState(() => _isUploading = false);

    if (success && mounted) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.verified_rounded, color: Color(0xFF219653), size: 28),
              SizedBox(width: 10),
              Text('Documents Submitted', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            ],
          ),
          content: const Text(
            'Your vehicle documents have been successfully uploaded and submitted for safety team verification.\n\nYou will receive a notification once verified.',
            style: TextStyle(fontSize: 14, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: Palette.primary),
              child: const Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.vehicle;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Vehicle Documents',
          style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A2E)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: Nums.horizontalPadding,
            vertical: 16,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vehicle Info Strip
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Palette.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.directions_car_rounded, color: Palette.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              v.model,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF1A1A2E)),
                            ),
                            Text(
                              '${v.category} • ${v.registrationNumber}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      _statusPill(v.verificationStatus),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Rejection reason banner if rejected
                if (v.rejectionReason != null && v.rejectionReason!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5484D).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5484D).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Color(0xFFE5484D), size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Verification Action Required',
                                style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFE5484D), fontSize: 13),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                v.rejectionReason!,
                                style: const TextStyle(fontSize: 12, color: Color(0xFF78350F)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ─── 1. DRIVING LICENSE ───
                _buildDocCard(
                  sectionTitle: '1. Driving License (DL)',
                  docIcon: Icons.badge_outlined,
                  isUploadedAlready: v.drivingLicenseDoc != null,
                  hasNewFile: _dlBase64 != null,
                  onPickFile: () => _pickImage((b64) => _dlBase64 = b64),
                  fields: [
                    _buildTextField(
                      controller: _dlNumberCtrl,
                      label: 'Driving License Number',
                      hint: 'e.g. DL-1420110012345',
                      icon: Icons.credit_card_rounded,
                      textCapitalization: TextCapitalization.characters,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Driving license number is required';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildDateField(
                      controller: _dlExpiryCtrl,
                      label: 'DL Expiry Date',
                      hint: 'YYYY-MM-DD',
                      onTap: () => _selectDate(_dlExpiryCtrl),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // ─── 2. REGISTRATION CERTIFICATE (RC) ───
                _buildDocCard(
                  sectionTitle: '2. Registration Certificate (RC)',
                  docIcon: Icons.document_scanner_outlined,
                  isUploadedAlready: v.rcDoc != null,
                  hasNewFile: _rcBase64 != null,
                  onPickFile: () => _pickImage((b64) => _rcBase64 = b64),
                  fields: [
                    _buildTextField(
                      controller: _rcNumberCtrl,
                      label: 'RC Book / Plate Number',
                      hint: 'e.g. MH 04 AB 1234',
                      icon: Icons.confirmation_number_outlined,
                      textCapitalization: TextCapitalization.characters,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'RC number is required';
                        return null;
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // ─── 3. COMMERCIAL INSURANCE ───
                _buildDocCard(
                  sectionTitle: '3. Vehicle Commercial Insurance',
                  docIcon: Icons.security_outlined,
                  isUploadedAlready: v.insuranceDoc != null,
                  hasNewFile: _insuranceBase64 != null,
                  onPickFile: () => _pickImage((b64) => _insuranceBase64 = b64),
                  fields: [
                    _buildTextField(
                      controller: _insurancePolicyCtrl,
                      label: 'Policy / Covernote Number',
                      hint: 'e.g. POL-99887766-01',
                      icon: Icons.policy_outlined,
                      textCapitalization: TextCapitalization.characters,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Insurance policy number is required';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildDateField(
                      controller: _insuranceExpiryCtrl,
                      label: 'Policy Expiry Date',
                      hint: 'YYYY-MM-DD',
                      onTap: () => _selectDate(_insuranceExpiryCtrl),
                    ),
                  ],
                ),
                const SizedBox(height: 30),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isUploading ? null : _onUpload,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Palette.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isUploading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Text(
                            'Submit Documents for Verification',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDocCard({
    required String sectionTitle,
    required IconData docIcon,
    required bool isUploadedAlready,
    required bool hasNewFile,
    required VoidCallback onPickFile,
    required List<Widget> fields,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(docIcon, color: Palette.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  sectionTitle,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...fields,
          const SizedBox(height: 14),

          // Upload File CTA / Status
          InkWell(
            onTap: onPickFile,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: hasNewFile
                    ? const Color(0xFF219653).withValues(alpha: 0.08)
                    : isUploadedAlready
                        ? const Color(0xFFF1F5F9)
                        : Palette.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasNewFile
                      ? const Color(0xFF219653)
                      : isUploadedAlready
                          ? const Color(0xFFCBD5E1)
                          : Palette.primary.withValues(alpha: 0.3),
                  style: BorderStyle.solid,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    hasNewFile
                        ? Icons.check_circle_rounded
                        : isUploadedAlready
                            ? Icons.task_alt_rounded
                            : Icons.cloud_upload_outlined,
                    color: hasNewFile
                        ? const Color(0xFF219653)
                        : isUploadedAlready
                            ? const Color(0xFF475569)
                            : Palette.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasNewFile
                              ? 'New Photo Attached (Ready to submit)'
                              : isUploadedAlready
                                  ? 'Current Document on File (Tap to replace)'
                                  : 'Upload Document Photo',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: hasNewFile
                                ? const Color(0xFF219653)
                                : isUploadedAlready
                                    ? const Color(0xFF334155)
                                    : Palette.primary,
                          ),
                        ),
                        Text(
                          hasNewFile
                              ? 'Tap to change photo'
                              : 'Supports Camera photo or Gallery image (PNG, JPG)',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          textCapitalization: textCapitalization,
          validator: validator,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400, fontWeight: FontWeight.w500),
            prefixIcon: Icon(icon, size: 20, color: const Color(0xFF64748B)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Palette.primary, width: 1.5)),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          readOnly: true,
          onTap: onTap,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400, fontWeight: FontWeight.w500),
            prefixIcon: const Icon(Icons.calendar_today_outlined, size: 20, color: Color(0xFF64748B)),
            suffixIcon: const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Palette.primary, width: 1.5)),
          ),
        ),
      ],
    );
  }

  Widget _statusPill(String status) {
    Color bg;
    Color fg;
    switch (status.toLowerCase()) {
      case 'approved':
        bg = const Color(0xFF219653).withValues(alpha: 0.12);
        fg = const Color(0xFF219653);
        break;
      case 'rejected':
        bg = const Color(0xFFE5484D).withValues(alpha: 0.12);
        fg = const Color(0xFFE5484D);
        break;
      case 'pending':
      default:
        bg = const Color(0xFFF59E0B).withValues(alpha: 0.12);
        fg = const Color(0xFFB45309);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w800),
      ),
    );
  }
}

