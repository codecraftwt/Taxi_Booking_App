import 'package:flutter/material.dart';
import 'package:saffar_app/core/models/driver.dart';
import 'package:saffar_app/core/palette.dart';
import 'package:saffar_app/features/find_ride/presenter/cubits/ride_driver_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RideDriverInfoWidget extends StatelessWidget {
  const RideDriverInfoWidget({
    Key? key,
    required this.driver,
    required this.onCancelRidePressed,
    this.otp = '4829',
    this.pickupSpot = 'Pickup Point',
    this.rideFare = 78.50,
    this.rideType = 'Auto Smart Ride',
  }) : super(key: key);

  final Driver driver;
  final Function() onCancelRidePressed;
  final String otp;
  final String pickupSpot;
  final double rideFare;
  final String rideType;

  void _showChatDialog(BuildContext context) {
    final TextEditingController textController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage: NetworkImage(
                    driver.imageUrl ??
                        'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?w=150',
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const Text('Driver is driving safely', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 10),
            // Quick message chips
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text("I'm waiting at Gate 2"),
                  onPressed: () => textController.text = "I'm waiting at Gate 2",
                ),
                ActionChip(
                  label: const Text('Coming down in 1 min'),
                  onPressed: () => textController.text = 'Coming down in 1 min',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: textController,
                    decoration: InputDecoration(
                      hintText: 'Message driver...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: Palette.primary),
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Message sent to driver')),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSafetyToolkit(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.shield_rounded, color: Palette.tertiary, size: 28),
                  SizedBox(width: 12),
                  Text(
                    'Saffar Safety Toolkit',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.share_location_rounded, color: Palette.primary),
                title: const Text('Share live trip status'),
                subtitle: const Text('Send trusted contacts your live route and ETA'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.read<RideDriverCubit>().shareDriverInfo(driver);
                },
              ),
              ListTile(
                leading: const Icon(Icons.emergency_rounded, color: Palette.sosRed),
                title: const Text('Emergency Assistance (112)'),
                subtitle: const Text('Direct call to emergency response dispatch'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.read<RideDriverCubit>().openCallerApp('112');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<String> otpChars = otp.padLeft(4, '0').split('');

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // START RIDE CODE Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFFEDD5)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B00),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.key_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'START RIDE CODE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: Color(0xFF9A3412),
                        ),
                      ),
                      Text(
                        'Share OTP with driver',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                // OTP blocks
                Row(
                  children: otpChars.map((ch) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFED7AA)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Text(
                        ch,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF9A3412),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Driver details card
          Row(
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: Image.network(
                      driver.imageUrl ??
                          'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?w=150',
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const CircleAvatar(
                        radius: 26,
                        child: Icon(Icons.person, size: 28),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: Color(0xFF20A46B),
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          driver.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Palette.neutral,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified,
                          color: Color(0xFF20A46B),
                          size: 16,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${driver.vehicleName} • 3,240 trips',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.star, color: Color(0xFFD97706), size: 12),
                              SizedBox(width: 2),
                              Text(
                                '4.9',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            driver.vehicleNumber,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Call button
              GestureDetector(
                onTap: () {
                  context.read<RideDriverCubit>().openCallerApp(driver.phone);
                },
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E3A8A),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.call, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 10),
              // Chat button
              GestureDetector(
                onTap: () => _showChatDialog(context),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEFF6FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: Color(0xFF1E3A8A),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Fare Info Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Palette.cardBorder),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.electric_rickshaw_rounded,
                  color: Palette.secondary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rideType,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Palette.neutral,
                        ),
                      ),
                      Text(
                        'Pay via UPI / Cash',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${rideFare.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Palette.neutral,
                      ),
                    ),
                    const Text(
                      'Best rate guaranteed',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF20A46B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Pickup spot info card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Palette.cardBorder),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on,
                  color: Color(0xFFFF6B00),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PICKUP SPOT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        pickupSpot,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Palette.neutral,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Contact driver to adjust pickup point')),
                    );
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(50, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Change',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF6B00),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Action buttons: Cancel Ride, Safety Toolkit, Help Support
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCancelRidePressed,
                  icon: const Icon(Icons.close_rounded, color: Color(0xFFDC2626), size: 16),
                  label: const Text(
                    'Cancel Ride',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFFFEF2F2),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showSafetyToolkit(context),
                  icon: const Icon(Icons.shield_outlined, color: Palette.neutral, size: 16),
                  label: const Text(
                    'Safety Toolkit',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Palette.neutral,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFFF8FAFC),
                    side: const BorderSide(color: Palette.cardBorder),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Connecting to 24x7 Saffar Guardian Support...')),
                    );
                  },
                  icon: const Icon(Icons.support_agent_rounded, color: Palette.neutral, size: 16),
                  label: const Text(
                    'Help Support',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Palette.neutral,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFFF8FAFC),
                    side: const BorderSide(color: Palette.cardBorder),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Saffar Guardian Protection footer
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.verified_user_outlined, color: Color(0xFF20A46B), size: 14),
              SizedBox(width: 6),
              Text(
                'Ride covered by 24×7 Saffar Guardian Protection',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
