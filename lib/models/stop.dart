class RouteStop {
  final String id;
  final String? routeId;
  final String? orderId;
  final int? sequence;
  final String? stopType;
  final String? status;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? customerName;
  final String? photoUrl;
  final String? notes;
  final String? arrivedAt;
  final String? completedAt;
  final String? createdAt;

  RouteStop({
    required this.id,
    this.routeId,
    this.orderId,
    this.sequence,
    this.stopType,
    this.status,
    this.address,
    this.latitude,
    this.longitude,
    this.customerName,
    this.photoUrl,
    this.notes,
    this.arrivedAt,
    this.completedAt,
    this.createdAt,
  });

  factory RouteStop.fromJson(Map<String, dynamic> json) {
    return RouteStop(
      id: json['id'] as String,
      routeId: json['route_id'] as String?,
      orderId: json['order_id'] as String?,
      sequence: json['sequence'] as int?,
      stopType: json['stop_type'] as String?,
      status: json['status'] as String?,
      address: json['address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      customerName: json['customer_name'] as String?,
      photoUrl: json['photo_url'] as String?,
      notes: json['notes'] as String?,
      arrivedAt: json['arrived_at'] as String?,
      completedAt: json['completed_at'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }

  RouteStop copyWith({
    String? id,
    String? routeId,
    String? orderId,
    int? sequence,
    String? stopType,
    String? status,
    String? address,
    double? latitude,
    double? longitude,
    String? customerName,
    String? photoUrl,
    String? notes,
    String? arrivedAt,
    String? completedAt,
    String? createdAt,
  }) {
    return RouteStop(
      id: id ?? this.id,
      routeId: routeId ?? this.routeId,
      orderId: orderId ?? this.orderId,
      sequence: sequence ?? this.sequence,
      stopType: stopType ?? this.stopType,
      status: status ?? this.status,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      customerName: customerName ?? this.customerName,
      photoUrl: photoUrl ?? this.photoUrl,
      notes: notes ?? this.notes,
      arrivedAt: arrivedAt ?? this.arrivedAt,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
