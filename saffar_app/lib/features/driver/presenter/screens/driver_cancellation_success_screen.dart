import 'package:flutter/material.dart';
import 'package:saffar_app/core/palette.dart';
import 'package:saffar_app/features/driver/presenter/screens/driver_shell_screen.dart';

class DriverCancellationSuccessScreen extends StatelessWidget {
  const DriverCancellationSuccessScreen({
    Key? key,
    required this.rideId,
    required this.reason,
    this.notes,
    this.passengerName = 'Passenger',
    this.pickupAddress = 'Pickup Point',
    this.cancelledAt,
  }) : super(key: key);

  static const String routeName = '/driver_cancellation_success';

  final String rideId;
  final String reason;
  final String? notes;
  final String passengerName;
  final String pickupAddress;
  final String? cancelledAt;

  void _returnToDashboard(BuildContext context) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      DriverShellScreen.routeName,
      (route) => false,
    );
  }

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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 30),

                // Cancellation Icon Emblem
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: Palette.error.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.cancel_rounded,
                      size: 52,
                      color: Palette.error,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  'Ride Cancelled',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Palette.neutral,
                    letterSpacing: -0.5,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'The ride booking has been cancelled and the passenger has been notified.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 28),

                // Eligibility Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF219653).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF219653).withValues(alpha: 0.25)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: Color(0xFF219653), size: 28),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ready for Next Ride',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF219653),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'You remain online and eligible to receive new ride dispatches.',
                              style: TextStyle(fontSize: 12, color: Palette.neutral),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Cancellation Details Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CANCELLATION SUMMARY',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 16),

                      _buildSummaryRow('Ride ID', rideId),
                      const Divider(height: 20, color: Color(0xFFEEEEEE)),

                      _buildSummaryRow('Passenger', passengerName),
                      const Divider(height: 20, color: Color(0xFFEEEEEE)),

                      _buildSummaryRow('Pickup', pickupAddress),
                      const Divider(height: 20, color: Color(0xFFEEEEEE)),

                      _buildSummaryRow(
                        'Reason',
                        reason,
                        valueColor: Palette.error,
                        isBold: true,
                      ),

                      if (notes != null && notes!.isNotEmpty) ...[
                        const Divider(height: 20, color: Color(0xFFEEEEEE)),
                        _buildSummaryRow('Notes', notes!),
                      ],

                      const Divider(height: 20, color: Color(0xFFEEEEEE)),
                      _buildSummaryRow(
                        'Status',
                        'Cancelled by Driver',
                        valueColor: Palette.error,
                        isBold: true,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 36),

                // Return to Dashboard Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => _returnToDashboard(context),
                    icon: const Icon(Icons.home_rounded, color: Colors.white),
                    label: const Text(
                      'Back to Dashboard',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Palette.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? valueColor, bool isBold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: valueColor ?? Palette.neutral,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

