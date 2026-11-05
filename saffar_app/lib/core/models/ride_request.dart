class RideRequest {
  const RideRequest({
    required this.requestId,
    required this.rideId,
    required this.passengerName,
    this.passengerPhone,
    this.passengerImage,
    required this.pickupAddress,
    required this.destinationAddress,
    this.pickupLat,
    this.pickupLon,
    this.destinationLat,
    this.destinationLon,
    required this.distanceToPickup,
    this.estimatedDistance = '8.4 km',
    required this.fare,
    required this.vehicleType,
    this.otp,
    required this.expiresAt,
    this.secondsLeft = 45,
  });

  final String requestId;
  final String rideId;
  final String passengerName;
  final String? passengerPhone;
  final String? passengerImage;
  final String pickupAddress;
  final String destinationAddress;
  final double? pickupLat;
  final double? pickupLon;
  final double? destinationLat;
  final double? destinationLon;
  final String distanceToPickup;
  final String estimatedDistance;
  final double fare;
  final String vehicleType;
  final String? otp;
  final DateTime expiresAt;
  final int secondsLeft;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  factory RideRequest.fromMap(Map<String, dynamic> map) {
    DateTime parsedExpires;
    try {
      parsedExpires = map['expires_at'] != null
          ? DateTime.parse(map['expires_at'].toString())
          : DateTime.now().add(const Duration(seconds: 45));
    } catch (_) {
      parsedExpires = DateTime.now().add(const Duration(seconds: 45));
    }

    double? parseDbl(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString());
    }

    final double fareVal = parseDbl(map['fare'] ?? map['price']) ?? 135.0;

    int remaining = map['seconds_left'] != null
        ? int.tryParse(map['seconds_left'].toString()) ?? 45
        : parsedExpires.difference(DateTime.now()).inSeconds;
    if (remaining < 0) remaining = 0;

    return RideRequest(
      requestId: map['request_id']?.toString() ?? 'req_${map['ride_id']}',
      rideId: map['ride_id'].toString(),
      passengerName: map['passenger_name']?.toString() ?? 'Passenger',
      passengerPhone: map['passenger_phone']?.toString(),
      passengerImage: map['passenger_image']?.toString(),
      pickupAddress: map['pickup_address']?.toString() ?? 'Pickup Location',
      destinationAddress: map['destination_address']?.toString() ?? 'Destination',
      pickupLat: parseDbl(map['pickup_lat']),
      pickupLon: parseDbl(map['pickup_lon']),
      destinationLat: parseDbl(map['destination_lat']),
      destinationLon: parseDbl(map['destination_lon']),
      distanceToPickup: map['distance_to_pickup']?.toString() ?? '1.2 km away',
      estimatedDistance: map['estimated_distance']?.toString() ?? map['trip_distance']?.toString() ?? '8.4 km',
      fare: fareVal,
      vehicleType: map['vehicle_type']?.toString() ?? 'Auto',
      otp: map['otp']?.toString(),
      expiresAt: parsedExpires,
      secondsLeft: remaining,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'request_id': requestId,
      'ride_id': rideId,
      'passenger_name': passengerName,
      'passenger_phone': passengerPhone,
      'passenger_image': passengerImage,
      'pickup_address': pickupAddress,
      'destination_address': destinationAddress,
      'pickup_lat': pickupLat,
      'pickup_lon': pickupLon,
      'destination_lat': destinationLat,
      'destination_lon': destinationLon,
      'distance_to_pickup': distanceToPickup,
      'estimated_distance': estimatedDistance,
      'fare': fare,
      'vehicle_type': vehicleType,
      'otp': otp,
      'expires_at': expiresAt.toIso8601String(),
      'seconds_left': secondsLeft,
    };
  }

  RideRequest copyWith({
    String? requestId,
    String? rideId,
    String? passengerName,
    String? passengerPhone,
    String? passengerImage,
    String? pickupAddress,
    String? destinationAddress,
    double? pickupLat,
    double? pickupLon,
    double? destinationLat,
    double? destinationLon,
    String? distanceToPickup,
    String? estimatedDistance,
    double? fare,
    String? vehicleType,
    String? otp,
    DateTime? expiresAt,
    int? secondsLeft,
  }) {
    return RideRequest(
      requestId: requestId ?? this.requestId,
      rideId: rideId ?? this.rideId,
      passengerName: passengerName ?? this.passengerName,
      passengerPhone: passengerPhone ?? this.passengerPhone,
      passengerImage: passengerImage ?? this.passengerImage,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      destinationAddress: destinationAddress ?? this.destinationAddress,
      pickupLat: pickupLat ?? this.pickupLat,
      pickupLon: pickupLon ?? this.pickupLon,
      destinationLat: destinationLat ?? this.destinationLat,
      destinationLon: destinationLon ?? this.destinationLon,
      distanceToPickup: distanceToPickup ?? this.distanceToPickup,
      estimatedDistance: estimatedDistance ?? this.estimatedDistance,
      fare: fare ?? this.fare,
      vehicleType: vehicleType ?? this.vehicleType,
      otp: otp ?? this.otp,
      expiresAt: expiresAt ?? this.expiresAt,
      secondsLeft: secondsLeft ?? this.secondsLeft,
    );
  }
}

