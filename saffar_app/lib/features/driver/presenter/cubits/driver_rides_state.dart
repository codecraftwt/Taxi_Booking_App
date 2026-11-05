part of 'driver_rides_cubit.dart';

@immutable
class DriverRidesState {
  const DriverRidesState({
    this.rides = const [],
    this.categoryCounts = const {
      'all': 0,
      'assigned': 0,
      'ongoing': 0,
      'completed': 0,
      'cancelled': 0,
    },
    this.selectedFilter = 'all',
    this.selectedPeriod = 'all',
    this.currentPage = 1,
    this.totalRides = 0,
    this.isLoading = false,
    this.selectedTripDetails,
    this.isLoadingDetails = false,
    this.error,
  });

  final List<dynamic> rides;
  final Map<String, int> categoryCounts;
  final String selectedFilter;
  final String selectedPeriod;
  final int currentPage;
  final int totalRides;
  final bool isLoading;
  final Map<String, dynamic>? selectedTripDetails;
  final bool isLoadingDetails;
  final String? error;

  DriverRidesState copyWith({
    List<dynamic>? rides,
    Map<String, int>? categoryCounts,
    String? selectedFilter,
    String? selectedPeriod,
    int? currentPage,
    int? totalRides,
    bool? isLoading,
    Map<String, dynamic>? selectedTripDetails,
    bool? isLoadingDetails,
    String? error,
  }) {
    return DriverRidesState(
      rides: rides ?? this.rides,
      categoryCounts: categoryCounts ?? this.categoryCounts,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
      currentPage: currentPage ?? this.currentPage,
      totalRides: totalRides ?? this.totalRides,
      isLoading: isLoading ?? this.isLoading,
      selectedTripDetails: selectedTripDetails ?? this.selectedTripDetails,
      isLoadingDetails: isLoadingDetails ?? this.isLoadingDetails,
      error: error,
    );
  }
}
