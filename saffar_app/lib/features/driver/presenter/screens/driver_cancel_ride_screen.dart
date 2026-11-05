import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:saffar_app/core/palette.dart';
import 'package:saffar_app/features/driver/presenter/cubits/driver_cubit.dart';
import 'package:saffar_app/features/driver/presenter/cubits/driver_pickup_cubit.dart';
import 'package:saffar_app/features/driver/presenter/cubits/driver_pickup_state.dart';
import 'package:saffar_app/features/driver/presenter/screens/driver_cancellation_success_screen.dart';

class DriverCancelRideScreen extends StatefulWidget {
  const DriverCancelRideScreen({
    Key? key,
    required this.rideId,
    this.passengerName = 'Passenger',
    this.pickupAddress = '',
    this.destinationAddress = '',
    this.fare = '',
    this.currentStatus = 'accepted',
  }) : super(key: key);

  static const String routeName = '/driver_cancel_ride';

  final String rideId;
  final String passengerName;
  final String pickupAddress;
  final String destinationAddress;
  final String fare;
  final String currentStatus;

  @override
  State<DriverCancelRideScreen> createState() => _DriverCancelRideScreenState();
}

class _DriverCancelRideScreenState extends State<DriverCancelRideScreen> {
  final TextEditingController _notesController = TextEditingController();
  String? _selectedReason;
  bool _isSubmitting = false;

  final List<String> _cancellationReasons = const [
    'Customer did not show up',
    'Vehicle issue / breakdown',
    'Customer requested cancellation',
    'Accident / Emergency',
    'Cannot reach pickup location',
    'Incorrect pickup location',
    'Other',
  ];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _showConfirmDialog() {
    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a cancellation reason before proceeding.'),
          backgroundColor: Palette.error,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Palette.error, size: 28),
            SizedBox(width: 10),
            Text(
              'Confirm Cancellation',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to cancel this ride? The passenger will be notified immediately.',
              style: TextStyle(fontSize: 14, color: Palette.neutral),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFEEEEEE)),
              ),
              child: Text(
                'Reason: $_selectedReason',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Palette.neutral),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Keep Ride', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              _submitCancellation();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Palette.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Yes, Cancel Ride', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _submitCancellation() async {
    final token = context.read<DriverCubit>().state.token;
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Driver authentication missing.'), backgroundColor: Palette.error),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final success = await context.read<DriverPickupCubit>().cancelRide(
          token,
          reason: _selectedReason!,
          notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      final state = context.read<DriverPickupCubit>().state;
      final cancelData = state.cancellationData;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DriverCancellationSuccessScreen(
            rideId: widget.rideId,
            reason: _selectedReason!,
            notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
            passengerName: widget.passengerName,
            pickupAddress: widget.pickupAddress,
            cancelledAt: cancelData?['cancelled_at']?.toString(),
          ),
        ),
      );
    } else {
      final error = context.read<DriverPickupCubit>().state.errorMessage ?? 'Failed to cancel ride.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Palette.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<DriverPickupCubit, DriverPickupState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!), backgroundColor: Palette.error),
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: const Text(
            'Cancel Ride',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          backgroundColor: Colors.white,
          elevation: 0.5,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Palette.neutral),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ride Overview Card
                Container(
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
                                radius: 20,
                                backgroundColor: Palette.primary.withValues(alpha: 0.12),
                                child: const Icon(Icons.person, color: Palette.primary, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.passengerName,
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                  ),
                                  Text(
                                    'Ride ID: ${widget.rideId}',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF219653).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              widget.fare,
                              style: const TextStyle(
                                color: Color(0xFF219653),
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
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
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.pickupAddress,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Palette.neutral),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on_rounded, size: 16, color: Palette.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.destinationAddress,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Palette.neutral),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Reasons Section Title
                const Text(
                  'Select Cancellation Reason',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Palette.neutral,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Choose the primary reason for cancelling this trip. Saffar uses this to improve ride matching.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),

                const SizedBox(height: 16),

                // Reasons Radio List
                Container(
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
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Column(
                      children: _cancellationReasons.map((reason) {
                        final isSelected = _selectedReason == reason;
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedReason = reason;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? Palette.error.withValues(alpha: 0.05) : Colors.transparent,
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.grey.withValues(alpha: 0.15),
                                  width: 0.8,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                  color: isSelected ? Palette.error : Colors.grey.shade400,
                                  size: 20,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    reason,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                      color: isSelected ? Palette.error : Palette.neutral,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Optional Notes
                const Text(
                  'Additional Notes (Optional)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Palette.neutral,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _notesController,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Describe what happened (e.g., flat tire, customer no-show after calling)...',
                      hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Palette.primary, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Action Buttons
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: (_isSubmitting || _selectedReason == null) ? null : _showConfirmDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Palette.error,
                      disabledBackgroundColor: Colors.grey.shade300,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Text(
                            'Cancel Ride',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Don\'t Cancel, Return to Trip',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Colors.grey,
                      ),
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
}

