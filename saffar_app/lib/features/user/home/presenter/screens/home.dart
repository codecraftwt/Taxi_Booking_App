import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:saffar_app/core/config/map_config.dart';
import 'package:saffar_app/core/services/map_service.dart';
import 'package:saffar_app/core/widgets/map_marker_widgets.dart';
import 'package:saffar_app/core/cubits/previous_rides_cubit.dart';
import 'package:saffar_app/core/palette.dart';
import 'package:saffar_app/core/service_locator.dart';
import 'package:saffar_app/features/authentication/presenter/screens/role_selection_screen.dart';
import 'package:saffar_app/features/driver/presenter/screens/driver_sign_in_screen.dart';
import 'package:saffar_app/features/user/presenter/cubits/user_cubit.dart';
import 'package:saffar_app/features/home/presenter/cubits/home_cubit.dart';
import 'package:saffar_app/features/home/presenter/widgets/choose_location_modal.dart';
import 'package:saffar_app/features/ride/data/repositories/ride_repo.dart';
import 'package:saffar_app/features/ride/presenter/screens/ride_confirmation_screen.dart';
import 'package:saffar_app/features/ride/presenter/screens/active_trip_screen.dart';
import 'package:saffar_app/features/user/presenter/screens/user_profile_screen.dart';
import 'package:saffar_app/features/user/presenter/screens/user_ride_history_screen.dart';
import 'package:saffar_app/features/user/presenter/screens/user_support_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  static const String routeName = '/home';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final HomeCubit _homeCubit;
  late final MapController _mapController;

  // Center location default (Maharashtra / Kolhapur default, updated via live GPS)
  LatLng _userLocation = const LatLng(16.7050, 74.2433);

  int _selectedNavIndex = 0;
  Map<String, dynamic>? _nearbyData;
  bool _isLoadingNearby = false;
  String _currentPickupAddress = 'Current Location';

  @override
  void initState() {
    super.initState();
    _homeCubit = HomeCubit();
    _homeCubit.initHomeCubit(context);
    _mapController = MapController();
    context.read<PreviousRidesCubit>().getListOfPreviousRidesAndEmit();
    context.read<UserCubit>().fetchAndRefreshUserProfile();
    _fetchNearbyVehicles();
    _checkActiveRideAndRestore();
    _loadCurrentAddress();
  }

  Future<void> _loadCurrentAddress() async {
    try {
      final addr = await _homeCubit.getCurrentAddress();
      if (addr != null && mounted) {
        setState(() {
          _userLocation = addr.latLng;
          final text = [addr.street, addr.place].where((s) => s != null && s.isNotEmpty).join(', ');
          if (text.isNotEmpty) {
            _currentPickupAddress = text;
          }
        });
        _mapController.move(addr.latLng, 14.8);
        _fetchNearbyVehicles();
      }
    } catch (_) {}
  }

  Future<void> _checkActiveRideAndRestore() async {
    try {
      final activeRide = await sl<RideRepo>().getActiveRide();
      if (activeRide != null && mounted) {
        final status = activeRide['status']?.toString();
        const activeStatuses = ['accepted', 'reaching_pickup', 'arrived', 'in_progress', 'started'];
        if (status != null && activeStatuses.contains(status)) {
          final driverName = activeRide['driver_name']?.toString();
          if (driverName != null &&
              driverName.isNotEmpty &&
              driverName != 'Driver' &&
              driverName != 'Driver Unassigned') {
            Navigator.pushNamed(
              context,
              ActiveTripScreen.routeName,
              arguments: {
                'ride_id': activeRide['ride_id'] ?? activeRide['id'] ?? '',
                'otp': activeRide['otp'] ?? '',
                'driver_name': driverName,
                'vehicle_name': activeRide['vehicle_name'] ?? '',
                'vehicle_number': activeRide['vehicle_number'] ?? '',
                'driver_rating': activeRide['driver_rating'] ?? '5.0',
                'driver_trips': activeRide['driver_trips'] ?? '',
                'driver_phone': activeRide['driver_phone'] ?? '',
                'driver_image_url': activeRide['driver_image_url'],
                'ride_type': activeRide['vehicle_type'] ?? 'Ride',
                'fare': activeRide['price'] != null ? '₹${activeRide['price']}' : '',
                'pickup_spot': activeRide['pickup_address'] ?? '',
              },
            );
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchNearbyVehicles() async {
    if (!mounted) return;
    setState(() => _isLoadingNearby = true);
    try {
      final data = await sl<RideRepo>().getNearbyVehicleAvailability(
        latitude: _userLocation.latitude,
        longitude: _userLocation.longitude,
        radiusKm: 5.0,
      );
      if (mounted) {
        setState(() {
          _nearbyData = data;
          _isLoadingNearby = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingNearby = false);
      }
    }
  }

  void _openBookingScreen({
    String? pickupText,
    String? destinationText,
    String? distanceText,
    String? durationText,
    double? pickupLat,
    double? pickupLon,
    double? destLat,
    double? destLon,
  }) async {
    await Navigator.pushNamed(
      context,
      RideConfirmationScreen.routeName,
      arguments: {
        'pickup_text': pickupText ?? '',
        'destination_text': destinationText ?? '',
        'distance_text': distanceText ?? '',
        'duration_text': durationText ?? '',
        'pickup_lat': pickupLat ?? _userLocation.latitude,
        'pickup_lon': pickupLon ?? _userLocation.longitude,
        'dest_lat': destLat,
        'dest_lon': destLon,
      },
    );

    if (mounted) {
      context.read<PreviousRidesCubit>().getListOfPreviousRidesAndEmit();
      context.read<UserCubit>().fetchAndRefreshUserProfile();
    }
  }

  void _openLocationSearch({
    String? initialDestination,
    bool focusDestination = true,
  }) {
    ChooseLocationModal.show(
      context,
      initialPickup: _currentPickupAddress,
      initialDestination: initialDestination,
      focusDestination: focusDestination,
      onLocationSelected: (pickup, destination, distance, duration, {destLat, destLon}) {
        _openBookingScreen(
          pickupText: pickup,
          destinationText: destination,
          distanceText: distance,
          durationText: duration,
          pickupLat: _userLocation.latitude,
          pickupLon: _userLocation.longitude,
          destLat: destLat,
          destLon: destLon,
        );
      },
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out of your Saffar account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              context
                  .read<UserCubit>()
                  .deleteCurrentUserFromLocalStorageAndEmitCurrentUser(context);
              Navigator.pushNamedAndRemoveUntil(
                context,
                RoleSelectionScreen.routeName,
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE5484D)),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserCubit>().state.currentUser;
    final String? userImageUrl = user?.imageUrl;
    final String userName = user?.name.split(' ').first ?? 'Sameer';

    return BlocProvider<HomeCubit>.value(
      value: _homeCubit,
      child: Scaffold(
        key: _scaffoldKey,
        drawer: _buildDrawer(context, user, userImageUrl),
        backgroundColor: const Color(0xFFF6F8FC),
        body: SafeArea(
          child: Column(
            children: [
              // Top Bar
              _buildTopAppBar(userImageUrl),

              // Main Body: Scrollable with Map and Stitch cards
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.zero,
                  children: [
                    // Map Section
                    _buildMapSection(),

                    // Greeting Card
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: _buildGreetingCard(userName),
                    ),

                    // "Where would you like to go?" Card + 3 Quick Chips
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: _buildSearchAndChipsCard(),
                    ),

                    // "Available Rides" Section
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                      child: _buildAvailableRidesSection(),
                    ),

                    // Promotion Banner Card
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: _buildPromoBannerCard(),
                    ),

                    const SizedBox(height: 12),
                  ],
                ),
              ),

              // Bottom Navigation Bar
              _buildBottomNavBar(),
            ],
          ),
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
          // Saffar Logo
          GestureDetector(
            onTap: () => _scaffoldKey.currentState?.openDrawer(),
            child: Row(
              children: [
                Image.asset(
                  'assets/images/saffar_logo_rounded.png',
                  width: 32,
                  height: 32,
                  errorBuilder: (_, __, ___) => Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Palette.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.navigation, color: Colors.white, size: 18),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'Saffar',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Palette.neutral,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      'Home',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          // Bell Icon
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No new notifications')),
              );
            },
            icon: const Icon(Icons.notifications_none_rounded, color: Palette.neutral, size: 24),
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          // User Avatar
          GestureDetector(
            onTap: () {
              Navigator.pushNamed(context, UserProfileScreen.routeName);
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Palette.primary, width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.network(
                  userImageUrl ??
                      'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Palette.neutral),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapSection() {
    // Determine dynamic polyline to closest nearby vehicle if available
    final List<dynamic>? vehicles = _nearbyData?['vehicles'] as List<dynamic>?;
    List<LatLng>? routePoints;
    if (vehicles != null && vehicles.isNotEmpty) {
      final v = vehicles.first;
      final double? lat = (v['latitude'] as num?)?.toDouble();
      final double? lng = (v['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        routePoints = [_userLocation, LatLng(lat, lng)];
      }
    }

    return SizedBox(
      height: 230,
      width: double.infinity,
      child: Stack(
        children: [
          // FlutterMap with central provider configuration
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userLocation,
              initialZoom: 14.8,
            ),
            children: [
              MapService.instance.buildTileLayer(),
              if (routePoints != null && routePoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routePoints,
                      color: Palette.primary,
                      strokeWidth: 3.5,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  MapMarkerWidgets.buildUserLocationMarker(_userLocation),
                  ..._buildDynamicVehicleMarkers(),
                ],
              ),
            ],
          ),

          // Attribution Widget
          MapService.instance.buildAttributionWidget(context),

          // Floating Location Pill (Top Left)
          Positioned(
            top: 10,
            left: 12,
            child: GestureDetector(
              onTap: () => _openLocationSearch(focusDestination: false),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.circle, color: Color(0xFFFF6B00), size: 10),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _currentPickupAddress,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Palette.neutral,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ),

          // Floating Action Buttons (Top Right: Red Shield & Target)
          Positioned(
            top: 10,
            right: 12,
            child: Row(
              children: [
                // Red Shield SOS
                GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(context, UserSupportScreen.routeName);
                  },
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      color: Color(0xFFB91C1C),
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Target GPS button
                GestureDetector(
                  onTap: () {
                    _mapController.move(_userLocation, 14.8);
                  },
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Marker> _buildDynamicVehicleMarkers() {
    final List<dynamic>? vehicles = _nearbyData?['vehicles'] as List<dynamic>?;
    if (vehicles != null && vehicles.isNotEmpty) {
      return vehicles.map((v) {
        final double lat = (v['latitude'] as num?)?.toDouble() ?? _userLocation.latitude;
        final double lng = (v['longitude'] as num?)?.toDouble() ?? _userLocation.longitude;
        final String cat = v['category']?.toString() ?? 'Auto';
        final double? dist = (v['distance_km'] as num?)?.toDouble();
        final String eta = dist != null ? '${(dist * 2.5).round().clamp(1, 15)}m' : '3m';

        IconData icon = Icons.electric_rickshaw_rounded;
        Color iconColor = const Color(0xFFFF6B00);

        if (cat.toLowerCase().contains('bike')) {
          icon = Icons.two_wheeler_rounded;
          iconColor = const Color(0xFF10B981);
        } else if (cat.toLowerCase().contains('car') ||
            cat.toLowerCase().contains('sedan') ||
            cat.toLowerCase().contains('suv')) {
          icon = Icons.directions_car_filled_rounded;
          iconColor = const Color(0xFF173B67);
        }

        return _buildMapVehicleMarker(
          LatLng(lat, lng),
          icon,
          eta,
          iconColor: iconColor,
        );
      }).toList();
    }

    // No fake fallback markers when drivers are not active
    return const [];
  }

  Marker _buildMapVehicleMarker(LatLng point, IconData icon, String eta,
      {Color iconColor = const Color(0xFF173B67)}) {
    return Marker(
      point: point,
      width: 58,
      height: 32,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(width: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade300, width: 0.8),
            ),
            child: Text(
              eta,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Palette.neutral,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGreetingCard(String userName) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good morning, $userName 👋',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Palette.neutral,
                  ),
                ),
                const SizedBox(height: 3),
                GestureDetector(
                  onTap: () => _openLocationSearch(focusDestination: false),
                  child: Row(
                    children: const [
                      Icon(Icons.near_me_rounded, color: Color(0xFFFF6B00), size: 13),
                      SizedBox(width: 4),
                      Text(
                        'Central Blvd, Tower A',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.keyboard_arrow_down, size: 14, color: Color(0xFF94A3B8)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F8F0),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: const [
                Icon(Icons.circle, color: Color(0xFF10B981), size: 8),
                SizedBox(width: 5),
                Text(
                  'Fast pickups',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF047857),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndChipsCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top Search Bar
          GestureDetector(
            onTap: () => _openLocationSearch(focusDestination: true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B00),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.search_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Where would you like to go?',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Palette.neutral,
                          ),
                        ),
                        SizedBox(height: 1),
                        Text(
                          'Explore rides, airports, or enter o...',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mic_none_rounded, color: Colors.grey, size: 18),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // 3 Quick Destination Chips: Home, Office, Recent
          Row(
            children: [
              Expanded(
                child: _buildDestinationChip(
                  icon: Icons.home_outlined,
                  iconColor: const Color(0xFF173B67),
                  title: 'Home',
                  subtitle: '12 Elm Street',
                  onTap: () => _openLocationSearch(
                    initialDestination: 'Home, 12 Elm Street',
                    focusDestination: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDestinationChip(
                  icon: Icons.business_center_outlined,
                  iconColor: const Color(0xFF173B67),
                  title: 'Office',
                  subtitle: 'Tech Park BD',
                  onTap: () => _openLocationSearch(
                    initialDestination: 'Office, Tech Park BD',
                    focusDestination: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDestinationChip(
                  icon: Icons.star_rounded,
                  iconColor: const Color(0xFFFF6B00),
                  title: 'Recent',
                  subtitle: 'Skyline...',
                  onTap: () => _openLocationSearch(
                    focusDestination: true,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDestinationChip({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Palette.neutral,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 9,
                      color: Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailableRidesSection() {
    final categories = _nearbyData?['categories'] as Map<String, dynamic>?;
    final bike = categories?['Bike'] as Map<String, dynamic>?;
    final auto = categories?['Auto'] as Map<String, dynamic>?;
    final car = categories?['Mini Car'] as Map<String, dynamic>?;
    final sedan = categories?['Sedan'] as Map<String, dynamic>?;
    final int totalDrivers = _nearbyData?['total_nearby_drivers'] as int? ?? 0;

    final String bikeEta = bike?['eta_text']?.toString() ?? '2 mins';
    final String bikePrice = '₹${(bike?['base_fare'] as num?)?.round() ?? 49}';
    final int bikeCount = (bike?['count'] as num?)?.toInt() ?? 0;

    final String autoEta = auto?['eta_text']?.toString() ?? '3 mins';
    final String autoPrice = '₹${(auto?['base_fare'] as num?)?.round() ?? 82}';
    final int autoCount = (auto?['count'] as num?)?.toInt() ?? 0;

    final String carEta = car?['eta_text']?.toString() ?? '4 mins';
    final String carPrice = '₹${(car?['base_fare'] as num?)?.round() ?? 145}';
    final int carCount = (car?['count'] as num?)?.toInt() ?? 0;

    final String sedanEta = sedan?['eta_text']?.toString() ?? '5 mins';
    final String sedanPrice = '₹${(sedan?['base_fare'] as num?)?.round() ?? 210}';
    final int sedanCount = (sedan?['count'] as num?)?.toInt() ?? 0;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text(
                  'Available Rides',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Palette.neutral,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: totalDrivers > 0 ? const Color(0xFFE8F5E9) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: totalDrivers > 0 ? const Color(0xFF2E7D32) : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isLoadingNearby
                            ? 'Scanning...'
                            : '$totalDrivers drivers nearby',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: totalDrivers > 0 ? const Color(0xFF2E7D32) : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: () => _openLocationSearch(focusDestination: true),
              child: const Text(
                'See All >',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Palette.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 4 Available Ride Cards
        Row(
          children: [
            Expanded(
              child: _buildStitchRideCard(
                badge: bikeCount > 0 ? '$bikeCount online' : 'FASTEST',
                badgeColor: const Color(0xFFFF6B00),
                icon: Icons.two_wheeler_rounded,
                iconBg: const Color(0xFFF1F5F9),
                title: 'Bike',
                eta: bikeEta,
                price: bikePrice,
                onTap: () => _openLocationSearch(focusDestination: true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStitchRideCard(
                badge: autoCount > 0 ? '$autoCount online' : 'VALUE',
                badgeColor: const Color(0xFF10B981),
                icon: Icons.electric_rickshaw_rounded,
                iconBg: const Color(0xFFFFEFE7),
                iconColor: const Color(0xFFFF6B00),
                title: 'Auto',
                eta: autoEta,
                price: autoPrice,
                onTap: () => _openLocationSearch(focusDestination: true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStitchRideCard(
                badge: carCount > 0 ? '$carCount online' : null,
                badgeColor: const Color(0xFF173B67),
                icon: Icons.directions_car_filled_rounded,
                iconBg: const Color(0xFFF1F5F9),
                title: 'Car',
                eta: carEta,
                price: carPrice,
                onTap: () => _openLocationSearch(focusDestination: true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStitchRideCard(
                badge: sedanCount > 0 ? '$sedanCount online' : null,
                badgeColor: const Color(0xFF6B7280),
                icon: Icons.directions_bus_filled_rounded,
                iconBg: const Color(0xFFF1F5F9),
                title: 'Rentals',
                eta: sedanEta,
                price: sedanPrice,
                isEtaGray: true,
                onTap: () => _openLocationSearch(focusDestination: true),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStitchRideCard({
    String? badge,
    Color? badgeColor,
    required IconData icon,
    required Color iconBg,
    Color iconColor = const Color(0xFF173B67),
    required String title,
    required String eta,
    required String price,
    bool isEtaGray = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                const SizedBox(height: 2),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Palette.neutral,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  eta,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isEtaGray ? const Color(0xFF64748B) : const Color(0xFF0D9488),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  price,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Palette.neutral,
                  ),
                ),
              ],
            ),
          ),
          if (badge != null)
            Positioned(
              top: -7,
              left: 4,
              right: 4,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPromoBannerCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFDEC2)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFFFDEC2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.local_offer_rounded, color: Palette.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Save 20% on next 5 Auto rides',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Palette.neutral,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Code: SAFFARFIRST • Applied automatically',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_rounded, size: 20, color: Color(0xFF9A3412)),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(Icons.map_outlined, 'Home', _selectedNavIndex == 0,
              hasDot: true, onTap: () {
            setState(() => _selectedNavIndex = 0);
          }),
          _buildNavItem(Icons.history_rounded, 'My Rides', _selectedNavIndex == 1,
              onTap: () {
            Navigator.pushNamed(context, UserRideHistoryScreen.routeName);
          }),
          _buildNavItem(Icons.notifications_none_rounded, 'Notifications',
              _selectedNavIndex == 2, onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No new notifications')),
            );
          }),
          _buildNavItem(Icons.person_outline_rounded, 'Profile',
              _selectedNavIndex == 3, onTap: () {
            Navigator.pushNamed(context, UserProfileScreen.routeName);
          }),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive,
      {bool hasDot = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isActive ? const Color(0xFF0284C7) : const Color(0xFF64748B),
            size: 24,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              color: isActive ? const Color(0xFF0284C7) : const Color(0xFF64748B),
            ),
          ),
          if (hasDot) ...[
            const SizedBox(height: 2),
            Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: Color(0xFFFF6B00),
                shape: BoxShape.circle,
              ),
            ),
          ] else ...[
            const SizedBox(height: 7),
          ],
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, dynamic user, String? userImageUrl) {
    return Drawer(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, UserProfileScreen.routeName);
            },
            child: Container(
              color: Palette.primary,
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.of(context).padding.top + 24,
                20,
                20,
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(width: 2, color: Colors.white),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: userImageUrl != null
                          ? Image.network(userImageUrl, fit: BoxFit.cover)
                          : const Icon(Icons.person, size: 36, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'Passenger',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '+91 ${user?.phone ?? ''}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'View Profile >',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              children: [
                ListTile(
                  leading: const Icon(Icons.home_rounded, color: Palette.primary),
                  title: const Text('Home Dashboard'),
                  onTap: () => Navigator.pop(context),
                ),
                ListTile(
                  leading: const Icon(Icons.history_rounded, color: Palette.neutral),
                  title: const Text('My Trips & Activity'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, UserRideHistoryScreen.routeName);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.person_outline_rounded, color: Palette.neutral),
                  title: const Text('Manage Profile'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, UserProfileScreen.routeName);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.support_agent_rounded, color: Palette.neutral),
                  title: const Text('Help & 24/7 SOS'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, UserSupportScreen.routeName);
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.local_taxi_rounded, color: Color(0xFF008577)),
                  title: const Text('Switch to Driver Mode'),
                  subtitle: const Text('Start accepting rides & earning'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, DriverSignInScreen.routeName);
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: () => _showLogoutDialog(context),
              icon: const Icon(Icons.logout, color: Color(0xFFE5484D)),
              label: const Text(
                'Log Out',
                style: TextStyle(
                  color: Color(0xFFE5484D),
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFE5484D)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
