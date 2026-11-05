part of 'ride_request_cubit.dart';

class RideRequestState {
  const RideRequestState({
    this.pendingRequests = const [],
    this.activeRequest,
    this.isLoading = false,
    this.isActionLoading = false,
    this.acceptedRide,
    this.error,
    this.successMessage,
  });

  final List<RideRequest> pendingRequests;
  final RideRequest? activeRequest;
  final bool isLoading;
  final bool isActionLoading;
  final Map<String, dynamic>? acceptedRide;
  final String? error;
  final String? successMessage;

  RideRequestState copyWith({
    List<RideRequest>? pendingRequests,
    RideRequest? activeRequest,
    bool clearActiveRequest = false,
    bool? isLoading,
    bool? isActionLoading,
    Map<String, dynamic>? acceptedRide,
    bool clearAcceptedRide = false,
    String? error,
    bool clearError = false,
    String? successMessage,
    bool clearSuccess = false,
  }) {
    return RideRequestState(
      pendingRequests: pendingRequests ?? this.pendingRequests,
      activeRequest: clearActiveRequest ? null : (activeRequest ?? this.activeRequest),
      isLoading: isLoading ?? this.isLoading,
      isActionLoading: isActionLoading ?? this.isActionLoading,
      acceptedRide: clearAcceptedRide ? null : (acceptedRide ?? this.acceptedRide),
      error: clearError ? null : (error ?? this.error),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

