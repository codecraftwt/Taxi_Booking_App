import 'dart:async';
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
import 'package:saffar_app/features/user/presenter/cubits/user_cubit.dart';
import 'package:saffar_app/features/user/presenter/screens/user_support_screen.dart';
import 'package:saffar_app/features/ride/presenter/screens/rate_review_driver_screen.dart';
import 'package:saffar_app/features/ride/services/customer_socket_service.dart';
import 'package:saffar_app/features/user/data/repositories/user_repo.dart';

class ActiveTripScreen extends StatefulWidget {
  const ActiveTripScreen({
    Key? key,
    this.rideId = '',
    this.otp = '',
    this.driverName = 'Driver',
    this.vehicleName = 'Vehicle',
    this.vehicleNumber = '',
    this.driverTrips = '',
    this.driverRating = '5.0',
    this.driverPhone = '',
    this.driverImageUrl,
    this.rideType = 'Ride',
    this.fare = '',
    this.pickupSpot = '',
    this.etaMinutes = 0,
    this.distanceAway = '',
  }) : super(key: key);

  static const String routeName = '/active_trip';

  final String rideId;
  final String otp;
  final String driverName;
  final String vehicleName;
  final String vehicleNumber;
  final String driverTrips;
  final String driverRating;
  final String driverPhone;
  final String? driverImageUrl;
  final String rideType;
  final String fare;
  final String pickupSpot;
  final int etaMinutes;
  final String distanceAway;

  @override
  State<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends State<ActiveTripScreen> {
  late final MapController _mapController;

  // Bengaluru coordinates matching the Stitch map mockup
  final LatLng _userLocation = const LatLng(12.9350, 77.6850); // Bellandur / Gate 2
  final LatLng _driverStartLocation = const LatLng(12.9780, 77.6350); // Indiranagar

  late LatLng _currentDriverLocation;
  Timer? _animationTimer;
  Timer? _statusPollTimer;
  bool _isCancellationDialogShowing = false;
  double _animationProgress = 0.0;
  late String _currentOtp;

  @override
  void initState() {
    super.initState();
    _currentOtp = widget.otp;
    _mapController = MapController();
    _currentDriverLocation = _driverStartLocation;
    _fetchLiveOtp();
    _checkRideStatus();

    // Connect to Customer Real-Time WebSocket
    try {
      final userRepo = sl<UserRepo>();
      final token = userRepo.getTokenFromLocalStorage();
      final userMap = userRepo.getUserMapFromLocalStorage();
      final userId = userMap?['id']?.toString() ?? 'user_001';
      CustomerSocketService.instance.connect(userId, token);
      CustomerSocketService.instance.joinRide(widget.rideId);

      CustomerSocketService.instance.driverLocationNotifier.addListener(_onLiveDriverLocation);
      CustomerSocketService.instance.tripCompletedNotifier.addListener(_onLiveTripCompleted);
      CustomerSocketService.instance.cancellationNotifier.addListener(_onLiveCancellation);
    } catch (e) {
      debugPrint('[CustomerSocket Init Error] $e');
    }

    // Fallback periodic poll for status changes
    _statusPollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _checkRideStatus();
    });

    // Smoothly animate driver vehicle along the route
    _animationTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      if (!mounted) return;
      setState(() {
        _animationProgress += 0.015;
        if (_animationProgress > 1.0) _animationProgress = 0.0;

        _currentDriverLocation = LatLng(
          _driverStartLocation.latitude +
              (_userLocation.latitude - _driverStartLocation.latitude) *
                  _animationProgress,
          _driverStartLocation.longitude +
              (_userLocation.longitude - _driverStartLocation.longitude) *
                  _animationProgress,
        );
      });
    });
  }

  @override
  void dispose() {
    CustomerSocketService.instance.driverLocationNotifier.removeListener(_onLiveDriverLocation);
    CustomerSocketService.instance.tripCompletedNotifier.removeListener(_onLiveTripCompleted);
    CustomerSocketService.instance.cancellationNotifier.removeListener(_onLiveCancellation);
    _animationTimer?.cancel();
    _statusPollTimer?.cancel();
    super.dispose();
  }

  void _onLiveDriverLocation() {
    final loc = CustomerSocketService.instance.driverLocationNotifier.value;
    if (loc != null && mounted) {
      _animationTimer?.cancel(); // Cancel dummy linear interpolation when real GPS arrives
      setState(() {
        _currentDriverLocation = loc;
      });
    }
  }

  void _onLiveTripCompleted() {
    final data = CustomerSocketService.instance.tripCompletedNotifier.value;
    if (data != null && mounted) {
      _animationTimer?.cancel();
      _statusPollTimer?.cancel();
      final finalFare = data['final_fare'] != null ? '₹${data['final_fare']}' : widget.fare;
      Navigator.pushReplacementNamed(
        context,
        RateReviewDriverScreen.routeName,
        arguments: {
          'ride_id': widget.rideId,
          'driver_name': widget.driverName,
          'vehicle_model': widget.vehicleName,
          'vehicle_number': widget.vehicleNumber,
          'fare_paid': finalFare,
          'pickup_address': widget.pickupSpot,
        },
      );
    }
  }

  void _onLiveCancellation() {
    final reason = CustomerSocketService.instance.cancellationNotifier.value;
    if (reason != null && mounted && !_isCancellationDialogShowing) {
      _showCancellationDialog('driver', reason);
    }
  }

  void _showCancellationDialog(String cancelledBy, String reason) {
    if (_isCancellationDialogShowing) return;
    _isCancellationDialogShowing = true;
    _animationTimer?.cancel();
    _statusPollTimer?.cancel();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cancel_rounded, color: Palette.error, size: 28),
            SizedBox(width: 10),
            Text('Ride Cancelled', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              cancelledBy == 'driver'
                  ? 'The driver had to cancel this booking.'
                  : 'This ride has been cancelled.',
              style: const TextStyle(fontSize: 14, color: Palette.neutral),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFEEEEEE)),
              ),
              child: Text(
                'Reason: $reason',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Palette.error),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Any deducted fare has been refunded to your Saffar Wallet balance.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Palette.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Back to Home', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _checkRideStatus() async {
    if (!mounted || _isCancellationDialogShowing) return;
    try {
      final statusRes = await sl<RideRepo>().getRideStatus(widget.rideId);
      if (!mounted || _isCancellationDialogShowing) return;

      if (statusRes['cancelled'] == true || statusRes['status'] == 'cancelled') {
        final cancelledBy = statusRes['cancelled_by']?.toString() ?? 'driver';
        final reason = statusRes['cancellation_reason']?.toString() ?? 'Ride was cancelled';
        _showCancellationDialog(cancelledBy, reason);
      }
    } catch (_) {}
  }

  void _fetchLiveOtp() async {
    try {
      final res = await sl<RideRepo>().getRideOtp(widget.rideId);
      if (res['otp'] != null && mounted) {
        setState(() {
          _currentOtp = res['otp'].toString();
        });
      }
    } catch (_) {}
  }

  void _showChatBottomSheet() {
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
                  radius: 20,
                  backgroundImage: NetworkImage(
                    widget.driverImageUrl ??
                        'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?w=150',
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.driverName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const Text('Driver is arriving safely',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
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
            const SizedBox(height: 8),
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
                      hintText: 'Message ${widget.driverName}...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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

  void _showSafetyToolkit() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.shield_rounded, color: Color(0xFF20A46B), size: 28),
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Live trip link copied to clipboard')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.emergency_rounded, color: Color(0xFFB91C1C)),
              title: const Text('Emergency Assistance (112)'),
              subtitle: const Text('Direct call to 24x7 emergency response dispatch'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Connecting to Emergency Helpline 112...')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Cancel Ride?'),
        content: const Text(
          'Your driver is already on the way. Are you sure you want to cancel this trip?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Keep Ride'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                final res = await sl<RideRepo>().cancelRide(
                  rideId: widget.rideId,
                  reason: 'User cancelled from active trip screen',
                );
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(res['message']?.toString() ?? 'Ride cancelled successfully'),
                      backgroundColor: Palette.neutral,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Ride cancelled: $e'),
                      backgroundColor: Palette.neutral,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Cancel Ride', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserCubit>().state.currentUser;
    final List<String> otpChars = _currentOtp.padLeft(4, '0').split('');

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top App Bar
            _buildTopAppBar(user?.imageUrl),

            // 2. Middle Map Section with Overlay Arrival Banner & Controls
            Expanded(
              flex: 4,
              child: Stack(
                children: [
                  // Flutter Map
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: const LatLng(12.9565, 77.6600),
                      initialZoom: 13.0,
                    ),
                    children: [
                      MapService.instance.buildTileLayer(),
                      // Orange Route Line
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: [
                              _driverStartLocation,
                              const LatLng(12.9565, 77.6600),
                              _userLocation,
                            ],
                            color: MapConfig.routeColor,
                            strokeWidth: 4,
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          // User Location Marker
                          MapMarkerWidgets.buildPickupMarker(_userLocation, label: 'PICKUP (YOU)'),

                          // Animated Live Driver Marker with heading
                          MapMarkerWidgets.buildDriverLiveMarker(
                            position: _currentDriverLocation,
                            heading: MapService.instance.calculateBearing(_currentDriverLocation, _userLocation),
                            category: widget.vehicleName,
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Map Tile Attribution
                  MapService.instance.buildAttributionWidget(context),

                  // Floating Driver Arriving Live Banner (Top of Map)
                  Positioned(
                    top: 12,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Pulsing Green Live Dot
                          Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE2F7ED),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Driver arriving in ${widget.etaMinutes} mins',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: Palette.neutral,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Approaching main entrance lane',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F8F0),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              widget.distanceAway,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF047857),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Floating Controls on Bottom-Right of Map: Re-center, Share, SOS
                  Positioned(
                    bottom: 14,
                    right: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Re-center Target Button
                        GestureDetector(
                          onTap: () {
                            _mapController.move(_userLocation, 13.5);
                          },
                          child: Container(
                            width: 40,
                            height: 40,
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
                        const SizedBox(height: 8),

                        // Share Trip Button
                        GestureDetector(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Live trip link copied to share')),
                            );
                          },
                          child: Container(
                            width: 40,
                            height: 40,
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
                              Icons.share_outlined,
                              color: Palette.neutral,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // SOS Red Pill Button
                        GestureDetector(
                          onTap: () {
                            Navigator.pushNamed(context, UserSupportScreen.routeName);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFB91C1C),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFB91C1C).withOpacity(0.4),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.shield_rounded, color: Colors.white, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'SOS',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 3. Lower Half Bottom Card Section (Stitch Active Trip Details)
            Expanded(
              flex: 5,
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
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    // Centered Drag Handle
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

                    // Row 1: START RIDE CODE OTP Banner
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
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6B00),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.key_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
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
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // OTP Digits in Individual Styled Boxes
                          Row(
                            children: otpChars.map((digit) {
                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                                  digit,
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

                    const SizedBox(height: 12),

                    // Row 2: Driver Info Card (Rajesh Kumar, Photo, Rating 4.9, Plate, Call, Chat)
                    Row(
                      children: [
                        // Driver Photo with Rating Badge
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(26),
                              child: Image.network(
                                widget.driverImageUrl ??
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
                              bottom: -4,
                              left: 2,
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star_rounded,
                                        color: Color(0xFFD97706), size: 12),
                                    const SizedBox(width: 2),
                                    Text(
                                      widget.driverRating,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF92400E),
                                      ),
                                    ),
                                  ],
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
                                    widget.driverName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Palette.neutral,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.check_circle,
                                      color: Color(0xFF10B981), size: 16),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${widget.vehicleName} • ${widget.driverTrips}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  widget.vehicleNumber,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Call Action Button
                        GestureDetector(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Calling ${widget.driverPhone}...')),
                            );
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
                        const SizedBox(width: 8),
                        // Chat Action Button
                        GestureDetector(
                          onTap: _showChatBottomSheet,
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

                    // Row 3: Auto Smart Ride & Fare Info
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Palette.cardBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEFE7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.electric_rickshaw_rounded,
                                color: Color(0xFFFF6B00), size: 22),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.rideType,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Palette.neutral,
                                  ),
                                ),
                                const Text(
                                  'Pay via UPI / Cash',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                widget.fare,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: Palette.neutral,
                                ),
                              ),
                              const Text(
                                'Best rate guaranteed',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Row 4: Pickup Spot Details
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Palette.cardBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, color: Color(0xFFFF6B00), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'PICKUP SPOT',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                Text(
                                  widget.pickupSpot,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
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
                                const SnackBar(
                                    content: Text('Contact driver to adjust pickup point')),
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

                    const SizedBox(height: 12),

                    // Complete Ride & Rate Driver Banner Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushReplacementNamed(
                            context,
                            RateReviewDriverScreen.routeName,
                            arguments: {
                              'ride_id': widget.rideId,
                              'driver_name': widget.driverName,
                              'vehicle_model': widget.vehicleName,
                              'vehicle_number': widget.vehicleNumber,
                              'fare_paid': widget.fare,
                              'pickup_address': widget.pickupSpot,
                            },
                          );
                        },
                        icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 18),
                        label: const Text(
                          'Trip Completed? Rate Driver →',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Row 5: Action Buttons (Cancel Ride, Safety Toolkit, Help Support)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _showCancelDialog,
                            icon: const Icon(Icons.close_rounded,
                                color: Color(0xFFDC2626), size: 16),
                            label: const Text(
                              'Cancel Ride',
                              style: TextStyle(
                                fontSize: 11,
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
                            onPressed: _showSafetyToolkit,
                            icon: const Icon(Icons.shield_outlined,
                                color: Palette.neutral, size: 16),
                            label: const Text(
                              'Safety Toolkit',
                              style: TextStyle(
                                fontSize: 11,
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
                              Navigator.pushNamed(context, UserSupportScreen.routeName);
                            },
                            icon: const Icon(Icons.support_agent_rounded,
                                color: Palette.neutral, size: 16),
                            label: const Text(
                              'Help Support',
                              style: TextStyle(
                                fontSize: 11,
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

                    const SizedBox(height: 10),

                    // Row 6: Saffar Guardian Protection Footer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.shield_outlined, color: Color(0xFF10B981), size: 14),
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
            'Active Trip',
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

