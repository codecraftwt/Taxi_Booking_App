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
import 'package:saffar_app/features/driver/presenter/screens/ride_otp_verification_screen.dart';
import 'package:saffar_app/features/driver/presenter/screens/driver_active_trip_screen.dart';
import 'package:saffar_app/features/driver/presenter/screens/driver_cancel_ride_screen.dart';

class DriverPickupNavigationScreen extends StatefulWidget {
  const DriverPickupNavigationScreen({
    Key? key,
    required this.rideId,
  }) : super(key: key);

  static const String routeName = '/driver_pickup_navigation';
  final String rideId;

  @override
  State<DriverPickupNavigationScreen> createState() => _DriverPickupNavigationScreenState();
}

class _DriverPickupNavigationScreenState extends State<DriverPickupNavigationScreen> {
  final MapController _mapController = MapController();
  bool _hasInitialCentered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRideData();
    });
  }

  void _loadRideData() {
    final token = context.read<DriverCubit>().state.token;
    if (token != null) {
      context.read<DriverPickupCubit>().loadAssignedRide(token, widget.rideId);
    }
  }

  void _fitBounds(LatLng driverPos, LatLng pickupPos) {
    try {
      final bounds = LatLngBounds.fromPoints([driverPos, pickupPos]);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.only(top: 80, bottom: 320, left: 60, right: 60),
        ),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final token = context.watch<DriverCubit>().state.token ?? '';

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
        if (state.successMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.successMessage!),
              backgroundColor: const Color(0xFF219653),
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
                    'Loading assigned booking details...',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Palette.neutral),
                  ),
                ],
              ),
            ),
          );
        }

        if (state.status == DriverPickupStatus.error && state.rideData == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Assigned Ride'),
              backgroundColor: Colors.white,
              elevation: 0,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 64, color: Palette.error),
                    const SizedBox(height: 16),
                    Text(
                      state.errorMessage ?? 'Unable to retrieve assigned ride details.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: Palette.neutral),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _loadRideData,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Palette.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final ride = state.rideData;
        final pickup = ride?['pickup'] as Map<String, dynamic>?;
        final destination = ride?['destination'] as Map<String, dynamic>?;
        final passenger = ride?['passenger'] as Map<String, dynamic>?;

        final pickupLat = (pickup?['lat'] as num?)?.toDouble() ?? 16.7050;
        final pickupLon = (pickup?['lon'] as num?)?.toDouble() ?? 74.2433;
        final pickupLatLng = LatLng(pickupLat, pickupLon);

        final driverPos = state.driverLocation ?? LatLng(pickupLat - 0.008, pickupLon - 0.008);

        // Auto center map on first load
        if (!_hasInitialCentered) {
          _hasInitialCentered = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _fitBounds(driverPos, pickupLatLng);
          });
        }

        return Scaffold(
          body: Stack(
            children: [
              // 1. Live Interactive Map
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: pickupLatLng,
                  initialZoom: 14.5,
                ),
                children: [
                  MapService.instance.buildTileLayer(),
                  // Polyline between driver and pickup
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: [driverPos, pickupLatLng],
                        strokeWidth: 4.5,
                        color: Palette.primary,
                        borderColor: Colors.white,
                        borderStrokeWidth: 2.0,
                      ),
                    ],
                  ),
                  // Markers: Driver & Pickup
                  MarkerLayer(
                    markers: [
                      // Driver Marker
                      Marker(
                        point: driverPos,
                        width: 50,
                        height: 50,
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
                            color: Palette.primary,
                            size: 26,
                          ),
                        ),
                      ),
                      // Pickup Location Marker
                      Marker(
                        point: pickupLatLng,
                        width: 55,
                        height: 55,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF219653),
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
                                Icons.person_pin_circle_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Tile attribution
              MapService.instance.buildAttributionWidget(context),

              // 2. Top Header Bar: Status Badge & Back / Menu
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      // Back Button
                      InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          padding: const EdgeInsets.all(10),
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
                          child: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Status Badge Banner
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildStatusIndicator(state.bookingStatus),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _getStatusLabel(state.bookingStatus),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: _getStatusColor(state.bookingStatus),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Recenter / Fit Map Button
                      InkWell(
                        onTap: () => _fitBounds(driverPos, pickupLatLng),
                        child: Container(
                          padding: const EdgeInsets.all(10),
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

                      // Cancel Ride Button
                      InkWell(
                        onTap: () => _navigateToCancelScreen(context, state),
                        child: Container(
                          padding: const EdgeInsets.all(10),
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

              // 3. Bottom Sliding Card: Passenger & Pickup Details & Action Buttons
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
                      // Passenger Details Card
                      Row(
                        children: [
                          // Passenger Avatar
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: Palette.primary.withValues(alpha: 0.15),
                            backgroundImage: passenger?['image_url'] != null &&
                                    passenger!['image_url'].toString().isNotEmpty
                                ? NetworkImage(passenger['image_url'].toString())
                                : null,
                            child: passenger?['image_url'] == null ||
                                    passenger!['image_url'].toString().isEmpty
                                ? const Icon(Icons.person, color: Palette.primary, size: 28)
                                : null,
                          ),
                          const SizedBox(width: 14),

                          // Passenger Name & Rating
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  passenger?['name']?.toString() ?? 'Passenger',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Palette.neutral,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.star_rounded, size: 16, color: Color(0xFFFFB800)),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${passenger?['rating'] ?? 4.9} • Verified Rider',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Call Passenger Button
                          InkWell(
                            onTap: () => context.read<DriverPickupCubit>().callPassenger(),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF219653).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFF219653).withValues(alpha: 0.3),
                                ),
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

                      const SizedBox(height: 18),
                      const Divider(height: 1, color: Color(0xFFEBEBEB)),
                      const SizedBox(height: 14),

                      // Distance & ETA Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Palette.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.near_me_rounded, color: Palette.primary, size: 20),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Distance to Pickup',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    '${state.distanceToPickupKm ?? 1.2} km away',
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
                                child: const Icon(Icons.access_time_rounded, color: Color(0xFFD97706), size: 20),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Est. Arrival',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    '${state.etaMinutes ?? 4} mins',
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

                      // Pickup & Destination Address
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFEEEEEE)),
                        ),
                        child: Column(
                          children: [
                            // Pickup
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Icon(Icons.trip_origin_rounded, size: 16, color: Color(0xFF219653)),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'PICKUP LOCATION',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                          color: Color(0xFF219653),
                                        ),
                                      ),
                                      Text(
                                        pickup?['address']?.toString() ?? 'Pickup Point',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
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
                            const Padding(
                              padding: EdgeInsets.only(left: 7),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: SizedBox(
                                  height: 12,
                                  child: VerticalDivider(width: 2, color: Colors.grey),
                                ),
                              ),
                            ),
                            // Destination
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Icon(Icons.location_on_rounded, size: 16, color: Palette.error),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'DESTINATION',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                          color: Palette.error,
                                        ),
                                      ),
                                      Text(
                                        destination?['address']?.toString() ?? 'Destination Point',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
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

                      const SizedBox(height: 16),

                      // If Trip Started: Show In-Progress Banner
                      if (state.isTripStarted) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF20A46B).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF20A46B).withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.directions_car_rounded, color: Color(0xFF20A46B), size: 22),
                              SizedBox(width: 8),
                              Text(
                                '🎉 Trip In Progress • En route to destination',
                                style: TextStyle(
                                  color: Color(0xFF20A46B),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ] else if (state.hasArrived) ...[
                        // If Arrived: Show OTP Prompt Banner
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF219653).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF219653).withValues(alpha: 0.3)),
                          ),
                          child: const Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle_rounded, color: Color(0xFF219653), size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Arrived at Pickup Spot',
                                    style: TextStyle(
                                      color: Color(0xFF219653),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Ask passenger for their 4-digit Start-Trip OTP to verify & begin.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Palette.neutral,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Action Buttons: Navigation / Arrived / Enter OTP
                      if (state.isTripStarted) ...[
                        Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => BlocProvider.value(
                                        value: context.read<DriverPickupCubit>(),
                                        child: DriverActiveTripScreen(rideId: widget.rideId),
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.directions_car_rounded, color: Colors.white),
                                label: const Text(
                                  'Go to Active Trip',
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF20A46B),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 0,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  context.read<DriverPickupCubit>().launchNavigation(toDestination: true);
                                },
                                icon: const Icon(Icons.navigation_rounded, color: Color(0xFF20A46B)),
                                label: const Text(
                                  'Turn-by-turn Google Maps',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF20A46B)),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFF20A46B), width: 1.5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else if (state.hasArrived) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BlocProvider.value(
                                    value: context.read<DriverPickupCubit>(),
                                    child: RideOtpVerificationScreen(
                                      rideId: widget.rideId,
                                      passengerName: passenger?['name']?.toString() ?? 'Passenger',
                                      pickupAddress: pickup?['address']?.toString() ?? 'Pickup Spot',
                                      fare: '₹${ride?['price'] ?? 135.0}',
                                    ),
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.pin_rounded, color: Colors.white),
                            label: const Text(
                              'Enter Passenger OTP to Start Trip',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF219653),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            // Turn-by-Turn Navigation Button
                            Expanded(
                              flex: 2,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  context.read<DriverPickupCubit>().launchNavigation(token: token);
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

                            // Arrived at Pickup Button
                            Expanded(
                              flex: 3,
                              child: ElevatedButton(
                                onPressed: state.isActionLoading
                                    ? null
                                    : () {
                                        context.read<DriverPickupCubit>().arriveAtPickup(token);
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF219653),
                                  disabledBackgroundColor: const Color(0xFF219653).withValues(alpha: 0.6),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 0,
                                ),
                                child: state.isActionLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                      )
                                    : const Text(
                                        'Arrived at Pickup',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 12),
                      Center(
                        child: TextButton.icon(
                          onPressed: () => _navigateToCancelScreen(context, state),
                          icon: const Icon(Icons.cancel_outlined, size: 16, color: Palette.error),
                          label: const Text(
                            'Cancel Ride',
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

  Widget _buildStatusIndicator(String status) {
    Color color;
    switch (status) {
      case 'started':
      case 'in_progress':
        color = const Color(0xFF20A46B);
        break;
      case 'arrived':
        color = const Color(0xFF219653);
        break;
      case 'reaching_pickup':
        color = const Color(0xFF0284C7);
        break;
      case 'accepted':
      default:
        color = const Color(0xFFF59E0B);
        break;
    }

    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'started':
      case 'in_progress':
        return 'Trip In Progress';
      case 'arrived':
        return 'Driver Arrived at Pickup';
      case 'reaching_pickup':
        return 'Driver Reaching Pickup';
      case 'accepted':
      default:
        return 'Driver Assigned';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'started':
      case 'in_progress':
        return const Color(0xFF20A46B);
      case 'arrived':
        return const Color(0xFF219653);
      case 'reaching_pickup':
        return const Color(0xFF0284C7);
      case 'accepted':
      default:
        return const Color(0xFFB45309);
    }
  }

  void _navigateToCancelScreen(BuildContext context, DriverPickupState state) {
    final ride = state.rideData?['ride'] as Map<String, dynamic>?;
    final passenger = state.rideData?['passenger'] as Map<String, dynamic>?;
    final pickup = state.rideData?['pickup'] as Map<String, dynamic>?;
    final destination = state.rideData?['destination'] as Map<String, dynamic>?;

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
            currentStatus: state.bookingStatus,
          ),
        ),
      ),
    );
  }
}

