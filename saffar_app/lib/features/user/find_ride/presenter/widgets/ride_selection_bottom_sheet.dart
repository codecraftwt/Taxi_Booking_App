import 'package:flutter/material.dart';
import 'package:saffar_app/core/palette.dart';

class RideOption {
  const RideOption({
    required this.id,
    required this.name,
    this.badge,
    this.badgeColor,
    this.subBadge,
    this.subBadgeColor,
    required this.capacity,
    required this.etaMins,
    required this.description,
    required this.price,
    this.originalPrice,
    required this.icon,
  });

  final String id;
  final String name;
  final String? badge;
  final Color? badgeColor;
  final String? subBadge;
  final Color? subBadgeColor;
  final int capacity;
  final int etaMins;
  final String description;
  final double price;
  final double? originalPrice;
  final IconData icon;
}

class RideSelectionBottomSheet extends StatefulWidget {
  const RideSelectionBottomSheet({
    Key? key,
    required this.pickupAddressText,
    required this.destinationAddressText,
    required this.distanceKm,
    required this.durationMins,
    required this.onBookRidePressed,
    required this.onEditRoutePressed,
  }) : super(key: key);

  final String pickupAddressText;
  final String destinationAddressText;
  final double distanceKm;
  final int durationMins;
  final Function(RideOption selectedOption, String paymentMethod, String coupon)
      onBookRidePressed;
  final VoidCallback onEditRoutePressed;

  @override
  State<RideSelectionBottomSheet> createState() =>
      _RideSelectionBottomSheetState();
}

class _RideSelectionBottomSheetState extends State<RideSelectionBottomSheet> {
  String _selectedOptionId = 'auto';
  String _selectedPaymentMethod = 'Cash';
  String _appliedCoupon = 'SAVE30 applied';

  late final List<RideOption> _options;

  @override
  void initState() {
    super.initState();
    _options = [
      const RideOption(
        id: 'bike',
        name: 'Saffar Bike',
        badge: 'FASTEST',
        badgeColor: Color(0xFFE0F2FE),
        capacity: 1,
        etaMins: 2,
        description: '1 • Drop 09:45 AM • 2 min',
        price: 85,
        originalPrice: 95,
        icon: Icons.two_wheeler_rounded,
      ),
      const RideOption(
        id: 'auto',
        name: 'Saffar Auto',
        badge: 'POPULAR',
        badgeColor: Color(0xFFFFEDD5),
        subBadge: 'Eco Save',
        subBadgeColor: Color(0xFFE2F7ED),
        capacity: 3,
        etaMins: 3,
        description: '3 • Eco-friendly • 3 min',
        price: 135,
        icon: Icons.electric_rickshaw_rounded,
      ),
      const RideOption(
        id: 'mini',
        name: 'Mini Cab',
        subBadge: 'Standard',
        capacity: 4,
        etaMins: 4,
        description: '4 • AC Compact • 4 min',
        price: 210,
        icon: Icons.directions_car_filled_rounded,
      ),
      const RideOption(
        id: 'sedan',
        name: 'Prime Sedan',
        capacity: 4,
        etaMins: 6,
        description: '4 • Spacious Sedan • 6 min',
        price: 280,
        icon: Icons.local_taxi_rounded,
      ),
    ];
  }

  RideOption get _selectedRideOption =>
      _options.firstWhere((o) => o.id == _selectedOptionId,
          orElse: () => _options[1]);

  void _showPaymentPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Payment Method',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.payments_rounded, color: Palette.tertiary),
              title: const Text('Cash to Driver'),
              trailing: _selectedPaymentMethod == 'Cash'
                  ? const Icon(Icons.check, color: Palette.primary)
                  : null,
              onTap: () {
                setState(() => _selectedPaymentMethod = 'Cash');
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_2_rounded, color: Palette.primary),
              title: const Text('UPI (GPay / PhonePe / Paytm)'),
              trailing: _selectedPaymentMethod == 'UPI'
                  ? const Icon(Icons.check, color: Palette.primary)
                  : null,
              onTap: () {
                setState(() => _selectedPaymentMethod = 'UPI');
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet_rounded,
                  color: Palette.secondary),
              title: const Text('Saffar Wallet (₹500.00)'),
              trailing: _selectedPaymentMethod == 'Saffar Wallet'
                  ? const Icon(Icons.check, color: Palette.primary)
                  : null,
              onTap: () {
                setState(() => _selectedPaymentMethod = 'Saffar Wallet');
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedOption = _selectedRideOption;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Route summary pill
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF20A46B),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${widget.pickupAddressText} ➔ ${widget.destinationAddressText}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Palette.neutral,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: widget.onEditRoutePressed,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.edit_outlined,
                        size: 14,
                        color: Palette.neutral,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Available Rides',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Palette.neutral,
                  ),
                ),
                Text(
                  '${_options.length} options nearby',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Vehicle list
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _options.length,
            itemBuilder: (context, index) {
              final option = _options[index];
              final bool isSelected = option.id == _selectedOptionId;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedOptionId = option.id;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFFFF9F5) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? Palette.primary : const Color(0xFFF1F5F9),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFFFEDD5)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          option.icon,
                          color: isSelected
                              ? Palette.primary
                              : Palette.secondary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  option.name,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Palette.neutral,
                                  ),
                                ),
                                if (option.badge != null) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: option.badge == 'FASTEST'
                                          ? const Color(0xFFE0F2FE)
                                          : const Color(0xFFFFEDD5),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      option.badge!,
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: option.badge == 'FASTEST'
                                            ? const Color(0xFF0369A1)
                                            : const Color(0xFFC2410C),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              option.description,
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
                          Row(
                            children: [
                              Text(
                                '₹${option.price.toInt()}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Palette.neutral,
                                ),
                              ),
                              if (option.originalPrice != null) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '₹${option.originalPrice!.toInt()}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade400,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (option.subBadge != null) ...[
                            Text(
                              option.subBadge!,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF20A46B),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 6),

          // Payment & Coupon Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Payment selector
                Expanded(
                  child: InkWell(
                    onTap: _showPaymentPicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.payments_rounded,
                              size: 16, color: Palette.tertiary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _selectedPaymentMethod,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Palette.neutral,
                              ),
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down,
                              size: 16, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Coupon pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2F7ED),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.local_offer_rounded,
                          size: 14, color: Color(0xFF0F5A38)),
                      const SizedBox(width: 6),
                      Text(
                        _appliedCoupon,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F5A38),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.check_circle,
                          size: 14, color: Color(0xFF0F5A38)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Big Orange CTA Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  widget.onBookRidePressed(
                    selectedOption,
                    _selectedPaymentMethod,
                    _appliedCoupon,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Palette.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Book ${selectedOption.name} • ₹${selectedOption.price.toInt()}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Trust Badges footer
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.shield_outlined, size: 14, color: Color(0xFF20A46B)),
                SizedBox(width: 4),
                Text(
                  'Sanitized vehicles • Verified Drivers • Live GPS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

