import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

enum DriverPickupStatus { initial, loading, loaded, arriving, arrived, error }

@immutable
class DriverPickupState {
  const DriverPickupState({
    this.status = DriverPickupStatus.initial,
    this.rideId,
    this.rideData,
    this.driverLocation,
    this.distanceToPickupKm,
    this.etaMinutes,
    this.bookingStatus = 'accepted', // 'accepted' | 'reaching_pickup' | 'arrived'
    this.otp,
    this.isActionLoading = false,
    this.isPermissionDenied = false,
    this.isGpsDisabled = false,
    this.errorMessage,
    this.successMessage,
    this.remainingOtpAttempts,
    this.completedRideData,
    this.cancellationData,
  });

  final DriverPickupStatus status;
  final String? rideId;
  final Map<String, dynamic>? rideData;
  final LatLng? driverLocation;
  final double? distanceToPickupKm;
  final int? etaMinutes;
  final String bookingStatus;
  final String? otp;
  final bool isActionLoading;
  final bool isPermissionDenied;
  final bool isGpsDisabled;
  final String? errorMessage;
  final String? successMessage;
  final int? remainingOtpAttempts;
  final Map<String, dynamic>? completedRideData;
  final Map<String, dynamic>? cancellationData;

  bool get isLoading => status == DriverPickupStatus.loading;
  bool get hasArrived => bookingStatus == 'arrived';
  bool get isReaching => bookingStatus == 'reaching_pickup';
  bool get isTripStarted => bookingStatus == 'started' || bookingStatus == 'in_progress';
  bool get isTripCompleted => bookingStatus == 'completed';
  bool get isCancelled => bookingStatus == 'cancelled';

  DriverPickupState copyWith({
    DriverPickupStatus? status,
    String? rideId,
    Map<String, dynamic>? rideData,
    LatLng? driverLocation,
    double? distanceToPickupKm,
    int? etaMinutes,
    String? bookingStatus,
    String? otp,
    bool? isActionLoading,
    bool? isPermissionDenied,
    bool? isGpsDisabled,
    String? errorMessage,
    String? successMessage,
    int? remainingOtpAttempts,
    Map<String, dynamic>? completedRideData,
    Map<String, dynamic>? cancellationData,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return DriverPickupState(
      status: status ?? this.status,
      rideId: rideId ?? this.rideId,
      rideData: rideData ?? this.rideData,
      driverLocation: driverLocation ?? this.driverLocation,
      distanceToPickupKm: distanceToPickupKm ?? this.distanceToPickupKm,
      etaMinutes: etaMinutes ?? this.etaMinutes,
      bookingStatus: bookingStatus ?? this.bookingStatus,
      otp: otp ?? this.otp,
      isActionLoading: isActionLoading ?? this.isActionLoading,
      isPermissionDenied: isPermissionDenied ?? this.isPermissionDenied,
      isGpsDisabled: isGpsDisabled ?? this.isGpsDisabled,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
      remainingOtpAttempts: remainingOtpAttempts ?? this.remainingOtpAttempts,
      completedRideData: completedRideData ?? this.completedRideData,
      cancellationData: cancellationData ?? this.cancellationData,
    );
  }
}

