import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Strings {
  static String get baseApiUrl {
    final url = dotenv.env['BASE_API_URL'] ?? 'http://localhost:5000/api';
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        url.contains('localhost')) {
      return url.replaceAll('localhost', '10.0.2.2');
    }
    return url;
  }

  static String mapApiKey = dotenv.env['TOMTOM_MAP_API'] ?? 'dummy_tomtom_api_key';
  static String razorpayKeyId = dotenv.env['RAZORPAY_KEY_ID'] ?? 'dummy_razorpay_key_id';
  static String razorpayKeySecret = dotenv.env['RAZORPAY_KEY_SECRET'] ?? 'dummy_razorpay_key_secret';
  static const String saffarCaption = 'Ride with ease and comfort.';
}
