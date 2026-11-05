import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:saffar_app/core/config/map_config.dart';
import 'package:saffar_app/core/palette.dart';
import 'package:saffar_app/core/service_locator.dart';
import 'package:saffar_app/core/services/map_service.dart';
import 'package:saffar_app/core/widgets/map_marker_widgets.dart';
import 'package:saffar_app/features/ride/data/repositories/ride_repo.dart';
import 'package:saffar_app/features/search_places_and_get_route/data/repositories/map_route_repo.dart';
import 'package:saffar_app/features/ride/presenter/screens/active_trip_screen.dart';
import 'package:saffar_app/features/user/presenter/cubits/user_cubit.dart';

class RideOptionItem {
  const RideOptionItem({
    required this.id,
    required this.name,
    this.badge,
    this.badgeBg,
    this.badgeTextColor,
    required this.capacity,
    required this.etaText,
    required this.featureText,
    required this.price,
    this.originalPrice,
    this.bottomTag,
    this.bottomTagColor,
    required this.icon,
    this.iconColor,
    this.iconBg,
  });

  final String id;
  final String name;
  final String? badge;
  final Color? badgeBg;
  final Color? badgeTextColor;
  final int capacity;
  final String etaText;
  final String featureText;
  final int price;
  final int? originalPrice;
  final String? bottomTag;
  final Color? bottomTagColor;
  final IconData icon;
  final Color? iconColor;
  final Color? iconBg;
}

class RideConfirmationScreen extends StatefulWidget {
  const RideConfirmationScreen({
    Key? key,
    this.pickupText = '',
    this.destinationText = '',
    this.distanceText = '',
    this.durationText = '',
    this.pickupLat,
    this.pickupLon,
    this.destLat,
    this.destLon,
  }) : super(key: key);

  static const String routeName = '/ride_confirmation';

  final String pickupText;
  final String destinationText;
  final String distanceText;
  final String durationText;
  final double? pickupLat;
  final double? pickupLon;
  final double? destLat;
  final double? destLon;

  @override
  State<RideConfirmationScreen> createState() => _RideConfirmationScreenState();
}

class _RideConfirmationScreenState extends State<RideConfirmationScreen> {
  late final MapController _mapController;

  late LatLng _pickupLocation;
  late LatLng _destinationLocation;

  List<LatLng> _routePoints = [];
  String _selectedOptionId = 'auto';
  String _selectedPayment = 'Cash';
  final String _appliedCoupon = 'SAVE30 applied';

  late final List<RideOptionItem> _options;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    _pickupLocation = (widget.pickupLat != null && widget.pickupLon != null)
        ? LatLng(widget.pickupLat!, widget.pickupLon!)
        : const LatLng(16.7050, 74.2433);

    _destinationLocation = (widget.destLat != null && widget.destLon != null)
        ? LatLng(widget.destLat!, widget.destLon!)
        : const LatLng(16.6959, 74.4556);

    _loadRoute();

    _options = [
      const RideOptionItem(
        id: 'bike',
        name: 'Saffar Bike',
        badge: 'FASTEST',
        badgeBg: Color(0xFFE0F2FE),
        badgeTextColor: Color(0xFF0369A1),
        capacity: 1,
        etaText: '2 min',
        featureText: 'Drop 09:45 AM',
        price: 85,
        originalPrice: 95,
        icon: Icons.two_wheeler_rounded,
        iconBg: Color(0xFFEFF6FF),
        iconColor: Color(0xFF1E3A8A),
      ),
      const RideOptionItem(
        id: 'auto',
        name: 'Saffar Auto',
        badge: 'POPULAR',
        badgeBg: Color(0xFFFFEDD5),
        badgeTextColor: Color(0xFFC2410C),
        capacity: 3,
        etaText: '3 min',
        featureText: 'Eco-friendly',
        price: 135,
        bottomTag: 'Eco Save',
        bottomTagColor: Color(0xFF10B981),
        icon: Icons.electric_rickshaw_rounded,
        iconBg: Color(0xFFFFEFE7),
        iconColor: Color(0xFFFF6B00),
      ),
      const RideOptionItem(
        id: 'mini',
        name: 'Mini Cab',
        capacity: 4,
        etaText: '4 min',
        featureText: 'AC Compact',
        price: 210,
        bottomTag: 'Standard',
        bottomTagColor: Color(0xFF64748B),
        icon: Icons.directions_car_filled_rounded,
        iconBg: Color(0xFFF1F5F9),
        iconColor: Color(0xFF173B67),
      ),
      const RideOptionItem(
        id: 'sedan',
        name: 'Prime Sedan',
        capacity: 4,
        etaText: '6 min',
        featureText: 'AC Premium',
        price: 280,
        icon: Icons.local_taxi_rounded,
        iconBg: Color(0xFFF1F5F9),
        iconColor: Color(0xFF173B67),
      ),
    ];
  }

  Future<void> _loadRoute() async {
    try {
      final points = await sl<MapRouteRepo>().getPointsFromSourceToDestination(
        _pickupLocation,
        _destinationLocation,
      );
      if (mounted && points.isNotEmpty) {
        setState(() {
          _routePoints = points;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          MapService.instance.fitCameraToBounds(
            _mapController,
            points,
            padding: const EdgeInsets.all(70),
          );
        });
      }
    } catch (_) {}
  }

  RideOptionItem get _selectedOption => _options.firstWhere(
        (o) => o.id == _selectedOptionId,
        orElse: () => _options[1],
      );

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
              leading: const Icon(Icons.payments_outlined, color: Palette.tertiary),
              title: const Text('Cash to Driver'),
              trailing: _selectedPayment == 'Cash'
                  ? const Icon(Icons.check_circle, color: Palette.primary)
                  : null,
              onTap: () {
                setState(() => _selectedPayment = 'Cash');
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_rounded, color: Palette.primary),
              title: const Text('UPI (GPay / PhonePe / Paytm)'),
              trailing: _selectedPayment == 'UPI'
                  ? const Icon(Icons.check_circle, color: Palette.primary)
                  : null,
              onTap: () {
                setState(() => _selectedPayment = 'UPI');
                Navigator.pop(ctx);
              },
            ),
            Builder(
              builder: (innerCtx) {
                final walletBalance =
                    context.watch<UserCubit>().state.currentUser?.walletBalance ?? 1240.0;
                return ListTile(
                  leading: const Icon(Icons.account_balance_wallet_outlined,
                      color: Palette.secondary),
                  title: Text('Saffar Wallet (₹${walletBalance.toStringAsFixed(2)})'),
                  trailing: _selectedPayment == 'Saffar Wallet'
                      ? const Icon(Icons.check_circle, color: Palette.primary)
                      : null,
                  onTap: () {
                    setState(() => _selectedPayment = 'Saffar Wallet');
                    Navigator.pop(ctx);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  bool _isBooking = false;

  Future<void> _bookRide() async {
    final selected = _selectedOption;

    if (_selectedPayment == 'Saffar Wallet') {
      final currentWallet =
          context.read<UserCubit>().state.currentUser?.walletBalance ?? 0.0;
      if (currentWallet < selected.price) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Insufficient Wallet balance (₹${currentWallet.toStringAsFixed(0)}). Please add money or choose Cash / UPI.'),
            backgroundColor: Palette.error,
          ),
        );
        return;
      }
    }

    setState(() => _isBooking = true);

    try {
      final res = await sl<RideRepo>().bookRide(
        vehicleType: selected.name,
        price: selected.price.toDouble(),
        sourceAddress: widget.pickupText,
        destinationAddress: widget.destinationText,
        paymentMethod: 'Paid via $_selectedPayment',
      );

      if (!mounted) return;

      final rideId = res['ride_id']?.toString() ?? '';
      final otp = res['otp']?.toString() ?? '';
      final driver = res['driver'] as Map<String, dynamic>?;

      Navigator.pushReplacementNamed(
        context,
        ActiveTripScreen.routeName,
        arguments: {
          'ride_id': rideId,
          'otp': otp,
          'driver_name': driver?['name'] ?? 'Driver',
          'vehicle_name': driver?['vehicle_name'] ?? selected.name,
          'vehicle_number': driver?['vehicle_number'] ?? '',
          'driver_trips': driver?['total_trips'] ?? '',
          'driver_rating': driver?['rating']?.toString() ?? '5.0',
          'driver_phone': driver?['phone'] ?? '',
          'driver_image_url': driver?['image_url'],
          'ride_type': '${selected.name} Ride',
          'fare': '₹${selected.price}.00',
          'pickup_spot': widget.pickupText,
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking error: $e'),
            backgroundColor: Palette.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserCubit>().state.currentUser;
    final selectedOption = _selectedOption;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top Bar
            _buildTopAppBar(user?.imageUrl),

            // 2. Map Section with Floating Distance Pill & Target Button
            Expanded(
              flex: 4,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: const LatLng(17.4415, 78.3735),
                      initialZoom: 13.5,
                    ),
                    children: [
                      MapService.instance.buildTileLayer(),
                      if (_routePoints.isNotEmpty)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: _routePoints,
                              color: MapConfig.routeColor,
                              strokeWidth: 4.5,
                              borderColor: Colors.white,
                              borderStrokeWidth: 2.0,
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          MapMarkerWidgets.buildPickupMarker(
                            _pickupLocation,
                            label: widget.pickupText.isNotEmpty ? widget.pickupText : 'Pickup Location',
                          ),
                          MapMarkerWidgets.buildDestinationMarker(
                            _destinationLocation,
                            label: widget.destinationText.isNotEmpty ? widget.destinationText : 'Destination',
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Attribution overlay
                  MapService.instance.buildAttributionWidget(context),

                  // Floating Distance & Time Pill (Top Center of Map)
                  Positioned(
                    top: 12,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.navigation_rounded,
                                color: Color(0xFF10B981), size: 14),
                            const SizedBox(width: 6),
                            Text(
                              '${widget.distanceText} • ${widget.durationText}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Re-center Target Button (Top Right of Map)
                  Positioned(
                    top: 12,
                    right: 14,
                    child: GestureDetector(
                      onTap: () {
                        _mapController.move(const LatLng(17.4415, 78.3735), 13.5);
                      },
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.my_location_rounded,
                          color: Palette.neutral,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 3. Bottom Sheet: Route Pill, Available Rides, Payment, and CTA Button
            Expanded(
              flex: 6,
              child: Container(
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
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  children: [
                    // Drag Handle
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Route Summary Pill: Pickup -> Destination
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.circle, color: Color(0xFF10B981), size: 9),
                          const SizedBox(width: 8),
                          Text(
                            widget.pickupText,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Palette.neutral,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded,
                              size: 14, color: Color(0xFF64748B)),
                          const SizedBox(width: 8),
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6B00),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.destinationText,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Palette.neutral,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
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

                    const SizedBox(height: 14),

                    // Available Rides Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text(
                          'Available Rides',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Palette.neutral,
                          ),
                        ),
                        Text(
                          '5 options nearby',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Vehicle Options List
                    ..._options.map((option) {
                      final bool isSelected = option.id == _selectedOptionId;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedOptionId = option.id;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFFFF9F5) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFFF6B00)
                                  : const Color(0xFFF1F5F9),
                              width: isSelected ? 1.8 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Icon container with selected checkmark on top-left if selected
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: option.iconBg ?? const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      option.icon,
                                      color: option.iconColor ?? Palette.secondary,
                                      size: 24,
                                    ),
                                  ),
                                  if (isSelected)
                                    Positioned(
                                      top: -3,
                                      left: -3,
                                      child: Container(
                                        width: 14,
                                        height: 14,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFFF6B00),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 10,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              // Title & Subtitle
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
                                                horizontal: 6, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: option.badgeBg,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              option.badge!,
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w900,
                                                color: option.badgeTextColor,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        const Icon(Icons.person_outline,
                                            size: 13, color: Color(0xFF64748B)),
                                        const SizedBox(width: 2),
                                        Text(
                                          '${option.capacity} • ${option.featureText} • ${option.etaText}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Price Column
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        '₹${option.price}',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          color: isSelected
                                              ? const Color(0xFF9A3412)
                                              : Palette.neutral,
                                        ),
                                      ),
                                      if (option.originalPrice != null) ...[
                                        const SizedBox(width: 4),
                                        Text(
                                          '₹${option.originalPrice}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF94A3B8),
                                            decoration: TextDecoration.lineThrough,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (option.bottomTag != null) ...[
                                    Text(
                                      option.bottomTag!,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: option.bottomTagColor,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),

                    const SizedBox(height: 6),

                    // Payment & Coupon Row
                    Row(
                      children: [
                        // Cash Dropdown
                        Expanded(
                          child: InkWell(
                            onTap: _showPaymentPicker,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.payments_outlined,
                                      size: 16, color: Color(0xFF10B981)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _selectedPayment,
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
                        // SAVE30 Applied Green Pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F8F0),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.local_offer_outlined,
                                  size: 14, color: Color(0xFF047857)),
                              const SizedBox(width: 6),
                              Text(
                                _appliedCoupon,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF047857),
                                ),
                              ),
                              const SizedBox(width: 5),
                              const Icon(Icons.check_circle_outline,
                                  size: 14, color: Color(0xFF047857)),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Big Orange Action Button (CTA)
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isBooking ? null : _bookRide,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B00),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isBooking
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Book ${selectedOption.name} • ₹${selectedOption.price}',
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

                    const SizedBox(height: 10),

                    // Trust Badges Footer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.shield_outlined,
                            size: 14, color: Color(0xFF10B981)),
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopAppBar(String? userImageUrl) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Palette.neutral),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 12),
          Image.asset(
            'assets/images/saffar_logo_rounded.png',
            width: 28,
            height: 28,
            errorBuilder: (_, __, ___) => Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: Palette.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.navigation, color: Colors.white, size: 16),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Ride Confirm...',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Palette.neutral,
            ),
          ),
          const Spacer(),
          CircleAvatar(
            radius: 17,
            backgroundImage: NetworkImage(
              userImageUrl ??
                  'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150',
            ),
          ),
        ],
      ),
    );
  }
}

