import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:saffar_app/features/driver/data/repositories/driver_repo.dart';
import 'package:saffar_app/core/service_locator.dart';

part 'driver_earnings_state.dart';

class DriverEarningsCubit extends Cubit<DriverEarningsState> {
  DriverEarningsCubit() : super(const DriverEarningsState());

  final DriverRepo _driverRepo = sl<DriverRepo>();

  /// Fetch earnings summary and history for a given period or custom date range
  Future<void> fetchEarningsSummary(
    String token, {
    String period = 'today',
    String? fromDate,
    String? toDate,
  }) async {
    emit(state.copyWith(
      isLoading: true,
      clearError: true,
      selectedPeriod: period,
      fromDate: fromDate,
      toDate: toDate,
    ));

    try {
      final earnings = await _driverRepo.getEarningsSummary(
        token,
        period: period,
        fromDate: fromDate,
        toDate: toDate,
      );

      final history = await _driverRepo.getEarningsHistory(
        token,
        period: period,
        fromDate: fromDate,
        toDate: toDate,
      );

      emit(state.copyWith(
        isLoading: false,
        grossEarnings: (earnings['gross_earnings'] as num?)?.toDouble() ?? 0.0,
        netEarnings: (earnings['net_earnings'] as num?)?.toDouble() ?? 0.0,
        platformCommission: (earnings['platform_commission'] as num?)?.toDouble() ?? 0.0,
        otherDeductions: (earnings['other_deductions'] as num?)?.toDouble() ?? 0.0,
        totalEarnings: (earnings['net_earnings'] as num?)?.toDouble() ?? 0.0,
        todayEarnings: (earnings['today_earnings'] as num?)?.toDouble() ?? 0.0,
        weeklyEarnings: (earnings['weekly_earnings'] as num?)?.toDouble() ?? 0.0,
        monthlyEarnings: (earnings['monthly_earnings'] as num?)?.toDouble() ?? 0.0,
        allTimeEarnings: (earnings['all_time_earnings'] as num?)?.toDouble() ?? 0.0,
        completedRides: (earnings['completed_rides'] as num?)?.toInt() ?? 0,
        cancelledRides: (earnings['cancelled_rides'] as num?)?.toInt() ?? 0,
        todayRides: (earnings['today_rides'] as num?)?.toInt() ?? 0,
        weeklyRides: (earnings['weekly_rides'] as num?)?.toInt() ?? 0,
        monthlyRides: (earnings['monthly_rides'] as num?)?.toInt() ?? 0,
        totalCompletedRides: (earnings['total_completed_rides'] as num?)?.toInt() ?? 0,
        selectedPeriod: period,
        fromDate: fromDate,
        toDate: toDate,
        earningsHistory: history,
      ));
    } catch (e) {
      final err = e.toString().replaceAll('CustomException: ', '');
      emit(state.copyWith(isLoading: false, error: err));
    }
  }

  /// Fetch full individual trip earnings breakdown
  Future<Map<String, dynamic>?> fetchTripEarningDetails(String token, String rideId) async {
    emit(state.copyWith(isLoadingTripDetail: true, clearError: true));
    try {
      final details = await _driverRepo.getTripEarningDetails(token, rideId);
      emit(state.copyWith(
        isLoadingTripDetail: false,
        selectedTripEarnings: details,
      ));
      return details;
    } catch (e) {
      final err = e.toString().replaceAll('CustomException: ', '');
      emit(state.copyWith(isLoadingTripDetail: false, error: err));
      return null;
    }
  }
}
