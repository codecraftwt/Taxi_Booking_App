part of 'driver_cubit.dart';

@immutable
class DriverState {
  const DriverState({
    this.currentDriver,
    this.token,
    this.isLoading = false,
    this.error,
  });

  final Driver? currentDriver;
  final String? token;
  final bool isLoading;
  final String? error;

  bool get isLoggedIn => currentDriver != null && token != null;
  bool get isOnline => currentDriver?.active ?? false;

  DriverState copyWith({
    Driver? currentDriver,
    String? token,
    bool? isLoading,
    String? error,
  }) {
    return DriverState(
      currentDriver: currentDriver ?? this.currentDriver,
      token: token ?? this.token,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}
