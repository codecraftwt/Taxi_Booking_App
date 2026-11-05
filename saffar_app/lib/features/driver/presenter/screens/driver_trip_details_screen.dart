import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:saffar_app/core/palette.dart';
import 'package:saffar_app/features/driver/presenter/cubits/driver_cubit.dart';
import 'package:saffar_app/features/driver/presenter/cubits/driver_rides_cubit.dart';
import 'package:saffar_app/features/driver/presenter/screens/driver_pickup_navigation_screen.dart';
import 'package:saffar_app/features/driver/presenter/screens/driver_active_trip_screen.dart';

class DriverTripDetailsScreen extends StatefulWidget {
  const DriverTripDetailsScreen({
    Key? key,
    required this.rideId,
  }) : super(key: key);

  static const String routeName = '/driver_trip_details';

  final String rideId;

  @override
  State<DriverTripDetailsScreen> createState() => _DriverTripDetailsScreenState();
}

class _DriverTripDetailsScreenState extends State<DriverTripDetailsScreen> {
  @override
  void initState() {
    super.initState();
    _loadTripDetails();
  }

  void _loadTripDetails() {
    final token = context.read<DriverCubit>().state.token;
    if (token != null) {
      context.read<DriverRidesCubit>().fetchTripDetails(token, widget.rideId);
    }
  }

  Future<void> _callPassenger(String? phone) async {
    if (phone == null || phone.trim().isEmpty) return;
    final Uri url = Uri(scheme: 'tel', path: phone.trim());
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot launch call to $phone')),
        );
      }
    }
  }

  String _formatTimestamp(dynamic ts) {
    if (ts == null) return '—';
    try {
      final dt = DateTime.parse(ts.toString()).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
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
          'Trip Details',
          style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A1A2E)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTripDetails,
            tooltip: 'Refresh details',
          ),
        ],
      ),
      body: SafeArea(
        child: BlocBuilder<DriverRidesCubit, DriverRidesState>(
          builder: (context, state) {
            if (state.isLoadingDetails) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state.error != null && state.selectedTripDetails == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 54, color: Color(0xFFE5484D)),
                      const SizedBox(height: 12),
                      const Text(
                        'Failed to load trip details',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        state.error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton(
                        onPressed: _loadTripDetails,
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final trip = state.selectedTripDetails;
            if (trip == null) {
              return const Center(child: Text('Trip not found.'));
            }

            return _buildContent(trip);
          },
        ),
      ),
    );
  }

  Widget _buildContent(Map<String, dynamic> trip) {
    final isCancelled = trip['cancelled'] == true || trip['status'] == 'cancelled';
    final isCompleted = !isCancelled && (trip['status'] == 'completed' || trip['end_time'] != null);
    final isOngoing = !isCancelled && !isCompleted && ['arrived', 'started', 'in_progress'].contains(trip['status']);
    final isAssigned = !isCancelled && !isCompleted && !isOngoing;

    final passenger = trip['passenger'] is Map ? Map<String, dynamic>.from(trip['passenger'] as Map) : null;
    final source = trip['source_address'] is Map ? Map<String, dynamic>.from(trip['source_address'] as Map) : null;
    final dest = trip['destination_address'] is Map ? Map<String, dynamic>.from(trip['destination_address'] as Map) : null;

    final grossFare = (trip['gross_fare'] as num?)?.toDouble() ?? 0.0;
    final commission = (trip['platform_commission'] as num?)?.toDouble() ?? 0.0;
    final netEarnings = (trip['net_earnings'] as num?)?.toDouble() ?? 0.0;
    final otherDeductions = (trip['other_deductions'] as num?)?.toDouble() ?? 0.0;
    final distance = (trip['distance_km'] as num?)?.toDouble() ?? 0.0;
    final duration = (trip['duration_minutes'] as num?)?.toInt() ?? 0;
    final paymentStatus = trip['payment_status']?.toString() ?? 'Pending';
    final paymentMethod = trip['payment_method']?.toString() ?? 'UPI';

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header Card (Booking ID, Status Badge, Vehicle Type)
          _buildHeaderCard(trip, isCancelled, isCompleted, isOngoing, isAssigned),
          const SizedBox(height: 14),

          // 2. Cancellation Alert Card (if cancelled)
          if (isCancelled) ...[
            _buildCancellationCard(trip),
            const SizedBox(height: 14),
          ],

          // 3. Passenger Information Card
          if (passenger != null) ...[
            _buildPassengerCard(passenger),
            const SizedBox(height: 14),
          ],

          // 4. Route Card (Pickup & Destination with vertical timeline)
          _buildRouteCard(source, dest),
          const SizedBox(height: 14),

          // 5. Trip Timings & Metrics (Booking time, Start time, End time, Distance, Duration)
          _buildTimingsCard(trip, distance, duration),
          const SizedBox(height: 14),

          // 6. Itemized Fare Breakdown & Payment
          _buildFareBreakdownCard(grossFare, commission, otherDeductions, netEarnings, paymentStatus, paymentMethod),
          const SizedBox(height: 20),

          // 7. Contextual Actions
          if (isAssigned) ...[
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pushNamed(
                  DriverPickupNavigationScreen.routeName,
                  arguments: {'ride_id': widget.rideId},
                );
              },
              icon: const Icon(Icons.navigation, color: Colors.white),
              label: const Text(
                'Navigate to Pickup',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Palette.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ] else if (isOngoing) ...[
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pushNamed(
                  DriverActiveTripScreen.routeName,
                  arguments: {'ride_id': widget.rideId},
                );
              },
              icon: const Icon(Icons.directions_car, color: Colors.white),
              label: const Text(
                'Open Active Trip',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF219653),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(
    Map<String, dynamic> trip,
    bool isCancelled,
    bool isCompleted,
    bool isOngoing,
    bool isAssigned,
  ) {
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

    final bookingId = trip['id']?.toString() ?? '—';
    final vehicleType = trip['vehicle_type']?.toString() ?? 'Sedan';

    return Container(
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Booking #$bookingId',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.directions_car, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    vehicleType,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: badgeColor,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancellationCard(Map<String, dynamic> trip) {
    final reason = trip['cancellation_reason']?.toString() ?? 'Not specified';
    final notes = trip['cancellation_notes']?.toString();
    final cancelledBy = trip['cancelled_by']?.toString() ?? 'Unknown';
    final cancelledAt = _formatTimestamp(trip['cancelled_at']);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5484D).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFE5484D), size: 20),
              SizedBox(width: 8),
              Text(
                'Cancellation Details',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: Color(0xFFE5484D),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _kvRow('Reason:', reason, isBoldVal: true),
          if (notes != null && notes.isNotEmpty) ...[
            const SizedBox(height: 6),
            _kvRow('Notes:', notes),
          ],
          const SizedBox(height: 6),
          _kvRow('Cancelled By:', cancelledBy.toUpperCase()),
          const SizedBox(height: 6),
          _kvRow('Cancelled At:', cancelledAt),
        ],
      ),
    );
  }

  Widget _buildPassengerCard(Map<String, dynamic> passenger) {
    final name = passenger['name']?.toString() ?? 'Passenger';
    final phone = passenger['phone']?.toString();
    final imageUrl = passenger['image_url']?.toString();

    return Container(
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
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Palette.primary.withValues(alpha: 0.1),
            backgroundImage: (imageUrl != null && imageUrl.isNotEmpty) ? NetworkImage(imageUrl) : null,
            child: (imageUrl == null || imageUrl.isEmpty)
                ? const Icon(Icons.person, color: Palette.primary, size: 26)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF1A1A2E)),
                ),
                if (phone != null && phone.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    phone,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
          if (phone != null && phone.isNotEmpty)
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF219653).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.phone, color: Color(0xFF219653), size: 20),
              ),
              onPressed: () => _callPassenger(phone),
              tooltip: 'Call Passenger',
            ),
        ],
      ),
    );
  }

  Widget _buildRouteCard(Map<String, dynamic>? source, Map<String, dynamic>? dest) {
    final pickup = source?['street']?.toString() ?? source?['place']?.toString() ?? 'Pickup Point';
    final drop = dest?['street']?.toString() ?? dest?['place']?.toString() ?? 'Destination Point';

    return Container(
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
          const Text(
            'Route Information',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF1A1A2E)),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  const Icon(Icons.radio_button_checked, size: 16, color: Color(0xFF219653)),
                  Container(
                    width: 2,
                    height: 32,
                    color: Colors.grey.shade300,
                  ),
                  const Icon(Icons.location_on, size: 18, color: Palette.primary),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PICKUP',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey.shade500),
                    ),
                    Text(
                      pickup,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E)),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'DESTINATION',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey.shade500),
                    ),
                    Text(
                      drop,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimingsCard(Map<String, dynamic> trip, double distance, int duration) {
    return Container(
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
          const Text(
            'Trip Schedule & Metrics',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF1A1A2E)),
          ),
          const SizedBox(height: 12),
          _metricRow(Icons.calendar_today_outlined, 'Booking Time', _formatTimestamp(trip['created_at'] ?? trip['start_time'])),
          const Divider(height: 18),
          _metricRow(Icons.play_circle_outline, 'Trip Started At', _formatTimestamp(trip['trip_started_at'])),
          const Divider(height: 18),
          _metricRow(Icons.check_circle_outline, 'Trip Completed At', _formatTimestamp(trip['end_time'])),
          const Divider(height: 18),
          Row(
            children: [
              Expanded(
                child: _metricRow(Icons.straighten, 'Distance', '${distance.toStringAsFixed(1)} km'),
              ),
              Expanded(
                child: _metricRow(Icons.timer_outlined, 'Duration', '$duration mins'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFareBreakdownCard(
    double grossFare,
    double commission,
    double deductions,
    double netEarnings,
    String paymentStatus,
    String paymentMethod,
  ) {
    return Container(
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Fare Breakdown',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF1A1A2E)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: paymentStatus.toLowerCase() == 'paid'
                      ? const Color(0xFF219653).withValues(alpha: 0.12)
                      : const Color(0xFFF2994A).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$paymentStatus ($paymentMethod)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: paymentStatus.toLowerCase() == 'paid' ? const Color(0xFF219653) : const Color(0xFFF2994A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _financialRow('Gross Fare', '₹${grossFare.toStringAsFixed(2)}', false),
          const SizedBox(height: 6),
          _financialRow('Platform Commission (15%)', '-₹${commission.toStringAsFixed(2)}', false, isNegative: true),
          if (deductions > 0) ...[
            const SizedBox(height: 6),
            _financialRow('Other Deductions', '-₹${deductions.toStringAsFixed(2)}', false, isNegative: true),
          ],
          const Divider(height: 20),
          _financialRow('Driver Net Take-Home', '₹${netEarnings.toStringAsFixed(2)}', true),
        ],
      ),
    );
  }

  Widget _metricRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1A1A2E)),
        ),
      ],
    );
  }

  Widget _financialRow(String label, String value, bool isTotal, {bool isNegative = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 15 : 13,
            fontWeight: isTotal ? FontWeight.w800 : FontWeight.w500,
            color: isTotal ? const Color(0xFF1A1A2E) : Colors.grey.shade700,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 16 : 13,
            fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
            color: isNegative
                ? const Color(0xFFE5484D)
                : isTotal
                    ? const Color(0xFF219653)
                    : const Color(0xFF1A1A2E),
          ),
        ),
      ],
    );
  }

  Widget _kvRow(String key, String value, {bool isBoldVal = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            key,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBoldVal ? FontWeight.w700 : FontWeight.w500,
              color: const Color(0xFF1A1A2E),
            ),
          ),
        ),
      ],
    );
  }
}

