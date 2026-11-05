part of 'driver_earnings_cubit.dart';

@immutable
class DriverEarningsState {
  const DriverEarningsState({
    this.grossEarnings = 0.0,
    this.netEarnings = 0.0,
    this.platformCommission = 0.0,
    this.otherDeductions = 0.0,
    this.totalEarnings = 0.0,
    this.todayEarnings = 0.0,
    this.weeklyEarnings = 0.0,
    this.monthlyEarnings = 0.0,
    this.allTimeEarnings = 0.0,
    this.completedRides = 0,
    this.cancelledRides = 0,
    this.todayRides = 0,
    this.weeklyRides = 0,
    this.monthlyRides = 0,
    this.totalCompletedRides = 0,
    this.selectedPeriod = 'today', // 'today', 'this_week', 'this_month', 'custom'
    this.fromDate,
    this.toDate,
    this.earningsHistory = const [],
    this.selectedTripEarnings,
    this.isLoadingTripDetail = false,
    this.isLoading = false,
    this.error,
  });

  final double grossEarnings;
  final double netEarnings;
  final double platformCommission;
  final double otherDeductions;
  final double totalEarnings;
  final double todayEarnings;
  final double weeklyEarnings;
  final double monthlyEarnings;
  final double allTimeEarnings;
  final int completedRides;
  final int cancelledRides;
  final int todayRides;
  final int weeklyRides;
  final int monthlyRides;
  final int totalCompletedRides;
  final String selectedPeriod;
  final String? fromDate;
  final String? toDate;
  final List<dynamic> earningsHistory;
  final Map<String, dynamic>? selectedTripEarnings;
  final bool isLoadingTripDetail;
  final bool isLoading;
  final String? error;

  DriverEarningsState copyWith({
    double? grossEarnings,
    double? netEarnings,
    double? platformCommission,
    double? otherDeductions,
    double? totalEarnings,
    double? todayEarnings,
    double? weeklyEarnings,
    double? monthlyEarnings,
    double? allTimeEarnings,
    int? completedRides,
    int? cancelledRides,
    int? todayRides,
    int? weeklyRides,
    int? monthlyRides,
    int? totalCompletedRides,
    String? selectedPeriod,
    String? fromDate,
    String? toDate,
    List<dynamic>? earningsHistory,
    Map<String, dynamic>? selectedTripEarnings,
    bool? isLoadingTripDetail,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearDates = false,
  }) {
    return DriverEarningsState(
      grossEarnings: grossEarnings ?? this.grossEarnings,
      netEarnings: netEarnings ?? this.netEarnings,
      platformCommission: platformCommission ?? this.platformCommission,
      otherDeductions: otherDeductions ?? this.otherDeductions,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      todayEarnings: todayEarnings ?? this.todayEarnings,
      weeklyEarnings: weeklyEarnings ?? this.weeklyEarnings,
      monthlyEarnings: monthlyEarnings ?? this.monthlyEarnings,
      allTimeEarnings: allTimeEarnings ?? this.allTimeEarnings,
      completedRides: completedRides ?? this.completedRides,
      cancelledRides: cancelledRides ?? this.cancelledRides,
      todayRides: todayRides ?? this.todayRides,
      weeklyRides: weeklyRides ?? this.weeklyRides,
      monthlyRides: monthlyRides ?? this.monthlyRides,
      totalCompletedRides: totalCompletedRides ?? this.totalCompletedRides,
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
      fromDate: clearDates ? null : (fromDate ?? this.fromDate),
      toDate: clearDates ? null : (toDate ?? this.toDate),
      earningsHistory: earningsHistory ?? this.earningsHistory,
      selectedTripEarnings: selectedTripEarnings ?? this.selectedTripEarnings,
      isLoadingTripDetail: isLoadingTripDetail ?? this.isLoadingTripDetail,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
