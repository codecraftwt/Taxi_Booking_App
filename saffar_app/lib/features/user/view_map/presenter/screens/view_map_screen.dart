import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:saffar_app/core/config/map_config.dart';
import 'package:saffar_app/core/palette.dart';
import 'package:saffar_app/core/services/map_service.dart';
import 'package:saffar_app/features/find_ride/presenter/widgets/ride_selection_bottom_sheet.dart';
import 'package:saffar_app/features/user/presenter/cubits/user_cubit.dart';
import 'package:saffar_app/core/models/address.dart';
import 'package:saffar_app/core/models/driver.dart';
import 'package:saffar_app/core/models/user.dart';
import 'package:saffar_app/core/utils/view_helper.dart';
import 'package:saffar_app/core/widgets/expansion_animation_widget.dart';
import 'package:saffar_app/features/find_ride/presenter/cubits/ride_driver_cubit.dart';
import 'package:saffar_app/features/find_ride/presenter/widgets/ride_driver_info_widget.dart';
import 'package:saffar_app/features/payment/presenter/screens/payment_screen.dart';
import 'package:saffar_app/features/ride/presenter/cubits/ride_cubit.dart';
import 'package:saffar_app/features/search_places_and_get_route/presenter/cubits/map_route_cubit.dart';
import 'package:saffar_app/features/search_places_and_get_route/presenter/cubits/searched_places_cubit.dart';
import 'package:saffar_app/features/search_places_and_get_route/presenter/widgets/input_pickup_and_destination_location_widget.dart';

import 'package:saffar_app/core/models/ride.dart';
import '../widgets/address_list_bottom_widget.dart';

class ViewMapScreenArguments {
  const ViewMapScreenArguments({
    this.initialPickupAddress,
    this.initialDestinationAddress,
  });

  final Address? initialPickupAddress;
  final Address? initialDestinationAddress;
}

class ViewMapScreen extends StatefulWidget {
  const ViewMapScreen({
    Key? key,
    required this.viewMapScreenArguments,
  }) : super(key: key);

  static const String routeName = '/view_map';

  final ViewMapScreenArguments viewMapScreenArguments;

  @override
  State<ViewMapScreen> createState() => _ViewMapScreenState();
}

class _ViewMapScreenState extends State<ViewMapScreen>
    with TickerProviderStateMixin {
  late final AnimationController _topSectionAnimationController;
  late final AnimationController _bottomSectionAnimationController;

  late final MapController _mapController;

  late final TextEditingController _pickupTextEditingController;
  late final TextEditingController _destinationTextEditingController;

  late final FocusNode _pickupFocusNode;
  late final FocusNode _destinationFocusNode;

  late final SearchedPlacesCubit _searchedPlacesCubit;
  late final MapRouteCubit _mapRouteCubit;
  late final RideDriverCubit _rideDriverCubit;
  late final RideCubit _rideCubit;

  Address? _pickupAddress;
  Address? _destinationAddress;

  bool _showUpButton = false;

  /// Show source to destination route of user
  bool _showRoute = false;

  /// Stitch Ride Selection Bottom Sheet (Image 4)
  bool _showRideSelection = false;

  /// Selected ride options
  String _selectedVehicleName = 'Saffar Auto';
  double _selectedPrice = 135.0;
  String _selectedPayment = 'Cash';

  bool _showDemoRideCountDown = false;
  int _countDownNumber = 10;

  late final DateTime _startTime;
  Timer? _driverPositionTimer;
  Timer? _countDownTimer;

  void _onShowUpButtonPressed() {
    _topSectionAnimationController.reverse();
    _bottomSectionAnimationController.reverse();
    _mapRouteCubit.clearRoute();
    _showRoute = false;
    _showRideSelection = false;
    setState(() {});
  }

  void _onDonePressed() async {
    _showUpButton = false;
    _bottomSectionAnimationController.removeListener(() {});
    setState(() {});

    if (_pickupAddress != null && _destinationAddress != null) {
      final LatLng sourceLatLng = _pickupAddress!.latLng;
      final LatLng destinationLatLng = _destinationAddress!.latLng;

      await _mapRouteCubit.getRouteFromSourceToDestination(
        context,
        sourceLatLng,
        destinationLatLng,
      );

      _topSectionAnimationController.forward();
      _bottomSectionAnimationController.forward();

      final MapCamera mapCamera = CameraFit.bounds(
        bounds: LatLngBounds(sourceLatLng, destinationLatLng),
        padding: const EdgeInsets.all(80),
      ).fit(_mapController.camera);

      _mapController.move(
        mapCamera.center,
        mapCamera.zoom,
      );

      _showRoute = true;
      _showRideSelection = true;
      setState(() {});
    }
  }

  void _confirmAndBookRide(
      RideOption selectedOption, String paymentMethod, String coupon) async {
    setState(() {
      _selectedVehicleName = selectedOption.name;
      _selectedPrice = selectedOption.price;
      _selectedPayment = paymentMethod;
      _showRideSelection = false;
    });

    if (_pickupAddress != null) {
      await _rideDriverCubit.findRideDriver(
        context,
        _pickupAddress!.latLng,
      );

      final RideDriverState rideDriverState = _rideDriverCubit.state;

      if (rideDriverState is RideDriverGot) {
        _driverPositionTimer = Timer.periodic(
          const Duration(milliseconds: 150),
          (timer) {
            if (timer.tick < rideDriverState.points.length) {
              _rideDriverCubit.moveRideDriverByOnePoint();
            } else {
              _showStartDemoRideCountDown();
              timer.cancel();
            }
          },
        );
      }
    }

    setState(() {});
  }

  void _onAddressSelected(Address address) {
    if (_pickupFocusNode.hasFocus) {
      _pickupTextEditingController.text = ViewHelper.getAddress(address);
      _pickupAddress = address;
      _mapController.move(address.latLng, 13);
      _pickupFocusNode.unfocus();
      _destinationFocusNode.requestFocus();
    } else if (_destinationFocusNode.hasFocus) {
      _destinationTextEditingController.text = ViewHelper.getAddress(address);
      _destinationAddress = address;
      _mapController.move(address.latLng, 13);
      _destinationFocusNode.unfocus();
    }

    setState(() {});
  }

  void _showStartDemoRideCountDown() {
    _showDemoRideCountDown = true;

    _countDownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (timer.tick <= 10) {
          setState(() {
            _countDownNumber = 10 - timer.tick;
          });
        } else {
          _showDemoRideCountDown = false;
          _startRide();
          timer.cancel();
        }
      },
    );
  }

  void _startRide() async {
    _startTime = DateTime.now();

    if (_pickupAddress == null || _destinationAddress == null) {
      return;
    }

    final LatLng sourcePosition = _pickupAddress!.latLng;
    final LatLng destinationPosition = _destinationAddress!.latLng;

    await _rideCubit.getRoutePointsAndStartRide(
      context,
      sourcePosition,
      destinationPosition,
    );

    final MapCamera mapCamera = CameraFit.bounds(
      bounds: LatLngBounds(sourcePosition, destinationPosition),
      padding: const EdgeInsets.all(100),
    ).fit(_mapController.camera);

    _mapController.move(
      mapCamera.center,
      mapCamera.zoom,
    );

    final RideState rideState = _rideCubit.state;

    if (rideState is RideActive) {
      _driverPositionTimer = Timer.periodic(
        const Duration(milliseconds: 150),
        (timer) {
          if (timer.tick < rideState.routePoints.length) {
            _rideCubit.moveRiderByOnePoint();
          } else {
            _rideCubit.endRide();
            timer.cancel();
          }
        },
      );
    }

    _showRoute = true;
    setState(() {});
  }

  void _onCancelRidePressed() {
    final RideDriverState rideDriverState = _rideDriverCubit.state;

    if (rideDriverState is RideDriverGot &&
        _pickupAddress != null &&
        _destinationAddress != null) {
      final User user = context.read<UserCubit>().state.currentUser!;
      final Driver driver = rideDriverState.driver;

      final Ride ride = _rideCubit.createRide(
        user: user,
        driver: driver,
        sourceAddress: _pickupAddress!,
        destinationAddress: _destinationAddress!,
        startTime: DateTime.now(),
        cancelled: true,
        price: 0,
      );
      _rideCubit.addRide(ride);
    }

    _driverPositionTimer?.cancel();
    _countDownTimer?.cancel();
    _rideDriverCubit.emitRideDriverInitialState();
    _onShowUpButtonPressed();
  }

  @override
  void initState() {
    super.initState();

    _searchedPlacesCubit = SearchedPlacesCubit();
    _mapRouteCubit = MapRouteCubit();
    _rideDriverCubit = RideDriverCubit();
    _rideCubit = RideCubit();

    _mapController = MapController();

    final String? initialPickUpAddressString =
        widget.viewMapScreenArguments.initialPickupAddress != null
            ? ViewHelper.getAddress(
                widget.viewMapScreenArguments.initialPickupAddress!,
              )
            : null;
    final String? initialDestinationAddressString =
        widget.viewMapScreenArguments.initialDestinationAddress != null
            ? ViewHelper.getAddress(
                widget.viewMapScreenArguments.initialDestinationAddress!,
              )
            : null;

    _pickupTextEditingController = TextEditingController(
      text: initialPickUpAddressString ?? '',
    );
    _destinationTextEditingController = TextEditingController(
      text: initialDestinationAddressString ?? '',
    );

    _pickupAddress = widget.viewMapScreenArguments.initialPickupAddress;
    _destinationAddress =
        widget.viewMapScreenArguments.initialDestinationAddress;

    _pickupFocusNode = FocusNode();
    _destinationFocusNode = FocusNode();

    _topSectionAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _bottomSectionAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _bottomSectionAnimationController.addListener(() {
      setState(() {
        _showUpButton = _bottomSectionAnimationController.isCompleted;
      });
    });

    _pickupTextEditingController.addListener(() {
      final String searchText = _pickupTextEditingController.text;
      if (searchText.trim().isNotEmpty) {
        _searchedPlacesCubit.searchPlaces(context, searchText);
      }
      if (searchText.isEmpty) {
        _pickupAddress = null;
      }
    });

    _destinationTextEditingController.addListener(() {
      final String searchText = _destinationTextEditingController.text;
      if (searchText.trim().isNotEmpty) {
        _searchedPlacesCubit.searchPlaces(context, searchText);
      }
      if (searchText.isEmpty) {
        _destinationAddress = null;
      }
    });

    _rideDriverCubit.stream.listen((rideDriverState) {
      if (rideDriverState is RideDriverGot) {
        final LatLng vehicleSourcePosition = rideDriverState.points[0];
        final LatLng userPosition =
            _pickupAddress?.latLng ?? MapConfig.defaultCenter;

        final MapCamera mapCamera = CameraFit.bounds(
          bounds: LatLngBounds(vehicleSourcePosition, userPosition),
          padding: const EdgeInsets.all(90),
        ).fit(_mapController.camera);

        _mapController.move(
          mapCamera.center,
          mapCamera.zoom,
        );

        _showRoute = false;
        setState(() {});
      }
    });

    _rideCubit.stream.listen((rideState) {
      final RideDriverState rideDriverState = _rideDriverCubit.state;

      if (rideState is RideCompleted && rideDriverState is RideDriverGot) {
        final Driver driver = rideDriverState.driver;
        _rideDriverCubit.emitRideDriverInitialState();

        Navigator.pushReplacementNamed(
          context,
          PaymentScreen.routeName,
          arguments: PaymentScreenArguments(
            driver: driver,
            sourceAddress: _pickupAddress!,
            destinationAddress: _destinationAddress!,
            startTime: _startTime,
          ),
        );
      }
    });

    // Auto calculate route if initial addresses provided
    if (_pickupAddress != null && _destinationAddress != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _onDonePressed();
      });
    }
  }

  @override
  void dispose() {
    _driverPositionTimer?.cancel();
    _countDownTimer?.cancel();
    _topSectionAnimationController.dispose();
    _bottomSectionAnimationController.dispose();
    _pickupTextEditingController.dispose();
    _destinationTextEditingController.dispose();
    _pickupFocusNode.dispose();
    _destinationFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final user = context.watch<UserCubit>().state.currentUser;

    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _searchedPlacesCubit),
        BlocProvider.value(value: _mapRouteCubit),
        BlocProvider.value(value: _rideDriverCubit),
        BlocProvider.value(value: _rideCubit),
      ],
      child: BlocBuilder<RideDriverCubit, RideDriverState>(
        builder: (context, rideDriverState) {
          return BlocBuilder<RideCubit, RideState>(
            builder: (context, rideState) {
              final bool isDriverActive =
                  rideDriverState is RideDriverGot && rideState is! RideActive;

              return Scaffold(
                body: Stack(
                  children: [
                    // Interactive Map
                    BlocBuilder<MapRouteCubit, MapRouteState>(
                      builder: (context, mapRouteState) {
                        return FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: _pickupAddress?.latLng ??
                                MapConfig.defaultCenter,
                            initialZoom: 13.5,
                          ),
                          children: [
                            MapService.instance.buildTileLayer(),
                            MarkerLayer(
                              markers: [
                                if (_pickupAddress != null)
                                  Marker(
                                    point: _pickupAddress!.latLng,
                                    width: 44,
                                    height: 44,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF20A46B),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white, width: 3),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.2),
                                            blurRadius: 6,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(Icons.person,
                                          color: Colors.white, size: 20),
                                    ),
                                  ),
                                if (_destinationAddress != null)
                                  Marker(
                                    point: _destinationAddress!.latLng,
                                    width: 44,
                                    height: 44,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF6B00),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: Colors.white, width: 3),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.2),
                                            blurRadius: 6,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(Icons.flag_rounded,
                                          color: Colors.white, size: 20),
                                    ),
                                  ),
                                if (rideDriverState is RideDriverGot &&
                                    !_showRoute)
                                  Marker(
                                    point: rideDriverState.points[0],
                                    width: 50,
                                    height: 50,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFEDD5),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Palette.primary, width: 2),
                                      ),
                                      child: const Icon(
                                        Icons.electric_rickshaw_rounded,
                                        color: Palette.primary,
                                        size: 28,
                                      ),
                                    ),
                                  ),
                                if (rideState is RideActive && _showRoute)
                                  Marker(
                                    point: rideState.currentPosition,
                                    width: 50,
                                    height: 50,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFEDD5),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Palette.primary, width: 2),
                                      ),
                                      child: const Icon(
                                        Icons.electric_rickshaw_rounded,
                                        color: Palette.primary,
                                        size: 28,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            PolylineLayer(
                              polylines: [
                                if (mapRouteState is MapRouteGot && _showRoute)
                                  Polyline(
                                    points: mapRouteState.points,
                                    color: Palette.primary,
                                    strokeWidth: 5,
                                  ),
                                if (rideDriverState is RideDriverGot &&
                                    !_showRoute)
                                  Polyline(
                                    points: rideDriverState.points,
                                    color: Palette.primary,
                                    strokeWidth: 5,
                                  ),
                                if (rideState is RideActive && _showRoute)
                                  Polyline(
                                    points: rideState.routePoints,
                                    color: Palette.primary,
                                    strokeWidth: 5,
                                  ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),

                    // Tile Attribution
                    MapService.instance.buildAttributionWidget(context),

                    // Top Bar (Stitch Active Trip / Ride Confirm Top Bar)
                    SafeArea(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            color: Colors.white.withOpacity(0.92),
                            child: Row(
                              children: [
                                IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.arrow_back,
                                      color: Palette.neutral),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: const BoxDecoration(
                                    color: Palette.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.directions_car_filled_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isDriverActive
                                      ? 'Active Trip'
                                      : 'Ride Confirm...',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Palette.neutral,
                                  ),
                                ),
                                const Spacer(),
                                CircleAvatar(
                                  radius: 16,
                                  backgroundImage: NetworkImage(
                                    user?.imageUrl ??
                                        'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150',
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Stitch Distance & Duration Pill (Image 4)
                          if (_showRideSelection)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.navigation_rounded,
                                        color: Color(0xFF20A46B), size: 14),
                                    SizedBox(width: 6),
                                    Text(
                                      '8.4 km • 22 mins',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // Stitch Driver Arriving Live Banner (Image 3)
                          if (isDriverActive)
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
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
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF20A46B),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF20A46B)
                                                .withOpacity(0.4),
                                            blurRadius: 6,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Text(
                                                'Driver arriving in 2 mins',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                  color: Palette.neutral,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFFE2F7ED),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: const Text(
                                                  '450m away',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF0F5A38),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Approaching main entrance lane',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Floating Right Map Controls (Target, Share, SOS)
                    Positioned(
                      right: 16,
                      bottom: isDriverActive ? 520 : (_showRideSelection ? 380 : 120),
                      child: Column(
                        children: [
                          // Re-center button
                          FloatingActionButton.small(
                            heroTag: 'map_center_btn',
                            onPressed: () {
                              if (_pickupAddress != null) {
                                _mapController.move(_pickupAddress!.latLng, 14);
                              }
                            },
                            backgroundColor: Colors.white,
                            child: const Icon(Icons.my_location_rounded,
                                color: Palette.neutral),
                          ),
                          const SizedBox(height: 10),
                          if (isDriverActive) ...[
                            // Share trip button
                            FloatingActionButton.small(
                              heroTag: 'map_share_btn',
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Live trip link copied')),
                                );
                              },
                              backgroundColor: Colors.white,
                              child: const Icon(Icons.share_outlined,
                                  color: Palette.neutral),
                            ),
                            const SizedBox(height: 10),
                            // SOS button
                            GestureDetector(
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Saffar SOS triggered: 112 notified')),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFB91C1C),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFB91C1C)
                                          .withOpacity(0.4),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.shield,
                                        color: Colors.white, size: 14),
                                    SizedBox(width: 4),
                                    Text(
                                      'SOS',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Input & Destination Picker top widget (when not on confirm or active)
                    if (!_showRideSelection && !isDriverActive)
                      SingleChildScrollView(
                        child: SizedBox(
                          height: _showUpButton ? 300 : size.height,
                          width: double.infinity,
                          child: Column(
                            children: [
                              BlocBuilder<MapRouteCubit, MapRouteState>(
                                builder: (context, state) {
                                  return ExpansionAnimationWidget(
                                    controller:
                                        _topSectionAnimationController,
                                    child:
                                        InputPickupAndDestinationLocationWidget(
                                      onDonePressed: _pickupAddress != null &&
                                              _destinationAddress != null
                                          ? () => (state is MapRouteLoading)
                                              ? null
                                              : _onDonePressed()
                                          : null,
                                      pickupTextEditingController:
                                          _pickupTextEditingController,
                                      destinationTextEditingController:
                                          _destinationTextEditingController,
                                      pickupFocusNode: _pickupFocusNode,
                                      destinationFocusNode:
                                          _destinationFocusNode,
                                    ),
                                  );
                                },
                              ),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: AddressListBottomWidget(
                                    onAddressSelected: (address) {
                                      _onAddressSelected(address);
                                    },
                                    animationController:
                                        _bottomSectionAnimationController,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Loading screen
                    if (rideDriverState is RideDriverLoading)
                      Container(
                        height: size.height,
                        width: size.width,
                        color: Colors.black38,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                CircularProgressIndicator(color: Palette.primary),
                                SizedBox(height: 16),
                                Text(
                                  'Finding nearest verified driver...',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Palette.neutral,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                // Bottom Sheets: Stitch Ride Selection OR Active Trip Driver Info
                bottomSheet: _showRideSelection
                    ? RideSelectionBottomSheet(
                        pickupAddressText:
                            _pickupAddress?.street ?? _pickupAddress?.place ?? 'Pickup Location',
                        destinationAddressText:
                            _destinationAddress?.street ?? _destinationAddress?.place ?? 'Destination Location',
                        distanceKm: 8.4,
                        durationMins: 22,
                        onEditRoutePressed: () {
                          setState(() {
                            _showRideSelection = false;
                            _showUpButton = true;
                          });
                        },
                        onBookRidePressed: (option, payment, coupon) {
                          _confirmAndBookRide(option, payment, coupon);
                        },
                      )
                    : (isDriverActive
                        ? Container(
                            height: 500,
                            width: size.width,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(24),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 16,
                                  offset: Offset(0, -4),
                                ),
                              ],
                            ),
                            child: _showDemoRideCountDown
                                ? Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      const Text(
                                        'Starting trip in...',
                                        style: TextStyle(
                                          color: Palette.neutral,
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        '$_countDownNumber',
                                        style: const TextStyle(
                                          color: Palette.primary,
                                          fontSize: 64,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  )
                                : RideDriverInfoWidget(
                                    driver: rideDriverState.driver,
                                    otp: '4829',
                                    pickupSpot:
                                        _pickupAddress?.street ?? _pickupAddress?.place ?? 'Pickup Point',
                                    rideFare: _selectedPrice,
                                    rideType: '$_selectedVehicleName • $_selectedPayment',
                                    onCancelRidePressed: () =>
                                        _onCancelRidePressed(),
                                  ),
                          )
                        : null),
              );
            },
          );
        },
      ),
    );
  }
}
