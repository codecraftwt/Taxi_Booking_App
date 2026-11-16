import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AdminApiService {
  AdminApiService._();
  static final AdminApiService instance = AdminApiService._();

  late final Dio _dio;
  String? _token;
  Map<String, dynamic>? _currentAdmin;

  String? get token => _token;
  Map<String, dynamic>? get currentAdmin => _currentAdmin;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  void init() {
    String base = "http://localhost:5000/api/admin";
    if (dotenv.isInitialized) {
      final envBase = dotenv.env['BASE_API_URL'];
      if (envBase != null && envBase.isNotEmpty) {
        base = envBase.replaceAll('/api', '') + '/api/admin';
      }
    }

    _dio = Dio(
      BaseOptions(
        baseUrl: base,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_token != null) {
            options.headers['Authorization'] = 'Bearer $_token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) {
          return handler.next(error);
        },
      ),
    );
  }

  void setAuth(String token, Map<String, dynamic> admin) {
    _token = token;
    _currentAdmin = admin;
  }

  void logout() {
    _token = null;
    _currentAdmin = null;
  }

  // --- API Methods ---

  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    if (res.data['success'] == true) {
      final data = res.data['data'];
      setAuth(data['token'], Map<String, dynamic>.from(data['admin']));
    }
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> getDashboardStats() async {
    final res = await _dio.get('/dashboard/stats');
    return Map<String, dynamic>.from(res.data['data']);
  }

  Future<Map<String, dynamic>> getDrivers({
    String status = 'all',
    String? category,
    String? search,
    int page = 1,
    int limit = 15,
  }) async {
    final queryParams = <String, dynamic>{
      'status': status,
      'page': page,
      'limit': limit,
    };
    if (category != null && category != 'All') queryParams['category'] = category;
    if (search != null && search.trim().isNotEmpty) queryParams['search'] = search.trim();

    final res = await _dio.get('/drivers', queryParameters: queryParams);
    return Map<String, dynamic>.from(res.data['data']);
  }

  Future<Map<String, dynamic>> getDriverDetails(String driverId) async {
    final res = await _dio.get('/drivers/$driverId');
    return Map<String, dynamic>.from(res.data['data']);
  }

  Future<bool> updateDriverStatus(String driverId, String action, {String? reason}) async {
    final res = await _dio.patch('/drivers/$driverId/status', data: {
      'action': action,
      'reason': reason,
    });
    return res.data['success'] == true;
  }

  Future<bool> updateDriverDetails(String driverId, Map<String, dynamic> updateData) async {
    final res = await _dio.put('/drivers/$driverId', data: updateData);
    return res.data['success'] == true;
  }

  Future<bool> deleteDriver(String driverId) async {
    final res = await _dio.delete('/drivers/$driverId');
    return res.data['success'] == true;
  }

  Future<bool> deleteAllDrivers() async {
    final res = await _dio.delete('/drivers/purge-all');
    return res.data['success'] == true;
  }

  Future<Map<String, dynamic>> getDocuments({
    String status = 'pending',
    String? documentType,
    int page = 1,
    int limit = 20,
  }) async {
    final queryParams = <String, dynamic>{
      'status': status,
      'page': page,
      'limit': limit,
    };
    if (documentType != null && documentType != 'all') {
      queryParams['documentType'] = documentType;
    }
    final res = await _dio.get('/documents', queryParameters: queryParams);
    return Map<String, dynamic>.from(res.data['data']);
  }

  Future<bool> verifyDocument(String documentId, String status, {String? rejectionReason}) async {
    final res = await _dio.post('/documents/$documentId/verify', data: {
      'status': status,
      'rejectionReason': rejectionReason,
    });
    return res.data['success'] == true;
  }

  Future<List<dynamic>> getLiveDrivers({String category = 'All', String status = 'All'}) async {
    final res = await _dio.get('/tracking/live', queryParameters: {
      'category': category,
      'status': status,
    });
    return List<dynamic>.from(res.data['data']['drivers'] ?? []);
  }

  Future<List<dynamic>> getFares() async {
    final res = await _dio.get('/fares');
    return List<dynamic>.from(res.data['data'] ?? []);
  }

  Future<bool> updateFare(String category, Map<String, dynamic> fareData) async {
    final res = await _dio.put('/fares/$category', data: fareData);
    return res.data['success'] == true;
  }

  Future<Map<String, dynamic>> getRides({
    String status = 'all',
    String? search,
    int page = 1,
    int limit = 15,
  }) async {
    final queryParams = <String, dynamic>{
      'status': status,
      'page': page,
      'limit': limit,
    };
    if (search != null && search.trim().isNotEmpty) queryParams['search'] = search.trim();
    final res = await _dio.get('/rides', queryParameters: queryParams);
    return Map<String, dynamic>.from(res.data['data']);
  }

  Future<bool> cancelRide(String rideId, String reason) async {
    final res = await _dio.post('/rides/$rideId/cancel', data: {'reason': reason});
    return res.data['success'] == true;
  }

  Future<Map<String, dynamic>> getFinanceOverview() async {
    final res = await _dio.get('/finance/overview');
    return Map<String, dynamic>.from(res.data['data']);
  }

  Future<List<dynamic>> getSettlements() async {
    final res = await _dio.get('/finance/settlements');
    return List<dynamic>.from(res.data['data'] ?? []);
  }

  Future<Map<String, dynamic>> getCustomers({String? search, int page = 1, int limit = 15}) async {
    final queryParams = <String, dynamic>{'page': page, 'limit': limit};
    if (search != null && search.trim().isNotEmpty) queryParams['search'] = search.trim();
    final res = await _dio.get('/customers', queryParameters: queryParams);
    return Map<String, dynamic>.from(res.data['data']);
  }

  Future<List<dynamic>> getAuditLogs({String? action, int limit = 50}) async {
    final queryParams = <String, dynamic>{'limit': limit};
    if (action != null) queryParams['action'] = action;
    final res = await _dio.get('/audit-logs', queryParameters: queryParams);
    return List<dynamic>.from(res.data['data'] ?? []);
  }

  Future<List<dynamic>> getStaff() async {
    final res = await _dio.get('/staff');
    return List<dynamic>.from(res.data['data'] ?? []);
  }

  Future<bool> createStaff(Map<String, dynamic> staffData) async {
    final res = await _dio.post('/staff', data: staffData);
    return res.data['success'] == true;
  }
}

