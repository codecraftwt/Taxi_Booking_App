import 'package:bloc/bloc.dart';
import 'package:saffar_app/core/models/ride_request.dart';
import 'package:saffar_app/core/service_locator.dart';
import 'package:saffar_app/features/driver/data/repositories/driver_repo.dart';
import 'package:saffar_app/features/driver/services/driver_socket_service.dart';

part 'ride_request_state.dart';

class RideRequestCubit extends Cubit<RideRequestState> {
  RideRequestCubit() : super(const RideRequestState()) {
    // Listen to incoming socket ride requests
    DriverSocketService.instance.incomingRequestNotifier.addListener(_onIncomingSocketRequest);
  }

  final DriverRepo _driverRepo = sl<DriverRepo>();

  void _onIncomingSocketRequest() {
    final incoming = DriverSocketService.instance.incomingRequestNotifier.value;
    if (incoming != null) {
      final updatedList = [incoming, ...state.pendingRequests.where((r) => r.rideId != incoming.rideId)];
      emit(state.copyWith(
        activeRequest: incoming,
        pendingRequests: updatedList,
      ));
    } else {
      emit(state.copyWith(clearActiveRequest: true));
    }
  }

  /// Manually set the active request (e.g. from list)
  void setActiveRequest(RideRequest? req) {
    emit(state.copyWith(
      activeRequest: req,
      clearActiveRequest: req == null,
    ));
  }

  /// Poll pending ride requests from server
  Future<void> fetchPendingRequests(String token) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final list = await _driverRepo.getPendingRideRequests(token);
      final active = list.isNotEmpty ? list.first : null;
      emit(state.copyWith(
        pendingRequests: list,
        activeRequest: active,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('CustomException: ', ''),
      ));
    }
  }

  /// Accept an incoming ride request
  Future<Map<String, dynamic>?> acceptRide(String token, String rideId) async {
    emit(state.copyWith(isActionLoading: true, clearError: true, clearSuccess: true));
    try {
      final result = await _driverRepo.acceptRide(token, rideId);
      final updatedList = state.pendingRequests.where((r) => r.rideId != rideId).toList();
      DriverSocketService.instance.clearCurrentRequest();

      emit(state.copyWith(
        isActionLoading: false,
        acceptedRide: result['ride'] as Map<String, dynamic>?,
        pendingRequests: updatedList,
        clearActiveRequest: true,
        successMessage: 'Ride accepted successfully! Navigating to pickup...',
      ));

      return result['ride'] as Map<String, dynamic>?;
    } catch (e) {
      final err = e.toString().replaceAll('CustomException: ', '');
      emit(state.copyWith(
        isActionLoading: false,
        error: err,
      ));
      return null;
    }
  }

  /// Reject an incoming ride request
  Future<void> rejectRide(String token, String rideId) async {
    emit(state.copyWith(isActionLoading: true, clearError: true));
    try {
      await _driverRepo.rejectRide(token, rideId);
      final updatedList = state.pendingRequests.where((r) => r.rideId != rideId).toList();
      DriverSocketService.instance.clearCurrentRequest();

      emit(state.copyWith(
        isActionLoading: false,
        pendingRequests: updatedList,
        clearActiveRequest: true,
      ));
    } catch (e) {
      final err = e.toString().replaceAll('CustomException: ', '');
      emit(state.copyWith(
        isActionLoading: false,
        error: err,
      ));
    }
  }

  /// Dismiss an expired or closed request
  void dismissActiveRequest() {
    DriverSocketService.instance.clearCurrentRequest();
    emit(state.copyWith(clearActiveRequest: true));
  }

  void clearMessages() {
    emit(state.copyWith(clearError: true, clearSuccess: true));
  }

  @override
  Future<void> close() {
    DriverSocketService.instance.incomingRequestNotifier.removeListener(_onIncomingSocketRequest);
    return super.close();
  }
}

