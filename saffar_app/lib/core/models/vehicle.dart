class Vehicle {
  const Vehicle({
    required this.id,
    required this.driverId,
    required this.category,
    required this.model,
    required this.registrationNumber,
    required this.color,
    this.isActive = true,
    this.drivingLicenseNumber,
    this.drivingLicenseExpiry,
    this.drivingLicenseDoc,
    this.rcNumber,
    this.rcDoc,
    this.insurancePolicyNumber,
    this.insuranceExpiry,
    this.insuranceDoc,
    this.verificationStatus = 'pending',
    this.rejectionReason,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String driverId;
  final String category;
  final String model;
  final String registrationNumber;
  final String color;
  final bool isActive;
  final String? drivingLicenseNumber;
  final String? drivingLicenseExpiry;
  final String? drivingLicenseDoc;
  final String? rcNumber;
  final String? rcDoc;
  final String? insurancePolicyNumber;
  final String? insuranceExpiry;
  final String? insuranceDoc;
  final String verificationStatus; // 'approved', 'pending', 'rejected'
  final String? rejectionReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isApproved => verificationStatus.toLowerCase() == 'approved';
  bool get isPending => verificationStatus.toLowerCase() == 'pending';
  bool get isRejected => verificationStatus.toLowerCase() == 'rejected';

  factory Vehicle.fromMap(Map<String, dynamic> map) {
    return Vehicle(
      id: map['id']?.toString() ?? '',
      driverId: map['driver_id']?.toString() ?? '',
      category: map['category']?.toString() ?? 'Auto',
      model: map['model']?.toString() ?? 'Standard Vehicle',
      registrationNumber: map['registration_number']?.toString() ?? '',
      color: map['color']?.toString() ?? 'Yellow & Black',
      isActive: map['is_active'] == true || map['is_active']?.toString() == 'true',
      drivingLicenseNumber: map['driving_license_number']?.toString(),
      drivingLicenseExpiry: map['driving_license_expiry']?.toString(),
      drivingLicenseDoc: map['driving_license_doc']?.toString(),
      rcNumber: map['rc_number']?.toString(),
      rcDoc: map['rc_doc']?.toString(),
      insurancePolicyNumber: map['insurance_policy_number']?.toString(),
      insuranceExpiry: map['insurance_expiry']?.toString(),
      insuranceDoc: map['insurance_doc']?.toString(),
      verificationStatus: map['verification_status']?.toString() ?? 'pending',
      rejectionReason: map['rejection_reason']?.toString(),
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'driver_id': driverId,
      'category': category,
      'model': model,
      'registration_number': registrationNumber,
      'color': color,
      'is_active': isActive,
      'driving_license_number': drivingLicenseNumber,
      'driving_license_expiry': drivingLicenseExpiry,
      'driving_license_doc': drivingLicenseDoc,
      'rc_number': rcNumber,
      'rc_doc': rcDoc,
      'insurance_policy_number': insurancePolicyNumber,
      'insurance_expiry': insuranceExpiry,
      'insurance_doc': insuranceDoc,
      'verification_status': verificationStatus,
      'rejection_reason': rejectionReason,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Vehicle copyWith({
    String? id,
    String? driverId,
    String? category,
    String? model,
    String? registrationNumber,
    String? color,
    bool? isActive,
    String? drivingLicenseNumber,
    String? drivingLicenseExpiry,
    String? drivingLicenseDoc,
    String? rcNumber,
    String? rcDoc,
    String? insurancePolicyNumber,
    String? insuranceExpiry,
    String? insuranceDoc,
    String? verificationStatus,
    String? rejectionReason,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Vehicle(
      id: id ?? this.id,
      driverId: driverId ?? this.driverId,
      category: category ?? this.category,
      model: model ?? this.model,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      color: color ?? this.color,
      isActive: isActive ?? this.isActive,
      drivingLicenseNumber: drivingLicenseNumber ?? this.drivingLicenseNumber,
      drivingLicenseExpiry: drivingLicenseExpiry ?? this.drivingLicenseExpiry,
      drivingLicenseDoc: drivingLicenseDoc ?? this.drivingLicenseDoc,
      rcNumber: rcNumber ?? this.rcNumber,
      rcDoc: rcDoc ?? this.rcDoc,
      insurancePolicyNumber: insurancePolicyNumber ?? this.insurancePolicyNumber,
      insuranceExpiry: insuranceExpiry ?? this.insuranceExpiry,
      insuranceDoc: insuranceDoc ?? this.insuranceDoc,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

