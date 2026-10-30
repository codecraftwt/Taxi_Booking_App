import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:saffar_app/features/driver/data/repositories/driver_repo.dart';
import 'package:saffar_app/core/service_locator.dart';

part 'driver_rides_state.dart';

class DriverRidesCubit extends Cubit<DriverRidesState> {
  DriverRidesCubit() : super(const DriverRidesState());

  final DriverRepo _driverRepo = sl<DriverRepo>();

  Future<void> fetchRides(String token, {String? status, int page = 1}) async {
    emit(state.copyWith(isLoading: true, error: null, selectedFilter: status));
    try {
      final result = await _driverRepo.getRideHistory(token, page: page, status: status);
      final rides = result['rides'] as List<dynamic>? ?? [];
      final pagination = result['pagination'] as Map<String, dynamic>?;
      emit(DriverRidesState(
        rides: rides,
        selectedFilter: status,
        currentPage: pagination?['page'] as int? ?? 1,
        totalRides: pagination?['total'] as int? ?? 0,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
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

