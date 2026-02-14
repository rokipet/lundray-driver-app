import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:storage_client/storage_client.dart' show FileOptions;
import '../config/supabase.dart';
import '../models/stop.dart';
import '../providers/routes_provider.dart';
import '../widgets/status_badge.dart';

class StopDetailScreen extends ConsumerStatefulWidget {
  final String routeId;
  final String stopId;

  const StopDetailScreen({
    super.key,
    required this.routeId,
    required this.stopId,
  });

  @override
  ConsumerState<StopDetailScreen> createState() => _StopDetailScreenState();
}

class _StopDetailScreenState extends ConsumerState<StopDetailScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _uploadingPhoto = false;

  RouteStop? _findStop(RouteDetailState state) {
    try {
      return state.stops.firstWhere((s) => s.id == widget.stopId);
    } catch (_) {
      return null;
    }
  }

  bool _isCurrentStop(RouteDetailState state, RouteStop stop) {
    final current = state.currentStop;
    return current?.id == stop.id;
  }

  Future<void> _openNavigation(RouteStop stop) async {
    final lat = stop.latitude;
    final lng = stop.longitude;
    final address = stop.address;

    if (lat == null && lng == null && (address == null || address.isEmpty)) {
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Navigate with',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading:
                    const Icon(Icons.map, color: Color(0xFF4285F4)),
                title: const Text('Google Maps'),
                onTap: () {
                  Navigator.pop(ctx);
                  final dest = lat != null && lng != null
                      ? '$lat,$lng'
                      : Uri.encodeComponent(address!);
                  launchUrl(
                    Uri.parse(
                        'https://www.google.com/maps/dir/?api=1&destination=$dest'),
                    mode: LaunchMode.externalApplication,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.directions,
                    color: Color(0xFF000000)),
                title: const Text('Apple Maps'),
                onTap: () {
                  Navigator.pop(ctx);
                  final dest = lat != null && lng != null
                      ? '$lat,$lng'
                      : Uri.encodeComponent(address!);
                  launchUrl(
                    Uri.parse('https://maps.apple.com/?daddr=$dest'),
                    mode: LaunchMode.externalApplication,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.navigation,
                    color: Color(0xFF33CCFF)),
                title: const Text('Waze'),
                onTap: () {
                  Navigator.pop(ctx);
                  if (lat != null && lng != null) {
                    launchUrl(
                      Uri.parse(
                          'https://waze.com/ul?ll=$lat,$lng&navigate=yes'),
                      mode: LaunchMode.externalApplication,
                    );
                  } else {
                    launchUrl(
                      Uri.parse(
                          'https://waze.com/ul?q=${Uri.encodeComponent(address!)}&navigate=yes'),
                      mode: LaunchMode.externalApplication,
                    );
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _takePhoto() async {
    setState(() => _uploadingPhoto = true);
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 80,
        maxWidth: 1200,
      );

      if (image == null) {
        if (mounted) setState(() => _uploadingPhoto = false);
        return;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path =
          'routes/${widget.routeId}/stop-${widget.stopId}-$timestamp.jpg';
      final bytes = await image.readAsBytes();

      await supabase.storage.from('order-photos').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );

      final url = supabase.storage.from('order-photos').getPublicUrl(path);

      await ref
          .read(routeDetailProvider(widget.routeId).notifier)
          .updateStopPhoto(widget.stopId, url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    if (mounted) setState(() => _uploadingPhoto = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(routeDetailProvider(widget.routeId));
    final stop = _findStop(state);

    if (stop == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Stop Details'),
          backgroundColor: const Color(0xFF111827),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('Stop not found')),
      );
    }

    final isCurrent = _isCurrentStop(state, stop);
    final isPartnerStop =
        stop.stopType == 'partner_pickup' || stop.stopType == 'partner_dropoff';
    final bagsForStop =
        state.bags.where((b) => b.orderId == stop.orderId).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(stop.customerName ?? 'Stop #${stop.sequence ?? 0}'),
        backgroundColor: const Color(0xFF111827),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Stop info card
          _buildInfoCard(stop),
          const SizedBox(height: 16),

          // Sequential enforcement
          if (!isCurrent &&
              stop.status != 'completed' &&
              stop.status != 'skipped') ...[
            _buildBlockedCard(),
          ] else ...[
            // Pending state
            if (stop.status == 'pending') _buildPendingActions(state, stop),

            // Arrived state
            if (stop.status == 'arrived')
              isPartnerStop
                  ? _buildPartnerArrivedActions(state, stop)
                  : _buildCustomerArrivedActions(
                      state, stop, bagsForStop.length),

            // Completed state
            if (stop.status == 'completed') _buildCompletedCard(stop),

            // Skipped state
            if (stop.status == 'skipped') _buildSkippedCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard(RouteStop stop) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      '${stop.sequence ?? 0}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stop.customerName ?? _stopTypeLabel(stop.stopType),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (stop.stopType != null)
                        Text(
                          _stopTypeLabel(stop.stopType),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                    ],
                  ),
                ),
                StatusBadge(status: stop.status ?? 'pending'),
              ],
            ),
            if (stop.address != null && stop.address!.isNotEmpty) ...[
              const Divider(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on,
                      size: 18, color: Color(0xFF6B7280)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      stop.address!,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openNavigation(stop),
                icon: const Icon(Icons.navigation),
                label: const Text('Navigate'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF10B981),
                  side: const BorderSide(color: Color(0xFF10B981)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockedCard() {
    return Card(
      color: const Color(0xFFFEF3C7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.lock, color: Color(0xFF92400E)),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Complete the previous stop first',
                style: TextStyle(
                  color: Color(0xFF92400E),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingActions(RouteDetailState state, RouteStop stop) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: state.isLoading
                ? null
                : () => ref
                    .read(routeDetailProvider(widget.routeId).notifier)
                    .updateStopStatus(stop.id, 'arrived'),
            icon: const Icon(Icons.location_on),
            label: const Text('I\'m Here'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: state.isLoading
                ? null
                : () => ref
                    .read(routeDetailProvider(widget.routeId).notifier)
                    .updateStopStatus(stop.id, 'skipped'),
            icon: const Icon(Icons.skip_next),
            label: const Text('Skip'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF6B7280),
              side: const BorderSide(color: Color(0xFFD1D5DB)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerArrivedActions(
      RouteDetailState state, RouteStop stop, int bagCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Scan bags — pickup: tag new bags, delivery: verify existing bags
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () => stop.stopType == 'delivery'
                ? context.push(
                    '/route/${widget.routeId}/stop/${stop.id}/delivery-scan')
                : context.push(
                    '/route/${widget.routeId}/stop/${stop.id}/scan'),
            icon: const Icon(Icons.qr_code_scanner),
            label: Text(stop.stopType == 'delivery'
                ? 'Verify Bags'
                : 'Scan Bags ($bagCount tagged)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Take photo
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _uploadingPhoto ? null : _takePhoto,
            icon: _uploadingPhoto
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.camera_alt),
            label: Text(stop.photoUrl != null ? 'Retake Photo' : 'Take Photo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B7280),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),

        if (stop.photoUrl != null) ...[
          const SizedBox(height: 8),
          const Row(
            children: [
              Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
              SizedBox(width: 4),
              Text('Photo uploaded',
                  style: TextStyle(color: Color(0xFF10B981), fontSize: 13)),
            ],
          ),
        ],

        const SizedBox(height: 16),

        // Complete stop
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: state.isLoading
                ? null
                : () => ref
                    .read(routeDetailProvider(widget.routeId).notifier)
                    .updateStopStatus(stop.id, 'completed'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: state.isLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    'Complete Stop',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildPartnerArrivedActions(RouteDetailState state, RouteStop stop) {
    final isDropoff = stop.stopType == 'partner_dropoff';
    final isPickup = stop.stopType == 'partner_pickup';
    final totalBags = state.bags.length;

    return Column(
      children: [
        // Verify bags button (only for drop-off stops with bags)
        if (isDropoff && totalBags > 0) ...[
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => context.push(
                  '/route/${widget.routeId}/stop/${stop.id}/verify'),
              icon: const Icon(Icons.qr_code_scanner),
              label: Text('Verify Bags ($totalBags bags)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Scan clean bags button (partner pickup — delivery route)
        if (isPickup) ...[
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => context.push(
                  '/route/${widget.routeId}/stop/${stop.id}/pickup-scan'),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan Clean Bags'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Confirm button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: state.isLoading
                ? null
                : () => ref
                    .read(routeDetailProvider(widget.routeId).notifier)
                    .updateStopStatus(stop.id, 'completed'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: state.isLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    isDropoff ? 'Confirm Drop-off' : 'Confirm Pickup',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedCard(RouteStop stop) {
    return Card(
      color: const Color(0xFFD1FAE5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF065F46), size: 40),
            const SizedBox(height: 8),
            const Text(
              'Stop Completed',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF065F46),
              ),
            ),
            if (stop.completedAt != null) ...[
              const SizedBox(height: 4),
              Text(
                'Completed at ${stop.completedAt}',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF065F46),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSkippedCard() {
    return Card(
      color: const Color(0xFFF3F4F6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.skip_next, color: Color(0xFF6B7280), size: 40),
            SizedBox(height: 8),
            Text(
              'Stop Skipped',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _stopTypeLabel(String? type) {
    switch (type) {
      case 'pickup':
        return 'Pickup';
      case 'delivery':
        return 'Delivery';
      case 'partner_pickup':
        return 'Partner Pickup';
      case 'partner_dropoff':
        return 'Partner Drop-off';
      default:
        return 'Stop';
    }
  }
}
