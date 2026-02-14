import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:storage_client/storage_client.dart' show FileOptions;
import '../config/supabase.dart';
import '../providers/routes_provider.dart';
import '../providers/location_provider.dart';
import '../widgets/status_badge.dart';
import '../widgets/stop_card.dart';

class RouteDetailScreen extends ConsumerStatefulWidget {
  final String routeId;

  const RouteDetailScreen({super.key, required this.routeId});

  @override
  ConsumerState<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends ConsumerState<RouteDetailScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _uploadingSelfie = false;
  bool _uploadingVehicle = false;
  bool _uploadingPlate = false;

  Future<String?> _uploadPhoto(String field, CameraDevice camera) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: camera,
        imageQuality: 80,
        maxWidth: 1200,
      );

      if (image == null) return null;

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = 'routes/${widget.routeId}/$field-$timestamp.jpg';
      final bytes = await image.readAsBytes();

      await supabase.storage.from('order-photos').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );

      final url =
          supabase.storage.from('order-photos').getPublicUrl(path);

      return url;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  Future<void> _takeSelfie() async {
    setState(() => _uploadingSelfie = true);
    final url = await _uploadPhoto('selfie', CameraDevice.front);
    if (url != null) {
      await ref
          .read(routeDetailProvider(widget.routeId).notifier)
          .updateRoute({'selfie_photo_url': url});
    }
    if (mounted) setState(() => _uploadingSelfie = false);
  }

  Future<void> _takeVehiclePhoto() async {
    setState(() => _uploadingVehicle = true);
    final url = await _uploadPhoto('vehicle', CameraDevice.rear);
    if (url != null) {
      await ref
          .read(routeDetailProvider(widget.routeId).notifier)
          .updateRoute({'vehicle_photo_url': url});
    }
    if (mounted) setState(() => _uploadingVehicle = false);
  }

  Future<void> _takePlatePhoto() async {
    setState(() => _uploadingPlate = true);
    final url = await _uploadPhoto('plate', CameraDevice.rear);
    if (url != null) {
      await ref
          .read(routeDetailProvider(widget.routeId).notifier)
          .updateRoute({'plate_photo_url': url});
    }
    if (mounted) setState(() => _uploadingPlate = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(routeDetailProvider(widget.routeId));
    final route = state.route;

    if (state.isLoading && route == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Route Details'),
          backgroundColor: const Color(0xFF111827),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (state.error != null && route == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Route Details'),
          backgroundColor: const Color(0xFF111827),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(state.error ?? 'Unknown error'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref
                    .read(routeDetailProvider(widget.routeId).notifier)
                    .refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (route == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Route Details'),
          backgroundColor: const Color(0xFF111827),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('Route not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(route.routeNumber ?? 'Route'),
        backgroundColor: const Color(0xFF111827),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref
                .read(routeDetailProvider(widget.routeId).notifier)
                .refresh(),
          ),
        ],
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(RouteDetailState state) {
    final route = state.route!;

    // Start/stop location tracking based on route status
    final locationTracker = ref.read(locationTrackerProvider.notifier);
    if (route.status == 'in_progress') {
      locationTracker.startTracking();
    } else if (route.status == 'completed') {
      locationTracker.stopTracking();
    }

    if (state.error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.error!),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
    }

    // Check if all stops are done on a pickup route (show dropoff button)
    final allStopsDone = state.stops.isNotEmpty &&
        state.stops.every(
            (s) => s.status == 'completed' || s.status == 'skipped');
    final isPickupRoute = route.routeType == 'pickup';
    final showDropoffButton =
        allStopsDone && isPickupRoute && route.status == 'in_progress';

    return RefreshIndicator(
      onRefresh: () => ref
          .read(routeDetailProvider(widget.routeId).notifier)
          .refresh(),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _buildRouteHeader(route),
          if (route.status == 'assigned') _buildPreStartChecklist(state),
          if (route.status == 'in_progress' || route.status == 'dropping_off')
            _buildStopsList(state),
          if (showDropoffButton) _buildDropoffButton(),
          if (route.status == 'completed') _buildCompletedSummary(state),
        ],
      ),
    );
  }

  Widget _buildDropoffButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: () => context.push('/route/${widget.routeId}/dropoff'),
          icon: const Icon(Icons.local_laundry_service),
          label: const Text(
            'Go to Laundry Facility Drop-off',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7C3AED),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRouteHeader(route) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  route.routeNumber ?? 'Route',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (route.routeType != null) TypeBadge(type: route.routeType!),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (route.status != null)
                StatusBadge(status: route.status!, fontSize: 13),
              const Spacer(),
              if (route.scheduledDate != null)
                Text(
                  route.scheduledDate!,
                  style: const TextStyle(color: Colors.grey),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreStartChecklist(RouteDetailState state) {
    final route = state.route!;
    final hasSupplies = route.suppliesPickedUp == true;
    final hasSelfie = route.selfiePhotoUrl != null;
    final hasVehicle = route.vehiclePhotoUrl != null;
    final hasPlate = route.platePhotoUrl != null;
    final allChecked = hasSupplies && hasSelfie && hasVehicle && hasPlate;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pre-Start Checklist',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildChecklistItem(
            icon: Icons.inventory_2,
            title: 'Supplies Picked Up',
            isChecked: hasSupplies,
            onTap: hasSupplies
                ? null
                : () => ref
                    .read(routeDetailProvider(widget.routeId).notifier)
                    .updateRoute({'supplies_picked_up': true}),
          ),
          const SizedBox(height: 12),
          _buildPhotoItem(
            icon: Icons.face,
            title: 'Take Selfie',
            isChecked: hasSelfie,
            isLoading: _uploadingSelfie,
            onTap: hasSelfie ? null : _takeSelfie,
          ),
          const SizedBox(height: 12),
          _buildPhotoItem(
            icon: Icons.directions_car,
            title: 'Vehicle Photo',
            isChecked: hasVehicle,
            isLoading: _uploadingVehicle,
            onTap: hasVehicle ? null : _takeVehiclePhoto,
          ),
          const SizedBox(height: 12),
          _buildPhotoItem(
            icon: Icons.badge,
            title: 'Plate Photo',
            isChecked: hasPlate,
            isLoading: _uploadingPlate,
            onTap: hasPlate ? null : _takePlatePhoto,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: allChecked && !state.isLoading
                  ? () => ref
                      .read(routeDetailProvider(widget.routeId).notifier)
                      .startRoute()
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                disabledBackgroundColor: const Color(0xFFD1D5DB),
              ),
              child: state.isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Start Route',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistItem({
    required IconData icon,
    required String title,
    required bool isChecked,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          Icon(
            isChecked ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isChecked ? const Color(0xFF10B981) : const Color(0xFFD1D5DB),
            size: 24,
          ),
          const SizedBox(width: 12),
          Icon(icon, size: 20, color: const Color(0xFF6B7280)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                color: isChecked ? const Color(0xFF6B7280) : const Color(0xFF111827),
                decoration: isChecked ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          if (!isChecked)
            const Icon(Icons.chevron_right, color: Color(0xFFD1D5DB)),
        ],
      ),
    );
  }

  Widget _buildPhotoItem({
    required IconData icon,
    required String title,
    required bool isChecked,
    required bool isLoading,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          Icon(
            isChecked ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isChecked ? const Color(0xFF10B981) : const Color(0xFFD1D5DB),
            size: 24,
          ),
          const SizedBox(width: 12),
          Icon(icon, size: 20, color: const Color(0xFF6B7280)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                color: isChecked ? const Color(0xFF6B7280) : const Color(0xFF111827),
                decoration: isChecked ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          if (isLoading)
            const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (!isChecked)
            const Icon(Icons.camera_alt, color: Color(0xFF10B981)),
        ],
      ),
    );
  }

  Widget _buildStopsList(RouteDetailState state) {
    final currentStop = state.currentStop;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            'Stops',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...state.stops.map((stop) {
          final isCurrent = currentStop?.id == stop.id;
          return StopCard(
            stop: stop,
            isCurrent: isCurrent,
            onTap: () => context.push(
              '/route/${widget.routeId}/stop/${stop.id}',
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCompletedSummary(RouteDetailState state) {
    final completed =
        state.stops.where((s) => s.status == 'completed').length;
    final skipped = state.stops.where((s) => s.status == 'skipped').length;
    final total = state.stops.length;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFD1FAE5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.check_circle,
            color: Color(0xFF065F46),
            size: 48,
          ),
          const SizedBox(height: 12),
          const Text(
            'Route Completed',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF065F46),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$completed/$total stops completed${skipped > 0 ? ', $skipped skipped' : ''}',
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF065F46),
            ),
          ),
          if (state.route?.completedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Completed at ${state.route!.completedAt!}',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF065F46),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
