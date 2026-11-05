import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:saffar_app/features/driver/data/repositories/driver_repo.dart';
import 'package:saffar_app/core/service_locator.dart';

part 'driver_rides_state.dart';

class DriverRidesCubit extends Cubit<DriverRidesState> {
  DriverRidesCubit() : super(const DriverRidesState());

  final DriverRepo _driverRepo = sl<DriverRepo>();

  Future<void> fetchRides(
    String token, {
    String? status,
    String? period,
    String? fromDate,
    String? toDate,
    int page = 1,
  }) async {
    final activeStatus = status ?? state.selectedFilter;
    final activePeriod = period ?? state.selectedPeriod;

    emit(state.copyWith(
      isLoading: true,
      error: null,
      selectedFilter: activeStatus,
      selectedPeriod: activePeriod,
    ));

    try {
      final result = await _driverRepo.getRideHistory(
        token,
        page: page,
        status: activeStatus == 'all' ? null : activeStatus,
        period: activePeriod == 'all' ? null : activePeriod,
        fromDate: fromDate,
        toDate: toDate,
      );

      final rides = result['rides'] as List<dynamic>? ?? [];
      final pagination = result['pagination'] as Map<String, dynamic>?;
      final rawCounts = result['category_counts'] as Map<String, dynamic>? ?? {};

      final counts = <String, int>{
        'all': (rawCounts['all'] as num?)?.toInt() ?? 0,
        'assigned': (rawCounts['assigned'] as num?)?.toInt() ?? 0,
        'ongoing': (rawCounts['ongoing'] as num?)?.toInt() ?? 0,
        'completed': (rawCounts['completed'] as num?)?.toInt() ?? 0,
        'cancelled': (rawCounts['cancelled'] as num?)?.toInt() ?? 0,
      };

      emit(state.copyWith(
        rides: rides,
        categoryCounts: counts,
        selectedFilter: activeStatus,
        selectedPeriod: activePeriod,
        currentPage: pagination?['page'] as int? ?? 1,
        totalRides: pagination?['total'] as int? ?? 0,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> fetchTripDetails(String token, String rideId) async {
    emit(state.copyWith(isLoadingDetails: true, error: null));
    try {
      final details = await _driverRepo.getDriverTripDetails(token, rideId);
      emit(state.copyWith(
        selectedTripDetails: details,
        isLoadingDetails: false,
      ));
    } catch (e) {
      emit(state.copyWith(isLoadingDetails: false, error: e.toString()));
    }
  }

  void clearTripDetails() {
    emit(state.copyWith(selectedTripDetails: null));
  }

  Future<void> completeRide(String token, String rideId) async {
    try {
      await _driverRepo.completeRide(token, rideId);
      await fetchRides(token, status: state.selectedFilter);
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }
}
