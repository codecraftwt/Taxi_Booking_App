import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:saffar_app/core/constants/nums.dart';
import 'package:saffar_app/core/models/vehicle.dart';
import 'package:saffar_app/core/palette.dart';
import 'package:saffar_app/features/driver/presenter/cubits/driver_cubit.dart';
import 'package:saffar_app/features/driver/presenter/cubits/vehicle_cubit.dart';
import 'package:saffar_app/features/driver/presenter/screens/add_vehicle_screen.dart';
import 'package:saffar_app/features/driver/presenter/screens/vehicle_details_screen.dart';

class DriverVehiclesScreen extends StatefulWidget {
  const DriverVehiclesScreen({Key? key}) : super(key: key);

  static const String routeName = '/driver_vehicles';

  @override
  State<DriverVehiclesScreen> createState() => _DriverVehiclesScreenState();
}

class _DriverVehiclesScreenState extends State<DriverVehiclesScreen> {
  @override
  void initState() {
    super.initState();
    _fetchVehicles();
  }

  void _fetchVehicles() {
    final token = context.read<DriverCubit>().state.token;
    if (token != null) {
      context.read<VehicleCubit>().fetchVehicles(token);
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'My Vehicles',
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
            icon: const Icon(Icons.add_circle_outline_rounded, color: Palette.primary, size: 26),
            onPressed: () {
              Navigator.pushNamed(context, AddVehicleScreen.routeName).then((_) => _fetchVehicles());
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, AddVehicleScreen.routeName).then((_) => _fetchVehicles());
        },
        backgroundColor: Palette.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add Vehicle',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _fetchVehicles(),
          color: Palette.primary,
          child: BlocConsumer<VehicleCubit, VehicleState>(
            listener: (context, state) {
              if (state.error != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(state.error!), backgroundColor: Palette.error),
                );
                context.read<VehicleCubit>().clearMessages();
              }
              if (state.successMessage != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(state.successMessage!), backgroundColor: const Color(0xFF219653)),
                );
                context.read<VehicleCubit>().clearMessages();
              }
            },
            builder: (context, state) {
              if (state.isLoading && state.vehicles.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (state.vehicles.isEmpty) {
                return Center(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Palette.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.directions_car_outlined, size: 44, color: Palette.primary),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'No Vehicles Registered',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E)),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add your vehicle details and documents to start accepting rides on Saffar.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.4),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pushNamed(context, AddVehicleScreen.routeName).then((_) => _fetchVehicles());
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Add Vehicle Now'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: Nums.horizontalPadding,
                  vertical: 16,
                ),
                itemCount: state.vehicles.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final vehicle = state.vehicles[index];
                  return _buildVehicleCard(context, vehicle);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleCard(BuildContext context, Vehicle vehicle) {
    final statusColor = _getStatusColor(vehicle.verificationStatus);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: vehicle.isActive
            ? Border.all(color: Palette.primary, width: 2)
            : Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            context.read<VehicleCubit>().selectVehicle(vehicle);
            Navigator.pushNamed(
              context,
              VehicleDetailsScreen.routeName,
              arguments: vehicle,
            ).then((_) => _fetchVehicles());
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Active Tag & Verification Badge
                Row(
                  children: [
                    if (vehicle.isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Palette.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle_rounded, size: 13, color: Palette.primary),
                            SizedBox(width: 4),
                            Text(
                              'ACTIVE VEHICLE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Palette.primary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'STANDBY',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    const Spacer(),
                    // Verification Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            vehicle.isApproved
                                ? Icons.verified_rounded
                                : vehicle.isRejected
                                    ? Icons.cancel_rounded
                                    : Icons.hourglass_top_rounded,
                            size: 13,
                            color: statusColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            vehicle.verificationStatus.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Vehicle Info Row with Category Icon
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Palette.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        _getCategoryIcon(vehicle.category),
                        color: Palette.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vehicle.model,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  vehicle.category,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                vehicle.color,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),

                // Registration Number Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Plate Number:',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFF59E0B)),
                      ),
                      child: Text(
                        vehicle.registrationNumber,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: Color(0xFF78350F),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

