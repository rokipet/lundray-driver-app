class Bag {
  final String id;
  final String? bagCode;
  final String? orderId;
  final String? routeId;
  final String? status;
  final String? taggedBy;
  final String? taggedAt;
  final double? weight;
  final String? createdAt;

  Bag({
    required this.id,
    this.bagCode,
    this.orderId,
    this.routeId,
    this.status,
    this.taggedBy,
    this.taggedAt,
    this.weight,
    this.createdAt,
  });

  factory Bag.fromJson(Map<String, dynamic> json) {
    return Bag(
      id: json['id'] as String,
      bagCode: json['bag_code'] as String?,
      orderId: json['order_id'] as String?,
      routeId: json['route_id'] as String?,
      status: json['status'] as String?,
      taggedBy: json['tagged_by'] as String?,
      taggedAt: json['tagged_at'] as String?,
      weight: (json['weight'] as num?)?.toDouble(),
      createdAt: json['created_at'] as String?,
    );
  }
}
