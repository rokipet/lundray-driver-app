import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../config/supabase.dart';

class LocationTracker extends StateNotifier<bool> {
  Timer? _timer;

  LocationTracker() : super(false);

  Future<void> startTracking() async {
    if (state) return; // Already tracking

    // Check permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
    }

    state = true;

    // Send location immediately, then every 30 seconds
    _sendLocation();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      _sendLocation();
    });
  }

  void stopTracking() {
    _timer?.cancel();
    _timer = null;
    state = false;
  }

  Future<void> _sendLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final headers = getAuthHeaders();
      await http.post(
        Uri.parse('$siteUrl/api/driver-location'),
        headers: headers,
        body: jsonEncode({
          'latitude': position.latitude,
          'longitude': position.longitude,
          'heading': position.heading,
          'speed': position.speed,
        }),
      );
    } catch (e) {
      // Silently fail — location tracking shouldn't interrupt the app
    }
  }

  @override
  void dispose() {
    stopTracking();
    super.dispose();
  }
}

final locationTrackerProvider =
    StateNotifierProvider<LocationTracker, bool>((ref) {
  return LocationTracker();
});
