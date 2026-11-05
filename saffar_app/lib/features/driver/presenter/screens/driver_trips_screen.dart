import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:saffar_app/core/constants/nums.dart';
import 'package:saffar_app/core/palette.dart';
import 'package:saffar_app/features/driver/presenter/cubits/driver_cubit.dart';
import 'package:saffar_app/features/driver/presenter/cubits/driver_rides_cubit.dart';
import 'package:saffar_app/features/driver/presenter/screens/driver_trip_details_screen.dart';

class DriverTripsScreen extends StatefulWidget {
  const DriverTripsScreen({Key? key}) : super(key: key);

  static const String routeName = '/driver_trips';

  @override
  State<DriverTripsScreen> createState() => _DriverTripsScreenState();
}

class _DriverTripsScreenState extends State<DriverTripsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _categoryKeys = ['all', 'assigned', 'ongoing', 'completed', 'cancelled'];
  String _selectedPeriod = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categoryKeys.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _fetchRides();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    _fetchRides();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _fetchRides() {
    final token = context.read<DriverCubit>().state.token;
    if (token != null) {
      final category = _categoryKeys[_tabController.index];
      context.read<DriverRidesCubit>().fetchRides(
        token,
        status: category == 'all' ? null : category,
        period: _selectedPeriod == 'all' ? null : _selectedPeriod,
      );
    }
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return '—';
    try {
      final dt = DateTime.parse(ts.toString()).toLocal();
      return DateFormat('dd MMM, hh:mm a').format(dt);
    } catch (_) {
      return ts.toString();
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: BlocBuilder<DriverRidesCubit, DriverRidesState>(
            builder: (context, state) {
              final counts = state.categoryCounts;
              return TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: Palette.primary,
                unselectedLabelColor: Colors.grey.shade600,
                indicatorColor: Palette.primary,
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                tabs: [
                  Tab(text: 'All (${counts['all'] ?? 0})'),
                  Tab(text: 'Assigned (${counts['assigned'] ?? 0})'),
                  Tab(text: 'Ongoing (${counts['ongoing'] ?? 0})'),
                  Tab(text: 'Completed (${counts['completed'] ?? 0})'),
                  Tab(text: 'Cancelled (${counts['cancelled'] ?? 0})'),
                ],
              );
            },
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Period Filter Chips (All Time, Today, This Week, This Month)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: Nums.horizontalPadding, vertical: 10),
              color: Colors.white,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _periodChip('All Time', 'all'),
                    const SizedBox(width: 8),
                    _periodChip('Today', 'today'),
                    const SizedBox(width: 8),
                    _periodChip('This Week', 'this_week'),
                    const SizedBox(width: 8),
                    _periodChip('This Month', 'this_month'),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            // Trip List
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => _fetchRides(),
                color: Palette.primary,
                child: BlocBuilder<DriverRidesCubit, DriverRidesState>(
                  builder: (context, state) {
                    if (state.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (state.error != null && state.rides.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 54, color: Color(0xFFE5484D)),
                              const SizedBox(height: 12),
                              const Text('Failed to load trips', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                              const SizedBox(height: 6),
                              Text(state.error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                              const SizedBox(height: 16),
                              ElevatedButton(onPressed: _fetchRides, child: const Text('Try Again')),
                            ],
                          ),
                        ),
                      );
                    }

                    if (state.rides.isEmpty) {
                      return _buildEmptyState(_categoryKeys[_tabController.index]);
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Nums.horizontalPadding,
                        vertical: 12,
                      ),
                      itemCount: state.rides.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final rawRide = state.rides[index];
                        final ride = Map<String, dynamic>.from(rawRide as Map);
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

  Widget _periodChip(String label, String period) {
    final isSelected = _selectedPeriod == period;
    return GestureDetector(
      onTap: () {
        if (_selectedPeriod == period) return;
        setState(() => _selectedPeriod = period);
        _fetchRides();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Palette.primary : const Color(0xFFF1F3F5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.grey.shade800,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String category) {
    String message;
    IconData icon;
    switch (category) {
      case 'assigned':
        message = 'No upcoming assigned trips';
        icon = Icons.schedule;
        break;
      case 'ongoing':
        message = 'No ongoing trips right now';
        icon = Icons.directions_car_filled_outlined;
        break;
      case 'completed':
        message = 'No completed trips in this period';
        icon = Icons.task_alt;
        break;
      case 'cancelled':
        message = 'No cancelled trips';
        icon = Icons.cancel_outlined;
        break;
      default:
        message = 'No trips found';
        icon = Icons.route_outlined;
    }

    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 60, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 8),
              Text(
                'Pull down to refresh or try another filter.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> ride) {
    final rideId = ride['id']?.toString() ?? '';
    final bookingId = ride['booking_id']?.toString() ?? rideId;
    final isCancelled = ride['cancelled'] == true || ride['status'] == 'cancelled';
    final isCompleted = !isCancelled && (ride['status'] == 'completed' || ride['end_time'] != null);
    final isOngoing = !isCancelled && !isCompleted && ['arrived', 'started', 'in_progress'].contains(ride['status']);

    final passenger = ride['passenger'] is Map ? Map<String, dynamic>.from(ride['passenger'] as Map) : null;
    final passengerName = passenger?['name']?.toString() ?? 'Passenger';

    final source = ride['source_address'] is Map ? Map<String, dynamic>.from(ride['source_address'] as Map) : null;
    final dest = ride['destination_address'] is Map ? Map<String, dynamic>.from(ride['destination_address'] as Map) : null;
    final pickup = source?['street']?.toString() ?? source?['place']?.toString() ?? 'Pickup Point';
    final destination = dest?['street']?.toString() ?? dest?['place']?.toString() ?? 'Destination Point';

    final bookingDate = _formatDate(ride['created_at'] ?? ride['start_time']);
    final vehicleCategory = ride['vehicle_type']?.toString() ?? 'Vehicle';
    final finalFare = (ride['gross_fare'] as num?)?.toDouble() ??
        (ride['original_price'] as num?)?.toDouble() ??
        (ride['price'] as num?)?.toDouble() ??
        0.0;

    Color badgeColor;
    String statusText;
    if (isCancelled) {
      badgeColor = const Color(0xFFE5484D);
      statusText = 'CANCELLED';
    } else if (isCompleted) {
      badgeColor = const Color(0xFF219653);
      statusText = 'COMPLETED';
    } else if (isOngoing) {
      badgeColor = const Color(0xFFF2994A);
      statusText = 'ONGOING';
    } else {
      badgeColor = Palette.primary;
      statusText = 'ASSIGNED';
    }

    return InkWell(
      onTap: () {
        Navigator.of(context).pushNamed(
          DriverTripDetailsScreen.routeName,
          arguments: {'ride_id': rideId},
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Booking ID + Vehicle Category & Status Badge
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Booking #$bookingId',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.directions_car, size: 13, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            vehicleCategory,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '• $bookingDate',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 18),
            // Passenger Row
            Row(
              children: [
                const Icon(Icons.person_pin, size: 18, color: Palette.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    passengerName,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1A1A2E)),
                  ),
                ),
                Text(
                  '₹${finalFare.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Pickup & Destination
            _addressRow(Icons.radio_button_checked, const Color(0xFF219653), pickup),
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Container(width: 2, height: 12, color: Colors.grey.shade300),
            ),
            _addressRow(Icons.location_on, Palette.primary, destination),
            const SizedBox(height: 12),
            // Tap hint
            const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'View Details',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Palette.primary,
                  ),
                ),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward_ios, size: 11, color: Palette.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _addressRow(IconData icon, Color color, String text) {
    return Row(
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, color: Color(0xFF333333)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
