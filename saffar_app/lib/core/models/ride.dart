import 'package:saffar_app/core/models/driver.dart';
import 'package:saffar_app/core/utils/model_helper.dart';

import 'address.dart';
import 'package:saffar_app/core/models/user.dart';

/// Ride from a taxi from source to destination.
class Ride {
  const Ride({
    required this.id,
    required this.user,
    required this.driver,
    required this.sourceAddress,
    required this.destinationAddress,
    required this.startTime,
    this.endTime,
    required this.cancelled,
    required this.price,
    this.discountPrice,
    this.otp = '4829',
    this.vehicleType = 'Saffar Auto',
    this.paymentMethod = 'Paid via UPI',
    this.co2Saved = 1.2,
    this.rating = 5.0,
    this.status = 'completed',
  });

  final String id;
  final User user;
  final Driver driver;
  final Address sourceAddress;
  final Address destinationAddress;
  final DateTime startTime;
  final DateTime? endTime;
  final bool cancelled;
  final double price;
  final double? discountPrice;
  final String otp;
  final String vehicleType;
  final String paymentMethod;
  final double co2Saved;
  final double rating;
  final String status;

  factory Ride.fromMap(Map<String, dynamic> map) {
    ModelHelper.throwExceptionIfRequiredFieldsNotPresentInMap(
      'Ride',
      map,
      [
        'id',
        'user',
        'driver',
        'source_address',
        'destination_address',
        'start_time',
        'price'
      ],
    );

    final DateTime? startTime = DateTime.tryParse(map['start_time'] as String);

    if (startTime == null) {
      throw Exception('Start time can not be parsed to DateTime.');
    }

    return Ride(
      id: map['id'] as String,
      user: User.fromMap(map['user']),
      driver: Driver.fromMap(map['driver']),
      sourceAddress:
          Address.fromMap(map['source_address'] as Map<dynamic, dynamic>),
      destinationAddress:
          Address.fromMap(map['destination_address'] as Map<dynamic, dynamic>),
      startTime: startTime,
      endTime: map['end_time'] != null
          ? DateTime.tryParse(map['end_time'] as String)
          : null,
      cancelled: map['cancelled'] != null ? map['cancelled'] as bool : false,
      price: double.parse(map['price'].toString()),
      discountPrice: map['discount_price'] != null
          ? double.tryParse(map['discount_price'].toString())
          : null,
      otp: map['otp'] != null ? map['otp'].toString() : '4829',
      vehicleType: map['vehicle_type'] != null
          ? map['vehicle_type'].toString()
          : (map['driver']?['vehicle_name']?.toString().contains('Auto') == true
              ? 'Saffar Auto'
              : 'Saffar Auto'),
      paymentMethod: map['payment_method'] != null
          ? map['payment_method'].toString()
          : 'Paid via UPI',
      co2Saved: map['co2_saved'] != null
          ? double.tryParse(map['co2_saved'].toString()) ?? 1.2
          : 1.2,
      rating: map['driver']?['rating'] != null
          ? double.tryParse(map['driver']['rating'].toString()) ?? 5.0
          : 5.0,
      status: map['status'] != null
          ? map['status'].toString()
          : (map['cancelled'] == true ? 'cancelled' : 'completed'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'status': status,
      'user_id': user.id,
      'driver_id': driver.id,
      'source_address': sourceAddress.toMap(),
      'destination_address': destinationAddress.toMap(),
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'cancelled': cancelled,
      'price': price,
      'discount_price': discountPrice,
      'otp': otp,
      'vehicle_type': vehicleType,
      'payment_method': paymentMethod,
      'co2_saved': co2Saved,
    };
  }
}
