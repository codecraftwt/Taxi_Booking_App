import 'package:flutter/material.dart';
import 'package:saffar_app/core/palette.dart';

class DriverTripEarningDetailsScreen extends StatelessWidget {
  const DriverTripEarningDetailsScreen({
    Key? key,
    required this.rideId,
    required this.bookingId,
    required this.tripDate,
    required this.grossFare,
    required this.platformCommission,
    required this.commissionRate,
    required this.netEarnings,
    this.otherDeductions = 0.0,
    this.distanceKm = 0.0,
    this.durationMinutes = 0,
    this.paymentStatus = 'Paid',
    this.paymentMethod = 'Paid via UPI',
    this.pickupAddress = 'Pickup Point',
    this.destinationAddress = 'Destination Point',
    this.passengerName = 'Passenger',
    this.vehicleType = 'Saffar Auto',
  }) : super(key: key);

  static const String routeName = '/driver_trip_earning_details';

  final String rideId;
  final String bookingId;
  final String tripDate;
  final double grossFare;
  final double platformCommission;
  final double commissionRate;
  final double otherDeductions;
  final double netEarnings;
  final double distanceKm;
  final int durationMinutes;
  final String paymentStatus;
  final String paymentMethod;
  final String pickupAddress;
  final String destinationAddress;
  final String passengerName;
  final String vehicleType;

  @override
  Widget build(BuildContext context) {
    final commissionPercent = (commissionRate * 100).toInt();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Trip Earnings Receipt',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Palette.neutral),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Badge & Net Earnings Highlight
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'BOOKING #$bookingId',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            paymentStatus.toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFF4ADE80),
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'YOUR NET TAKE-HOME',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${netEarnings.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.white60),
                        const SizedBox(width: 6),
                        Text(
                          tripDate,
                          style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Route & Ride Details Card
              Container(
                width: double.infinity,
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
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: Palette.primary.withValues(alpha: 0.15),
                              child: const Icon(Icons.person, color: Palette.primary, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  passengerName,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                ),
                                Text(
                                  vehicleType,
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (distanceKm > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${distanceKm.toStringAsFixed(1)} km • ${durationMinutes}m',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Palette.neutral,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: Color(0xFFEEEEEE)),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.trip_origin_rounded, size: 16, color: Color(0xFF219653)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            pickupAddress,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Palette.neutral),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on_rounded, size: 16, color: Palette.error),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            destinationAddress,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Palette.neutral),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Itemized Fare & Deductions Breakdown
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
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
                      'ACCOUNTING & EARNINGS BREAKDOWN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Gross Fare
                    _buildAccountingRow(
                      'Gross Fare (Paid by Rider)',
                      '₹${grossFare.toStringAsFixed(2)}',
                      isBold: true,
                    ),
                    const Divider(height: 18, color: Color(0xFFEEEEEE)),

                    // Platform Commission
                    _buildAccountingRow(
                      'Platform Commission ($commissionPercent%)',
                      '- ₹${platformCommission.toStringAsFixed(2)}',
                      valueColor: const Color(0xFFD97706),
                    ),

                    if (otherDeductions > 0) ...[
                      const Divider(height: 18, color: Color(0xFFEEEEEE)),
                      _buildAccountingRow(
                        'Taxes / Deductions',
                        '- ₹${otherDeductions.toStringAsFixed(2)}',
                        valueColor: const Color(0xFFDC2626),
                      ),
                    ],

                    const Divider(height: 20, thickness: 1.2, color: Color(0xFFE2E8F0)),

                    // Driver Net
                    _buildAccountingRow(
                      'Driver Net Earnings',
                      '₹${netEarnings.toStringAsFixed(2)}',
                      valueColor: const Color(0xFF16A34A),
                      isBold: true,
                      fontSize: 16,
                    ),

                    const Divider(height: 20, color: Color(0xFFEEEEEE)),

                    // Payment Method & Status
                    _buildAccountingRow(
                      'Payment Method',
                      paymentMethod,
                    ),
                    const SizedBox(height: 10),
                    _buildAccountingRow(
                      'Settlement Status',
                      paymentStatus,
                      valueColor: const Color(0xFF16A34A),
                      isBold: true,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Help / Audit Note
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined, color: Colors.blueGrey, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'All ride fares and commissions are calculated securely according to Saffar driver partner terms.',
                        style: TextStyle(fontSize: 12, color: Colors.blueGrey, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountingRow(
    String label,
    String value, {
    Color? valueColor,
    bool isBold = false,
    double fontSize = 14,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize - 1,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: isBold ? Palette.neutral : Colors.grey.shade700,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
            color: valueColor ?? Palette.neutral,
          ),
        ),
      ],
    );
  }
}

