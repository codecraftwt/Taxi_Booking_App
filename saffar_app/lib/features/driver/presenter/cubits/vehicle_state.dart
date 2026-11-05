part of 'vehicle_cubit.dart';

@immutable
class VehicleState {
  const VehicleState({
    this.vehicles = const [],
    this.selectedVehicle,
    this.isLoading = false,
    this.isSaving = false,
    this.error,
    this.successMessage,
  });

  final List<Vehicle> vehicles;
  final Vehicle? selectedVehicle;
  final bool isLoading;
  final bool isSaving;
  final String? error;
  final String? successMessage;

  Vehicle? get activeVehicle {
    try {
      return vehicles.firstWhere((v) => v.isActive);
    } catch (_) {
      return vehicles.isNotEmpty ? vehicles.first : null;
    }
  }

  VehicleState copyWith({
    List<Vehicle>? vehicles,
    Vehicle? selectedVehicle,
    bool? isLoading,
    bool? isSaving,
    String? error,
    String? successMessage,
    bool clearSelectedVehicle = false,
  }) {
    return VehicleState(
      vehicles: vehicles ?? this.vehicles,
      selectedVehicle: clearSelectedVehicle ? null : (selectedVehicle ?? this.selectedVehicle),
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: error,
      successMessage: successMessage,
    );
  }
}

