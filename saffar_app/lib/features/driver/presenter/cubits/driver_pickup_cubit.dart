import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:latlong2/latlong.dart';
import 'package:saffar_app/core/service_locator.dart';
import 'package:saffar_app/features/driver/data/repositories/driver_repo.dart';
import 'package:saffar_app/features/driver/presenter/cubits/driver_pickup_state.dart';
import 'package:saffar_app/features/driver/services/driver_location_service.dart';
import 'package:url_launcher/url_launcher.dart';

class DriverPickupCubit extends Cubit<DriverPickupState> {
  DriverPickupCubit() : super(const DriverPickupState()) {
    // Listen to live GPS location updates from DriverLocationService
    DriverLocationService.instance.currentLocationNotifier.addListener(_onLocationUpdate);
  }

  final DriverRepo _driverRepo = sl<DriverRepo>();
  final Distance _distanceCalc = const Distance();

  void _onLocationUpdate() {
    final loc = DriverLocationService.instance.currentLocation;
    if (loc != null && loc.latitude != null && loc.longitude != null) {
      final currentLatLng = LatLng(loc.latitude!, loc.longitude!);
      _updateLiveMetrics(currentLatLng);
    }
  }

  void _updateLiveMetrics(LatLng driverPos) {
    if (state.rideData != null) {
      final pickup = state.rideData?['pickup'] as Map<String, dynamic>?;
      final pLat = pickup?['lat'] as num?;
      final pLon = pickup?['lon'] as num?;

      if (pLat != null && pLon != null) {
        final pickupLatLng = LatLng(pLat.toDouble(), pLon.toDouble());
        final meters = _distanceCalc.as(LengthUnit.Meter, driverPos, pickupLatLng);
        final distanceKm = (meters / 1000.0 * 10).round() / 10.0;
        // Estimate ~25 km/h urban speed -> ~2.4 mins per km
        final eta = (distanceKm / 0.4).ceil().clamp(1, 120);

        emit(state.copyWith(
          driverLocation: driverPos,
          distanceToPickupKm: distanceKm,
          etaMinutes: eta,
        ));
        return;
      }
    }

    emit(state.copyWith(driverLocation: driverPos));
  }

  /// Load assigned booking details from backend
  Future<void> loadAssignedRide(String token, String rideId) async {
    emit(state.copyWith(
      status: DriverPickupStatus.loading,
      rideId: rideId,
      clearError: true,
      clearSuccess: true,
    ));

    try {
      final ride = await _driverRepo.getAssignedRideDetails(token, rideId);
      final bookingStatus = ride['status']?.toString() ?? 'accepted';
      final otp = ride['otp']?.toString();

      // Check current driver GPS
      final gpsLoc = DriverLocationService.instance.currentLocation;
      LatLng? driverLatLng;
      if (gpsLoc != null && gpsLoc.latitude != null && gpsLoc.longitude != null) {
        driverLatLng = LatLng(gpsLoc.latitude!, gpsLoc.longitude!);
      } else if (ride['driver_location']?['lat'] != null && ride['driver_location']?['lng'] != null) {
        driverLatLng = LatLng(
          (ride['driver_location']['lat'] as num).toDouble(),
          (ride['driver_location']['lng'] as num).toDouble(),
        );
      }

      double distanceKm = (ride['distance_to_pickup_km'] as num?)?.toDouble() ?? 1.2;
      int eta = (ride['eta_minutes'] as num?)?.toInt() ?? 4;

      if (driverLatLng != null && ride['pickup']?['lat'] != null && ride['pickup']?['lon'] != null) {
        final pLat = (ride['pickup']['lat'] as num).toDouble();
        final pLon = (ride['pickup']['lon'] as num).toDouble();
        final meters = _distanceCalc.as(LengthUnit.Meter, driverLatLng, LatLng(pLat, pLon));
        distanceKm = (meters / 1000.0 * 10).round() / 10.0;
        eta = (distanceKm / 0.4).ceil().clamp(1, 120);
      }

      emit(state.copyWith(
        status: DriverPickupStatus.loaded,
        rideData: ride,
        driverLocation: driverLatLng,
        distanceToPickupKm: distanceKm,
        etaMinutes: eta,
        bookingStatus: bookingStatus,
        otp: otp,
      ));
    } catch (e) {
      final err = e.toString().replaceAll('CustomException: ', '');
      emit(state.copyWith(
        status: DriverPickupStatus.error,
        errorMessage: err,
      ));
    }
  }

  /// Mark status as reaching pickup (called when driver starts navigation)
  Future<void> startReachingPickup(String token) async {
    final rideId = state.rideId;
    if (rideId == null) return;

    try {
      await _driverRepo.markReachingPickup(token, rideId);
      emit(state.copyWith(
        bookingStatus: 'reaching_pickup',
        successMessage: 'En route to passenger pickup location',
      ));
    } catch (e) {
      final err = e.toString().replaceAll('CustomException: ', '');
      emit(state.copyWith(errorMessage: err));
    }
  }

  /// Mark driver arrival at pickup
  Future<bool> arriveAtPickup(String token) async {
    final rideId = state.rideId;
    if (rideId == null) return false;

    emit(state.copyWith(isActionLoading: true, clearError: true));

    try {
      await _driverRepo.markDriverArrived(token, rideId);

      emit(state.copyWith(
        isActionLoading: false,
        bookingStatus: 'arrived',
        successMessage: 'You have arrived at the pickup spot! Passenger has been notified.',
      ));
      return true;
    } catch (e) {
      final err = e.toString().replaceAll('CustomException: ', '');
      emit(state.copyWith(
        isActionLoading: false,
        errorMessage: err,
      ));
      return false;
    }
  }

  /// Verify Passenger Ride-Start OTP and transition ride to Trip Started
  Future<bool> verifyOtpAndStartTrip(String token, String otp) async {
    final rideId = state.rideId;
    if (rideId == null) return false;

    emit(state.copyWith(isActionLoading: true, clearError: true));

    try {
      await _driverRepo.verifyRideStartOtp(token, rideId, otp);

      emit(state.copyWith(
        isActionLoading: false,
        bookingStatus: 'started',
        successMessage: '🎉 OTP verified successfully! Trip has started.',
      ));
      return true;
    } catch (e) {
      final err = e.toString().replaceAll('CustomException: ', '');
      emit(state.copyWith(
        isActionLoading: false,
        errorMessage: err,
      ));
      return false;
    }
  }

  /// Complete Ride when driver reaches destination
  Future<Map<String, dynamic>?> completeTrip(String token, {double? actualDistanceKm, double? finalFare}) async {
    final rideId = state.rideId;
    if (rideId == null) return null;

    emit(state.copyWith(isActionLoading: true, clearError: true));

    try {
      final result = await _driverRepo.completeRide(
        token,
        rideId,
        actualDistanceKm: actualDistanceKm,
        finalFare: finalFare,
      );

      emit(state.copyWith(
        isActionLoading: false,
        bookingStatus: 'completed',
        completedRideData: result,
        successMessage: '🎉 Trip completed successfully! Earnings added to your account.',
      ));
      return result;
    } catch (e) {
      final err = e.toString().replaceAll('CustomException: ', '');
      emit(state.copyWith(
        isActionLoading: false,
        errorMessage: err,
      ));
      return null;
    }
  }

  /// Cancel an assigned ride
  Future<bool> cancelRide(String token, {required String reason, String? notes}) async {
    final rideId = state.rideId;
    if (rideId == null) return false;

    emit(state.copyWith(isActionLoading: true, clearError: true));

    try {
      final result = await _driverRepo.cancelRide(
        token,
        rideId,
        reason: reason,
        notes: notes,
      );

      emit(state.copyWith(
        isActionLoading: false,
        bookingStatus: 'cancelled',
        cancellationData: result['cancellation'] as Map<String, dynamic>?,
        successMessage: 'Ride cancelled successfully.',
      ));
      return true;
    } catch (e) {
      final err = e.toString().replaceAll('CustomException: ', '');
      emit(state.copyWith(
        isActionLoading: false,
        errorMessage: err,
      ));
      return false;
    }
  }

  /// Launch external turn-by-turn navigation (Google Maps)
  Future<void> launchNavigation({bool toDestination = false, String? token}) async {
    final Map<String, dynamic>? target = toDestination
        ? (state.rideData?['destination'] as Map<String, dynamic>?)
        : (state.rideData?['pickup'] as Map<String, dynamic>?);
    final lat = target?['lat'] as num?;
    final lon = target?['lon'] as num?;

    if (lat == null || lon == null) {
      emit(state.copyWith(errorMessage: '${toDestination ? "Destination" : "Pickup"} coordinates unavailable for navigation'));
      return;
    }

    // If still in 'accepted' status, transition to 'reaching_pickup'
    if (token != null && state.bookingStatus == 'accepted') {
      startReachingPickup(token);
    }

    final nativeNavUri = Uri.parse('google.navigation:q=$lat,$lon&mode=d');
    final webMapsUri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lon');

    try {
      if (await canLaunchUrl(nativeNavUri)) {
        await launchUrl(nativeNavUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webMapsUri)) {
        await launchUrl(webMapsUri, mode: LaunchMode.externalApplication);
      } else {
        emit(state.copyWith(errorMessage: 'Could not open map navigation application.'));
      }
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Failed to launch navigation: $e'));
    }
  }

  /// Launch phone call to passenger
  Future<void> callPassenger() async {
    final passenger = state.rideData?['passenger'] as Map<String, dynamic>?;
    final phone = passenger?['phone']?.toString();

    if (phone == null || phone.trim().isEmpty) {
      emit(state.copyWith(errorMessage: 'Passenger phone number not available.'));
      return;
    }

    final telUri = Uri.parse('tel:$phone');
    try {
      if (await canLaunchUrl(telUri)) {
        await launchUrl(telUri);
      } else {
        emit(state.copyWith(errorMessage: 'Could not launch dialer for phone: $phone'));
      }
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Error launching call: $e'));
    }
  }

  @override
  Future<void> close() {
    DriverLocationService.instance.currentLocationNotifier.removeListener(_onLocationUpdate);
    return super.close();
  }
}

