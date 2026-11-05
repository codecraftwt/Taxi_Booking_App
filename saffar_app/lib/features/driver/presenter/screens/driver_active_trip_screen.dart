import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:saffar_app/core/config/map_config.dart';
import 'package:saffar_app/core/palette.dart';
import 'package:saffar_app/core/services/map_service.dart';
import 'package:saffar_app/core/widgets/map_marker_widgets.dart';
import 'package:saffar_app/features/driver/presenter/cubits/driver_cubit.dart';
import 'package:saffar_app/features/driver/presenter/cubits/driver_pickup_cubit.dart';
import 'package:saffar_app/features/driver/presenter/cubits/driver_pickup_state.dart';
import 'package:saffar_app/features/driver/presenter/screens/driver_trip_completed_screen.dart';
import 'package:saffar_app/features/driver/presenter/screens/driver_cancel_ride_screen.dart';

class DriverActiveTripScreen extends StatefulWidget {
  const DriverActiveTripScreen({
    Key? key,
    required this.rideId,
  }) : super(key: key);

  static const String routeName = '/driver_active_trip';
  final String rideId;

  @override
  State<DriverActiveTripScreen> createState() => _DriverActiveTripScreenState();
}

class _DriverActiveTripScreenState extends State<DriverActiveTripScreen> {
  final MapController _mapController = MapController();
  final Distance _distanceCalc = const Distance();
  Timer? _durationTimer;
  int _secondsElapsed = 0;
  bool _hasInitialCentered = false;

  @override
  void initState() {
    super.initState();
    _startDurationTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRideData();
    });
  }

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _secondsElapsed++;
        });
      }
    });
  }

  void _loadRideData() {
    final token = context.read<DriverCubit>().state.token;
    if (token != null) {
      context.read<DriverPickupCubit>().loadAssignedRide(token, widget.rideId);
    }
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _fitBounds(LatLng driverPos, LatLng destPos) {
    try {
      final bounds = LatLngBounds.fromPoints([driverPos, destPos]);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.only(top: 80, bottom: 330, left: 60, right: 60),
        ),
      );
    } catch (_) {}
  }

  Future<void> _confirmAndCompleteRide(BuildContext context, Map<String, dynamic>? ride) async {
    final destination = ride?['destination'] as Map<String, dynamic>?;
    final destAddress = destination?['address']?.toString() ?? 'the destination';
    final currentFare = (ride?['price'] as num?)?.toDouble() ?? 135.0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.flag_rounded, color: Color(0xFF219653)),
            SizedBox(width: 8),
            Text('Complete Ride?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
        content: Text(
          'Have you safely dropped off the passenger at $destAddress?\n\nFare to collect: ₹${currentFare.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF219653),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Confirm & Complete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final token = context.read<DriverCubit>().state.token;
      if (token == null) return;

      final result = await context.read<DriverPickupCubit>().completeTrip(token, finalFare: currentFare);
      if (result != null && mounted) {
        final completedRide = result['ride'] as Map<String, dynamic>?;
        final finalFare = (completedRide?['final_fare'] as num?)?.toDouble() ?? currentFare;
        final distanceKm = (completedRide?['distance_km'] as num?)?.toDouble() ?? 8.4;
        final durationMinutes = (completedRide?['duration_minutes'] as num?)?.toInt() ?? (_secondsElapsed ~/ 60);

        final passenger = ride?['passenger'] as Map<String, dynamic>?;
        final pickup = ride?['pickup'] as Map<String, dynamic>?;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => DriverTripCompletedScreen(
              rideId: widget.rideId,
              finalFare: finalFare,
              distanceKm: distanceKm,
              durationMinutes: durationMinutes,
              passengerName: passenger?['name']?.toString() ?? 'Passenger',
              pickupAddress: pickup?['address']?.toString() ?? 'Pickup Spot',
              destinationAddress: destAddress,
              paymentMethod: ride?['payment_method']?.toString() ?? 'Paid via UPI / Cash',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<DriverPickupCubit, DriverPickupState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: Palette.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state.isLoading) {
          return const Scaffold(
            backgroundColor: Color(0xFFF8F9FA),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Palette.primary),
                  SizedBox(height: 16),
                  Text(
                    'Loading active trip route...',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Palette.neutral),
                  ),
                ],
              ),
            ),
          );
        }

        final ride = state.rideData;
        final destination = ride?['destination'] as Map<String, dynamic>?;
        final passenger = ride?['passenger'] as Map<String, dynamic>?;

        final destLat = (destination?['lat'] as num?)?.toDouble() ?? 12.9352;
        final destLon = (destination?['lon'] as num?)?.toDouble() ?? 77.6245;
        final destLatLng = LatLng(destLat, destLon);

        final driverPos = state.driverLocation ?? LatLng(destLat - 0.015, destLon - 0.015);

        // Calculate live distance to destination
        final metersToDest = _distanceCalc.as(LengthUnit.Meter, driverPos, destLatLng);
        final distanceKmToDest = (metersToDest / 1000.0 * 10).round() / 10.0;

        if (!_hasInitialCentered) {
          _hasInitialCentered = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _fitBounds(driverPos, destLatLng);
          });
        }

        return Scaffold(
          body: Stack(
            children: [
              // 1. Live Interactive Map
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: destLatLng,
                  initialZoom: 14.0,
                ),
                children: [
                  MapService.instance.buildTileLayer(),
                  // Route Polyline towards destination
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: [driverPos, destLatLng],
                        strokeWidth: 5.0,
                        color: const Color(0xFF20A46B),
                        borderColor: Colors.white,
                        borderStrokeWidth: 2.0,
                      ),
                    ],
                  ),
                  // Markers: Live Driver & Destination
                  MarkerLayer(
                    markers: [
                      // Driver Vehicle Marker
                      Marker(
                        point: driverPos,
                        width: 52,
                        height: 52,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.directions_car_rounded,
                            color: Color(0xFF20A46B),
                            size: 28,
                          ),
                        ),
                      ),
                      // Destination Marker
                      Marker(
                        point: destLatLng,
                        width: 55,
                        height: 55,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Palette.error,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Tile attribution
              MapService.instance.buildAttributionWidget(context),

              // 2. Top Header Bar: Status Badge & Recenter
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      // Status Badge
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 12,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF20A46B),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'TRIP IN PROGRESS',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                  letterSpacing: 0.5,
                                  color: Color(0xFF20A46B),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                _formatDuration(_secondsElapsed),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: Palette.neutral,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Recenter Button
                      InkWell(
                        onTap: () => _fitBounds(driverPos, destLatLng),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.my_location_rounded, color: Palette.primary),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Cancel / Emergency Button
                      InkWell(
                        onTap: () => _navigateToCancelScreen(context, ride),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.close_rounded, color: Palette.error),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Bottom Sliding Card: Passenger Details & Trip Controls
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 25,
                        offset: const Offset(0, -6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Passenger Info & Call Button
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: Palette.primary.withValues(alpha: 0.15),
                            backgroundImage: passenger?['image_url'] != null &&
                                    passenger!['image_url'].toString().isNotEmpty
                                ? NetworkImage(passenger['image_url'].toString())
                                : null,
                            child: passenger?['image_url'] == null ||
                                    passenger!['image_url'].toString().isEmpty
                                ? const Icon(Icons.person, color: Palette.primary, size: 26)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  passenger?['name']?.toString() ?? 'Passenger',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: Palette.neutral,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Fare: ₹${ride?['price'] ?? 135.0} • Cash/UPI',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: () => context.read<DriverPickupCubit>().callPassenger(),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF219653).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFF219653).withValues(alpha: 0.3)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.call_rounded, color: Color(0xFF219653), size: 18),
                                  SizedBox(width: 6),
                                  Text(
                                    'Call',
                                    style: TextStyle(
                                      color: Color(0xFF219653),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                      const Divider(height: 1, color: Color(0xFFEBEBEB)),
                      const SizedBox(height: 14),

                      // Distance Remaining & Trip Duration Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF20A46B).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.navigation_rounded, color: Color(0xFF20A46B), size: 20),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Remaining Distance',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                  ),
                                  Text(
                                    '$distanceKmToDest km',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Palette.neutral,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFB800).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.timer_rounded, color: Color(0xFFD97706), size: 20),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Elapsed Time',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                  ),
                                  Text(
                                    _formatDuration(_secondsElapsed),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Palette.neutral,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Destination Address Highlight Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFEEEEEE)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(Icons.location_on_rounded, size: 18, color: Palette.error),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'HEADING TO DESTINATION',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                      color: Palette.error,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    destination?['address']?.toString() ?? 'Destination Spot',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Palette.neutral,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Action Buttons: Navigate & Complete Ride
                      Row(
                        children: [
                          // Turn-by-Turn Navigation Button
                          Expanded(
                            flex: 2,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                context.read<DriverPickupCubit>().launchNavigation(toDestination: true);
                              },
                              icon: const Icon(Icons.navigation_rounded, size: 20),
                              label: const Text(
                                'Navigate',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Palette.primary,
                                side: const BorderSide(color: Palette.primary, width: 1.8),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Complete Ride Button
                          Expanded(
                            flex: 3,
                            child: ElevatedButton.icon(
                              onPressed: state.isActionLoading
                                  ? null
                                  : () => _confirmAndCompleteRide(context, ride),
                              icon: const Icon(Icons.flag_rounded, color: Colors.white, size: 20),
                              label: state.isActionLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                    )
                                  : const Text(
                                      'Complete Ride',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                      ),
                                    ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF219653),
                                disabledBackgroundColor: const Color(0xFF219653).withValues(alpha: 0.6),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                      Center(
                        child: TextButton.icon(
                          onPressed: () => _navigateToCancelScreen(context, ride),
                          icon: const Icon(Icons.warning_amber_rounded, size: 16, color: Palette.error),
                          label: const Text(
                            'Cancel Trip (Emergency / Breakdown)',
                            style: TextStyle(
                              color: Palette.error,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _navigateToCancelScreen(BuildContext context, Map<String, dynamic>? ride) {
    final passenger = ride?['passenger'] as Map<String, dynamic>?;
    final pickup = ride?['pickup'] as Map<String, dynamic>?;
    final destination = ride?['destination'] as Map<String, dynamic>?;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<DriverPickupCubit>(),
          child: DriverCancelRideScreen(
            rideId: widget.rideId,
            passengerName: passenger?['name']?.toString() ?? 'Passenger',
            pickupAddress: pickup?['address']?.toString() ?? 'Pickup Point',
            destinationAddress: destination?['address']?.toString() ?? 'Destination Point',
            fare: '₹${ride?['price'] ?? 135.0}',
            currentStatus: 'started',
          ),
        ),
      ),
    );
  }
}

