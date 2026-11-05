import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:saffar_app/core/models/driver.dart';
import 'package:saffar_app/features/driver/data/repositories/driver_repo.dart';
import 'package:saffar_app/features/driver/services/driver_location_service.dart';
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
        if (driver.isOnline) {
          DriverLocationService.instance.startLocationTracking(token: token);
        }
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
    String? vehicleModel,
    String? email,
  }) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final result = await _driverRepo.driverSignUp(
        name: name,
        phone: phone,
        password: password,
        vehicleName: vehicleName,
        vehicleNumber: vehicleNumber,
        vehicleModel: vehicleModel,
        email: email,
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

  /// Request password reset token
  Future<Map<String, dynamic>> forgotPassword(String phone) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final res = await _driverRepo.driverForgotPassword(phone: phone);
      emit(state.copyWith(isLoading: false));
      return res;
    } catch (e) {
      final errMsg = e.toString().replaceAll('CustomException: ', '');
      emit(state.copyWith(isLoading: false, error: errMsg));
      rethrow;
    }
  }

  /// Reset password and log in
  Future<void> resetPassword({
    required String phone,
    required String newPassword,
    String? resetToken,
  }) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final result = await _driverRepo.driverResetPassword(
        phone: phone,
        newPassword: newPassword,
        resetToken: resetToken,
      );
      final driver = result['driver'] as Driver;
      final token = result['token'] as String;

      await _driverRepo.putDriverMapInLocalStorage(driver.toMap());
      await _driverRepo.putTokenInLocalStorage(token);

      emit(DriverState(currentDriver: driver, token: token));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString().replaceAll('CustomException: ', '')));
      rethrow;
    }
  }

  /// Upload driver photo
  Future<void> uploadPhoto(String base64Image) async {
    if (state.token == null) return;
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final driver = await _driverRepo.uploadDriverPhoto(state.token!, base64Image);
      await _driverRepo.putDriverMapInLocalStorage(driver.toMap());
      emit(DriverState(currentDriver: driver, token: state.token));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString().replaceAll('CustomException: ', '')));
    }
  }

  /// Toggle online/offline availability
  Future<bool> toggleAvailability(bool isOnline) async {
    if (state.token == null) return false;
    emit(state.copyWith(isLoading: true, error: null));

    try {
      double? lat;
      double? lng;
      double? heading;
      double? speed;

      if (isOnline) {
        // 1. Ensure GPS permission and hardware service are enabled
        final hasPermission = await DriverLocationService.instance.ensureLocationPermissionAndService();
        if (!hasPermission) {
          emit(state.copyWith(
            isLoading: false,
            error: 'GPS location permission is required to go online and receive ride bookings.',
          ));
          return false;
        }

        // 2. Fetch immediate location fix
        final loc = await DriverLocationService.instance.getCurrentLocation();
        lat = loc?.latitude;
        lng = loc?.longitude;
        heading = loc?.heading;
        speed = loc?.speed;
      }

      // 3. Update status on backend
      final updatedDriver = await _driverRepo.toggleAvailability(
        token: state.token!,
        isOnline: isOnline,
        latitude: lat,
        longitude: lng,
        heading: heading,
        speed: speed,
      );

      await _driverRepo.putDriverMapInLocalStorage(updatedDriver.toMap());
      emit(DriverState(currentDriver: updatedDriver, token: state.token));

      // 4. Start or stop background location tracking
      if (isOnline) {
        await DriverLocationService.instance.startLocationTracking(token: state.token!);
      } else {
        await DriverLocationService.instance.stopLocationTracking();
      }

      return true;
    } catch (e) {
      final errorMsg = e.toString().replaceAll('CustomException: ', '');
      emit(state.copyWith(isLoading: false, error: errorMsg));
      return false;
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

  Future<void> fetchProfile() => refreshProfile();

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
    await DriverLocationService.instance.stopLocationTracking();
    await _driverRepo.clearDriverLocalStorage();
    emit(const DriverState());
  }

  /// Clear error
  void clearError() {
    emit(state.copyWith(error: null));
  }
}

