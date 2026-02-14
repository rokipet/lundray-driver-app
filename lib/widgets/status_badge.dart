import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final double fontSize;

  const StatusBadge({
    super.key,
    required this.status,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getConfig(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: config.backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        config.label,
        style: TextStyle(
          color: config.textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static _BadgeConfig _getConfig(String status) {
    switch (status.toLowerCase()) {
      case 'assigned':
        return _BadgeConfig(
          label: 'Assigned',
          backgroundColor: const Color(0xFFDBEAFE),
          textColor: const Color(0xFF1E40AF),
        );
      case 'in_progress':
        return _BadgeConfig(
          label: 'In Progress',
          backgroundColor: const Color(0xFFFEF3C7),
          textColor: const Color(0xFF92400E),
        );
      case 'dropping_off':
        return _BadgeConfig(
          label: 'Dropping Off',
          backgroundColor: const Color(0xFFFDE68A),
          textColor: const Color(0xFF78350F),
        );
      case 'completed':
        return _BadgeConfig(
          label: 'Completed',
          backgroundColor: const Color(0xFFD1FAE5),
          textColor: const Color(0xFF065F46),
        );
      case 'pending':
        return _BadgeConfig(
          label: 'Pending',
          backgroundColor: const Color(0xFFF3F4F6),
          textColor: const Color(0xFF374151),
        );
      case 'arrived':
        return _BadgeConfig(
          label: 'Arrived',
          backgroundColor: const Color(0xFFFEF3C7),
          textColor: const Color(0xFF92400E),
        );
      case 'skipped':
        return _BadgeConfig(
          label: 'Skipped',
          backgroundColor: const Color(0xFFF3F4F6),
          textColor: const Color(0xFF6B7280),
        );
      default:
        return _BadgeConfig(
          label: status.replaceAll('_', ' '),
          backgroundColor: const Color(0xFFF3F4F6),
          textColor: const Color(0xFF374151),
        );
    }
  }
}

class TypeBadge extends StatelessWidget {
  final String type;
  final double fontSize;

  const TypeBadge({
    super.key,
    required this.type,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    final isPickup = type.toLowerCase().contains('pickup');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isPickup ? const Color(0xFFDBEAFE) : const Color(0xFFD1FAE5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isPickup ? 'Pickup' : 'Delivery',
        style: TextStyle(
          color:
              isPickup ? const Color(0xFF1E40AF) : const Color(0xFF065F46),
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _BadgeConfig {
  final String label;
  final Color backgroundColor;
  final Color textColor;

  _BadgeConfig({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });
}
