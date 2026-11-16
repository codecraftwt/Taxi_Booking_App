import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:saffar_app/core/config/map_config.dart';
import 'package:saffar_app/core/models/ride_request.dart';
import 'package:saffar_app/core/palette.dart';
import 'package:saffar_app/features/driver/presenter/cubits/driver_cubit.dart';
import 'package:saffar_app/features/driver/presenter/cubits/ride_request_cubit.dart';
import 'package:saffar_app/features/driver/presenter/screens/driver_pickup_navigation_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class RideRequestDetailsScreen extends StatefulWidget {
  const RideRequestDetailsScreen({
    Key? key,
    required this.request,
  }) : super(key: key);

  static const String routeName = '/ride_request_details';

  final RideRequest request;

  @override
  State<RideRequestDetailsScreen> createState() => _RideRequestDetailsScreenState();
}

class _RideRequestDetailsScreenState extends State<RideRequestDetailsScreen> {
  late int _remainingSeconds;
  Timer? _countdownTimer;
  bool _isExpired = false;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.request.secondsLeft > 0 ? widget.request.secondsLeft : 45;
    _startTimer();
  }

  void _startTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds <= 1) {
        timer.cancel();
        setState(() {
          _remainingSeconds = 0;
          _isExpired = true;
        });
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _makePhoneCall(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final Uri url = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _onAccept() async {
    _countdownTimer?.cancel();
    final token = context.read<DriverCubit>().state.token;
    if (token == null) return;

    final acceptedRide = await context.read<RideRequestCubit>().acceptRide(token, widget.request.rideId);
    if (!mounted) return;

    if (acceptedRide != null) {
      Navigator.of(context).pop(); // pop details screen
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Ride accepted! Navigating to pickup...'),
          backgroundColor: Color(0xFF219653),
        ),
      );

      Navigator.pushNamed(
        context,
        DriverPickupNavigationScreen.routeName,
        arguments: {
          'ride_id': widget.request.rideId,
        },
      );
    }
  }

  Future<void> _onReject() async {
    _countdownTimer?.cancel();
    final token = context.read<DriverCubit>().state.token;
    if (token != null) {
      context.read<RideRequestCubit>().rejectRide(token, widget.request.rideId);
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.request;
    final pickupPoint = LatLng(
      req.pickupLat ?? MapConfig.defaultCenter.latitude,
      req.pickupLon ?? MapConfig.defaultCenter.longitude,
    );
    final dropPoint = LatLng(
      req.destinationLat ?? MapConfig.defaultCenter.latitude,
      req.destinationLon ?? MapConfig.defaultCenter.longitude,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Ride Request Details', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A2E)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Countdown Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: _remainingSeconds <= 10 ? const Color(0xFFE5484D).withValues(alpha: 0.1) : Palette.primary.withValues(alpha: 0.08),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 18,
                    color: _remainingSeconds <= 10 ? const Color(0xFFE5484D) : Palette.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isExpired ? 'Request Expired' : 'Expires in $_remainingSeconds seconds',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _remainingSeconds <= 10 ? const Color(0xFFE5484D) : Palette.primary,
                    ),
                  ),
                ],
              ),
            ),

            // Map Route Preview
            Expanded(
              flex: 4,
              child: Stack(
                children: [
                  FlutterMap(
                    options: MapOptions(
                      initialCenter: pickupPoint,
                      initialZoom: 13.5,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.saffar_app',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: pickupPoint,
                            width: 36,
                            height: 36,
                            child: const Icon(Icons.location_on, color: Color(0xFF219653), size: 36),
                          ),
                          Marker(
                            point: dropPoint,
                            width: 36,
                            height: 36,
                            child: const Icon(Icons.location_on, color: Color(0xFFE5484D), size: 36),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                      ),
                      child: Text(
                        '${req.distanceToPickup} • ${req.estimatedDistance} trip',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Passenger & Trip Info Card
            Expanded(
              flex: 5,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Passenger Row
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: Palette.primary.withValues(alpha: 0.12),
                          backgroundImage: (req.passengerImage != null && req.passengerImage!.isNotEmpty)
                              ? NetworkImage(req.passengerImage!)
                              : null,
                          child: req.passengerImage == null
                              ? const Icon(Icons.person, color: Palette.primary, size: 30)
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                req.passengerName,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E)),
                              ),
                              Text(
                                'Passenger • ${req.vehicleType}',
                                style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        if (req.passengerPhone != null && req.passengerPhone!.isNotEmpty)
                          IconButton(
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF219653).withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.phone_rounded, color: Color(0xFF219653), size: 20),
                            ),
                            onPressed: () => _makePhoneCall(req.passengerPhone),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Divider(height: 1),
                    const SizedBox(height: 16),

                    // Pickup Address
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.radio_button_checked, color: Color(0xFF219653), size: 18),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('PICKUP LOCATION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                              const SizedBox(height: 2),
                              Text(req.pickupAddress, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Destination Address
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on, color: Color(0xFFE5484D), size: 18),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('DESTINATION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                              const SizedBox(height: 2),
                              Text(req.destinationAddress, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Fare Box
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Total Estimated Fare', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                              Text('Cash / Wallet Included', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                          Text(
                            '₹${req.fare.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF219653)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Action Buttons
                    BlocBuilder<RideRequestCubit, RideRequestState>(
                      builder: (context, state) {
                        final isActionLoading = state.isActionLoading;

                        if (_isExpired) {
                          return SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade400),
                              child: const Text('Back to Home', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          );
                        }

                        return Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: OutlinedButton(
                                onPressed: isActionLoading ? null : _onReject,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                child: const Text('Decline', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.grey)),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 3,
                              child: ElevatedButton(
                                onPressed: isActionLoading ? null : _onAccept,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF219653),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 0,
                                ),
                                child: isActionLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                      )
                                    : const Text(
                                        'Accept Ride',
                                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white),
                                      ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

