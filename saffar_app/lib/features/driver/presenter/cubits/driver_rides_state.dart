part of 'driver_rides_cubit.dart';

@immutable
class DriverRidesState {
  const DriverRidesState({
    this.rides = const [],
    this.selectedFilter,
    this.currentPage = 1,
    this.totalRides = 0,
    this.isLoading = false,
    this.error,
  });

  final List<dynamic> rides;
  final String? selectedFilter;
  final int currentPage;
  final int totalRides;
  final bool isLoading;
  final String? error;

  DriverRidesState copyWith({
    List<dynamic>? rides,
    String? selectedFilter,
    int? currentPage,
    int? totalRides,
    bool? isLoading,
    String? error,
  }) {
    return DriverRidesState(
      rides: rides ?? this.rides,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      currentPage: currentPage ?? this.currentPage,
      totalRides: totalRides ?? this.totalRides,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}
