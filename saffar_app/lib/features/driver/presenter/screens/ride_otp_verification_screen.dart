import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:saffar_app/core/palette.dart';
import 'package:saffar_app/features/driver/presenter/cubits/driver_cubit.dart';
import 'package:saffar_app/features/driver/presenter/cubits/driver_pickup_cubit.dart';
import 'package:saffar_app/features/driver/presenter/cubits/driver_pickup_state.dart';
import 'package:saffar_app/features/driver/presenter/screens/driver_active_trip_screen.dart';

class RideOtpVerificationScreen extends StatefulWidget {
  const RideOtpVerificationScreen({
    Key? key,
    required this.rideId,
    this.passengerName = 'Passenger',
    this.pickupAddress = '',
    this.fare = '',
  }) : super(key: key);

  static const String routeName = '/ride_otp_verification';

  final String rideId;
  final String passengerName;
  final String pickupAddress;
  final String fare;

  @override
  State<RideOtpVerificationScreen> createState() => _RideOtpVerificationScreenState();
}

class _RideOtpVerificationScreenState extends State<RideOtpVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  String _errorMessage = '';

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _enteredOtp => _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    setState(() {
      _errorMessage = '';
    });

    if (value.length == 1 && index < 3) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    if (_enteredOtp.length == 4) {
      _submitOtp();
    }
  }

  Future<void> _submitOtp() async {
    final otp = _enteredOtp.trim();
    if (otp.length != 4) {
      setState(() {
        _errorMessage = 'Please enter all 4 digits of the passenger OTP.';
      });
      return;
    }

    final token = context.read<DriverCubit>().state.token;
    if (token == null) return;

    final success = await context.read<DriverPickupCubit>().verifyOtpAndStartTrip(token, otp);
    if (!mounted) return;

    if (success) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => BlocProvider.value(
            value: context.read<DriverPickupCubit>(),
            child: DriverActiveTripScreen(rideId: widget.rideId),
          ),
        ),
      );
    } else {
      // Clear inputs for retry
      for (var c in _controllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<DriverPickupCubit, DriverPickupState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          setState(() {
            _errorMessage = state.errorMessage!;
          });
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: const Text(
            'Start Trip Verification',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Palette.neutral),
          ),
          backgroundColor: Colors.white,
          elevation: 0.5,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Palette.neutral),
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),

              // Shield Icon & Security Headline
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Palette.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.security_rounded,
                    size: 38,
                    color: Palette.primary,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'Enter Passenger OTP',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Palette.neutral,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                'Ask ${widget.passengerName} for the 4-digit code shown on their Saffar app to confirm their ride and start the trip.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 28),

              // Passenger & Trip Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
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
                      radius: 22,
                      backgroundColor: Palette.primary.withValues(alpha: 0.15),
                      child: const Icon(Icons.person, color: Palette.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.passengerName,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.pickupAddress,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF219653).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        widget.fare,
                        style: const TextStyle(
                          color: Color(0xFF219653),
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // 4 Individual OTP Digit Input Boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(4, (index) {
                  return SizedBox(
                    width: 64,
                    height: 68,
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      autofocus: index == 0,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Palette.neutral,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Palette.primary, width: 2.2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: _controllers[index].text.isNotEmpty
                                ? Palette.primary
                                : Colors.grey.shade300,
                            width: 1.5,
                          ),
                        ),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      onChanged: (val) => _onDigitChanged(index, val),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 20),

              // Error Banner (if any)
              if (_errorMessage.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF87171)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Palette.error, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage,
                          style: const TextStyle(
                            color: Palette.error,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 36),

              // Submit & Verify Button
              BlocBuilder<DriverPickupCubit, DriverPickupState>(
                builder: (context, state) {
                  return SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: state.isActionLoading ? null : _submitOtp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF219653),
                        disabledBackgroundColor: const Color(0xFF219653).withValues(alpha: 0.6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: state.isActionLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                  'Verify OTP & Start Trip',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // Return to Navigation button
              TextButton.icon(
                onPressed: () => Navigator.of(context).pop(false),
                icon: const Icon(Icons.arrow_back_rounded, size: 18, color: Colors.grey),
                label: const Text(
                  'Return to Pickup Screen',
                  style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

