import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:saffar_app/core/constants/strings.dart';
import 'package:saffar_app/core/errors/custom_exception.dart';
import 'package:saffar_app/core/models/driver.dart';
import 'package:saffar_app/core/service_locator.dart';

class DriverRepo {
  final Dio _dio = sl<Dio>();
  final HiveInterface _hive = sl<HiveInterface>();
  Box? _driverBox;

  /// Initialize driver local storage box
  Future<void> initDriverRepo() async {
    try {
      if (!_hive.isBoxOpen('driver_box')) {
        _driverBox = await _hive.openBox('driver_box');
      } else {
        _driverBox = _hive.box('driver_box');
      }
    } catch (e) {
      throw CustomException(message: e.toString());
    }
  }

  // ─── Local Storage ───────────────────────────────────

  Future<void> putDriverMapInLocalStorage(Map<dynamic, dynamic> driverMap) async {
    if (_driverBox == null) await initDriverRepo();
    await _driverBox!.put('current_driver', driverMap);
  }

  Future<void> putTokenInLocalStorage(String token) async {
    if (_driverBox == null) await initDriverRepo();
    await _driverBox!.put('driver_token', token);
  }

  Map<dynamic, dynamic>? getDriverMapFromLocalStorage() {
    if (_driverBox == null) return null;
    return _driverBox!.get('current_driver');
  }

  String? getTokenFromLocalStorage() {
    if (_driverBox == null) return null;
    return _driverBox!.get('driver_token');
  }

  Future<void> clearDriverLocalStorage() async {
    if (_driverBox == null) await initDriverRepo();
    await _driverBox!.delete('current_driver');
    await _driverBox!.delete('driver_token');
  }

  // ─── Auth API ────────────────────────────────────────

  Future<Map<String, dynamic>> driverSignIn({
    required String phone,
    required String password,
  }) async {
    try {
      final Response response = await _dio.post(
        '${Strings.baseApiUrl}/auth/driver_sign_in',
        data: {'phone': phone, 'password': password},
      );
      final data = response.data as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return {
          'driver': Driver.fromMap(Map<String, dynamic>.from(data['driver'])),
          'token': data['token'],
        };
      }
      throw CustomException(
        code: data['error']?['code']?.toString(),
        message: data['error']?['message']?.toString() ?? 'Driver sign in failed',
      );
    } on DioException catch (e) {
      throw CustomException(
        code: e.response?.data?['error']?['code']?.toString(),
        message: e.response?.data?['error']?['message']?.toString() ?? e.message,
      );
    }
  }

  Future<Map<String, dynamic>> driverSignUp({
    required String name,
    required String phone,
    required String password,
    required String vehicleName,
    required String vehicleNumber,
  }) async {
    try {
      final Response response = await _dio.post(
        '${Strings.baseApiUrl}/auth/driver_sign_up',
        data: {
          'name': name,
          'phone': phone,
          'password': password,
          'vehicle_name': vehicleName,
          'vehicle_number': vehicleNumber,
        },
      );
      final data = response.data as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return {
          'driver': data['driver'] != null
              ? Driver.fromMap(Map<String, dynamic>.from(data['driver']))
              : Driver(
                  id: 'temp_id',
                  name: name,
                  phone: phone,
                  vehicleName: vehicleName,
                  vehicleNumber: vehicleNumber,
                  active: true,
                ),
          'token': data['token'],
        };
      }
      throw CustomException(
        code: data['error']?['code']?.toString(),
        message: data['error']?['message']?.toString() ?? 'Driver sign up failed',
      );
    } on DioException catch (e) {
      throw CustomException(
        code: e.response?.data?['error']?['code']?.toString(),
        message: e.response?.data?['error']?['message']?.toString() ?? e.message,
      );
    }
  }

  // ─── Profile API ─────────────────────────────────────

  Future<Driver> getDriverProfile(String token) async {
    try {
      final response = await _dio.get(
        '${Strings.baseApiUrl}/driver/profile',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = response.data as Map<String, dynamic>;
      return Driver.fromMap(Map<String, dynamic>.from(data['driver']));
    } on DioException catch (e) {
      throw CustomException(
        message: e.response?.data?['error']?['message']?.toString() ?? 'Failed to fetch profile',
      );
    }
  }

  Future<Driver> updateDriverProfile(String token, Map<String, dynamic> fields) async {
    try {
      final response = await _dio.patch(
        '${Strings.baseApiUrl}/driver/profile',
        data: fields,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = response.data as Map<String, dynamic>;
      return Driver.fromMap(Map<String, dynamic>.from(data['driver']));
    } on DioException catch (e) {
      throw CustomException(
        message: e.response?.data?['error']?['message']?.toString() ?? 'Failed to update profile',
      );
    }
  }

  // ─── Availability API ────────────────────────────────

  Future<Driver> toggleAvailability(String token, bool active) async {
    try {
      final response = await _dio.post(
        '${Strings.baseApiUrl}/driver/availability',
        data: {'active': active},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = response.data as Map<String, dynamic>;
      return Driver.fromMap(Map<String, dynamic>.from(data['driver']));
    } on DioException catch (e) {
      throw CustomException(
        message: e.response?.data?['error']?['message']?.toString() ?? 'Failed to toggle availability',
      );
    }
  }

  // ─── Dashboard API ───────────────────────────────────

  Future<Map<String, dynamic>> getDashboardStats(String token) async {
    try {
      final response = await _dio.get(
        '${Strings.baseApiUrl}/driver/dashboard',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return (response.data as Map<String, dynamic>)['stats'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw CustomException(
        message: e.response?.data?['error']?['message']?.toString() ?? 'Failed to fetch dashboard',
      );
    }
  }

  // ─── Rides API ───────────────────────────────────────

  Future<Map<String, dynamic>> getRideHistory(String token, {int page = 1, int limit = 20, String? status}) async {
    try {
      final queryParams = <String, dynamic>{'page': page, 'limit': limit};
      if (status != null) queryParams['status'] = status;
      final response = await _dio.get(
        '${Strings.baseApiUrl}/driver/rides/history',
        queryParameters: queryParams,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw CustomException(
        message: e.response?.data?['error']?['message']?.toString() ?? 'Failed to fetch ride history',
      );
    }
  }

  Future<void> completeRide(String token, String rideId) async {
    try {
      await _dio.post(
        '${Strings.baseApiUrl}/driver/rides/$rideId/complete',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } on DioException catch (e) {
      throw CustomException(
        message: e.response?.data?['error']?['message']?.toString() ?? 'Failed to complete ride',
      );
    }
  }

  // ─── Earnings API ────────────────────────────────────

  Future<Map<String, dynamic>> getEarningsSummary(String token, {String period = 'daily'}) async {
    try {
      final response = await _dio.get(
        '${Strings.baseApiUrl}/driver/earnings/summary',
        queryParameters: {'period': period},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return (response.data as Map<String, dynamic>)['earnings'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw CustomException(
        message: e.response?.data?['error']?['message']?.toString() ?? 'Failed to fetch earnings',
      );
    }
  }

  Future<List<dynamic>> getEarningsHistory(String token, {int page = 1, int limit = 20}) async {
    try {
      final response = await _dio.get(
        '${Strings.baseApiUrl}/driver/earnings/history',
        queryParameters: {'page': page, 'limit': limit},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return (response.data as Map<String, dynamic>)['rides'] as List<dynamic>;
    } on DioException catch (e) {
      throw CustomException(
        message: e.response?.data?['error']?['message']?.toString() ?? 'Failed to fetch earnings history',
      );
    }
  }
}
