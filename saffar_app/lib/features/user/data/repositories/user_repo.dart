import 'package:dio/dio.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:saffar_app/core/constants/strings.dart';
import 'package:saffar_app/core/errors/custom_exception.dart';
import 'package:saffar_app/core/service_locator.dart';
import 'package:saffar_app/features/user/data/models/user.dart';

class UserRepo {
  final HiveInterface _hive = sl<HiveInterface>();
  final Dio _dio = sl<Dio>();
  Box? _userBox;

  /// Initialize User Repo.
  Future<void> initUserRepo() async {
    try {
      if (!_hive.isBoxOpen('user_box')) {
        _userBox = await _hive.openBox('user_box');
      } else {
        _userBox = _hive.box('user_box');
      }
    } catch (e) {
      throw CustomException(
        message: e.toString(),
      );
    }
  }

  /// Writes user map info to local storage
  Future<void> putUserMapInLocalStorage(Map<dynamic, dynamic> userMap) async {
    if (_userBox == null) await initUserRepo();

    try {
      await _userBox!.put('current_user', userMap);
    } catch (e) {
      throw const CustomException(
        message: 'Failed to store user info in local storage.',
      );
    }
  }

  /// Writes token to local storage
  Future<void> putTokenInLocalStorage(String token) async {
    if (_userBox == null) await initUserRepo();

    try {
      await _userBox!.put('token', token);
    } catch (e) {
      throw const CustomException(
        message: 'Failed to store token in local storage.',
      );
    }
  }

  /// Reads user map info from local storage
  Map<dynamic, dynamic> getUserMapFromLocalStorage() {
    if (_userBox == null) {
      throw const CustomException(message: 'User box is null.');
    }

    try {
      final data = _userBox!.get('current_user');
      if (data == null) {
        throw const CustomException(message: 'No user in local storage.');
      }
      return data;
    } catch (e) {
      throw const CustomException(
        message: 'Failed to get user info from local storage.',
      );
    }
  }

  /// Reads token from local storage
  String getTokenFromLocalStorage() {
    if (_userBox == null) {
      throw const CustomException(message: 'User box is null.');
    }

    try {
      final data = _userBox!.get('token');
      if (data == null) {
        throw const CustomException(message: 'No token in local storage.');
      }
      return data;
    } catch (e) {
      throw const CustomException(
        message: 'Failed to get token from local storage.',
      );
    }
  }

  /// Deletes token from local storage
  Future<bool> deleteTokenFromLocalStorage() async {
    if (_userBox == null) await initUserRepo();

    try {
      await _userBox!.delete('token');
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Deletes user from local storage
  Future<bool> deleteUserFromLocalStorage() async {
    if (_userBox == null) await initUserRepo();

    try {
      await _userBox!.delete('current_user');
      return true;
    } catch (e) {
      return false;
    }
  }

  // ─── Remote API ──────────────────────────────────────────────

  /// Fetch user profile from backend
  Future<User> fetchUserProfile(String token, String userId) async {
    try {
      final response = await _dio.get(
        '${Strings.baseApiUrl}/user',
        queryParameters: {'id': userId},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final data = response.data as Map<String, dynamic>;
      final userMap = data['user'] as Map<String, dynamic>;
      return User.fromMap(userMap);
    } on DioException catch (e) {
      throw CustomException(
        message: e.response?.data?['error']?['message']?.toString() ??
            'Failed to fetch user profile',
      );
    }
  }

  /// Update user profile on backend
  Future<User> updateUserProfile(
    String token,
    Map<String, dynamic> fields,
  ) async {
    try {
      final response = await _dio.patch(
        '${Strings.baseApiUrl}/user',
        data: fields,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final data = response.data as Map<String, dynamic>;
      final userMap = data['user'] as Map<String, dynamic>;
      final user = User.fromMap(userMap);

      // Cache locally
      await putUserMapInLocalStorage(user.toMap());

      return user;
    } on DioException catch (e) {
      throw CustomException(
        message: e.response?.data?['error']?['message']?.toString() ??
            'Failed to update profile',
      );
    }
  }
}
