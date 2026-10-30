part of 'driver_dashboard_cubit.dart';

@immutable
class DriverDashboardState {
  const DriverDashboardState({
    this.todayEarnings = 0,
    this.todayRides = 0,
    this.totalRides = 0,
    this.isOnline = false,
    this.activeRide,
    this.isLoading = false,
    this.error,
  });

  final double todayEarnings;
  final int todayRides;
  final int totalRides;
  final bool isOnline;
  final Map<String, dynamic>? activeRide;
  final bool isLoading;
  final String? error;

  DriverDashboardState copyWith({
    double? todayEarnings,
    int? todayRides,
    int? totalRides,
    bool? isOnline,
    Map<String, dynamic>? activeRide,
    bool? isLoading,
    String? error,
  }) {
    return DriverDashboardState(
      todayEarnings: todayEarnings ?? this.todayEarnings,
      todayRides: todayRides ?? this.todayRides,
      totalRides: totalRides ?? this.totalRides,
      isOnline: isOnline ?? this.isOnline,
      activeRide: activeRide ?? this.activeRide,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}
