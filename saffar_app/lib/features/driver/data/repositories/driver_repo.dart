import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:saffar_app/core/constants/strings.dart';
import 'package:saffar_app/core/errors/custom_exception.dart';
import 'package:saffar_app/core/models/driver.dart';
import 'package:saffar_app/core/models/ride_request.dart';
import 'package:saffar_app/core/models/vehicle.dart';
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

  Future<List<Map<String, dynamic>>> getVehicleFares() async {
    try {
      final response = await _dio.get('${Strings.baseApiUrl}/auth/fares');
      if (response.data != null && response.data['fares'] != null) {
        return List<Map<String, dynamic>>.from(response.data['fares']);
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>> driverSignUp({
    required String name,
    required String phone,
    required String password,
    required String vehicleName,
    required String vehicleNumber,
    String? vehicleModel,
    String? vehicleCategory,
    String? email,
    String? dlNumber,
    String? dlExpiry,
    String? dlDoc,
    String? rcNumber,
    String? rcDoc,
    String? insuranceNumber,
    String? insuranceExpiry,
    String? insuranceDoc,
    String? aadhaarNumber,
    String? aadhaarDoc,
  }) async {
    try {
      final payload = <String, dynamic>{
        'name': name,
        'phone': phone,
        'password': password,
        'vehicle_name': vehicleName,
        'vehicle_number': vehicleNumber,
      };
      if (vehicleModel != null && vehicleModel.isNotEmpty) {
        payload['vehicle_model'] = vehicleModel;
      }
      if (vehicleCategory != null && vehicleCategory.isNotEmpty) {
        payload['vehicle_category'] = vehicleCategory;
      }
      if (email != null && email.isNotEmpty) {
        payload['email'] = email;
      }
      if (dlNumber != null && dlNumber.isNotEmpty) {
        payload['driving_license_number'] = dlNumber;
      }
      if (dlExpiry != null && dlExpiry.isNotEmpty) {
        payload['driving_license_expiry'] = dlExpiry;
      }
      if (dlDoc != null && dlDoc.isNotEmpty) {
        payload['driving_license_doc'] = dlDoc;
      }
      if (rcNumber != null && rcNumber.isNotEmpty) {
        payload['rc_number'] = rcNumber;
      }
      if (rcDoc != null && rcDoc.isNotEmpty) {
        payload['rc_doc'] = rcDoc;
      }
      if (insuranceNumber != null && insuranceNumber.isNotEmpty) {
        payload['insurance_policy_number'] = insuranceNumber;
      }
      if (insuranceExpiry != null && insuranceExpiry.isNotEmpty) {
        payload['insurance_expiry'] = insuranceExpiry;
      }
      if (insuranceDoc != null && insuranceDoc.isNotEmpty) {
        payload['insurance_doc'] = insuranceDoc;
      }
      if (aadhaarNumber != null && aadhaarNumber.isNotEmpty) {
        payload['aadhaar_number'] = aadhaarNumber;
      }
      if (aadhaarDoc != null && aadhaarDoc.isNotEmpty) {
        payload['aadhaar_doc'] = aadhaarDoc;
      }

      final Response response = await _dio.post(
        '${Strings.baseApiUrl}/auth/driver_sign_up',
        data: payload,
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
                  active: false,
                  verificationStatus: 'pending',
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

  Future<Map<String, dynamic>> driverForgotPassword({
    required String phone,
  }) async {
    try {
      final Response response = await _dio.post(
        '${Strings.baseApiUrl}/auth/driver_forgot_password',
        data: {'phone': phone},
      );
      final data = response.data as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return data;
      }
      throw CustomException(
        code: data['error']?['code']?.toString(),
        message: data['error']?['message']?.toString() ?? 'Failed to verify driver account',
      );
    } on DioException catch (e) {
      throw CustomException(
        code: e.response?.data?['error']?['code']?.toString(),
        message: e.response?.data?['error']?['message']?.toString() ?? e.message,
      );
    }
  }

  Future<Map<String, dynamic>> driverResetPassword({
    required String phone,
    required String newPassword,
    String? resetToken,
  }) async {
    try {
      final Response response = await _dio.post(
        '${Strings.baseApiUrl}/auth/driver_reset_password',
        data: {
          'phone': phone,
          'new_password': newPassword,
          if (resetToken != null) 'reset_token': resetToken,
        },
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
        message: data['error']?['message']?.toString() ?? 'Failed to reset password',
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

  Future<Driver> uploadDriverPhoto(String token, String base64Image) async {
    try {
      final response = await _dio.post(
        '${Strings.baseApiUrl}/driver/photo',
        data: {'image_url': base64Image},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = response.data as Map<String, dynamic>;
      return Driver.fromMap(Map<String, dynamic>.from(data['driver']));
    } on DioException catch (e) {
      throw CustomException(
        message: e.response?.data?['error']?['message']?.toString() ?? 'Failed to upload photo',
      );
    }
  }

  // ─── Availability & Location APIs ─────────────────────

  Future<Driver> toggleAvailability({
    required String token,
    required bool isOnline,
    double? latitude,
    double? longitude,
    double? heading,
    double? speed,
  }) async {
    try {
      final payload = <String, dynamic>{
        'is_online': isOnline,
        'active': isOnline,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (heading != null) 'heading': heading,
        if (speed != null) 'speed': speed,
      };

      final response = await _dio.post(
        '${Strings.baseApiUrl}/driver/availability',
        data: payload,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = response.data as Map<String, dynamic>;
      return Driver.fromMap(Map<String, dynamic>.from(data['driver']));
    } on DioException catch (e) {
      throw CustomException(
        code: e.response?.data?['error']?['code']?.toString(),
        message: e.response?.data?['error']?['message']?.toString() ?? 'Failed to toggle availability',
      );
    }
  }

  Future<Map<String, dynamic>> updateDriverLocation({
    required String token,
    required double latitude,
    required double longitude,
    double? heading,
    double? speed,
    DateTime? timestamp,
  }) async {
    try {
      final response = await _dio.post(
        '${Strings.baseApiUrl}/driver/location',
        data: {
          'latitude': latitude,
          'longitude': longitude,
          'heading': heading ?? 0.0,
          'speed': speed ?? 0.0,
          'timestamp': (timestamp ?? DateTime.now()).toIso8601String(),
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw CustomException(
        code: e.response?.data?['error']?['code']?.toString(),
        message: e.response?.data?['error']?['message']?.toString() ?? 'Failed to update location',
      );
    }
  }

  Future<Map<String, dynamic>> getDriverStatus(String token) async {
    try {
      final response = await _dio.get(
        '${Strings.baseApiUrl}/driver/status',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw CustomException(
        code: e.response?.data?['error']?['code']?.toString(),
        message: e.response?.data?['error']?['message']?.toString() ?? 'Failed to get status',
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

  Future<Map<String, dynamic>> getRideHistory(
    String token, {
    int page = 1,
    int limit = 20,
    String? status,
    String? period,
    String? fromDate,
    String? toDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{'page': page, 'limit': limit};
      if (status != null && status.isNotEmpty && status != 'all') {
        queryParams['status'] = status;
      }
      if (period != null && period.isNotEmpty && period != 'all') {
        queryParams['period'] = period;
      }
      if (fromDate != null && fromDate.isNotEmpty) {
        queryParams['from_date'] = fromDate;
      }
      if (toDate != null && toDate.isNotEmpty) {
        queryParams['to_date'] = toDate;
      }
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

  Future<Map<String, dynamic>> getDriverTripDetails(String token, String rideId) async {
    try {
      final response = await _dio.get(
        '${Strings.baseApiUrl}/driver/rides/$rideId/details',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return (response.data as Map<String, dynamic>)['trip'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw CustomException(
        message: e.response?.data?['error']?['message']?.toString() ?? 'Failed to fetch trip details',
      );
    }
  }



  // ─── Earnings API ────────────────────────────────────

  Future<Map<String, dynamic>> getEarningsSummary(
    String token, {
    String period = 'today',
    String? fromDate,
    String? toDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{'period': period};
      if (fromDate != null) queryParams['from_date'] = fromDate;
      if (toDate != null) queryParams['to_date'] = toDate;

      final response = await _dio.get(
        '${Strings.baseApiUrl}/driver/earnings/summary',
        queryParameters: queryParams,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return (response.data as Map<String, dynamic>)['earnings'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw CustomException(
        message: e.response?.data?['error']?['message']?.toString() ?? 'Failed to fetch earnings',
      );
    }
  }

  Future<List<dynamic>> getEarningsHistory(
    String token, {
    int page = 1,
    int limit = 20,
    String? period,
    String? fromDate,
    String? toDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{'page': page, 'limit': limit};
      if (period != null) queryParams['period'] = period;
      if (fromDate != null) queryParams['from_date'] = fromDate;
      if (toDate != null) queryParams['to_date'] = toDate;

      final response = await _dio.get(
        '${Strings.baseApiUrl}/driver/earnings/history',
        queryParameters: queryParams,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return (response.data as Map<String, dynamic>)['rides'] as List<dynamic>;
    } on DioException catch (e) {
      throw CustomException(
        message: e.response?.data?['error']?['message']?.toString() ?? 'Failed to fetch earnings history',
      );
    }
  }

  Future<Map<String, dynamic>> getTripEarningDetails(String token, String rideId) async {
    try {
      final response = await _dio.get(
        '${Strings.baseApiUrl}/driver/earnings/$rideId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return (response.data as Map<String, dynamic>)['trip_earnings'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw CustomException(
        message: e.response?.data?['error']?['message']?.toString() ?? 'Failed to fetch trip earning details',
      );
    }
  }

  // ─── Vehicle Management APIs ──────────────────────────

  Future<List<Vehicle>> getVehicles(String token) async {
    try {
      final response = await _dio.get(
        '${Strings.baseApiUrl}/driver/vehicles',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final rawList = (response.data as Map<String, dynamic>)['vehicles'] as List<dynamic>? ?? [];
      return rawList.map((m) => Vehicle.fromMap(Map<String, dynamic>.from(m as Map))).toList();
    } on DioException catch (e) {
      throw CustomException(
        message: e.response?.data?['error']?['message']?.toString() ?? 'Failed to fetch vehicles',
      );
    }
  }

  Future<Vehicle> getVehicleById(String token, String id) async {
    try {
      final response = await _dio.get(
        '${Strings.baseApiUrl}/driver/vehicles/$id',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = (response.data as Map<String, dynamic>)['vehicle'] as Map<String, dynamic>;
      return Vehicle.fromMap(data);
    } on DioException catch (e) {
      throw CustomException(
        message: e.response?.data?['error']?['message']?.toString() ?? 'Failed to get vehicle details',
      );
    }
  }

  Future<Vehicle> addVehicle(String token, Map<String, dynamic> data) async {
    try {
      final response = await _dio.post(
        '${Strings.baseApiUrl}/driver/vehicles',
        data: data,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final vehMap = (response.data as Map<String, dynamic>)['vehicle'] as Map<String, dynamic>;
      return Vehicle.fromMap(vehMap);
    } on DioException catch (e) {
      throw CustomException(
        message: e.response?.data?['error']?['message']?.toString() ?? 'Failed to add vehicle',
      );
    }
  }

  Future<Vehicle> updateVehicle(String token, String id, Map<String, dynamic> data) async {
    try {
      final response = await _dio.patch(
        '${Strings.baseApiUrl}/driver/vehicles/$id',
        data: data,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final vehMap = (response.data as Map<String, dynamic>)['vehicle'] as Map<String, dynamic>;
      return Vehicle.fromMap(vehMap);
    } on DioException catch (e) {
      throw CustomException(
        message: e.response?.data?['error']?['message']?.toString() ?? 'Failed to update vehicle',
      );
    }
  }

  Future<Vehicle> uploadVehicleDocuments(String token, String id, Map<String, dynamic> docs) async {
    try {
      final response = await _dio.post(
        '${Strings.baseApiUrl}/driver/vehicles/$id/documents',
        data: docs,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final vehMap = (response.data as Map<String, dynamic>)['vehicle'] as Map<String, dynamic>;
      return Vehicle.fromMap(vehMap);
    } on DioException catch (e) {
      throw CustomException(
        message: e.response?.data?['error']?['message']?.toString() ?? 'Failed to upload vehicle documents',
      );
    }
  }

  Future<Vehicle> activateVehicle(String token, String id) async {
    try {
      final response = await _dio.post(
        '${Strings.baseApiUrl}/driver/vehicles/$id/activate',
        data: {},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final vehMap = (response.data as Map<String, dynamic>)['vehicle'] as Map<String, dynamic>;
      return Vehicle.fromMap(vehMap);
    } on DioException catch (e) {
      throw CustomException(
        message: e.response?.data?['error']?['message']?.toString() ?? 'Failed to activate vehicle',
      );
    }
  }

  Future<void> deleteVehicle(String token, String id) async {
    try {
      await _dio.delete(
        '${Strings.baseApiUrl}/driver/vehicles/$id',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } on DioException catch (e) {
      throw CustomException(
        message: e.response?.data?['error']?['message']?.toString() ?? 'Failed to delete vehicle',
      );
    }
  }

  // ─── Ride Requests Management ─────────────────────────

  Future<List<RideRequest>> getPendingRideRequests(String token) async {
    try {
      final response = await _dio.get(
        '${Strings.baseApiUrl}/driver/rides/pending_requests',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final list = (response.data['requests'] as List? ?? []);
      return list.map((item) => RideRequest.fromMap(Map<String, dynamic>.from(item))).toList();
    } on DioException catch (e) {
      throw CustomException(
        code: e.response?.data?['error']?['code']?.toString(),
        message: e.response?.data?['error']?['message']?.toString() ?? 'Failed to fetch pending requests',
      );
    }
  }

  Future<Map<String, dynamic>> acceptRide(String token, String rideId) async {
    try {
      final response = await _dio.post(
        '${Strings.baseApiUrl}/driver/rides/$rideId/accept',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw CustomException(
        code: e.response?.data?['error']?['code']?.toString(),
        message: e.response?.data?['error']?['message']?.toString() ?? 'Failed to accept ride',
      );
    }
  }

  Future<bool> rejectRide(String token, String rideId) async {
    try {
      await _dio.post(
        '${Strings.baseApiUrl}/driver/rides/$rideId/reject',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return true;
    } on DioException catch (e) {
      throw CustomException(
        code: e.response?.data?['error']?['code']?.toString(),
        message: e.response?.data?['error']?['message']?.toString() ?? 'Failed to reject ride',
      );
    }
  }

  // ─── Pickup Navigation & Arrival Management ───────────

  Future<Map<String, dynamic>> getAssignedRideDetails(String token, String rideId) async {
    try {
      final response = await _dio.get(
        '${Strings.baseApiUrl}/driver/rides/$rideId/assigned',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data['ride'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw CustomException(
        code: e.response?.data?['error']?['code']?.toString(),
        message: e.response?.data?['error']?['message']?.toString() ?? 'Failed to fetch assigned ride details',
      );
    }
  }

  Future<Map<String, dynamic>> markReachingPickup(String token, String rideId) async {
    try {
      final response = await _dio.post(
        '${Strings.baseApiUrl}/driver/rides/$rideId/reaching',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw CustomException(
        code: e.response?.data?['error']?['code']?.toString(),
        message: e.response?.data?['error']?['message']?.toString() ?? 'Failed to update reaching pickup status',
      );
    }
  }

  Future<Map<String, dynamic>> markDriverArrived(String token, String rideId) async {
    try {
      final response = await _dio.post(
        '${Strings.baseApiUrl}/driver/rides/$rideId/arrive',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw CustomException(
        code: e.response?.data?['error']?['code']?.toString(),
        message: e.response?.data?['error']?['message']?.toString() ?? 'Failed to record arrival at pickup',
      );
    }
  }

  Future<Map<String, dynamic>> verifyRideStartOtp(String token, String rideId, String otp) async {
    try {
      final response = await _dio.post(
        '${Strings.baseApiUrl}/driver/rides/$rideId/verify_otp_start',
        data: {'otp': otp},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw CustomException(
        code: e.response?.data?['error']?['code']?.toString(),
        message: e.response?.data?['error']?['message']?.toString() ?? 'OTP verification failed',
      );
    }
  }

  Future<Map<String, dynamic>> completeRide(
    String token,
    String rideId, {
    double? actualDistanceKm,
    double? finalFare,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (actualDistanceKm != null) payload['actual_distance_km'] = actualDistanceKm;
      if (finalFare != null) payload['final_fare'] = finalFare;

      final response = await _dio.post(
        '${Strings.baseApiUrl}/driver/rides/$rideId/complete',
        data: payload,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw CustomException(
        code: e.response?.data?['error']?['code']?.toString(),
        message: e.response?.data?['error']?['message']?.toString() ?? 'Failed to complete ride',
      );
    }
  }

  Future<Map<String, dynamic>> cancelRide(
    String token,
    String rideId, {
    required String reason,
    String? notes,
  }) async {
    try {
      final payload = <String, dynamic>{
        'reason': reason,
      };
      if (notes != null && notes.trim().isNotEmpty) {
        payload['notes'] = notes.trim();
      }

      final response = await _dio.post(
        '${Strings.baseApiUrl}/driver/rides/$rideId/cancel',
        data: payload,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw CustomException(
        code: e.response?.data?['error']?['code']?.toString(),
        message: e.response?.data?['error']?['message']?.toString() ?? 'Failed to cancel ride',
      );
    }
  }

  Future<Map<String, dynamic>> getDriverCancellationHistory(
    String token, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _dio.get(
        '${Strings.baseApiUrl}/driver/rides/cancellations',
        queryParameters: {'page': page, 'limit': limit},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw CustomException(
        code: e.response?.data?['error']?['code']?.toString(),
        message: e.response?.data?['error']?['message']?.toString() ?? 'Failed to fetch cancellation history',
      );
    }
  }

  /// Check if the driver has an active assigned or in-progress trip
  Future<Map<String, dynamic>?> getActiveTrip(String token) async {
    try {
      final response = await _dio.get(
        '${Strings.baseApiUrl}/driver/active_trip',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        if (data['active_trip'] != null) {
          return Map<String, dynamic>.from(data['active_trip']);
        }
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw CustomException(
        code: e.response?.data?['error']?['code']?.toString(),
        message: e.response?.data?['error']?['message']?.toString() ?? 'Failed to check active trip',
      );
    } catch (_) {
      return null;
    }
  }
}
