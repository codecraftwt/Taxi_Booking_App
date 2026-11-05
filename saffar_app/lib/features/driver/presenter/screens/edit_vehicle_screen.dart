import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:saffar_app/core/constants/nums.dart';
import 'package:saffar_app/core/models/vehicle.dart';
import 'package:saffar_app/core/palette.dart';
import 'package:saffar_app/features/driver/presenter/cubits/driver_cubit.dart';
import 'package:saffar_app/features/driver/presenter/cubits/vehicle_cubit.dart';

class EditVehicleScreen extends StatefulWidget {
  const EditVehicleScreen({Key? key, required this.vehicle}) : super(key: key);

  static const String routeName = '/edit_vehicle';

  final Vehicle vehicle;

  @override
  State<EditVehicleScreen> createState() => _EditVehicleScreenState();
}

class _EditVehicleScreenState extends State<EditVehicleScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late TextEditingController _modelController;
  late TextEditingController _regController;
  late TextEditingController _colorController;

  late String _selectedCategory;
  late bool _isActive;
  bool _isSaving = false;

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Bike', 'icon': Icons.two_wheeler_rounded, 'desc': 'Fast 1-passenger 2-wheeler'},
    {'name': 'Auto', 'icon': Icons.electric_rickshaw_rounded, 'desc': 'Standard 3-wheeler Auto'},
    {'name': 'Mini Car', 'icon': Icons.directions_car_rounded, 'desc': 'Compact 4-seater hatchback'},
    {'name': 'Sedan', 'icon': Icons.directions_car_filled_rounded, 'desc': 'Comfortable 4-seater sedan'},
    {'name': 'SUV', 'icon': Icons.airport_shuttle_rounded, 'desc': 'Spacious 6-7 seater SUV'},
  ];

  @override
  void initState() {
    super.initState();
    _modelController = TextEditingController(text: widget.vehicle.model);
    _regController = TextEditingController(text: widget.vehicle.registrationNumber);
    _colorController = TextEditingController(text: widget.vehicle.color);
    _selectedCategory = widget.vehicle.category;
    _isActive = widget.vehicle.isActive;
  }

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

    setState(() => _isSaving = true);

    final success = await context.read<VehicleCubit>().updateVehicle(
      token,
      widget.vehicle.id,
      {
        'category': _selectedCategory,
        'model': _modelController.text.trim(),
        'registration_number': _regController.text.trim().toUpperCase(),
        'color': _colorController.text.trim(),
        'is_active': _isActive,
      },
    );

    setState(() => _isSaving = false);

    if (success && mounted) {
      // Sync driver cubit so driver profile updates if active vehicle changed
      await context.read<DriverCubit>().fetchProfile();
      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  Future<void> _onDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Vehicle', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
          'Are you sure you want to remove ${widget.vehicle.model} (${widget.vehicle.registrationNumber}) from your account?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Palette.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Vehicle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final token = context.read<DriverCubit>().state.token;
    if (token == null) return;

    final deleted = await context.read<VehicleCubit>().deleteVehicle(token, widget.vehicle.id);
    if (deleted && mounted) {
      // Refresh driver profile as well
      await context.read<DriverCubit>().fetchProfile();
      if (mounted) {
        // Pop edit screen and details screen back to vehicle list
        Navigator.pop(context); // pop Edit
        Navigator.pop(context); // pop Details
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Edit Vehicle',
          style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A2E)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Palette.error),
            tooltip: 'Delete Vehicle',
            onPressed: _isSaving ? null : _onDelete,
          ),
        ],
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
                  '1. VEHICLE CATEGORY',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),

                // Category Selection Cards
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = _selectedCategory.toLowerCase() == (cat['name'] as String).toLowerCase();
                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => setState(() => _selectedCategory = cat['name'] as String),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? Palette.primary.withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? Palette.primary : const Color(0xFFE2E8F0),
                            width: isSelected ? 1.8 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isSelected ? Palette.primary : Colors.grey.shade200,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                cat['icon'] as IconData,
                                color: isSelected ? Colors.white : Colors.grey.shade700,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cat['name'] as String,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: isSelected ? Palette.primary : const Color(0xFF1E293B),
                                    ),
                                  ),
                                  Text(
                                    cat['desc'] as String,
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle_rounded, color: Palette.primary, size: 22),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                const Text(
                  '2. VEHICLE SPECIFICATIONS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),

                // Vehicle Model Field
                _buildField(
                  controller: _modelController,
                  label: 'Vehicle Model & Make',
                  hint: 'e.g. Maruti Swift Dzire, Honda Activa',
                  icon: Icons.directions_car_outlined,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Please enter vehicle model';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Registration Number Field
                _buildField(
                  controller: _regController,
                  label: 'Registration Plate Number',
                  hint: 'e.g. MH 04 AB 1234',
                  icon: Icons.confirmation_number_outlined,
                  textCapitalization: TextCapitalization.characters,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Registration number is required';
                    if (val.trim().length < 5) return 'Invalid registration number';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Color Field
                _buildField(
                  controller: _colorController,
                  label: 'Vehicle Color',
                  hint: 'e.g. Pearl White, Silver, Black',
                  icon: Icons.palette_outlined,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Vehicle color is required';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Active Status Toggle
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Palette.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.flash_on_rounded, color: Palette.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Active Vehicle for Rides',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                            Text(
                              'Select this vehicle to receive instant ride bookings',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: _isActive,
                        activeColor: Palette.primary,
                        onChanged: (val) => setState(() => _isActive = val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _onSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Palette.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Text(
                            'Save Vehicle Changes',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextCapitalization textCapitalization = TextCapitalization.words,
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
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          textCapitalization: textCapitalization,
          validator: validator,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey.shade400),
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
}

