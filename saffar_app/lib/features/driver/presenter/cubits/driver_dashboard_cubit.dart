import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:saffar_app/features/driver/data/repositories/driver_repo.dart';
import 'package:saffar_app/core/service_locator.dart';

part 'driver_dashboard_state.dart';

class DriverDashboardCubit extends Cubit<DriverDashboardState> {
  DriverDashboardCubit() : super(const DriverDashboardState());

  final DriverRepo _driverRepo = sl<DriverRepo>();

  Future<void> fetchDashboard(String token) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final stats = await _driverRepo.getDashboardStats(token);
      emit(DriverDashboardState(
        todayEarnings: (stats['today_earnings'] as num?)?.toDouble() ?? 0,
        todayRides: (stats['today_rides'] as num?)?.toInt() ?? 0,
        totalRides: (stats['total_rides'] as num?)?.toInt() ?? 0,
        isOnline: stats['is_online'] as bool? ?? false,
        activeRide: stats['active_ride'] as Map<String, dynamic>?,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }
}

