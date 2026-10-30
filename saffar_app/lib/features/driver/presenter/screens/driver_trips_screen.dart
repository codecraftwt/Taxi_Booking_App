import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:saffar_app/core/constants/nums.dart';
import 'package:saffar_app/core/palette.dart';
import 'package:saffar_app/features/driver/presenter/cubits/driver_cubit.dart';
import 'package:saffar_app/features/driver/presenter/cubits/driver_rides_cubit.dart';

class DriverTripsScreen extends StatefulWidget {
  const DriverTripsScreen({Key? key}) : super(key: key);

  static const String routeName = '/driver_trips';

  @override
  State<DriverTripsScreen> createState() => _DriverTripsScreenState();
}

class _DriverTripsScreenState extends State<DriverTripsScreen> {
  String? _selectedFilter;

  @override
  void initState() {
    super.initState();
    _fetchRides();
  }

  void _fetchRides() {
    final token = context.read<DriverCubit>().state.token;
    if (token != null) {
      context.read<DriverRidesCubit>().fetchRides(token, status: _selectedFilter);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'My Trips',
          style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Nums.horizontalPadding, vertical: 12),
              child: _buildFilterChips(),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => _fetchRides(),
                color: Palette.primary,
                child: BlocBuilder<DriverRidesCubit, DriverRidesState>(
                  builder: (context, state) {
                    if (state.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (state.rides.isEmpty) {
                      return Center(
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.directions_car_filled_outlined, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              Text(
                                'No trips found',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Nums.horizontalPadding,
                        vertical: 8,
                      ),
                      itemCount: state.rides.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final ride = state.rides[index] as Map<String, dynamic>;
                        return _buildTripCard(ride);
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterChip('All Trips', null),
          const SizedBox(width: 8),
          _filterChip('Completed', 'completed'),
          const SizedBox(width: 8),
          _filterChip('Active', 'active'),
          const SizedBox(width: 8),
          _filterChip('Cancelled', 'cancelled'),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String? filter) {
    final isSelected = _selectedFilter == filter;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedFilter = filter);
        _fetchRides();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Palette.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Palette.primary : Colors.grey.shade300,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Palette.primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildTripCard(dynamic rawRide) {
    final ride = Map<String, dynamic>.from(rawRide as Map);
    final passenger = ride['passenger'] is Map ? Map<String, dynamic>.from(ride['passenger'] as Map) : null;
    final source = ride['source_address'] is Map ? Map<String, dynamic>.from(ride['source_address'] as Map) : null;
    final dest = ride['destination_address'] is Map ? Map<String, dynamic>.from(ride['destination_address'] as Map) : null;
    final isCancelled = ride['cancelled'] == true;
    final isCompleted = ride['end_time'] != null && !isCancelled;
    final price = ride['price']?.toString() ?? '—';
    final rideId = ride['id']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isCancelled
                      ? const Color(0xFFE5484D).withValues(alpha: 0.12)
                      : isCompleted
                          ? const Color(0xFF219653).withValues(alpha: 0.12)
                          : Palette.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isCancelled
                      ? 'CANCELLED'
                      : isCompleted
                          ? 'COMPLETED'
                          : 'IN PROGRESS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isCancelled
                        ? const Color(0xFFE5484D)
                        : isCompleted
                            ? const Color(0xFF219653)
                            : Palette.primary,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '₹$price',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (passenger != null) ...[
            Row(
              children: [
                const Icon(Icons.person, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  passenger['name']?.toString() ?? 'Passenger',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          _addressItem(
            Icons.circle,
            const Color(0xFF219653),
            source?['street']?.toString() ?? source?['place']?.toString() ?? 'Pickup',
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Container(width: 2, height: 16, color: Colors.grey.shade300),
          ),
          _addressItem(
            Icons.circle,
            Palette.primary,
            dest?['street']?.toString() ?? dest?['place']?.toString() ?? 'Destination',
          ),
          if (!isCompleted && !isCancelled) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final token = context.read<DriverCubit>().state.token;
                  if (token != null) {
                    await context.read<DriverRidesCubit>().completeRide(token, rideId);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Ride marked as completed!'),
                          backgroundColor: Color(0xFF219653),
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.check_circle, size: 18),
                label: const Text('Complete Trip'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF219653),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _addressItem(IconData icon, Color color, String text) {
    return Row(
      children: [
        Icon(icon, color: color, size: 10),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

