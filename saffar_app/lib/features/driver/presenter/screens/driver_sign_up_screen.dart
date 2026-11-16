import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:saffar_app/core/constants/nums.dart';
import 'package:saffar_app/core/palette.dart';
import 'package:saffar_app/core/service_locator.dart';
import 'package:saffar_app/features/driver/data/repositories/driver_repo.dart';
import 'package:saffar_app/features/driver/presenter/cubits/driver_cubit.dart';
import 'package:saffar_app/features/driver/presenter/screens/driver_shell_screen.dart';
import 'package:saffar_app/features/driver/presenter/screens/driver_sign_in_screen.dart';
import 'package:saffar_app/features/authentication/presenter/screens/role_selection_screen.dart';

class DriverSignUpScreen extends StatefulWidget {
  const DriverSignUpScreen({Key? key}) : super(key: key);

  static const String routeName = '/driver_sign_up';

  @override
  State<DriverSignUpScreen> createState() => _DriverSignUpScreenState();
}

class _DriverSignUpScreenState extends State<DriverSignUpScreen> {
  final GlobalKey<FormState> _step1FormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _step2FormKey = GlobalKey<FormState>();

  // Current Step: 0 = Personal & Vehicle, 1 = Compliance Documents
  int _currentStep = 0;

  // Controllers - Step 1
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _vehicleModelController = TextEditingController();
  final TextEditingController _vehicleNumberController = TextEditingController();

  // Selected Category
  String _selectedCategory = 'Auto';

  // Live Fare Configs from Super Admin
  List<Map<String, dynamic>> _fareConfigs = [];
  bool _isLoadingFares = true;

  // Controllers - Step 2 (Documents)
  final TextEditingController _dlNumberController = TextEditingController();
  final TextEditingController _dlExpiryController = TextEditingController();
  final TextEditingController _rcNumberController = TextEditingController();
  final TextEditingController _insuranceNumberController = TextEditingController();
  final TextEditingController _insuranceExpiryController = TextEditingController();
  final TextEditingController _aadhaarNumberController = TextEditingController();

  // Document Base64 Files
  String? _dlBase64;
  String? _rcBase64;
  String? _insuranceBase64;
  String? _aadhaarBase64;

  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchFares();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _vehicleModelController.dispose();
    _vehicleNumberController.dispose();
    _dlNumberController.dispose();
    _dlExpiryController.dispose();
    _rcNumberController.dispose();
    _insuranceNumberController.dispose();
    _insuranceExpiryController.dispose();
    _aadhaarNumberController.dispose();
    super.dispose();
  }

  Future<void> _fetchFares() async {
    setState(() => _isLoadingFares = true);
    try {
      final fares = await sl<DriverRepo>().getVehicleFares();
      if (mounted) {
        setState(() {
          _fareConfigs = fares;
          _isLoadingFares = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingFares = false);
      }
    }
  }

  Map<String, dynamic> _getSelectedFare() {
    final match = _fareConfigs.firstWhere(
      (f) => f['category']?.toString().toLowerCase() == _selectedCategory.toLowerCase(),
      orElse: () => {
        'category': _selectedCategory,
        'base_fare': _selectedCategory == 'Bike' ? 20 : (_selectedCategory == 'Auto' ? 30 : (_selectedCategory == 'Car' ? 50 : 70)),
        'per_km': _selectedCategory == 'Bike' ? 8 : (_selectedCategory == 'Auto' ? 12 : (_selectedCategory == 'Car' ? 15 : 18)),
        'per_minute': _selectedCategory == 'Bike' ? 1 : 1.5,
        'minimum_fare': _selectedCategory == 'Bike' ? 30 : (_selectedCategory == 'Auto' ? 40 : (_selectedCategory == 'Car' ? 70 : 90)),
        'commission_percentage': 15,
      },
    );
    return match;
  }

  Future<void> _pickDocumentImage(Function(String base64) onPicked) async {
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
                    final photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 75);
                    if (photo != null) {
                      final bytes = await File(photo.path).readAsBytes();
                      final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                      onPicked(base64Str);
                    }
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
                  title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w700)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final photo = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
                    if (photo != null) {
                      final bytes = await File(photo.path).readAsBytes();
                      final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                      onPicked(base64Str);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onNextToStep2() {
    FocusScope.of(context).unfocus();
    if (_step1FormKey.currentState?.validate() ?? false) {
      if (_passwordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Passwords do not match'),
            backgroundColor: Palette.error,
          ),
        );
        return;
      }
      // Auto populate RC Number with Vehicle Registration Number
      if (_rcNumberController.text.trim().isEmpty) {
        _rcNumberController.text = _vehicleNumberController.text.trim().toUpperCase();
      }
      setState(() => _currentStep = 1);
    }
  }

  void _onFinalSubmit() async {
    FocusScope.of(context).unfocus();

    if (_step2FormKey.currentState?.validate() ?? false) {
      // Validate DL & RC Numbers
      if (_dlNumberController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter Driving License Number'),
            backgroundColor: Palette.error,
          ),
        );
        return;
      }

      await context.read<DriverCubit>().signUp(
            name: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
            password: _passwordController.text.trim(),
            vehicleName: _selectedCategory,
            vehicleModel: _vehicleModelController.text.trim().isNotEmpty
                ? _vehicleModelController.text.trim()
                : _selectedCategory,
            vehicleNumber: _vehicleNumberController.text.trim().toUpperCase(),
            vehicleCategory: _selectedCategory,
            email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
            dlNumber: _dlNumberController.text.trim().toUpperCase(),
            dlExpiry: _dlExpiryController.text.trim().isNotEmpty ? _dlExpiryController.text.trim() : null,
            dlDoc: _dlBase64,
            rcNumber: _rcNumberController.text.trim().toUpperCase(),
            rcDoc: _rcBase64,
            insuranceNumber: _insuranceNumberController.text.trim().toUpperCase(),
            insuranceExpiry: _insuranceExpiryController.text.trim().isNotEmpty ? _insuranceExpiryController.text.trim() : null,
            insuranceDoc: _insuranceBase64,
            aadhaarNumber: _aadhaarNumberController.text.trim().isNotEmpty ? _aadhaarNumberController.text.trim() : null,
            aadhaarDoc: _aadhaarBase64,
          );
    }
  }

  void _showPendingApprovalDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.hourglass_top_rounded, color: Palette.primary, size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Registration Submitted!',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'STATUS: PENDING SUPER ADMIN APPROVAL',
                style: TextStyle(
                  color: Color(0xFFB45309),
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your driver registration and compliance documents have been safely received.\n\nThe Saffar Super Admin team will review your submitted credentials. You will be able to go online and accept rides immediately after your account is approved.',
              style: TextStyle(fontSize: 13, height: 1.45, color: Color(0xFF475569)),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushReplacementNamed(context, DriverShellScreen.routeName);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Palette.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              'Proceed to Dashboard',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<DriverCubit, DriverState>(
      listener: (context, state) {
        if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.error!),
              backgroundColor: Palette.error,
            ),
          );
        } else if (state.isLoggedIn) {
          _showPendingApprovalDialog();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
            onPressed: () {
              if (_currentStep == 1) {
                setState(() => _currentStep = 0);
              } else {
                Navigator.pushReplacementNamed(context, RoleSelectionScreen.routeName);
              }
            },
          ),
          title: Text(
            _currentStep == 0 ? 'Driver Registration' : 'Compliance Documents',
            style: const TextStyle(color: Palette.neutral, fontWeight: FontWeight.w800, fontSize: 18),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Column(
            children: [
              _buildStepIndicator(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: Nums.horizontalPadding, vertical: 12),
                  child: _currentStep == 0 ? _buildStep1Form() : _buildStep2Form(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          _buildStepPill(
            stepIndex: 0,
            title: '1. Vehicle & Pricing',
            isActive: _currentStep == 0,
            isCompleted: _currentStep > 0,
          ),
          Expanded(
            child: Container(
              height: 2,
              color: _currentStep > 0 ? Palette.primary : const Color(0xFFCBD5E1),
              margin: const EdgeInsets.symmetric(horizontal: 10),
            ),
          ),
          _buildStepPill(
            stepIndex: 1,
            title: '2. Documents',
            isActive: _currentStep == 1,
            isCompleted: false,
          ),
        ],
      ),
    );
  }

  Widget _buildStepPill({
    required int stepIndex,
    required String title,
    required bool isActive,
    required bool isCompleted,
  }) {
    Color bg = const Color(0xFFF1F5F9);
    Color fg = const Color(0xFF64748B);
    if (isActive) {
      bg = Palette.primary.withValues(alpha: 0.15);
      fg = Palette.primary;
    } else if (isCompleted) {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF16A34A);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCompleted ? Icons.check_circle_rounded : (stepIndex == 0 ? Icons.directions_car_rounded : Icons.assignment_rounded),
            size: 16,
            color: fg,
          ),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 1: Personal Details, Vehicle Model & Super Admin Fare Card
  // ---------------------------------------------------------------------------
  Widget _buildStep1Form() {
    final fare = _getSelectedFare();

    return Form(
      key: _step1FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Create Driver Account',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Palette.neutral),
          ),
          const SizedBox(height: 4),
          const Text(
            'Select your vehicle type to view the official Super Admin fare structure.',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 18),

          // Full Name
          TextFormField(
            controller: _nameController,
            decoration: _inputDecoration('Full Name', Icons.person_outline_rounded),
            validator: (v) => (v == null || v.trim().length < 3) ? 'Please enter your full name' : null,
          ),
          const SizedBox(height: 14),

          // Phone
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: _inputDecoration('Phone Number', Icons.phone_outlined, prefixText: '+91 '),
            validator: (v) => (v == null || v.trim().replaceAll(RegExp(r'\D'), '').length < 10)
                ? 'Enter valid 10-digit mobile number'
                : null,
          ),
          const SizedBox(height: 14),

          // Email
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: _inputDecoration('Email (Optional)', Icons.email_outlined),
          ),
          const SizedBox(height: 14),

          // Password
          TextFormField(
            controller: _passwordController,
            obscureText: !_passwordVisible,
            decoration: _inputDecoration('Password', Icons.lock_outline_rounded).copyWith(
              suffixIcon: IconButton(
                icon: Icon(_passwordVisible ? Icons.visibility : Icons.visibility_off, size: 20),
                onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
              ),
            ),
            validator: (v) => (v == null || v.length < 6) ? 'Password must be at least 6 characters' : null,
          ),
          const SizedBox(height: 14),

          // Confirm Password
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: !_confirmPasswordVisible,
            decoration: _inputDecoration('Confirm Password', Icons.lock_outline_rounded).copyWith(
              suffixIcon: IconButton(
                icon: Icon(_confirmPasswordVisible ? Icons.visibility : Icons.visibility_off, size: 20),
                onPressed: () => setState(() => _confirmPasswordVisible = !_confirmPasswordVisible),
              ),
            ),
            validator: (v) => (v == null || v.isEmpty) ? 'Confirm your password' : null,
          ),
          const SizedBox(height: 22),

          // Vehicle Category Selector
          const Text(
            'Select Vehicle Category',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Palette.neutral),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildCategorySelectChip('Auto', Icons.electric_rickshaw_rounded),
              const SizedBox(width: 8),
              _buildCategorySelectChip('Bike', Icons.two_wheeler_rounded),
              const SizedBox(width: 8),
              _buildCategorySelectChip('Car', Icons.directions_car_rounded),
              const SizedBox(width: 8),
              _buildCategorySelectChip('Prime Sedan', Icons.local_taxi_rounded),
            ],
          ),
          const SizedBox(height: 16),

          // Super Admin Official Fare Card
          _buildSuperAdminFareCard(fare),
          const SizedBox(height: 20),

          // Vehicle Model
          TextFormField(
            controller: _vehicleModelController,
            decoration: _inputDecoration('Vehicle Model / Name', Icons.drive_file_rename_outline_rounded,
                hint: 'e.g. Bajaj Compact RE, Maruti Dzire, Hero Splendor'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter vehicle model' : null,
          ),
          const SizedBox(height: 14),

          // Vehicle Registration Number
          TextFormField(
            controller: _vehicleNumberController,
            textCapitalization: TextCapitalization.characters,
            decoration: _inputDecoration('Vehicle Number Plate', Icons.confirmation_number_outlined,
                hint: 'e.g. MH 12 CC 1234'),
            validator: (v) => (v == null || v.trim().length < 5) ? 'Enter valid vehicle number' : null,
          ),
          const SizedBox(height: 24),

          // Next Button
          ElevatedButton(
            onPressed: _onNextToStep2,
            style: ElevatedButton.styleFrom(
              backgroundColor: Palette.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 2,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Next: Upload Compliance Documents',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Already have a driver account? '),
              GestureDetector(
                onTap: () => Navigator.pushReplacementNamed(context, DriverSignInScreen.routeName),
                child: const Text(
                  'Sign In',
                  style: TextStyle(color: Palette.primary, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildCategorySelectChip(String category, IconData icon) {
    final isSelected = _selectedCategory == category;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedCategory = category),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Palette.primary : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? Palette.primary : const Color(0xFFCBD5E1),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Palette.primary.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: isSelected ? Colors.white : Palette.neutral, size: 22),
              const SizedBox(height: 4),
              Text(
                category,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : Palette.neutral,
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

  Widget _buildSuperAdminFareCard(Map<String, dynamic> fare) {
    final baseFare = fare['base_fare'] ?? 30;
    final perKm = fare['per_km'] ?? 12;
    final perMin = fare['per_minute'] ?? 1.5;
    final minFare = fare['minimum_fare'] ?? 40;
    final comm = fare['commission_percentage'] ?? 15;
    final driverShare = 100 - (comm is num ? comm.toInt() : 15);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Palette.primary.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.verified_rounded, color: Palette.primary, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$_selectedCategory Fare & Earnings',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Driver Keeps $driverShare%',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF4ADE80),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 12),

          // Grid of 4 key rates
          Row(
            children: [
              _buildFareItem('BASE FARE', '₹$baseFare', Icons.flag_rounded),
              _buildFareItem('PER KM', '₹$perKm/km', Icons.straighten_rounded),
              _buildFareItem('PER MIN', '₹$perMin/m', Icons.timer_outlined),
              _buildFareItem('MIN FARE', '₹$minFare', Icons.shield_outlined),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Color(0xFF94A3B8), size: 13),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Official fare rates approved by Saffar Super Admin for all $_selectedCategory rides.',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFareItem(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Color(0xFF94A3B8),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 2: Compliance Document Submission
  // ---------------------------------------------------------------------------
  Widget _buildStep2Form() {
    return BlocBuilder<DriverCubit, DriverState>(
      builder: (context, driverState) {
        final isLoading = driverState.isLoading;

        return Form(
          key: _step2FormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Upload Compliance Documents',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Palette.neutral),
              ),
              const SizedBox(height: 4),
              const Text(
                'Government regulations require verification of driver and vehicle documents before account approval.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 18),

              // 1. Driving License
              _buildDocUploadCard(
                title: '1. Driving License (DL)',
                docTypeLabel: 'Driving License',
                icon: Icons.badge_outlined,
                numberController: _dlNumberController,
                numberLabel: 'DL Number (Required)',
                expiryController: _dlExpiryController,
                hasAttachment: _dlBase64 != null,
                onAttach: () => _pickDocumentImage((b64) => setState(() => _dlBase64 = b64)),
                onRemove: () => setState(() => _dlBase64 = null),
                isRequired: true,
              ),
              const SizedBox(height: 16),

              // 2. Registration Certificate (RC)
              _buildDocUploadCard(
                title: '2. Vehicle RC (Registration Certificate)',
                docTypeLabel: 'Registration Certificate',
                icon: Icons.drive_eta_outlined,
                numberController: _rcNumberController,
                numberLabel: 'RC Number (e.g. MH 12 CC 1234)',
                hasAttachment: _rcBase64 != null,
                onAttach: () => _pickDocumentImage((b64) => setState(() => _rcBase64 = b64)),
                onRemove: () => setState(() => _rcBase64 = null),
                isRequired: true,
              ),
              const SizedBox(height: 16),

              // 3. Vehicle Insurance
              _buildDocUploadCard(
                title: '3. Vehicle Insurance Policy',
                docTypeLabel: 'Insurance Policy',
                icon: Icons.security_rounded,
                numberController: _insuranceNumberController,
                numberLabel: 'Insurance Policy Number',
                expiryController: _insuranceExpiryController,
                hasAttachment: _insuranceBase64 != null,
                onAttach: () => _pickDocumentImage((b64) => setState(() => _insuranceBase64 = b64)),
                onRemove: () => setState(() => _insuranceBase64 = null),
                isRequired: false,
              ),
              const SizedBox(height: 16),

              // 4. Aadhaar / National ID (Optional)
              _buildDocUploadCard(
                title: '4. Aadhaar / National ID (Optional)',
                docTypeLabel: 'Identity Card',
                icon: Icons.credit_card_rounded,
                numberController: _aadhaarNumberController,
                numberLabel: 'Aadhaar / National ID Number',
                hasAttachment: _aadhaarBase64 != null,
                onAttach: () => _pickDocumentImage((b64) => setState(() => _aadhaarBase64 = b64)),
                onRemove: () => setState(() => _aadhaarBase64 = null),
                isRequired: false,
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      onPressed: isLoading ? null : () => setState(() => _currentStep = 0),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Back', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _onFinalSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Palette.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 2,
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            )
                          : const Text(
                              'Submit for Super Admin Approval',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDocUploadCard({
    required String title,
    required String docTypeLabel,
    required IconData icon,
    required TextEditingController numberController,
    required String numberLabel,
    TextEditingController? expiryController,
    required bool hasAttachment,
    required VoidCallback onAttach,
    required VoidCallback onRemove,
    bool isRequired = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: hasAttachment ? const Color(0xFF10B981) : const Color(0xFFE2E8F0), width: hasAttachment ? 1.5 : 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Palette.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Palette.neutral),
                ),
              ),
              if (hasAttachment)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 12),
                      SizedBox(width: 4),
                      Text('Attached', style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold, fontSize: 10)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Document Number Field
          TextFormField(
            controller: numberController,
            textCapitalization: TextCapitalization.characters,
            decoration: _inputDecoration(numberLabel, Icons.tag_rounded),
            validator: isRequired
                ? (v) => (v == null || v.trim().isEmpty) ? 'This field is required' : null
                : null,
          ),

          // Optional Expiry Date Field
          if (expiryController != null) ...[
            const SizedBox(height: 10),
            TextFormField(
              controller: expiryController,
              decoration: _inputDecoration('Expiry Date (YYYY-MM-DD)', Icons.calendar_today_outlined),
            ),
          ],
          const SizedBox(height: 12),

          // Attachment Action Row
          if (!hasAttachment)
            OutlinedButton.icon(
              onPressed: onAttach,
              icon: const Icon(Icons.upload_file_rounded, size: 18),
              label: Text('Upload $docTypeLabel Photo / Scan'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Palette.primary,
                side: const BorderSide(color: Palette.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: onAttach,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Change Document Photo'),
                  ),
                ),
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline_rounded, color: Palette.error, size: 20),
                  tooltip: 'Remove',
                ),
              ],
            ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, {String? hint, String? prefixText}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixText: prefixText,
      prefixIcon: Icon(icon, size: 20, color: const Color(0xFF64748B)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
        borderSide: const BorderSide(color: Palette.primary, width: 2),
      ),
    );
  }
}
