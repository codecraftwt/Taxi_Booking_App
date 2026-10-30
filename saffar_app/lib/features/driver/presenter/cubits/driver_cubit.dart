import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:saffar_app/core/models/driver.dart';
import 'package:saffar_app/features/driver/data/repositories/driver_repo.dart';
import 'package:saffar_app/core/service_locator.dart';

part 'driver_state.dart';

class DriverCubit extends Cubit<DriverState> {
  DriverCubit() : super(const DriverState());

  final DriverRepo _driverRepo = sl<DriverRepo>();

  /// Try restoring session from local storage
  Future<void> tryRestoreSession() async {
    try {
      await _driverRepo.initDriverRepo();
      final driverMap = _driverRepo.getDriverMapFromLocalStorage();
      final token = _driverRepo.getTokenFromLocalStorage();
      if (driverMap != null && token != null) {
        final driver = Driver.fromMap(Map<String, dynamic>.from(driverMap));
        emit(DriverState(currentDriver: driver, token: token));
      }
    } catch (_) {
      // No stored session
    }
  }

  /// Sign in and persist session
  Future<void> signIn({required String phone, required String password}) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final result = await _driverRepo.driverSignIn(phone: phone, password: password);
      final driver = result['driver'] as Driver;
      final token = result['token'] as String;

      await _driverRepo.putDriverMapInLocalStorage(driver.toMap());
      await _driverRepo.putTokenInLocalStorage(token);

      emit(DriverState(currentDriver: driver, token: token));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString().replaceAll('CustomException: ', '')));
    }
  }

  /// Sign up and persist session
  Future<void> signUp({
    required String name,
    required String phone,
    required String password,
    required String vehicleName,
    required String vehicleNumber,
  }) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final result = await _driverRepo.driverSignUp(
        name: name,
        phone: phone,
        password: password,
        vehicleName: vehicleName,
        vehicleNumber: vehicleNumber,
      );
      final driver = result['driver'] as Driver;
      final token = result['token'] as String;

      await _driverRepo.putDriverMapInLocalStorage(driver.toMap());
      await _driverRepo.putTokenInLocalStorage(token);

      emit(DriverState(currentDriver: driver, token: token));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString().replaceAll('CustomException: ', '')));
    }
  }

  /// Toggle online/offline
  Future<void> toggleAvailability(bool active) async {
    if (state.token == null) return;
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final updatedDriver = await _driverRepo.toggleAvailability(state.token!, active);
      await _driverRepo.putDriverMapInLocalStorage(updatedDriver.toMap());
      emit(DriverState(currentDriver: updatedDriver, token: state.token));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString().replaceAll('CustomException: ', '')));
    }
  }

  /// Refresh profile from server
  Future<void> refreshProfile() async {
    if (state.token == null) return;
    try {
      final driver = await _driverRepo.getDriverProfile(state.token!);
      await _driverRepo.putDriverMapInLocalStorage(driver.toMap());
      emit(DriverState(currentDriver: driver, token: state.token));
    } catch (_) {}
  }

  /// Update profile
  Future<void> updateProfile(Map<String, dynamic> fields) async {
    if (state.token == null) return;
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final driver = await _driverRepo.updateDriverProfile(state.token!, fields);
      await _driverRepo.putDriverMapInLocalStorage(driver.toMap());
      emit(DriverState(currentDriver: driver, token: state.token));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString().replaceAll('CustomException: ', '')));
    }
  }

  /// Set driver and token explicitly
  void emitDriverAndToken(Driver driver, String token) {
    _driverRepo.putDriverMapInLocalStorage(driver.toMap());
    _driverRepo.putTokenInLocalStorage(token);
    emit(DriverState(currentDriver: driver, token: token));
  }

  /// Logout
  Future<void> logout() async {
    await _driverRepo.clearDriverLocalStorage();
    emit(const DriverState());
  }

  /// Clear error
  void clearError() {
    emit(state.copyWith(error: null));
  }
}

