import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:saffar_app/core/models/ride_request.dart';
import 'package:saffar_app/core/palette.dart';
import 'package:saffar_app/features/driver/presenter/cubits/driver_cubit.dart';
import 'package:saffar_app/features/driver/presenter/cubits/ride_request_cubit.dart';
import 'package:saffar_app/features/driver/presenter/screens/driver_pickup_navigation_screen.dart';
import 'package:saffar_app/features/driver/presenter/screens/ride_request_details_screen.dart';

class IncomingRideRequestDialog extends StatefulWidget {
  const IncomingRideRequestDialog({
    Key? key,
    required this.request,
  }) : super(key: key);

  final RideRequest request;

  static Future<void> show(BuildContext context, RideRequest request) async {
    await showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => IncomingRideRequestDialog(request: request),
    );
  }

  @override
  State<IncomingRideRequestDialog> createState() => _IncomingRideRequestDialogState();
}

class _IncomingRideRequestDialogState extends State<IncomingRideRequestDialog> with SingleTickerProviderStateMixin {
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
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            context.read<RideRequestCubit>().dismissActiveRequest();
            Navigator.of(context).pop();
          }
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

  Future<void> _onAccept() async {
    _countdownTimer?.cancel();
    final token = context.read<DriverCubit>().state.token;
    if (token == null) return;

    final acceptedRide = await context.read<RideRequestCubit>().acceptRide(token, widget.request.rideId);
    if (!mounted) return;

    if (acceptedRide != null) {
      Navigator.of(context).pop(); // Dismiss bottom sheet
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Ride accepted! Navigating to pickup...'),
          backgroundColor: Color(0xFF219653),
        ),
      );

      // Navigate to driver pickup navigation screen
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
    final progress = _remainingSeconds / 45.0;

    return BlocListener<RideRequestCubit, RideRequestState>(
      listener: (context, state) {
        if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.error!), backgroundColor: Palette.error),
          );
          Navigator.of(context).pop();
        }
      },
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 25,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Vehicle badge & Circular Countdown Timer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Palette.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Palette.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.flash_on_rounded, size: 16, color: Palette.primary),
                      const SizedBox(width: 6),
                      Text(
                        'NEW RIDE REQUEST • ${req.vehicleType.toUpperCase()}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Palette.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                // Circular Timer
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 4,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _remainingSeconds <= 10 ? const Color(0xFFE5484D) : const Color(0xFF219653),
                        ),
                      ),
                    ),
                    Text(
                      '$_remainingSeconds',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: _remainingSeconds <= 10 ? const Color(0xFFE5484D) : const Color(0xFF1A1A2E),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Passenger Info Row
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Palette.primary.withValues(alpha: 0.12),
                  backgroundImage: (req.passengerImage != null && req.passengerImage!.isNotEmpty)
                      ? NetworkImage(req.passengerImage!)
                      : null,
                  child: req.passengerImage == null
                      ? const Icon(Icons.person, color: Palette.primary, size: 28)
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
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.near_me_rounded, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            req.distanceToPickup,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '•  ${req.estimatedDistance} trip',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF219653).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '₹${req.fare.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF219653),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // Route Points
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    const Icon(Icons.circle, color: Color(0xFF219653), size: 12),
                    Container(width: 2, height: 28, color: Colors.grey.shade300),
                    const Icon(Icons.square, color: Color(0xFFE5484D), size: 12),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        req.pickupAddress,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        req.destinationAddress,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Full Route Map Preview Link
            Center(
              child: TextButton.icon(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    RideRequestDetailsScreen.routeName,
                    arguments: req,
                  );
                },
                icon: const Icon(Icons.map_outlined, size: 16),
                label: const Text('View Full Route on Map', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ),
            const SizedBox(height: 8),

            // Expired Banner
            if (_isExpired) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5484D).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'Request Expired',
                    style: TextStyle(color: Color(0xFFE5484D), fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ] else ...[
              // Action Buttons: Reject & Accept
              BlocBuilder<RideRequestCubit, RideRequestState>(
                builder: (context, state) {
                  final isActionLoading = state.isActionLoading;

                  return Row(
                    children: [
                      // Decline Button
                      Expanded(
                        flex: 2,
                        child: OutlinedButton(
                          onPressed: isActionLoading ? null : _onReject,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                            side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Decline', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Accept Button
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
          ],
        ),
      ),
    );
  }
}

