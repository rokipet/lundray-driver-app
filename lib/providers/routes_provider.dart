import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:realtime_client/realtime_client.dart';
import '../config/supabase.dart';
import '../models/route.dart';
import '../models/stop.dart';
import '../models/bag.dart';
import 'auth_provider.dart';

// Today's routes provider
class TodayRoutesNotifier extends StateNotifier<AsyncValue<List<DriverRoute>>> {
  final Ref ref;
  RealtimeChannel? _channel;

  TodayRoutesNotifier(this.ref) : super(const AsyncValue.loading()) {
    _loadRoutes();
    _setupRealtime();
  }

  Future<void> _loadRoutes() async {
    try {
      final auth = ref.read(authProvider);
      if (auth.user == null) {
        state = const AsyncValue.data([]);
        return;
      }

      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final response = await supabase
          .from('routes')
          .select('*, route_stops(id)')
          .eq('driver_id', auth.user!.id)
          .eq('scheduled_date', todayStr)
          .order('created_at', ascending: false);

      final routes = (response as List).map((json) {
        final route = DriverRoute.fromJson(json);
        final stops = json['route_stops'] as List?;
        return route.copyWith(stopCount: stops?.length ?? 0);
      }).toList();

      state = AsyncValue.data(routes);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void _setupRealtime() {
    final auth = ref.read(authProvider);
    if (auth.user == null) return;

    _channel = supabase.channel('routes_realtime');
    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'routes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'driver_id',
            value: auth.user!.id,
          ),
          callback: (payload) {
            _loadRoutes();
          },
        )
        .subscribe();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    await _loadRoutes();
  }

  @override
  void dispose() {
    if (_channel != null) {
      supabase.removeChannel(_channel!);
    }
    super.dispose();
  }
}

final todayRoutesProvider =
    StateNotifierProvider<TodayRoutesNotifier, AsyncValue<List<DriverRoute>>>(
        (ref) {
  return TodayRoutesNotifier(ref);
});

// All routes provider
class AllRoutesNotifier extends StateNotifier<AsyncValue<List<DriverRoute>>> {
  final Ref ref;

  AllRoutesNotifier(this.ref) : super(const AsyncValue.loading()) {
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    try {
      final auth = ref.read(authProvider);
      if (auth.user == null) {
        state = const AsyncValue.data([]);
        return;
      }

      final response = await supabase
          .from('routes')
          .select('*, route_stops(id)')
          .eq('driver_id', auth.user!.id)
          .order('scheduled_date', ascending: false)
          .order('created_at', ascending: false);

      final routes = (response as List).map((json) {
        final route = DriverRoute.fromJson(json);
        final stops = json['route_stops'] as List?;
        return route.copyWith(stopCount: stops?.length ?? 0);
      }).toList();

      state = AsyncValue.data(routes);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    await _loadRoutes();
  }
}

final allRoutesProvider =
    StateNotifierProvider<AllRoutesNotifier, AsyncValue<List<DriverRoute>>>(
        (ref) {
  return AllRoutesNotifier(ref);
});

// Route detail state
class RouteDetailState {
  final DriverRoute? route;
  final List<RouteStop> stops;
  final List<Bag> bags;
  final bool isLoading;
  final String? error;

  const RouteDetailState({
    this.route,
    this.stops = const [],
    this.bags = const [],
    this.isLoading = false,
    this.error,
  });

  RouteDetailState copyWith({
    DriverRoute? route,
    List<RouteStop>? stops,
    List<Bag>? bags,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return RouteDetailState(
      route: route ?? this.route,
      stops: stops ?? this.stops,
      bags: bags ?? this.bags,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  RouteStop? get currentStop {
    try {
      return stops.firstWhere(
          (s) => s.status == 'pending' || s.status == 'arrived');
    } catch (_) {
      return null;
    }
  }
}

class RouteDetailNotifier extends StateNotifier<RouteDetailState> {
  final String routeId;
  final Ref ref;
  RealtimeChannel? _channel;

  RouteDetailNotifier(this.routeId, this.ref)
      : super(const RouteDetailState(isLoading: true)) {
    _load();
    _setupRealtime();
  }

  Future<void> _load() async {
    try {
      final routeResponse =
          await supabase.from('routes').select().eq('id', routeId).single();

      final route = DriverRoute.fromJson(routeResponse);

      final stopsResponse = await supabase
          .from('route_stops')
          .select()
          .eq('route_id', routeId)
          .order('sequence', ascending: true);

      final stops =
          (stopsResponse as List).map((j) => RouteStop.fromJson(j)).toList();

      final bagsResponse = await supabase
          .from('bags')
          .select()
          .eq('route_id', routeId)
          .order('created_at', ascending: false);

      final bags =
          (bagsResponse as List).map((j) => Bag.fromJson(j)).toList();

      state = RouteDetailState(route: route, stops: stops, bags: bags);
    } catch (e) {
      state = RouteDetailState(error: 'Failed to load route: $e');
    }
  }

  void _setupRealtime() {
    _channel = supabase.channel('route_detail_$routeId');
    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'routes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: routeId,
          ),
          callback: (payload) {
            _load();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'route_stops',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'route_id',
            value: routeId,
          ),
          callback: (payload) {
            _load();
          },
        )
        .subscribe();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    await _load();
  }

  Future<void> updateRoute(Map<String, dynamic> updates) async {
    try {
      state = state.copyWith(isLoading: true, clearError: true);

      final headers = getAuthHeaders();
      final response = await http.patch(
        Uri.parse('$siteUrl/api/routes/$routeId'),
        headers: headers,
        body: jsonEncode(updates),
      );

      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        throw Exception(body['error'] ?? 'Failed to update route');
      }

      await _load();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Update failed: $e');
    }
  }

  Future<void> startRoute() async {
    try {
      state = state.copyWith(isLoading: true, clearError: true);
      final headers = getAuthHeaders();
      final response = await http.post(
        Uri.parse('$siteUrl/api/routes/$routeId/start'),
        headers: headers,
      );

      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        throw Exception(body['error'] ?? 'Failed to start route');
      }

      await _load();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Start failed: $e');
    }
  }

  /// Updates a stop status via the API (not direct Supabase).
  /// This ensures SMS notifications, order status propagation, and
  /// sequential enforcement all work properly.
  Future<void> updateStopStatus(String stopId, String newStatus,
      {String? notes, String? photoUrl}) async {
    try {
      state = state.copyWith(isLoading: true, clearError: true);

      final headers = getAuthHeaders();
      final body = <String, dynamic>{'status': newStatus};
      if (notes != null) body['notes'] = notes;
      if (photoUrl != null) body['photo_url'] = photoUrl;

      final response = await http.patch(
        Uri.parse('$siteUrl/api/routes/$routeId/stops/$stopId'),
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) {
        final respBody = jsonDecode(response.body);
        throw Exception(respBody['error'] ?? 'Failed to update stop');
      }

      await _load();
    } catch (e) {
      state =
          state.copyWith(isLoading: false, error: 'Stop update failed: $e');
    }
  }

  Future<void> updateStopPhoto(String stopId, String photoUrl) async {
    try {
      await supabase
          .from('route_stops')
          .update({'photo_url': photoUrl}).eq('id', stopId);
      await _load();
    } catch (e) {
      state = state.copyWith(error: 'Photo update failed: $e');
    }
  }

  /// Creates a bag via the API endpoint for proper duplicate checking
  /// and bag code generation.
  Future<Bag?> createBag(String bagCode, String? orderId) async {
    try {
      final headers = getAuthHeaders();
      final body = <String, dynamic>{
        'bag_code': bagCode,
        'order_id': orderId,
        'route_id': routeId,
      };

      final response = await http.post(
        Uri.parse('$siteUrl/api/bags'),
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 409) {
        state = state.copyWith(error: 'Bag already scanned');
        return null;
      }

      if (response.statusCode != 200 && response.statusCode != 201) {
        final respBody = jsonDecode(response.body);
        throw Exception(respBody['error'] ?? 'Failed to create bag');
      }

      final respBody = jsonDecode(response.body);
      final bag = Bag.fromJson(respBody['bag'] ?? respBody);
      state = state.copyWith(bags: [bag, ...state.bags]);
      return bag;
    } catch (e) {
      if (e.toString().contains('409') ||
          e.toString().contains('duplicate') ||
          e.toString().contains('already')) {
        state = state.copyWith(error: 'Bag already scanned');
      } else {
        state = state.copyWith(error: 'Failed to create bag: $e');
      }
      return null;
    }
  }

  /// Complete the route via the API (handles order propagation for pickup routes).
  Future<void> completeRoute() async {
    try {
      state = state.copyWith(isLoading: true, clearError: true);

      final headers = getAuthHeaders();
      final response = await http.patch(
        Uri.parse('$siteUrl/api/routes/$routeId'),
        headers: headers,
        body: jsonEncode({'status': 'completed'}),
      );

      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        throw Exception(body['error'] ?? 'Failed to complete route');
      }

      await _load();
    } catch (e) {
      state = state.copyWith(
          isLoading: false, error: 'Route completion failed: $e');
    }
  }

  @override
  void dispose() {
    if (_channel != null) {
      supabase.removeChannel(_channel!);
    }
    super.dispose();
  }
}

final routeDetailProvider = StateNotifierProvider.family<RouteDetailNotifier,
    RouteDetailState, String>((ref, routeId) {
  return RouteDetailNotifier(routeId, ref);
});
