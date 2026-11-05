import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:saffar_app/core/constants/nums.dart';
import 'package:saffar_app/core/models/vehicle.dart';
import 'package:saffar_app/core/palette.dart';
import 'package:saffar_app/features/driver/presenter/cubits/driver_cubit.dart';
import 'package:saffar_app/features/driver/presenter/cubits/vehicle_cubit.dart';
import 'package:saffar_app/features/driver/presenter/screens/edit_vehicle_screen.dart';
import 'package:saffar_app/features/driver/presenter/screens/vehicle_document_upload_screen.dart';

class VehicleDetailsScreen extends StatefulWidget {
  const VehicleDetailsScreen({Key? key, required this.vehicle}) : super(key: key);

  static const String routeName = '/vehicle_details';

  final Vehicle vehicle;

  @override
  State<VehicleDetailsScreen> createState() => _VehicleDetailsScreenState();
}

class _VehicleDetailsScreenState extends State<VehicleDetailsScreen> {
  late Vehicle _vehicle;

  @override
  void initState() {
    super.initState();
    _vehicle = widget.vehicle;
  }

  void _refresh() {
    final token = context.read<DriverCubit>().state.token;
    if (token != null) {
      context.read<VehicleCubit>().fetchVehicleDetails(token, _vehicle.id);
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'bike':
        return Icons.two_wheeler_rounded;
      case 'auto':
        return Icons.electric_rickshaw_rounded;
      case 'sedan':
        return Icons.directions_car_filled_rounded;
      case 'suv':
        return Icons.airport_shuttle_rounded;
      case 'mini car':
      default:
        return Icons.directions_car_rounded;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return const Color(0xFF219653);
      case 'rejected':
        return const Color(0xFFE5484D);
      case 'pending':
      default:
        return const Color(0xFFF59E0B);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<VehicleCubit, VehicleState>(
      listener: (context, state) {
        if (state.selectedVehicle != null && state.selectedVehicle!.id == _vehicle.id) {
          setState(() => _vehicle = state.selectedVehicle!);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: Text(
            _vehicle.model,
            style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E)),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A2E)),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  EditVehicleScreen.routeName,
                  arguments: _vehicle,
                ).then((_) => _refresh());
              },
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: Nums.horizontalPadding,
              vertical: 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Vehicle Hero Card
                _buildHeroCard(),
                const SizedBox(height: 16),

                // 2. Active Toggle / Status Banner
                _buildActiveActionBanner(),
                const SizedBox(height: 20),

                // 3. Document Verification Status Banner
                _buildVerificationBanner(),
                const SizedBox(height: 20),

                // 4. Vehicle Specifications Card
                _buildSpecsCard(),
                const SizedBox(height: 20),

                // 5. Document Details Cards
                _buildDocumentsSection(),
                const SizedBox(height: 24),

                // 6. Action Button: Upload / Update Documents
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        VehicleDocumentUploadScreen.routeName,
                        arguments: _vehicle,
                      ).then((_) => _refresh());
                    },
                    icon: const Icon(Icons.upload_file_rounded),
                    label: const Text(
                      'Upload / Update Documents',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Palette.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(_getCategoryIcon(_vehicle.category), size: 36, color: Palette.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _vehicle.model,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_vehicle.category} • ${_vehicle.color}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Registration Plate:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                ),
                child: Text(
                  _vehicle.registrationNumber,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: Color(0xFF78350F),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveActionBanner() {
    if (_vehicle.isActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF219653).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF219653).withValues(alpha: 0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF219653)),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Currently Active Vehicle for Ride Requests',
                style: TextStyle(
                  color: Color(0xFF219653),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Colors.grey),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Standby Vehicle (Not currently receiving rides)',
              style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final token = context.read<DriverCubit>().state.token;
              if (token != null) {
                await context.read<VehicleCubit>().activateVehicle(token, _vehicle.id);
                _refresh();
              }
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            child: const Text('Set as Active', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationBanner() {
    final statusColor = _getStatusColor(_vehicle.verificationStatus);
    final isApproved = _vehicle.isApproved;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            isApproved ? Icons.verified_rounded : Icons.pending_actions_rounded,
            color: statusColor,
            size: 28,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verification Status: ${_vehicle.verificationStatus.toUpperCase()}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isApproved
                      ? 'All documents verified. Vehicle is eligible for rides.'
                      : 'Documents under review by Saffar safety team.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vehicle Details',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E)),
          ),
          const SizedBox(height: 12),
          _detailRow(Icons.category_outlined, 'Category', _vehicle.category),
          const Divider(),
          _detailRow(Icons.directions_car_outlined, 'Model Name', _vehicle.model),
          const Divider(),
          _detailRow(Icons.palette_outlined, 'Color', _vehicle.color),
          const Divider(),
          _detailRow(Icons.confirmation_number_outlined, 'Registration Plate', _vehicle.registrationNumber),
        ],
      ),
    );
  }

  Widget _buildDocumentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vehicle Documents',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E)),
        ),
        const SizedBox(height: 12),
        _docCard(
          title: 'Driving License',
          number: _vehicle.drivingLicenseNumber ?? 'Not Uploaded',
          expiry: _vehicle.drivingLicenseExpiry,
          isUploaded: _vehicle.drivingLicenseDoc != null,
          icon: Icons.badge_outlined,
        ),
        const SizedBox(height: 10),
        _docCard(
          title: 'Registration Certificate (RC)',
          number: _vehicle.rcNumber ?? 'Not Uploaded',
          isUploaded: _vehicle.rcDoc != null,
          icon: Icons.document_scanner_outlined,
        ),
        const SizedBox(height: 10),
        _docCard(
          title: 'Commercial Insurance Policy',
          number: _vehicle.insurancePolicyNumber ?? 'Not Uploaded',
          expiry: _vehicle.insuranceExpiry,
          isUploaded: _vehicle.insuranceDoc != null,
          icon: Icons.security_outlined,
        ),
      ],
    );
  }

  Widget _docCard({
    required String title,
    required String number,
    String? expiry,
    required bool isUploaded,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isUploaded ? const Color(0xFF219653).withValues(alpha: 0.1) : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: isUploaded ? const Color(0xFF219653) : Colors.grey.shade500, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  number,
                  style: TextStyle(
                    fontSize: 13,
                    color: isUploaded ? const Color(0xFF1E293B) : Colors.grey.shade500,
                    fontWeight: isUploaded ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                if (expiry != null && expiry.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Valid till: $expiry',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isUploaded ? const Color(0xFF219653).withValues(alpha: 0.1) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isUploaded ? 'UPLOADED' : 'MISSING',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: isUploaded ? const Color(0xFF219653) : Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
        ],
      ),
    );
  }
}

