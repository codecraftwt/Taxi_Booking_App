import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:location/location.dart';
import 'package:saffar_app/core/service_locator.dart';
import 'package:saffar_app/features/driver/data/repositories/driver_repo.dart';

class DriverLocationService {
  DriverLocationService._();
  static final DriverLocationService instance = DriverLocationService._();

  final Location _location = Location();
  final DriverRepo _driverRepo = sl<DriverRepo>();

  StreamSubscription<LocationData>? _subscription;
  String? _authToken;
  bool _isTracking = false;
  bool _isActiveTrip = false;

  final ValueNotifier<LocationData?> currentLocationNotifier = ValueNotifier<LocationData?>(null);
  final ValueNotifier<bool> isTrackingNotifier = ValueNotifier<bool>(false);

  bool get isTracking => _isTracking;
  LocationData? get currentLocation => currentLocationNotifier.value;

  /// Check whether GPS service and permission are granted
  Future<bool> ensureLocationPermissionAndService() async {
    // 1. Check if GPS service is turned on
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        return false;
      }
    }

    // 2. Check permission status
    PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted &&
          permissionGranted != PermissionStatus.grantedLimited) {
        return false;
      }
    }

    if (permissionGranted == PermissionStatus.deniedForever) {
      return false;
    }

    return true;
  }

  /// Get single current location fix
  Future<LocationData?> getCurrentLocation() async {
    try {
      final hasAccess = await ensureLocationPermissionAndService();
      if (!hasAccess) return null;
      final loc = await _location.getLocation();
      currentLocationNotifier.value = loc;
      return loc;
    } catch (e) {
      debugPrint('Error getting current location: $e');
      return null;
    }
  }

  /// Start continuous background location updates when driver goes online
  Future<bool> startLocationTracking({
    required String token,
    bool isActiveTrip = false,
  }) async {
    _authToken = token;
    _isActiveTrip = isActiveTrip;

    final hasAccess = await ensureLocationPermissionAndService();
    if (!hasAccess) return false;

    // Configure battery-efficient parameters
    await _configureLocationSettings(isActiveTrip);

    // Request system background location execution
    try {
      await _location.enableBackgroundMode(enable: true);
    } catch (e) {
      debugPrint('Background mode error (silent fallback): $e');
    }

    // Cancel any previous stream
    await stopLocationTracking();

    _isTracking = true;
    isTrackingNotifier.value = true;

    // Grab immediate fix
    final initialFix = await getCurrentLocation();
    if (initialFix != null && initialFix.latitude != null && initialFix.longitude != null) {
      _sendLocationToServer(initialFix);
    }

    DateTime lastSentTime = DateTime.now();

    _subscription = _location.onLocationChanged.listen(
      (LocationData loc) {
        currentLocationNotifier.value = loc;

        // Throttle updates: minimum 5s during active trip, 10s during idle online
        final minIntervalSecs = _isActiveTrip ? 4 : 8;
        if (DateTime.now().difference(lastSentTime).inSeconds >= minIntervalSecs) {
          lastSentTime = DateTime.now();
          _sendLocationToServer(loc);
        }
      },
      onError: (err) {
        debugPrint('Location stream error: $err');
      },
    );

    return true;
  }

  /// Update tracking interval mode (e.g. switch to active trip mode)
  Future<void> setActiveTripMode(bool isActiveTrip) async {
    if (_isActiveTrip == isActiveTrip) return;
    _isActiveTrip = isActiveTrip;
    if (_isTracking) {
      await _configureLocationSettings(isActiveTrip);
    }
  }

  Future<void> _configureLocationSettings(bool isActiveTrip) async {
    try {
      await _location.changeSettings(
        accuracy: isActiveTrip ? LocationAccuracy.high : LocationAccuracy.balanced,
        interval: isActiveTrip ? 5000 : 10000,
        distanceFilter: isActiveTrip ? 5 : 10,
      );
    } catch (e) {
      debugPrint('Error configuring location settings: $e');
    }
  }

  Future<void> _sendLocationToServer(LocationData loc) async {
    if (_authToken == null || loc.latitude == null || loc.longitude == null) return;
    try {
      await _driverRepo.updateDriverLocation(
        token: _authToken!,
        latitude: loc.latitude!,
        longitude: loc.longitude!,
        heading: loc.heading,
        speed: loc.speed,
        timestamp: loc.time != null ? DateTime.fromMillisecondsSinceEpoch(loc.time!.toInt()) : null,
      );
    } catch (e) {
      debugPrint('Silent location sync error: $e');
    }
  }

  /// Stop location updates when going offline or logging out
  Future<void> stopLocationTracking() async {
    _isTracking = false;
    isTrackingNotifier.value = false;
    await _subscription?.cancel();
    _subscription = null;
  }
}

