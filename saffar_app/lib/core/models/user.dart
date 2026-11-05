import 'package:saffar_app/core/utils/model_helper.dart';

/// User 
class User {
  const User({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.imageUrl,
    this.address,
    this.walletBalance = 1240.0,
    this.totalRides = 0,
    this.rating = 4.92,
    this.memberSince = 'Member since March 2023',
    this.savedPlacesCount = 2,
  });

  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? imageUrl;
  final String? address;
  final double walletBalance;
  final int totalRides;
  final double rating;
  final String? memberSince;
  final int savedPlacesCount;

  factory User.fromMap(Map<dynamic, dynamic> map) {
    ModelHelper.throwExceptionIfRequiredFieldsNotPresentInMap(
      'User',
      map,
      ['id', 'name', 'phone'],
    );

    double parseWallet(dynamic val) {
      if (val == null) return 1240.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 1240.0;
    }

    int parseInt(dynamic val, int fallback) {
      if (val == null) return fallback;
      if (val is int) return val;
      return int.tryParse(val.toString()) ?? fallback;
    }

    double parseDouble(dynamic val, double fallback) {
      if (val == null) return fallback;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? fallback;
    }

    return User(
      id: map['id'].toString(),
      name: map['name'].toString(),
      phone: map['phone'].toString(),
      email: map['email']?.toString(),
      imageUrl: (map['imageUrl'] ?? map['image_url'])?.toString(),
      address: (map['address'] ?? map['permanent_address'])?.toString(),
      walletBalance: parseWallet(map['walletBalance'] ?? map['wallet_balance']),
      totalRides: parseInt(map['totalRides'] ?? map['total_rides'], 0),
      rating: parseDouble(map['rating'], 4.92),
      memberSince: (map['memberSince'] ?? map['member_since'])?.toString() ?? 'Member since March 2023',
      savedPlacesCount: parseInt(map['savedPlacesCount'] ?? map['saved_places_count'], 2),
    );
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'imageUrl': imageUrl,
      'image_url': imageUrl,
      'address': address,
      'permanent_address': address,
      'walletBalance': walletBalance,
      'wallet_balance': walletBalance,
      'totalRides': totalRides,
      'total_rides': totalRides,
      'rating': rating,
      'memberSince': memberSince,
      'member_since': memberSince,
      'savedPlacesCount': savedPlacesCount,
      'saved_places_count': savedPlacesCount,
    };
  }

  User copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? imageUrl,
    String? address,
    double? walletBalance,
    int? totalRides,
    double? rating,
    String? memberSince,
    int? savedPlacesCount,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      imageUrl: imageUrl ?? this.imageUrl,
      address: address ?? this.address,
      walletBalance: walletBalance ?? this.walletBalance,
      totalRides: totalRides ?? this.totalRides,
      rating: rating ?? this.rating,
      memberSince: memberSince ?? this.memberSince,
      savedPlacesCount: savedPlacesCount ?? this.savedPlacesCount,
    );
  }
}

