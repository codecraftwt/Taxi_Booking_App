import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:saffar_app/core/constants/nums.dart';
import 'package:saffar_app/core/cubits/previous_rides_cubit.dart';
import 'package:saffar_app/core/models/ride.dart';
import 'package:saffar_app/core/palette.dart';
import 'package:saffar_app/features/view_map/presenter/screens/view_map_screen.dart';

class UserRideHistoryScreen extends StatefulWidget {
  const UserRideHistoryScreen({Key? key}) : super(key: key);

  static const String routeName = '/user_ride_history';

  @override
  State<UserRideHistoryScreen> createState() => _UserRideHistoryScreenState();
}

class _UserRideHistoryScreenState extends State<UserRideHistoryScreen> {
  String _filter = 'All'; // 'All', 'Completed', 'Cancelled'

  @override
  void initState() {
    super.initState();
    context.read<PreviousRidesCubit>().getListOfPreviousRidesAndEmit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'My Trips & Rides',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A1A2E),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Tabs
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: Nums.horizontalPadding,
                vertical: 12,
              ),
              child: Row(
                children: [
                  _filterChip('All Rides', 'All'),
                  const SizedBox(width: 8),
                  _filterChip('Completed', 'Completed'),
                  const SizedBox(width: 8),
                  _filterChip('Cancelled', 'Cancelled'),
                ],
              ),
            ),

            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  context
                      .read<PreviousRidesCubit>()
                      .getListOfPreviousRidesAndEmit();
                },
                color: Palette.primary,
                child: BlocBuilder<PreviousRidesCubit, PreviousRidesState>(
                  builder: (context, state) {
                    if (state is PreviousRidesLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (state is PreviousRidesGot) {
                      final allRides = state.previousRides;

                      final filteredRides = allRides.where((ride) {
                        if (_filter == 'Completed') {
                          return !ride.cancelled;
                        } else if (_filter == 'Cancelled') {
                          return ride.cancelled;
                        }
                        return true;
                      }).toList();

                      if (filteredRides.isEmpty) {
                        return Center(
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: Palette.primary.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.directions_car_outlined,
                                      size: 40,
                                      color: Palette.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _filter == 'All'
                                        ? 'No trips yet'
                                        : 'No $_filter trips',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1A1A2E),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Whenever you book a ride with Saffar, your trip receipts and details will appear here.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.pop(context);
                                    },
                                    icon: const Icon(Icons.search),
                                    label: const Text('Book a Ride Now'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 14,
                                      ),
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
                        itemCount: filteredRides.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final ride = filteredRides[index];
                          return _buildRideCard(context, ride);
                        },
                      );
                    }

                    return Center(
                      child: Text(
                        'Failed to load rides. Pull to retry.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
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

  Widget _filterChip(String label, String value) {
    final isSelected = _filter == value;
    return GestureDetector(
      onTap: () {
        setState(() => _filter = value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Palette.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Palette.primary : Colors.grey.shade300,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Palette.primary.withOpacity(0.2),
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

  Widget _buildRideCard(BuildContext context, Ride ride) {
    final isCancelled = ride.cancelled;
    final driver = ride.driver;
    final source = ride.sourceAddress;
    final destination = ride.destinationAddress;
    final startTime = ride.startTime;

    final dateStr =
        '${startTime.day}/${startTime.month}/${startTime.year} • ${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Date and Price/Status
          Row(
            children: [
              Text(
                dateStr,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isCancelled
                      ? const Color(0xFFE5484D).withOpacity(0.12)
                      : const Color(0xFF219653).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isCancelled ? 'CANCELLED' : 'COMPLETED',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isCancelled
                        ? const Color(0xFFE5484D)
                        : const Color(0xFF219653),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '₹${ride.price.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Route: Pickup to Drop
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  const Icon(Icons.circle, size: 10, color: Color(0xFF219653)),
                  Container(
                    width: 2,
                    height: 28,
                    color: Colors.grey.shade300,
                  ),
                  const Icon(Icons.circle, size: 10, color: Palette.primary),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      source.street.isNotEmpty ? source.street : (source.place ?? 'Pickup'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A2E),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      destination.street.isNotEmpty
                          ? destination.street
                          : (destination.place ?? 'Destination'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A2E),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Divider(height: 24),

          // Driver & Action Row
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Palette.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.drive_eta, color: Palette.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    Text(
                      '${driver.vehicleName} • ${driver.vehicleNumber}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Rebook Ride button
              TextButton.icon(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    ViewMapScreen.routeName,
                    arguments: ViewMapScreenArguments(
                      initialPickupAddress: source,
                      initialDestinationAddress: destination,
                    ),
                  );
                },
                icon: const Icon(Icons.replay_rounded, size: 16),
                label: const Text('Rebook'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

