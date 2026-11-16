import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:saffar_app/core/config/map_config.dart';
import 'package:saffar_app/core/constants/nums.dart';
import 'package:saffar_app/core/palette.dart';
import 'package:saffar_app/core/service_locator.dart';
import 'package:saffar_app/core/services/map_service.dart';
import 'package:saffar_app/core/widgets/map_marker_widgets.dart';
import 'package:saffar_app/features/driver/data/repositories/driver_repo.dart';
import 'package:saffar_app/features/driver/presenter/cubits/driver_cubit.dart';
import 'package:saffar_app/features/driver/presenter/cubits/driver_dashboard_cubit.dart';
import 'package:saffar_app/features/driver/presenter/screens/driver_active_trip_screen.dart';
import 'package:saffar_app/features/driver/presenter/screens/driver_pickup_navigation_screen.dart';
import 'package:saffar_app/features/driver/presenter/screens/driver_vehicles_screen.dart';
import 'package:saffar_app/features/driver/presenter/screens/ride_otp_verification_screen.dart';
import 'package:saffar_app/features/driver/services/driver_location_service.dart';
import 'package:saffar_app/features/driver/presenter/cubits/ride_request_cubit.dart';
import 'package:saffar_app/features/driver/presenter/widgets/incoming_ride_request_dialog.dart';
import 'package:saffar_app/features/driver/services/driver_socket_service.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({Key? key}) : super(key: key);

  static const String routeName = '/driver_dashboard';

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  bool _hasActiveTrip = false;
  late final MapController _dashMapController;
  Timer? _statusPollingTimer;

  @override
  void initState() {
    super.initState();
    _dashMapController = MapController();
    _loadDashboard();
    _initSocketAndRequestListener();
    _acquireInitialDriverLocation();
    _setupStatusPolling();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkActiveTripAndRestore();
    });
  }

  void _setupStatusPolling() {
    _statusPollingTimer?.cancel();
    _statusPollingTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) {
        final driver = context.read<DriverCubit>().state.currentDriver;
        if (driver != null && driver.verificationStatus.toLowerCase() != 'approved') {
          context.read<DriverCubit>().refreshProfile();
        } else if (driver != null && driver.verificationStatus.toLowerCase() == 'approved') {
          _statusPollingTimer?.cancel();
        }
      }
    });
  }

  Future<void> _acquireInitialDriverLocation() async {
    try {
      final loc = await DriverLocationService.instance.getCurrentLocation();
      if (loc != null && loc.latitude != null && loc.longitude != null && mounted) {
        final pos = LatLng(loc.latitude!, loc.longitude!);
        _dashMapController.move(pos, 15.0);
        setState(() {});
      }
    } catch (e) {
      debugPrint('[DRIVER DASHBOARD] Initial location error: $e');
    }
  }

  Future<void> _checkActiveTripAndRestore() async {
    final token = context.read<DriverCubit>().state.token;
    if (token == null) return;

    try {
      final trip = await sl<DriverRepo>().getActiveTrip(token);
      if (trip != null && mounted) {
        setState(() {
          _hasActiveTrip = true;
        });
        final rideId = trip['ride_id']?.toString() ?? trip['id']?.toString();
        final status = trip['status']?.toString();
        if (rideId != null && status != null) {
          if (status == 'accepted' || status == 'reaching_pickup') {
            Navigator.pushNamed(
              context,
              DriverPickupNavigationScreen.routeName,
              arguments: {'ride_id': rideId},
            ).then((_) {
              if (mounted) _checkActiveTripAndRestore();
            });
          } else if (status == 'arrived') {
            Navigator.pushNamed(
              context,
              RideOtpVerificationScreen.routeName,
              arguments: {
                'ride_id': rideId,
                'passenger_name': trip['passenger_name']?.toString() ?? 'Passenger',
                'pickup_address': trip['pickup_address']?.toString() ?? 'Pickup Spot',
                'fare': '₹${((trip['price'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
              },
            ).then((_) {
              if (mounted) _checkActiveTripAndRestore();
            });
          } else if (status == 'in_progress' || status == 'started') {
            Navigator.pushNamed(
              context,
              DriverActiveTripScreen.routeName,
              arguments: {'ride_id': rideId},
            ).then((_) {
              if (mounted) _checkActiveTripAndRestore();
            });
          }
        }
      } else {
        if (mounted && _hasActiveTrip) {
          setState(() {
            _hasActiveTrip = false;
          });
        }
      }
    } catch (_) {}
  }

  void _initSocketAndRequestListener() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final driver = context.read<DriverCubit>().state.currentDriver;
      final token = context.read<DriverCubit>().state.token;
      if (driver != null) {
        DriverSocketService.instance.connect(driver.id);
        if (driver.isOnline && token != null) {
          context.read<RideRequestCubit>().fetchPendingRequests(token);
        }
      }
    });

    DriverSocketService.instance.incomingRequestNotifier.addListener(_onNewIncomingRequest);
    DriverSocketService.instance.alertNotificationNotifier.addListener(_onSocketAlert);
    DriverSocketService.instance.driverStatusNotifier.addListener(_onDriverStatusUpdated);
    DriverSocketService.instance.fareUpdatedNotifier.addListener(_onFareConfigUpdated);
  }

  void _onFareConfigUpdated() {
    if (mounted) {
      _loadDashboard();
      final fare = DriverSocketService.instance.fareUpdatedNotifier.value;
      if (fare != null) {
        final cat = fare['category']?.toString() ?? 'Rates';
        final base = fare['base_fare'];
        final perKm = fare['per_km'];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚡ City Fare Updated for $cat: Base ₹$base, ₹$perKm/km'),
            backgroundColor: const Color(0xFF1E293B),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _onDriverStatusUpdated() {
    final statusData = DriverSocketService.instance.driverStatusNotifier.value;
    if (statusData != null && mounted) {
      final newStatus = statusData['verification_status']?.toString();
      final action = statusData['action']?.toString();

      // Immediately sync driver profile from backend
      context.read<DriverCubit>().refreshProfile();

      if (action == 'approve' || newStatus == 'approved') {
        _statusPollingTimer?.cancel();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.verified_rounded, color: Colors.white),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '🎉 Account Approved! You can now turn the toggle ON to go live.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 5),
          ),
        );
      } else if (action == 'reject' || newStatus == 'rejected') {
        final reason = statusData['reason']?.toString() ?? 'Documents verification failed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Account rejected by Super Admin: $reason'),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _onNewIncomingRequest() {
    if (_hasActiveTrip) return; // Guard: driver is already engaged in an active trip
    final req = DriverSocketService.instance.incomingRequestNotifier.value;
    if (req != null && mounted) {
      IncomingRideRequestDialog.show(context, req);
    }
  }

  void _onSocketAlert() {
    final alert = DriverSocketService.instance.alertNotificationNotifier.value;
    if (alert != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(alert), backgroundColor: Palette.primary),
      );
      DriverSocketService.instance.alertNotificationNotifier.value = null;
    }
  }

  @override
  void dispose() {
    _statusPollingTimer?.cancel();
    DriverSocketService.instance.incomingRequestNotifier.removeListener(_onNewIncomingRequest);
    DriverSocketService.instance.alertNotificationNotifier.removeListener(_onSocketAlert);
    DriverSocketService.instance.driverStatusNotifier.removeListener(_onDriverStatusUpdated);
    DriverSocketService.instance.fareUpdatedNotifier.removeListener(_onFareConfigUpdated);
    super.dispose();
  }

  void _loadDashboard() {
    final driverState = context.read<DriverCubit>().state;
    if (driverState.token != null) {
      context.read<DriverCubit>().refreshProfile();
      context.read<DriverDashboardCubit>().fetchDashboard(driverState.token!);
      if (driverState.currentDriver?.isOnline == true) {
        context.read<RideRequestCubit>().fetchPendingRequests(driverState.token!);
      }
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _loadDashboard(),
          color: Palette.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: Nums.horizontalPadding,
              vertical: 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 14),
                _buildVerificationNoticeBanner(),
                _buildOnlineToggle(),
                const SizedBox(height: 20),
                _buildLiveDriverMapPreview(),
                _buildPendingRequestBanner(),
                _buildStatsCards(),
                const SizedBox(height: 20),
                _buildActiveRideCard(),
                const SizedBox(height: 20),
                _buildQuickActions(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return BlocBuilder<DriverCubit, DriverState>(
      builder: (context, state) {
        final driver = state.currentDriver;
        return Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Palette.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: driver?.imageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.network(
                        driver!.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.person_rounded,
                          color: Palette.primary,
                          size: 28,
                        ),
                      ),
                    )
                  : Icon(
                      Icons.person_rounded,
                      color: Palette.primary,
                      size: 28,
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getGreeting(),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    driver?.name ?? 'Driver',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: IconButton(
                onPressed: () {
                  // TODO: Notifications
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Notifications coming soon')),
                  );
                },
                icon: Icon(
                  Icons.notifications_outlined,
                  color: Colors.grey.shade700,
                  size: 24,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleToggleAvailability(bool targetStatus) async {
    final currentDriver = context.read<DriverCubit>().state.currentDriver;
    final status = (currentDriver?.verificationStatus ?? 'pending').toLowerCase();

    // Guard: Driver cannot go online if not yet approved by Super Admin
    if (targetStatus && status != 'approved') {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.lock_clock_rounded, color: Palette.primary, size: 26),
              SizedBox(width: 10),
              Text('Approval Required', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            ],
          ),
          content: Text(
            status == 'rejected'
                ? 'Your driver account was not approved by Super Admin. Please contact support or update your compliance documents.'
                : 'Your driver account is currently PENDING review by the Saffar Super Admin.\n\nYou cannot go online or accept passenger rides until your vehicle and documents are officially approved.',
            style: const TextStyle(fontSize: 14, height: 1.45),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: Palette.primary),
              child: const Text('Understood', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    final success = await context.read<DriverCubit>().toggleAvailability(targetStatus);
    if (success && mounted) {
      final driver = context.read<DriverCubit>().state.currentDriver;
      final token = context.read<DriverCubit>().state.token;
      if (driver != null) {
        if (targetStatus) {
          DriverSocketService.instance.connect(driver.id);
          if (token != null) {
            context.read<RideRequestCubit>().fetchPendingRequests(token);
          }
        } else {
          DriverSocketService.instance.disconnect();
          context.read<RideRequestCubit>().dismissActiveRequest();
        }
      }
    } else if (!success && mounted) {
      final error = context.read<DriverCubit>().state.error;
      if (error != null) {
        _showEligibilityOrPermissionDialog(error);
      }
    }
  }

  Widget _buildPendingRequestBanner() {
    return BlocBuilder<RideRequestCubit, RideRequestState>(
      builder: (context, state) {
        final req = state.activeRequest;
        if (req == null) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF59E0B)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFF59E0B),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Incoming Ride: ${req.passengerName}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF78350F)),
                    ),
                    Text(
                      'Fare: ₹${req.fare.toStringAsFixed(0)} • ${req.distanceToPickup}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () => IncomingRideRequestDialog.show(context, req),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Review', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEligibilityOrPermissionDialog(String error) {
    final isVehicleError = error.toLowerCase().contains('vehicle') || error.toLowerCase().contains('document');
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(
              isVehicleError ? Icons.directions_car_filled_rounded : Icons.location_off_rounded,
              color: Palette.primary,
              size: 26,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isVehicleError ? 'Vehicle Verification Needed' : 'Location Required',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Text(
          error,
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Dismiss', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          if (isVehicleError)
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Palette.primary),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, DriverVehiclesScreen.routeName);
              },
              child: const Text('Manage Vehicles', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildVerificationNoticeBanner() {
    return BlocBuilder<DriverCubit, DriverState>(
      builder: (context, driverState) {
        final status = (driverState.currentDriver?.verificationStatus ?? 'pending').toLowerCase();
        if (status == 'approved') return const SizedBox.shrink();

        final isPending = status == 'pending';
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isPending ? const Color(0xFFFEF3C7) : const Color(0xFFFEE2E2),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isPending ? const Color(0xFFF59E0B) : const Color(0xFFEF4444),
              width: 1.2,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isPending ? Icons.pending_actions_rounded : Icons.gpp_bad_rounded,
                color: isPending ? const Color(0xFFD97706) : const Color(0xFFDC2626),
                size: 26,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPending ? 'Account Pending Super Admin Approval' : 'Account Rejected / Inactive',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: isPending ? const Color(0xFF92400E) : const Color(0xFF991B1B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isPending
                          ? 'Your vehicle details & compliance documents have been submitted to Super Admin. You will be authorized to go live on duty once approved.'
                          : 'Your driver account was not approved by Super Admin. Please contact support or update your vehicle documents.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: isPending ? const Color(0xFFB45309) : const Color(0xFFB91C1C),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOnlineToggle() {
    return BlocBuilder<DriverCubit, DriverState>(
      builder: (context, driverState) {
        final isApproved = (driverState.currentDriver?.verificationStatus ?? 'pending').toLowerCase() == 'approved';
        final isOnline = isApproved && (driverState.currentDriver?.active ?? false);
        final isLoading = driverState.isLoading;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isOnline
                  ? [const Color(0xFF15803D), const Color(0xFF16A34A)]
                  : [const Color(0xFF0F172A), const Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: (isOnline ? const Color(0xFF15803D) : const Color(0xFF0F172A))
                    .withValues(alpha: 0.35),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: isOnline
                                    ? const Color(0xFF4ADE80)
                                    : (isApproved ? Colors.grey.shade500 : const Color(0xFFF59E0B)),
                                shape: BoxShape.circle,
                                boxShadow: isOnline
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF4ADE80).withValues(alpha: 0.6),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isOnline
                                  ? 'LIVE ON DUTY'
                                  : (!isApproved ? 'PENDING APPROVAL' : 'OFFLINE / OFF DUTY'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: isOnline
                                    ? const Color(0xFFBBF7D0)
                                    : (!isApproved ? const Color(0xFFFCD34D) : Colors.grey.shade400),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          !isApproved
                              ? 'Awaiting Super Admin approval to go live'
                              : (isOnline ? 'Accepting ride requests' : 'Go online to start receiving rides'),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: isLoading ? null : () => _handleToggleAvailability(!isOnline),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 66,
                      height: 36,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: isOnline
                            ? Colors.white.withValues(alpha: 0.35)
                            : (!isApproved ? const Color(0xFFD97706).withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.15)),
                        border: !isApproved ? Border.all(color: const Color(0xFFF59E0B), width: 1.5) : null,
                      ),
                      child: AnimatedAlign(
                        duration: const Duration(milliseconds: 300),
                        alignment: isOnline ? Alignment.centerRight : Alignment.centerLeft,
                        child: isLoading
                            ? const SizedBox(
                                width: 30,
                                height: 30,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 5,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  !isApproved
                                      ? Icons.lock_rounded
                                      : (isOnline ? Icons.power_settings_new_rounded : Icons.power_off_outlined),
                                  size: 18,
                                  color: !isApproved
                                      ? const Color(0xFFD97706)
                                      : (isOnline ? const Color(0xFF15803D) : Colors.grey.shade700),
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 12),

              // GPS / Location Status Indicator
              ValueListenableBuilder<LocationData?>(
                valueListenable: DriverLocationService.instance.currentLocationNotifier,
                builder: (context, loc, _) {
                  if (isOnline) {
                    final latStr = loc?.latitude != null ? loc!.latitude!.toStringAsFixed(4) : (driverState.currentDriver?.currentLat?.toStringAsFixed(4) ?? 'Locating...');
                    final lngStr = loc?.longitude != null ? loc!.longitude!.toStringAsFixed(4) : (driverState.currentDriver?.currentLng?.toStringAsFixed(4) ?? '');
                    final speedStr = (loc?.speed != null && loc!.speed! > 0)
                        ? ' • ${(loc.speed! * 3.6).toStringAsFixed(0)} km/h'
                        : '';

                    return Row(
                      children: [
                        const Icon(Icons.gps_fixed_rounded, color: Color(0xFF4ADE80), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'GPS: $latStr, $lngStr$speedStr (Streaming live)',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'ACTIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Icon(Icons.location_off_outlined, color: Colors.grey.shade400, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Location updates paused to conserve battery',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLiveDriverMapPreview() {
    return BlocBuilder<DriverCubit, DriverState>(
      builder: (context, driverState) {
        final isOnline = driverState.currentDriver?.active ?? false;
        if (!isOnline) return const SizedBox.shrink();

        return ValueListenableBuilder<LocationData?>(
          valueListenable: DriverLocationService.instance.currentLocationNotifier,
          builder: (context, loc, _) {
            final locData = loc ?? DriverLocationService.instance.currentLocation;
            final lat = locData?.latitude ?? driverState.currentDriver?.currentLat ?? MapConfig.defaultCenter.latitude;
            final lon = locData?.longitude ?? driverState.currentDriver?.currentLng ?? MapConfig.defaultCenter.longitude;
            final driverPos = LatLng(lat, lon);
            final heading = locData?.heading ?? driverState.currentDriver?.heading ?? 0.0;
            final category = driverState.currentDriver?.vehicleName ?? 'Auto';

            return Container(
              margin: const EdgeInsets.only(bottom: 20),
              height: 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _dashMapController,
                      options: MapOptions(
                        initialCenter: driverPos,
                        initialZoom: 15.0,
                      ),
                      children: [
                        MapService.instance.buildTileLayer(),
                        MarkerLayer(
                          markers: [
                            MapMarkerWidgets.buildDriverLiveMarker(
                              position: driverPos,
                              heading: heading,
                              category: category,
                            ),
                          ],
                        ),
                      ],
                    ),
                    MapService.instance.buildAttributionWidget(context),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: GestureDetector(
                        onTap: () async {
                          final fresh = await DriverLocationService.instance.getCurrentLocation();
                          if (fresh != null && fresh.latitude != null && fresh.longitude != null) {
                            _dashMapController.move(LatLng(fresh.latitude!, fresh.longitude!), 15.0);
                          } else {
                            _dashMapController.move(driverPos, 15.0);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.my_location_rounded, color: Palette.secondary, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatsCards() {
    return BlocBuilder<DriverDashboardCubit, DriverDashboardState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          );
        }

        return Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.currency_rupee_rounded,
                label: "Today's Earnings",
                value: '₹${state.todayEarnings.toStringAsFixed(0)}',
                color: const Color(0xFFFF6F00),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.directions_car_rounded,
                label: "Today's Rides",
                value: '${state.todayRides}',
                color: const Color(0xFF219653),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.star_rounded,
                label: 'Total Rides',
                value: '${state.totalRides}',
                color: const Color(0xFF6C63FF),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActiveRideCard() {
    return BlocBuilder<DriverDashboardCubit, DriverDashboardState>(
      builder: (context, state) {
        if (state.activeRide == null) return const SizedBox.shrink();

        final ride = Map<String, dynamic>.from(state.activeRide!);
        final pickup = ride['source_address'] is Map ? Map<String, dynamic>.from(ride['source_address'] as Map) : null;
        final destination = ride['destination_address'] is Map ? Map<String, dynamic>.from(ride['destination_address'] as Map) : null;
        final passenger = ride['passenger'] is Map ? Map<String, dynamic>.from(ride['passenger'] as Map) : null;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Palette.primary.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: Palette.primary.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Palette.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'ACTIVE RIDE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Palette.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '₹${ride['price']?.toString() ?? '—'}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (passenger != null)
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      passenger['name']?.toString() ?? 'Passenger',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              _AddressRow(
                icon: Icons.circle,
                iconColor: const Color(0xFF219653),
                iconSize: 10,
                text: pickup?['street']?.toString() ?? pickup?['place']?.toString() ?? 'Pickup',
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Container(
                  width: 2,
                  height: 20,
                  color: Colors.grey.shade300,
                ),
              ),
              _AddressRow(
                icon: Icons.circle,
                iconColor: Palette.primary,
                iconSize: 10,
                text: destination?['street']?.toString() ?? destination?['place']?.toString() ?? 'Destination',
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      DriverPickupNavigationScreen.routeName,
                      arguments: {'ride_id': ride['id']?.toString()},
                    );
                  },
                  icon: const Icon(Icons.navigation_rounded, size: 18),
                  label: const Text(
                    'Open Pickup Navigation',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Palette.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _QuickAction(
              icon: Icons.account_balance_wallet_rounded,
              label: 'Earnings',
              color: const Color(0xFFFF6F00),
              onTap: () {
                // Navigate to Earnings tab via shell
                final shellState = context.findAncestorStateOfType<State>();
                if (shellState != null && shellState.mounted) {
                  // Will be handled by parent shell
                }
              },
            ),
            const SizedBox(width: 12),
            _QuickAction(
              icon: Icons.history_rounded,
              label: 'Trip History',
              color: const Color(0xFF6C63FF),
              onTap: () {},
            ),
            const SizedBox(width: 12),
            _QuickAction(
              icon: Icons.help_outline_rounded,
              label: 'Support',
              color: const Color(0xFF219653),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Support: Contact admin at support@saffar.com')),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  const _AddressRow({
    required this.icon,
    required this.iconColor,
    required this.iconSize,
    required this.text,
  });

  final IconData icon;
  final Color iconColor;
  final double iconSize;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: iconSize),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
