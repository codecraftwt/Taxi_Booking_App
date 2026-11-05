import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:saffar_app/core/constants/nums.dart';
import 'package:saffar_app/core/palette.dart';
import 'package:saffar_app/features/driver/presenter/cubits/driver_cubit.dart';
import 'package:saffar_app/features/driver/presenter/cubits/vehicle_cubit.dart';
import 'package:saffar_app/features/driver/presenter/screens/vehicle_document_upload_screen.dart';

class AddVehicleScreen extends StatefulWidget {
  const AddVehicleScreen({Key? key}) : super(key: key);

  static const String routeName = '/add_vehicle';

  @override
  State<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _regController = TextEditingController();
  final TextEditingController _colorController = TextEditingController();

  String _selectedCategory = 'Auto';
  bool _isActive = true;

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Bike', 'icon': Icons.two_wheeler_rounded, 'desc': 'Fast 1-passenger 2-wheeler'},
    {'name': 'Auto', 'icon': Icons.electric_rickshaw_rounded, 'desc': 'Standard 3-wheeler Auto'},
    {'name': 'Mini Car', 'icon': Icons.directions_car_rounded, 'desc': 'Compact 4-seater hatchback'},
    {'name': 'Sedan', 'icon': Icons.directions_car_filled_rounded, 'desc': 'Comfortable 4-seater sedan'},
    {'name': 'SUV', 'icon': Icons.airport_shuttle_rounded, 'desc': 'Spacious 6-7 seater SUV'},
  ];

  @override
  void dispose() {
    _modelController.dispose();
    _regController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final token = context.read<DriverCubit>().state.token;
    if (token == null) return;

    final vehicle = await context.read<VehicleCubit>().addVehicle(token, {
      'category': _selectedCategory,
      'model': _modelController.text.trim(),
      'registration_number': _regController.text.trim().toUpperCase(),
      'color': _colorController.text.trim(),
      'is_active': _isActive,
    });

    if (vehicle != null && mounted) {
      // Offer driver to upload documents right away
      Navigator.pushReplacementNamed(
        context,
        VehicleDocumentUploadScreen.routeName,
        arguments: vehicle,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Add New Vehicle',
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
                const Text(
                  '1. SELECT VEHICLE CATEGORY',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 12),

                // Category Selection Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((cat) {
                      final isSelected = _selectedCategory == cat['name'];
                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: InkWell(
                          onTap: () => setState(() => _selectedCategory = cat['name'] as String),
                          borderRadius: BorderRadius.circular(16),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? Palette.primary : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? Palette.primary : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  cat['icon'] as IconData,
                                  size: 20,
                                  color: isSelected ? Colors.white : const Color(0xFF475569),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  cat['name'] as String,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    color: isSelected ? Colors.white : const Color(0xFF1E293B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),

                const Text(
                  '2. VEHICLE INFORMATION',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 14),

                // Vehicle Model
                TextFormField(
                  controller: _modelController,
                  decoration: const InputDecoration(
                    labelText: 'Vehicle Model & Make',
                    hintText: 'e.g. Bajaj RE Auto, Swift Dzire, Splendor',
                    prefixIcon: Icon(Icons.directions_car_outlined),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter vehicle model and make';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Registration Number Plate
                TextFormField(
                  controller: _regController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Vehicle Registration Number',
                    hintText: 'e.g. MH01AB1234, KA03EQ8842',
                    prefixIcon: Icon(Icons.confirmation_number_outlined),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter registration plate number';
                    }
                    if (val.trim().length < 6) {
                      return 'Please enter a valid registration number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Vehicle Color
                TextFormField(
                  controller: _colorController,
                  decoration: const InputDecoration(
                    labelText: 'Vehicle Color',
                    hintText: 'e.g. Yellow & Black, Pearl White, Silver',
                    prefixIcon: Icon(Icons.palette_outlined),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter vehicle color';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Set as Active Switch
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, color: Palette.primary),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Set as Active Vehicle',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                            Text(
                              'Use this vehicle for accepting new ride requests',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isActive,
                        activeColor: Palette.primary,
                        onChanged: (val) => setState(() => _isActive = val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Submit Button
                BlocBuilder<VehicleCubit, VehicleState>(
                  builder: (context, state) {
                    return SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: state.isSaving ? null : _onSave,
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(Nums.roundedCornerRadius),
                          ),
                        ),
                        child: state.isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text(
                                'Save & Upload Documents',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

