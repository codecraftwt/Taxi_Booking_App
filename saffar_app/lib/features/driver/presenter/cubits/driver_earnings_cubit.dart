import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:saffar_app/features/driver/data/repositories/driver_repo.dart';
import 'package:saffar_app/core/service_locator.dart';

part 'driver_earnings_state.dart';

class DriverEarningsCubit extends Cubit<DriverEarningsState> {
  DriverEarningsCubit() : super(const DriverEarningsState());

  final DriverRepo _driverRepo = sl<DriverRepo>();

  Future<void> fetchEarningsSummary(String token, {String period = 'daily'}) async {
    emit(state.copyWith(isLoading: true, error: null, selectedPeriod: period));
    try {
      final earnings = await _driverRepo.getEarningsSummary(token, period: period);
      final history = await _driverRepo.getEarningsHistory(token);
      emit(DriverEarningsState(
        totalEarnings: (earnings['total_earnings'] as num?)?.toDouble() ?? 0,
        netEarnings: (earnings['net_earnings'] as num?)?.toDouble() ?? 0,
        totalDiscounts: (earnings['total_discounts'] as num?)?.toDouble() ?? 0,
        completedRides: (earnings['completed_rides'] as num?)?.toInt() ?? 0,
        cancelledRides: (earnings['cancelled_rides'] as num?)?.toInt() ?? 0,
        selectedPeriod: period,
        earningsHistory: history,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }
}

