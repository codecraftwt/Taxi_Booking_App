import 'package:flutter/material.dart';
import 'package:saffar_app/core/palette.dart';
import 'package:saffar_app/features/driver/presenter/screens/driver_shell_screen.dart';

class DriverTripCompletedScreen extends StatelessWidget {
  const DriverTripCompletedScreen({
    Key? key,
    required this.rideId,
    required this.finalFare,
    required this.distanceKm,
    required this.durationMinutes,
    this.passengerName = 'Passenger',
    this.pickupAddress = 'Pickup Point',
    this.destinationAddress = 'Destination Point',
    this.paymentMethod = 'Paid via UPI / Cash',
  }) : super(key: key);

  static const String routeName = '/driver_trip_completed';

  final String rideId;
  final double finalFare;
  final double distanceKm;
  final int durationMinutes;
  final String passengerName;
  final String pickupAddress;
  final String destinationAddress;
  final String paymentMethod;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _returnToDashboard(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 16),

                // Success Badge Animation
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF219653).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 52,
                      color: Color(0xFF219653),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                const Text(
                  'Trip Completed!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Palette.neutral,
                  ),
                ),
                const SizedBox(height: 6),

                Text(
                  'Great job! The fare has been credited to your earnings.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),

                const SizedBox(height: 28),

                // Big Fare Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'TOTAL FARE COLLECTED',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '₹${finalFare.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF219653),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Palette.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          paymentMethod,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Palette.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Trip Metrics Row (Distance & Duration)
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.straighten_rounded, color: Palette.primary, size: 24),
                            const SizedBox(height: 8),
                            Text(
                              '${distanceKm.toStringAsFixed(1)} km',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Palette.neutral,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Total Distance',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.timer_rounded, color: Color(0xFFD97706), size: 24),
                            const SizedBox(height: 8),
                            Text(
                              '$durationMinutes mins',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Palette.neutral,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Total Duration',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Route & Passenger Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    children: [
                      // Passenger
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: Palette.primary.withValues(alpha: 0.15),
                            child: const Icon(Icons.person, color: Palette.primary, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            passengerName,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Divider(height: 1, color: Color(0xFFEEEEEE)),
                      const SizedBox(height: 14),

                      // Pickup
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.trip_origin_rounded, size: 16, color: Color(0xFF219653)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              pickupAddress,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.only(left: 7),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(height: 10, child: VerticalDivider(width: 2, color: Colors.grey)),
                        ),
                      ),
                      // Drop
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on_rounded, size: 16, color: Palette.error),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              destinationAddress,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Back to Dashboard / Next Ride Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () => _returnToDashboard(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Palette.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.home_rounded, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Back to Dashboard',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _returnToDashboard(BuildContext context) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      DriverShellScreen.routeName,
      (route) => false,
    );
  }
}

