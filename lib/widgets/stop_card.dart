import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/stop.dart';
import 'status_badge.dart';

class StopCard extends StatelessWidget {
  final RouteStop stop;
  final bool isCurrent;
  final VoidCallback? onTap;
  final String? serviceCategory;

  const StopCard({
    super.key,
    required this.stop,
    this.isCurrent = false,
    this.onTap,
    this.serviceCategory,
  });

  Future<void> _openNavigation() async {
    String query;
    if (stop.latitude != null && stop.longitude != null) {
      query = '${stop.latitude},${stop.longitude}';
    } else if (stop.address != null && stop.address!.isNotEmpty) {
      query = Uri.encodeComponent(stop.address!);
    } else {
      return;
    }

    final url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$query');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  String get _displayName {
    if (stop.customerName != null && stop.customerName!.isNotEmpty) {
      return stop.customerName!;
    }
    switch (stop.stopType) {
      case 'partner_pickup':
        return 'Partner Pickup';
      case 'partner_dropoff':
        return 'Partner Drop-off';
      case 'pickup':
        return 'Pickup';
      case 'delivery':
        return 'Delivery';
      default:
        return 'Stop';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isCurrent ? 2 : 1,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isCurrent
            ? const BorderSide(color: Color(0xFF10B981), width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isCurrent
                      ? const Color(0xFF10B981)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Text(
                    '${stop.sequence ?? 0}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isCurrent ? Colors.white : Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (serviceCategory != null &&
                            stop.stopType != 'partner_pickup' &&
                            stop.stopType != 'partner_dropoff') ...[
                          const SizedBox(width: 6),
                          CategoryBadge(category: serviceCategory),
                        ],
                      ],
                    ),
                    if (stop.address != null && stop.address!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        stop.address!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    StatusBadge(status: stop.status ?? 'pending'),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.navigation_outlined),
                color: const Color(0xFF10B981),
                onPressed: _openNavigation,
                tooltip: 'Navigate',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
