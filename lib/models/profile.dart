class Profile {
  final String id;
  final String? role;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? email;
  final String? vehicleType;
  final bool? isAvailable;
  final String? businessName;
  final String? businessAddress;
  final double? latitude;
  final double? longitude;
  final String? createdAt;
  final String? updatedAt;

  Profile({
    required this.id,
    this.role,
    this.firstName,
    this.lastName,
    this.phone,
    this.email,
    this.vehicleType,
    this.isAvailable,
    this.businessName,
    this.businessAddress,
    this.latitude,
    this.longitude,
    this.createdAt,
    this.updatedAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      role: json['role'] as String?,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      vehicleType: json['vehicle_type'] as String?,
      isAvailable: json['is_available'] as bool?,
      businessName: json['business_name'] as String?,
      businessAddress: json['business_address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  Profile copyWith({
    String? id,
    String? role,
    String? firstName,
    String? lastName,
    String? phone,
    String? email,
    String? vehicleType,
    bool? isAvailable,
    String? businessName,
    String? businessAddress,
    double? latitude,
    double? longitude,
    String? createdAt,
    String? updatedAt,
  }) {
    return Profile(
      id: id ?? this.id,
      role: role ?? this.role,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      vehicleType: vehicleType ?? this.vehicleType,
      isAvailable: isAvailable ?? this.isAvailable,
      businessName: businessName ?? this.businessName,
      businessAddress: businessAddress ?? this.businessAddress,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get fullName {
    final parts = <String>[];
    if (firstName != null && firstName!.isNotEmpty) parts.add(firstName!);
    if (lastName != null && lastName!.isNotEmpty) parts.add(lastName!);
    return parts.isEmpty ? 'Driver' : parts.join(' ');
  }
}
