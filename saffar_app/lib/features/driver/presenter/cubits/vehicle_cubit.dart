import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:saffar_app/core/models/vehicle.dart';
import 'package:saffar_app/features/driver/data/repositories/driver_repo.dart';
import 'package:saffar_app/core/service_locator.dart';

part 'vehicle_state.dart';

class VehicleCubit extends Cubit<VehicleState> {
  VehicleCubit() : super(const VehicleState());

  final DriverRepo _driverRepo = sl<DriverRepo>();

  Future<void> fetchVehicles(String token) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final list = await _driverRepo.getVehicles(token);
      emit(state.copyWith(vehicles: list, isLoading: false));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('CustomException: ', ''),
      ));
    }
  }

  Future<void> selectVehicle(Vehicle vehicle) async {
    emit(state.copyWith(selectedVehicle: vehicle, error: null));
  }

  Future<void> fetchVehicleDetails(String token, String id) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final vehicle = await _driverRepo.getVehicleById(token, id);
      emit(state.copyWith(selectedVehicle: vehicle, isLoading: false));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('CustomException: ', ''),
      ));
    }
  }

  Future<Vehicle?> addVehicle(String token, Map<String, dynamic> data) async {
    emit(state.copyWith(isSaving: true, error: null, successMessage: null));
    try {
      final created = await _driverRepo.addVehicle(token, data);
      final updatedList = [created, ...state.vehicles.where((v) => v.id != created.id)];
      emit(state.copyWith(
        vehicles: updatedList,
        selectedVehicle: created,
        isSaving: false,
        successMessage: 'Vehicle added successfully!',
      ));
      return created;
    } catch (e) {
      final err = e.toString().replaceAll('CustomException: ', '');
      emit(state.copyWith(isSaving: false, error: err));
      return null;
    }
  }

  Future<bool> updateVehicle(String token, String id, Map<String, dynamic> data) async {
    emit(state.copyWith(isSaving: true, error: null, successMessage: null));
    try {
      final updated = await _driverRepo.updateVehicle(token, id, data);
      final updatedList = state.vehicles.map((v) => v.id == id ? updated : v).toList();
      emit(state.copyWith(
        vehicles: updatedList,
        selectedVehicle: updated,
        isSaving: false,
        successMessage: 'Vehicle updated successfully!',
      ));
      return true;
    } catch (e) {
      final err = e.toString().replaceAll('CustomException: ', '');
      emit(state.copyWith(isSaving: false, error: err));
      return false;
    }
  }

  Future<bool> uploadDocuments(String token, String id, Map<String, dynamic> docs) async {
    emit(state.copyWith(isSaving: true, error: null, successMessage: null));
    try {
      final updated = await _driverRepo.uploadVehicleDocuments(token, id, docs);
      final updatedList = state.vehicles.map((v) => v.id == id ? updated : v).toList();
      emit(state.copyWith(
        vehicles: updatedList,
        selectedVehicle: updated,
        isSaving: false,
        successMessage: 'Documents submitted & verified successfully!',
      ));
      return true;
    } catch (e) {
      final err = e.toString().replaceAll('CustomException: ', '');
      emit(state.copyWith(isSaving: false, error: err));
      return false;
    }
  }

  Future<bool> activateVehicle(String token, String id) async {
    emit(state.copyWith(isSaving: true, error: null));
    try {
      final activated = await _driverRepo.activateVehicle(token, id);
      final updatedList = state.vehicles.map((v) {
        if (v.id == id) return activated;
        return v.copyWith(isActive: false);
      }).toList();
      emit(state.copyWith(
        vehicles: updatedList,
        selectedVehicle: activated,
        isSaving: false,
        successMessage: '${activated.model} is now your active vehicle!',
      ));
      return true;
    } catch (e) {
      final err = e.toString().replaceAll('CustomException: ', '');
      emit(state.copyWith(isSaving: false, error: err));
      return false;
    }
  }

  Future<bool> deleteVehicle(String token, String id) async {
    emit(state.copyWith(isSaving: true, error: null));
    try {
      await _driverRepo.deleteVehicle(token, id);
      final updatedList = state.vehicles.where((v) => v.id != id).toList();
      emit(state.copyWith(
        vehicles: updatedList,
        clearSelectedVehicle: true,
        isSaving: false,
        successMessage: 'Vehicle removed successfully.',
      ));
      return true;
    } catch (e) {
      final err = e.toString().replaceAll('CustomException: ', '');
      emit(state.copyWith(isSaving: false, error: err));
      return false;
    }
  }

  void clearMessages() {
    emit(state.copyWith(error: null, successMessage: null));
  }
}

