part of 'driver_earnings_cubit.dart';

@immutable
class DriverEarningsState {
  const DriverEarningsState({
    this.totalEarnings = 0,
    this.netEarnings = 0,
    this.totalDiscounts = 0,
    this.completedRides = 0,
    this.cancelledRides = 0,
    this.selectedPeriod = 'daily',
    this.earningsHistory = const [],
    this.isLoading = false,
    this.error,
  });

  final double totalEarnings;
  final double netEarnings;
  final double totalDiscounts;
  final int completedRides;
  final int cancelledRides;
  final String selectedPeriod;
  final List<dynamic> earningsHistory;
  final bool isLoading;
  final String? error;

  DriverEarningsState copyWith({
    double? totalEarnings,
    double? netEarnings,
    double? totalDiscounts,
    int? completedRides,
    int? cancelledRides,
    String? selectedPeriod,
    List<dynamic>? earningsHistory,
    bool? isLoading,
    String? error,
  }) {
    return DriverEarningsState(
      totalEarnings: totalEarnings ?? this.totalEarnings,
      netEarnings: netEarnings ?? this.netEarnings,
      totalDiscounts: totalDiscounts ?? this.totalDiscounts,
      completedRides: completedRides ?? this.completedRides,
      cancelledRides: cancelledRides ?? this.cancelledRides,
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
      earningsHistory: earningsHistory ?? this.earningsHistory,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}
