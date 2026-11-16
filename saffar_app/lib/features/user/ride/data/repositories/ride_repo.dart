import 'package:dio/dio.dart';
import 'package:saffar_app/core/constants/strings.dart';
import 'package:saffar_app/core/errors/custom_exception.dart';
import 'package:saffar_app/core/models/ride.dart';
import 'package:saffar_app/core/models/ride_driver.dart';
import 'package:saffar_app/core/service_locator.dart';
import 'package:saffar_app/features/user/data/repositories/user_repo.dart';

/// Gets rides data and communicates with Saffar Ride backend APIs
class RideRepo {
  final Dio _dio = sl<Dio>();

  String? token;
  String? userId;

  /// Effective token: uses memory token or falls back to UserRepo stored token
  String? get effectiveToken {
    if (token != null && token!.isNotEmpty) return token;
    try {
      final userRepo = sl<UserRepo>();
      return userRepo.getTokenFromLocalStorage();
    } catch (_) {
      return null;
    }
  }

  /// Effective userId: uses memory userId or falls back to UserRepo stored user
  String? get effectiveUserId {
    if (userId != null && userId!.isNotEmpty) return userId;
    try {
      final userRepo = sl<UserRepo>();
      final map = userRepo.getUserMapFromLocalStorage();
      return map['id']?.toString();
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _authHeaders([String? customToken]) {
    final t = customToken ?? effectiveToken;
    final headers = <String, dynamic>{};
    if (t != null && t.isNotEmpty) {
      headers['authorization'] = 'Bearer $t';
    }
    return headers;
  }

  /// Initialized Rides Repo.
  void initRidesRepo(String token, String userId) {
    this.token = token;
    this.userId = userId;
  }

  /// Gets all available ride options from backend (Saffar Bike, Auto, Mini, Prime Sedan)
  Future<Map<String, dynamic>> getRideOptions({
    double distance = 8.4,
    String promo = 'SAVE30',
  }) async {
    try {
      final Response response = await _dio.get(
        '${Strings.baseApiUrl}/ride/ride_options',
        queryParameters: {
          'distance': distance,
          'promo': promo,
        },
        options: Options(headers: _authHeaders()),
      );

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
      throw CustomException(
        message: response.data?['error']?['message']?.toString() ??
            'Failed to fetch ride options',
      );
    } on DioException catch (e) {
      throw CustomException(
        code: e.response?.data?['error']?['code']?.toString(),
        message: e.response?.data?['error']?['message']?.toString() ??
            'Unable to connect to ride service. Please check your network.',
      );
    } catch (e) {
      throw CustomException(message: e.toString());
    }
  }

  /// Books a new ride via the backend and returns the created ride details
  Future<Map<String, dynamic>> bookRide({
    required String vehicleType,
    required double price,
    String? sourceAddress,
    String? destinationAddress,
    String? paymentMethod,
    double? discountPrice,
  }) async {
    try {
      final uid = effectiveUserId;
      if (uid == null || uid.isEmpty) {
        throw CustomException(message: 'User authentication required. Please log in.');
      }
      final Response response = await _dio.post(
        '${Strings.baseApiUrl}/ride/add_ride',
        data: {
          'user_id': uid,
          'vehicle_type': vehicleType,
          'price': price,
          'discount_price': discountPrice ?? 30.0,
          'source_address': sourceAddress ?? 'Current Location',
          'destination_address': destinationAddress ?? 'Destination Location',
          'payment_method': paymentMethod ?? 'Paid via Saffar Wallet',
        },
        options: Options(headers: _authHeaders()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data as Map<String, dynamic>;
      }
      throw CustomException(
        code: response.data?['error']?['code']?.toString(),
        message: response.data?['error']?['message']?.toString() ??
            'Failed to book ride',
      );
    } on DioException catch (e) {
      throw CustomException(
        code: e.response?.data?['error']?['code']?.toString(),
        message: e.response?.data?['error']?['message']?.toString() ??
            'Unable to process ride booking. Please try again.',
      );
    } catch (e) {
      throw CustomException(message: e.toString());
    }
  }

  /// Cancels an in-progress or booked ride
  Future<Map<String, dynamic>> cancelRide({
    required String rideId,
    String reason = 'Rider cancelled',
  }) async {
    try {
      final Response response = await _dio.post(
        '${Strings.baseApiUrl}/ride/cancel',
        data: {
          'ride_id': rideId,
          'reason': reason,
        },
        options: Options(headers: _authHeaders()),
      );

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
      throw CustomException(
        message: response.data?['error']?['message']?.toString() ??
            'Failed to cancel ride',
      );
    } on DioException catch (e) {
      throw CustomException(
        code: e.response?.data?['error']?['code']?.toString(),
        message: e.response?.data?['error']?['message']?.toString() ??
            'Unable to cancel ride right now.',
      );
    } catch (e) {
      throw CustomException(message: e.toString());
    }
  }

  /// Rebooks a previous ride by cloning pickup, drop and vehicle details
  Future<Map<String, dynamic>> rebookRide(String rideId) async {
    try {
      final uid = effectiveUserId;
      if (uid == null || uid.isEmpty) {
        throw CustomException(message: 'User authentication required. Please log in.');
      }
      final Response response = await _dio.post(
        '${Strings.baseApiUrl}/ride/rebook',
        data: {
          'ride_id': rideId,
          'user_id': uid,
        },
        options: Options(headers: _authHeaders()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data as Map<String, dynamic>;
      }
      throw CustomException(
        message: response.data?['error']?['message']?.toString() ??
            'Failed to rebook ride',
      );
    } on DioException catch (e) {
      throw CustomException(
        code: e.response?.data?['error']?['code']?.toString(),
        message: e.response?.data?['error']?['message']?.toString() ??
            'Unable to rebook ride. Please try again.',
      );
    } catch (e) {
      throw CustomException(message: e.toString());
    }
  }

  /// Gets all the previous rides of the user
  Future<List<Ride>> getPreviousRides() async {
    final t = effectiveToken;
    final uid = effectiveUserId;

    if (t == null) {
      throw CustomException.userNotLoggedIn();
    }

    try {
      final Response response = await _dio.get(
        '${Strings.baseApiUrl}/ride/previous_rides',
        queryParameters: uid != null ? {'user_id': uid} : null,
        options: Options(headers: _authHeaders(t)),
      );

      if (response.statusCode != 200) {
        throw CustomException(
          code: response.data['error']?['code'],
          message: response.data['error']?['message'] ?? 'Failed to get previous rides',
        );
      }

      final dynamic ridesList = response.data['previous_rides'];
      if (ridesList is List) {
        final List<Map<String, dynamic>> maps =
            ridesList.map((e) => e as Map<String, dynamic>).toList();
        return maps.map((map) => Ride.fromMap(map)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw CustomException(
        code: e.response?.data?['error']?['code']?.toString(),
        message: e.response?.data?['error']?['message']?.toString() ??
            'Failed to retrieve previous rides.',
      );
    } catch (e) {
      throw CustomException(message: e.toString());
    }
  }

  /// Gives Driver, drivers source position, drivers destination position
  /// Params: User source latitude and longitude
  Future<RideDriver> findRideDriver(
    double latitude,
    double longitude,
  ) async {
    try {
      final Response response = await _dio.get(
        '${Strings.baseApiUrl}/ride/find_ride_driver',
        queryParameters: {
          'latitude': latitude,
          'longitude': longitude,
          'map_api_key': Strings.mapApiKey,
        },
        options: Options(headers: _authHeaders()),
      );

      final Map<String, dynamic> map = response.data as Map<String, dynamic>;
      final RideDriver rideDriver = RideDriver.fromMap(map);

      return rideDriver;
    } on DioException catch (e) {
      throw CustomException(
        code: e.response?.data?['error']?['code']?.toString(),
        message: e.response?.data?['error']?['message']?.toString() ??
            'Could not find nearby drivers.',
      );
    } catch (e) {
      throw CustomException(message: e.toString());
    }
  }

  Future<void> addRide(Ride ride) async {
    try {
      final Map<String, dynamic> rideMap = ride.toMap();

      await _dio.post(
        '${Strings.baseApiUrl}/ride/add_ride',
        data: rideMap,
        options: Options(headers: _authHeaders()),
      );
    } on DioException catch (e) {
      throw CustomException(
        code: e.response?.data?['error']?['code']?.toString(),
        message: e.response?.data?['error']?['message']?.toString() ??
            'Failed to add ride.',
      );
    } catch (e) {
      throw CustomException(message: e.toString());
    }
  }

  /// Gets total ride price 
  Future<double> getTotalRidePrice(double distanceInKm) async {
    try {
      final Response response = await _dio.get(
        '${Strings.baseApiUrl}/ride/total_price',
        queryParameters: {
          'distance_in_km': distanceInKm,
        },
        options: Options(headers: _authHeaders()),
      );

      final double totalPrice = (response.data['total_price'] as num).toDouble();
      return totalPrice;
    } on DioException catch (e) {
      throw CustomException(
        code: e.response?.data?['error']?['code']?.toString(),
        message: e.response?.data?['error']?['message']?.toString() ??
            'Failed to compute total price.',
      );
    } catch (e) {
      throw CustomException(message: e.toString());
    }
  }

  /// Fetches completed ride review details
  Future<Map<String, dynamic>> getReviewDetails({String? rideId}) async {
    try {
      final Response response = await _dio.get(
        '${Strings.baseApiUrl}/ride/review_details',
        queryParameters: rideId != null ? {'ride_id': rideId} : null,
        options: Options(headers: _authHeaders()),
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw CustomException(
        code: e.response?.data?['error']?['code']?.toString(),
        message: e.response?.data?['error']?['message']?.toString() ??
            'Failed to load review details.',
      );
    } catch (e) {
      throw CustomException(message: e.toString());
    }
  }

  /// Submits rating, review tags, tip amount and optional note for the driver
  Future<Map<String, dynamic>> rateDriver({
    String? rideId,
    String? driverId,
    required double rating,
    required List<String> tags,
    required double tipAmount,
    String? note,
  }) async {
    try {
      final Response response = await _dio.post(
        '${Strings.baseApiUrl}/ride/rate_driver',
        data: {
          'ride_id': rideId,
          'driver_id': driverId ?? 'driver_001',
          'rating': rating,
          'tags': tags,
          'tip_amount': tipAmount,
          'note': note ?? '',
        },
        options: Options(headers: _authHeaders()),
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw CustomException(
        code: e.response?.data?['error']?['code']?.toString(),
        message: e.response?.data?['error']?['message']?.toString() ??
            'Failed to submit driver rating.',
      );
    } catch (e) {
      throw CustomException(message: e.toString());
    }
  }

  /// Searches places & landmarks matching a query from backend
  Future<List<Map<String, dynamic>>> searchPlaces(
    String queryText, {
    double? latitude,
    double? longitude,
  }) async {
    try {
      final queryParams = <String, dynamic>{'query': queryText};
      if (latitude != null && longitude != null) {
        queryParams['latitude'] = latitude;
        queryParams['longitude'] = longitude;
      }
      final Response response = await _dio.get(
        '${Strings.baseApiUrl}/ride/search_places',
        queryParameters: queryParams,
        options: Options(headers: _authHeaders()),
      );

      final data = response.data as Map<String, dynamic>;
      final list = (data['places'] as List<dynamic>?) ?? [];
      return list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Gets saved (Home, Office) and recent destination spots
  Future<Map<String, dynamic>> getSavedAndRecentPlaces() async {
    try {
      final Response response = await _dio.get(
        '${Strings.baseApiUrl}/ride/saved_places',
        options: Options(headers: _authHeaders()),
      );

      return response.data as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  /// Fetches ride-start OTP securely for the authenticated passenger
  Future<Map<String, dynamic>> getRideOtp(String rideId) async {
    try {
      final Response response = await _dio.get(
        '${Strings.baseApiUrl}/ride/$rideId/otp',
        options: Options(headers: _authHeaders()),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw CustomException(
        code: e.response?.data?['error']?['code']?.toString(),
        message: e.response?.data?['error']?['message']?.toString() ?? 'Failed to fetch ride start OTP',
      );
    }
  }

  /// Checks live ride booking status
  Future<Map<String, dynamic>> getRideStatus(String rideId) async {
    try {
      final Response response = await _dio.get(
        '${Strings.baseApiUrl}/ride/$rideId/status',
        options: Options(headers: _authHeaders()),
      );
      return response.data as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  /// Fetches real-time nearby vehicle counts, ETAs, and obfuscated map pins
  Future<Map<String, dynamic>> getNearbyVehicleAvailability({
    required double latitude,
    required double longitude,
    double radiusKm = 3.0,
    String? category,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'latitude': latitude,
        'longitude': longitude,
        'radius_km': radiusKm,
      };
      if (category != null && category.isNotEmpty) {
        queryParams['category'] = category;
      }

      final Response response = await _dio.get(
        '${Strings.baseApiUrl}/ride/nearby_availability',
        queryParameters: queryParams,
        options: Options(headers: _authHeaders()),
      );

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  /// Fetches the currently ongoing active ride for session restoration
  Future<Map<String, dynamic>?> getActiveRide() async {
    try {
      final Response response = await _dio.get(
        '${Strings.baseApiUrl}/ride/active_ride',
        options: Options(headers: _authHeaders()),
      );
      if (response.statusCode == 200 && response.data != null && response.data['active_ride'] != null) {
        return Map<String, dynamic>.from(response.data['active_ride']);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
