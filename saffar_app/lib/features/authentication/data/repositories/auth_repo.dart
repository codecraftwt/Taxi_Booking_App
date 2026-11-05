import 'package:dio/dio.dart';
import 'package:saffar_app/core/constants/strings.dart';
import 'package:saffar_app/core/errors/custom_exception.dart';
import 'package:saffar_app/features/user/data/models/user.dart';
import 'package:saffar_app/core/service_locator.dart';

/// Handles data to/from authentication APIs.
class AuthRepo {
  final Dio _dio = sl<Dio>();

  /// Signs up user and returns a User model and token.
  Future<Map<String, dynamic>> signUp(
    String name,
    String phone,
    String password, {
    String? email,
  }) async {
    try {
      final Map<String, dynamic> body = {
        'name': name,
        'phone': phone,
        'password': password,
      };
      if (email != null && email.trim().isNotEmpty) {
        body['email'] = email.trim();
      }

      final Response response = await _dio.post(
        '${Strings.baseApiUrl}/auth/sign_up',
        data: body,
      );

      final Map<String, dynamic> data = response.data as Map<String, dynamic>;

      if (response.statusCode == 200) {
        return {
          'user': User.fromMap(data['user']),
          'token': data['token'],
        };
      }

      throw CustomException(
        code: data['error']['code'],
        message: data['error']['message'],
      );
    } on DioException catch (e) {
      throw CustomException(
        code: e.response?.data['error']['code'],
        message: e.response?.data['error']['message'],
      );
    }
  }

  /// Signs in user and returns a User model and Token
  Future<Map<String, dynamic>> signIn(String phone, String password) async {
    try {
      final Response response = await _dio.post(
        '${Strings.baseApiUrl}/auth/sign_in',
        data: {
          'phone': phone,
          'password': password,
        },
      );

      final Map<String, dynamic> data = response.data as Map<String, dynamic>;

      if (response.statusCode == 200) {
        return {
          'user': User.fromMap(data['user']),
          'token': data['token'],
        };
      }

      throw CustomException(
        code: data['error']['code'],
        message: data['error']['message'],
      );
    } on DioException catch (e) {
      throw CustomException(
        code: e.response?.data['error']['code'],
        message: e.response?.data['error']['message'],
      );
    }
  }

  /// Sends forgot password recovery request
  Future<Map<String, dynamic>> forgotPassword({
    required String phoneOrEmail,
    String channel = 'SMS',
  }) async {
    try {
      final Response response = await _dio.post(
        '${Strings.baseApiUrl}/auth/forgot_password',
        data: {
          'phone': phoneOrEmail,
          'channel': channel,
        },
      );

      final Map<String, dynamic> data = response.data as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return data;
      }

      throw CustomException(
        code: data['error']?['code'] ?? 'ERROR',
        message: data['error']?['message'] ?? 'Failed to request reset',
      );
    } on DioException catch (e) {
      throw CustomException(
        code: e.response?.data?['error']?['code'] ?? 'ERROR',
        message: e.response?.data?['error']?['message'] ??
            'Failed to send reset code',
      );
    }
  }

  /// Resets user password and logs in
  Future<Map<String, dynamic>> resetPassword({
    required String phone,
    required String newPassword,
    bool logoutAllSessions = true,
  }) async {
    try {
      final Response response = await _dio.post(
        '${Strings.baseApiUrl}/auth/reset_password',
        data: {
          'phone': phone,
          'new_password': newPassword,
          'logout_all_sessions': logoutAllSessions,
        },
      );

      final Map<String, dynamic> data = response.data as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return {
          'user': User.fromMap(data['user']),
          'token': data['token'],
          'message': data['message'],
        };
      }

      throw CustomException(
        code: data['error']?['code'] ?? 'ERROR',
        message: data['error']?['message'] ?? 'Failed to reset password',
      );
    } on DioException catch (e) {
      throw CustomException(
        code: e.response?.data?['error']?['code'] ?? 'ERROR',
        message: e.response?.data?['error']?['message'] ??
            'Failed to reset password',
      );
    }
  }
}
