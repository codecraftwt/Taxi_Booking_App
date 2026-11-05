import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:saffar_app/core/cubits/previous_rides_cubit.dart';
import 'package:saffar_app/core/models/ride.dart';
import 'package:saffar_app/core/palette.dart';
import 'package:saffar_app/core/service_locator.dart';
import 'package:saffar_app/features/ride/data/repositories/ride_repo.dart';
import 'package:saffar_app/features/ride/presenter/screens/active_trip_screen.dart';
import 'package:saffar_app/features/ride/presenter/screens/ride_confirmation_screen.dart';
import 'package:saffar_app/features/user/presenter/cubits/user_cubit.dart';
import 'package:saffar_app/features/user/presenter/screens/user_profile_screen.dart';

class TripHistoryItem {
  const TripHistoryItem({
    required this.id,
    required this.vehicleType,
    required this.timeText,
    required this.fareText,
    required this.paymentText,
    required this.statusText,
    required this.pickupText,
    required this.dropText,
    this.driverName,
    this.driverRating,
    this.vehicleNumber,
    this.driverImageUrl,
    required this.icon,
    this.isHorizontalRoute = false,
  });

  final String id;
  final String vehicleType;
  final String timeText;
  final String fareText;
  final String paymentText;
  final String statusText;
  final String pickupText;
  final String dropText;
  final String? driverName;
  final String? driverRating;
  final String? vehicleNumber;
  final String? driverImageUrl;
  final IconData icon;
  final bool isHorizontalRoute;

  factory TripHistoryItem.fromRide(Ride ride) {
    IconData icon;
    final cat = ride.vehicleType.toLowerCase();
    if (cat.contains('bike')) {
      icon = Icons.two_wheeler_rounded;
    } else if (cat.contains('auto')) {
      icon = Icons.electric_rickshaw_rounded;
    } else {
      icon = Icons.directions_car_filled_rounded;
    }

    final now = DateTime.now();
    final st = ride.startTime;
    String formattedTime;
    if (st.year == now.year && st.month == now.month && st.day == now.day) {
      formattedTime = 'Today, ${_formatTime(st)}';
    } else if (st.year == now.year && st.month == now.month && st.day == now.day - 1) {
      formattedTime = 'Yesterday, ${_formatTime(st)}';
    } else {
      formattedTime = '${st.day} ${_monthName(st.month)}, ${_formatTime(st)}';
    }

    final pickup = [ride.sourceAddress.street, ride.sourceAddress.place]
        .where((s) => s != null && s.isNotEmpty)
        .join(', ');
    final drop = [ride.destinationAddress.street, ride.destinationAddress.place]
        .where((s) => s != null && s.isNotEmpty)
        .join(', ');

    return TripHistoryItem(
      id: ride.id,
      vehicleType: ride.vehicleType.isNotEmpty ? ride.vehicleType : 'Saffar Ride',
      timeText: formattedTime,
      fareText: '₹${ride.price.toStringAsFixed(0)}',
      paymentText: ride.paymentMethod.isNotEmpty ? ride.paymentMethod : 'Paid via Cash',
      statusText: ride.cancelled ? 'Cancelled' : 'Completed',
      pickupText: pickup.isNotEmpty ? pickup : 'Pickup Point',
      dropText: drop.isNotEmpty ? drop : 'Destination Point',
      driverName: (ride.driver.name.isNotEmpty &&
              ride.driver.name != 'Driver Unassigned')
          ? ride.driver.name
          : null,
      driverRating: ride.rating > 0 ? ride.rating.toStringAsFixed(1) : null,
      vehicleNumber: (ride.driver.vehicleNumber.isNotEmpty &&
              ride.driver.vehicleNumber != 'Not Assigned')
          ? ride.driver.vehicleNumber
          : null,
      driverImageUrl: ride.driver.imageUrl,
      icon: icon,
      isHorizontalRoute: false,
    );
  }

  static String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '$hour:$min $ampm';
  }

  static String _monthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return (month >= 1 && month <= 12) ? months[month - 1] : '';
  }
}

class UserRideHistoryScreen extends StatefulWidget {
  const UserRideHistoryScreen({Key? key}) : super(key: key);

  static const String routeName = '/user_ride_history';

  @override
  State<UserRideHistoryScreen> createState() => _UserRideHistoryScreenState();
}

class _UserRideHistoryScreenState extends State<UserRideHistoryScreen> {
  // 'Completed', 'Upcoming', 'Cancelled'
  String _selectedTab = 'Completed';

  @override
  void initState() {
    super.initState();
    context.read<PreviousRidesCubit>().getListOfPreviousRidesAndEmit();
  }

  Future<void> _rebookRide(TripHistoryItem trip) async {
    try {
      final res = await sl<RideRepo>().rebookRide(trip.id);
      final newRideId = res['ride_id']?.toString() ?? trip.id;
      final otp = res['otp']?.toString() ?? '4829';
      if (mounted) {
        Navigator.pushNamed(
          context,
          ActiveTripScreen.routeName,
          arguments: {
            'ride_id': newRideId,
            'otp': otp,
            'driver_name': trip.driverName ?? 'Saffar Driver',
            'vehicle_name': trip.vehicleType,
            'vehicle_number': trip.vehicleNumber ?? '',
            'fare': trip.fareText,
            'pickup_spot': trip.pickupText,
          },
        );
      }
    } catch (_) {
      if (mounted) {
        Navigator.pushNamed(
          context,
          RideConfirmationScreen.routeName,
        );
      }
    }
  }

  void _showInvoiceDialog(TripHistoryItem trip) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Trip Receipt',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Palette.neutral,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  trip.vehicleType,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                Text(
                  trip.fareText,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Palette.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Payment Mode: ${trip.paymentText}',
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
            const SizedBox(height: 14),
            Text(
              'From: ${trip.pickupText}',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              'To: ${trip.dropText}',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('PDF Invoice downloaded to device'),
                    ),
                  );
                },
                icon: const Icon(Icons.download),
                label: const Text('Download Invoice PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Palette.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserCubit>().state.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      body: SafeArea(
        child: BlocBuilder<PreviousRidesCubit, PreviousRidesState>(
          builder: (context, state) {
            final allRides = state is PreviousRidesGot ? state.previousRides : <Ride>[];
            final isLoading = state is PreviousRidesLoading;

            final completedRides = allRides.where((r) =>
                !r.cancelled &&
                (r.endTime != null ||
                    r.status == 'completed' ||
                    (r.status != 'requested' &&
                        r.status != 'accepted' &&
                        r.status != 'reaching_pickup' &&
                        r.status != 'arrived' &&
                        r.status != 'in_progress'))).toList();

            final upcomingRides = allRides.where((r) =>
                !r.cancelled &&
                (r.status == 'requested' ||
                    r.status == 'accepted' ||
                    r.status == 'reaching_pickup' ||
                    r.status == 'arrived' ||
                    r.status == 'in_progress')).toList();

            final cancelledRides =
                allRides.where((r) => r.cancelled == true || r.status == 'cancelled').toList();

            final double totalCo2 = completedRides.fold(0.0, (sum, r) => sum + r.co2Saved);

            return Column(
              children: [
                // Top App Bar
                _buildTopAppBar(user?.imageUrl),

                // Header Section: Title, Subtitle, Search & Filter Buttons
                _buildHeader(),

                // Filter Tabs: Completed | Upcoming | Cancelled
                _buildFilterTabs(
                  completedCount: completedRides.length,
                  upcomingCount: upcomingRides.length,
                  cancelledCount: cancelledRides.length,
                ),

                // Trips List
                Expanded(
                  child: isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: Palette.primary),
                        )
                      : RefreshIndicator(
                          onRefresh: () async {
                            context.read<PreviousRidesCubit>().getListOfPreviousRidesAndEmit();
                          },
                          color: Palette.primary,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            children: [
                              // Green Commute Impact Card
                              _buildGreenCommuteCard(totalCo2),

                              const SizedBox(height: 14),

                              if (_selectedTab == 'Completed') ...[
                                if (completedRides.isEmpty)
                                  _buildEmptyState(
                                    icon: Icons.directions_car_outlined,
                                    title: 'No completed rides yet',
                                    subtitle: 'Your completed trips and receipts will appear here.',
                                    showBookButton: true,
                                  )
                                else
                                  ...completedRides.asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final ride = entry.value;
                                    final trip = TripHistoryItem.fromRide(ride);
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: index == 0
                                          ? _buildTripCard1(trip)
                                          : _buildHorizontalTripCard(trip),
                                    );
                                  }),
                              ] else if (_selectedTab == 'Upcoming') ...[
                                if (upcomingRides.isEmpty)
                                  _buildEmptyState(
                                    icon: Icons.calendar_today_outlined,
                                    title: 'No upcoming rides',
                                    subtitle: 'Active or scheduled rides will appear here.',
                                    showBookButton: true,
                                  )
                                else
                                  ...upcomingRides.map((ride) => Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: _buildUpcomingRideCard(ride),
                                      )),
                              ] else ...[
                                if (cancelledRides.isEmpty)
                                  _buildEmptyState(
                                    icon: Icons.cancel_outlined,
                                    title: 'No cancelled rides',
                                    subtitle: 'You have not cancelled any trips.',
                                    showBookButton: false,
                                  )
                                else
                                  ...cancelledRides.asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final ride = entry.value;
                                    final trip = TripHistoryItem.fromRide(ride);
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: index == 0
                                          ? _buildTripCard1(trip)
                                          : _buildHorizontalTripCard(trip),
                                    );
                                  }),
                              ],

                              const SizedBox(height: 16),

                              // Past 30 Days Footer
                              _buildPastDaysFooter(),
                            ],
                          ),
                        ),
                ),

                // Bottom Navigation Bar
                _buildBottomNavBar(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool showBookButton,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: const Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Palette.neutral,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
            ),
          ),
          if (showBookButton) ...[
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B00),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Book a Ride',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUpcomingRideCard(Ride ride) {
    final pickup = [ride.sourceAddress.street, ride.sourceAddress.place]
        .where((s) => s != null && s.isNotEmpty)
        .join(', ');
    final drop = [ride.destinationAddress.street, ride.destinationAddress.place]
        .where((s) => s != null && s.isNotEmpty)
        .join(', ');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFED7AA)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0E6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  ride.status.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFFF6B00),
                  ),
                ),
              ),
              const Spacer(),
              if (ride.otp.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'OTP: ${ride.otp}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            ride.vehicleType,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'From: ${pickup.isNotEmpty ? pickup : "Pickup Location"}\nTo: ${drop.isNotEmpty ? drop : "Destination"}',
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  ActiveTripScreen.routeName,
                  arguments: {
                    'ride_id': ride.id,
                    'otp': ride.otp,
                    'driver_name': ride.driver.name,
                    'vehicle_name': ride.vehicleType,
                    'vehicle_number': ride.driver.vehicleNumber,
                    'fare': '₹${ride.price.toStringAsFixed(0)}',
                    'pickup_spot': pickup,
                  },
                );
              },
              icon: const Icon(Icons.navigation_outlined, size: 16),
              label: const Text('Track Active Ride', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B00),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPastDaysFooter() {
    return Center(
      child: Column(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 16,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Showing completed trips from the past 30 days',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _buildTopAppBar(String? userImageUrl) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          Image.asset(
            'assets/images/saffar_logo_rounded.png',
            width: 28,
            height: 28,
            errorBuilder: (_, __, ___) => Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: Palette.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.navigation, color: Colors.white, size: 16),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                'Saffar',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Palette.neutral,
                  height: 1.1,
                ),
              ),
              Text(
                'My Rides',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                  height: 1.1,
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No new notifications')),
              );
            },
            icon: const Icon(Icons.notifications_none_rounded,
                color: Palette.neutral, size: 22),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () {
              Navigator.pushNamed(context, UserProfileScreen.routeName);
            },
            child: CircleAvatar(
              radius: 16,
              backgroundImage: NetworkImage(
                userImageUrl ??
                    'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'My Rides',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Palette.neutral,
                    letterSpacing: -0.4,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Review receipts, ratings & easy rebook',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Search Icon Button
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search, size: 19, color: Palette.neutral),
          ),
          const SizedBox(width: 8),
          // Filter Button with orange dot
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.tune_rounded, size: 19, color: Palette.neutral),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF6B00),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs({
    int completedCount = 0,
    int upcomingCount = 0,
    int cancelledCount = 0,
  }) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            // Tab 1: Completed
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedTab = 'Completed'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _selectedTab == 'Completed'
                        ? Colors.white
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: _selectedTab == 'Completed'
                        ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Completed',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _selectedTab == 'Completed'
                              ? Palette.neutral
                              : const Color(0xFF64748B),
                        ),
                      ),
                      if (completedCount > 0) ...[
                        const SizedBox(width: 5),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF6B00),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Tab 2: Upcoming
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedTab = 'Upcoming'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _selectedTab == 'Upcoming'
                        ? Colors.white
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: _selectedTab == 'Upcoming'
                        ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Upcoming',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _selectedTab == 'Upcoming'
                              ? Palette.neutral
                              : const Color(0xFF64748B),
                        ),
                      ),
                      if (upcomingCount > 0) ...[
                        const SizedBox(width: 5),
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B00),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$upcomingCount',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Tab 3: Cancelled
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedTab = 'Cancelled'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _selectedTab == 'Cancelled'
                        ? Colors.white
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: _selectedTab == 'Cancelled'
                        ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Cancelled',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _selectedTab == 'Cancelled'
                              ? Palette.neutral
                              : const Color(0xFF64748B),
                        ),
                      ),
                      if (cancelledCount > 0) ...[
                        const SizedBox(width: 5),
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF64748B),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$cancelledCount',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGreenCommuteCard([double totalCo2 = 0.0]) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD6E8FC)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE6D5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.eco_outlined,
              color: Color(0xFFFF6B00),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'GREEN COMMUTE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${totalCo2 > 0 ? totalCo2.toStringAsFixed(1) : '0.0'} kg CO₂ saved',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Palette.neutral,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEAD8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'This Month',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFFC2410C),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Trip Card 1: Saffar Auto (with Vertical Pickup & Drop Layout)
  Widget _buildTripCard1(TripHistoryItem trip) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Auto icon, Title, Completed badge, Time, Fare, Payment
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(trip.icon,
                    color: const Color(0xFF1E3A8A), size: 24),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          trip.vehicleType,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Palette.neutral,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: trip.statusText.toLowerCase() == 'cancelled'
                                ? const Color(0xFFFEE2E2)
                                : const Color(0xFFE8F8F0),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            trip.statusText,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: trip.statusText.toLowerCase() == 'cancelled'
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF047857),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      trip.timeText,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    trip.fareText,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Palette.neutral,
                    ),
                  ),
                  Text(
                    trip.paymentText,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Vertical Route Container
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 3),
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PICKUP',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          Text(
                            trip.pickupText,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Palette.neutral,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 3),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 2,
                      height: 12,
                      color: const Color(0xFFCBD5E1),
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 3),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B00),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DROP',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          Text(
                            trip.dropText,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Palette.neutral,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (trip.driverName != null && trip.driverName!.isNotEmpty) ...[
            const SizedBox(height: 10),
            // Driver Row: Avatar, ★ Rating • Driver Name, Plate
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: trip.driverImageUrl != null && trip.driverImageUrl!.isNotEmpty
                      ? Image.network(
                          trip.driverImageUrl!,
                          width: 28,
                          height: 28,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const CircleAvatar(
                            radius: 14,
                            child: Icon(Icons.person, size: 16),
                          ),
                        )
                      : const CircleAvatar(
                          radius: 14,
                          child: Icon(Icons.person, size: 16),
                        ),
                ),
                const SizedBox(width: 6),
                if (trip.driverRating != null) ...[
                  const Icon(Icons.star_rounded, color: Color(0xFFD97706), size: 14),
                  const SizedBox(width: 2),
                  Text(
                    '${trip.driverRating}  •  ',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Palette.neutral,
                    ),
                  ),
                ],
                Text(
                  trip.driverName!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Palette.neutral,
                  ),
                ),
                if (trip.vehicleNumber != null && trip.vehicleNumber!.isNotEmpty) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      trip.vehicleNumber!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],

          const SizedBox(height: 12),

          // Rebook Button Row with Receipt & Info icons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _rebookRide(trip),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text(
                    'Rebook Ride',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B00),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _showInvoiceDialog(trip),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  padding: const EdgeInsets.all(12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Icon(Icons.receipt_long_outlined,
                    color: Palette.neutral, size: 18),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Trip Reference: ${trip.id}')),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  padding: const EdgeInsets.all(12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Icon(Icons.support_agent_rounded,
                    color: Palette.neutral, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Trip Cards 2 & 3: Prime Sedan & Saffar Bike (with Horizontal FROM ➔ TO layout)
  Widget _buildHorizontalTripCard(TripHistoryItem trip) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(trip.icon, color: const Color(0xFF1E3A8A), size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          trip.vehicleType,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Palette.neutral,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: trip.statusText.toLowerCase() == 'cancelled'
                                ? const Color(0xFFFEE2E2)
                                : const Color(0xFFE8F8F0),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            trip.statusText,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: trip.statusText.toLowerCase() == 'cancelled'
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF047857),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      trip.timeText,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    trip.fareText,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Palette.neutral,
                    ),
                  ),
                  Text(
                    trip.paymentText,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Horizontal Route: FROM ... ➔ TO ...
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'FROM',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        trip.pickupText,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Palette.neutral,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_forward_rounded,
                      size: 14, color: Color(0xFF64748B)),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'TO',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        trip.dropText,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Palette.neutral,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Download Invoice (Left) + Rebook Ride (Right)
          Row(
            children: [
              GestureDetector(
                onTap: () => _showInvoiceDialog(trip),
                child: Row(
                  children: const [
                    Icon(Icons.description_outlined,
                        size: 16, color: Color(0xFF1E3A8A)),
                    SizedBox(width: 4),
                    Text(
                      'Download Invoice',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _rebookRide(trip),
                icon: const Icon(Icons.refresh_rounded, size: 14),
                label: const Text(
                  'Rebook Ride',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFF0E6),
                  foregroundColor: const Color(0xFFFF6B00),
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(Icons.map_outlined, 'Home', false, onTap: () {
            Navigator.pop(context);
          }),
          _buildNavItem(Icons.history_rounded, 'My Rides', true, hasDot: true),
          _buildNavItem(Icons.notifications_none_rounded, 'Notifications', false,
              onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No new notifications')),
            );
          }),
          _buildNavItem(Icons.person_outline_rounded, 'Profile', false, onTap: () {
            Navigator.pushNamed(context, UserProfileScreen.routeName);
          }),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive,
      {bool hasDot = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isActive ? const Color(0xFF0284C7) : const Color(0xFF64748B),
            size: 24,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              color: isActive ? const Color(0xFF0284C7) : const Color(0xFF64748B),
            ),
          ),
          if (hasDot) ...[
            const SizedBox(height: 2),
            Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: Color(0xFFFF6B00),
                shape: BoxShape.circle,
              ),
            ),
          ] else ...[
            const SizedBox(height: 7),
          ],
        ],
      ),
    );
  }
}
