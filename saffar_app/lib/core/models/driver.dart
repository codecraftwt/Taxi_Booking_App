import 'package:saffar_app/core/utils/model_helper.dart';

class Driver {
  const Driver({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.age,
    this.gender,
    this.address,
    required this.vehicleName,
    this.vehicleModel,
    required this.vehicleNumber,
    this.imageUrl,
    required this.active,
    bool? isOnline,
    this.verificationStatus = 'Approved',
    this.currentLat,
    this.currentLng,
    this.heading,
    this.speed,
    this.lastLocationUpdatedAt,
  }) : isOnline = isOnline ?? active;

  final String id;
  final String name;
  final String phone;
  final String? email;
  final int? age;
  final String? gender;
  final String? address;
  final String vehicleName;
  final String? vehicleModel;
  final String vehicleNumber;
  final String? imageUrl;
  final bool active;
  final bool isOnline;
  final String verificationStatus;
  final double? currentLat;
  final double? currentLng;
  final double? heading;
  final double? speed;
  final String? lastLocationUpdatedAt;

  /// Converts a map to a `Driver` instance.
  factory Driver.fromMap(Map<String, dynamic> map) {
    ModelHelper.throwExceptionIfRequiredFieldsNotPresentInMap(
      'Driver',
      map,
      [
        'id',
        'name',
        'phone',
        'vehicle_name',
        'vehicle_number',
      ],
    );

    int? parsedAge;
    if (map['age'] != null) {
      parsedAge = int.tryParse(map['age'].toString());
    }

    final bool activeVal = map['active'] == true || map['active']?.toString() == 'true';
    final bool isOnlineVal = map['is_online'] != null
        ? (map['is_online'] == true || map['is_online']?.toString() == 'true')
        : activeVal;

    double? parseDouble(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString());
    }

    return Driver(
      id: map['id'].toString(),
      name: map['name'].toString(),
      phone: map['phone'].toString(),
      email: map['email']?.toString(),
      age: parsedAge,
      gender: map['gender']?.toString(),
      address: map['address']?.toString(),
      vehicleName: map['vehicle_name'].toString(),
      vehicleModel: map['vehicle_model']?.toString() ?? map['model']?.toString(),
      vehicleNumber: map['vehicle_number'].toString(),
      imageUrl: map['image_url']?.toString(),
      active: activeVal,
      isOnline: isOnlineVal,
      verificationStatus: map['verification_status']?.toString() ?? 'Approved',
      currentLat: parseDouble(map['current_lat'] ?? map['lat'] ?? map['latitude']),
      currentLng: parseDouble(map['current_lng'] ?? map['lng'] ?? map['lon'] ?? map['longitude']),
      heading: parseDouble(map['heading']),
      speed: parseDouble(map['speed']),
      lastLocationUpdatedAt: map['last_location_updated_at']?.toString(),
    );
  }

  /// Converts a `Driver` instance to a map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'age': age,
      'gender': gender,
      'address': address,
      'vehicle_name': vehicleName,
      'vehicle_model': vehicleModel,
      'vehicle_number': vehicleNumber,
      'image_url': imageUrl,
      'active': active,
      'is_online': isOnline,
      'verification_status': verificationStatus,
      'current_lat': currentLat,
      'current_lng': currentLng,
      'heading': heading,
      'speed': speed,
      'last_location_updated_at': lastLocationUpdatedAt,
    };
  }

  Driver copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    int? age,
    String? gender,
    String? address,
    String? vehicleName,
    String? vehicleModel,
    String? vehicleNumber,
    String? imageUrl,
    bool? active,
    bool? isOnline,
    String? verificationStatus,
    double? currentLat,
    double? currentLng,
    double? heading,
    double? speed,
    String? lastLocationUpdatedAt,
  }) {
    return Driver(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      address: address ?? this.address,
      vehicleName: vehicleName ?? this.vehicleName,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      imageUrl: imageUrl ?? this.imageUrl,
      active: active ?? this.active,
      isOnline: isOnline ?? this.isOnline,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      currentLat: currentLat ?? this.currentLat,
      currentLng: currentLng ?? this.currentLng,
      heading: heading ?? this.heading,
      speed: speed ?? this.speed,
      lastLocationUpdatedAt: lastLocationUpdatedAt ?? this.lastLocationUpdatedAt,
    );
  }
}
