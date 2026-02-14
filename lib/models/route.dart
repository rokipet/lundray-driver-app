class DriverRoute {
  final String id;
  final String? routeNumber;
  final String? driverId;
  final String? partnerId;
  final String? routeType;
  final String? status;
  final String? scheduledDate;
  final String? selfiePhotoUrl;
  final String? vehiclePhotoUrl;
  final String? platePhotoUrl;
  final bool? suppliesPickedUp;
  final String? startedAt;
  final String? completedAt;
  final String? notes;
  final String? createdAt;
  final String? updatedAt;
  final int? stopCount;

  DriverRoute({
    required this.id,
    this.routeNumber,
    this.driverId,
    this.partnerId,
    this.routeType,
    this.status,
    this.scheduledDate,
    this.selfiePhotoUrl,
    this.vehiclePhotoUrl,
    this.platePhotoUrl,
    this.suppliesPickedUp,
    this.startedAt,
    this.completedAt,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.stopCount,
  });

  factory DriverRoute.fromJson(Map<String, dynamic> json) {
    return DriverRoute(
      id: json['id'] as String,
      routeNumber: json['route_number'] as String?,
      driverId: json['driver_id'] as String?,
      partnerId: json['partner_id'] as String?,
      routeType: json['route_type'] as String?,
      status: json['status'] as String?,
      scheduledDate: json['scheduled_date'] as String?,
      selfiePhotoUrl: json['selfie_photo_url'] as String?,
      vehiclePhotoUrl: json['vehicle_photo_url'] as String?,
      platePhotoUrl: json['plate_photo_url'] as String?,
      suppliesPickedUp: json['supplies_picked_up'] as bool?,
      startedAt: json['started_at'] as String?,
      completedAt: json['completed_at'] as String?,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  DriverRoute copyWith({
    String? id,
    String? routeNumber,
    String? driverId,
    String? partnerId,
    String? routeType,
    String? status,
    String? scheduledDate,
    String? selfiePhotoUrl,
    String? vehiclePhotoUrl,
    String? platePhotoUrl,
    bool? suppliesPickedUp,
    String? startedAt,
    String? completedAt,
    String? notes,
    String? createdAt,
    String? updatedAt,
    int? stopCount,
  }) {
    return DriverRoute(
      id: id ?? this.id,
      routeNumber: routeNumber ?? this.routeNumber,
      driverId: driverId ?? this.driverId,
      partnerId: partnerId ?? this.partnerId,
      routeType: routeType ?? this.routeType,
      status: status ?? this.status,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      selfiePhotoUrl: selfiePhotoUrl ?? this.selfiePhotoUrl,
      vehiclePhotoUrl: vehiclePhotoUrl ?? this.vehiclePhotoUrl,
      platePhotoUrl: platePhotoUrl ?? this.platePhotoUrl,
      suppliesPickedUp: suppliesPickedUp ?? this.suppliesPickedUp,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      stopCount: stopCount ?? this.stopCount,
    );
  }
}
