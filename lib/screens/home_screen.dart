import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/route.dart';
import '../providers/routes_provider.dart';
import '../widgets/route_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routesAsync = ref.watch(todayRoutesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today\'s Routes'),
        backgroundColor: const Color(0xFF111827),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: routesAsync.when(
        data: (routes) {
          if (routes.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => ref.read(todayRoutesProvider.notifier).refresh(),
              child: ListView(
                children: const [
                  SizedBox(height: 120),
                  Icon(Icons.route, size: 64, color: Color(0xFFD1D5DB)),
                  SizedBox(height: 16),
                  Center(
                    child: Text(
                      'No routes for today',
                      style: TextStyle(
                        fontSize: 18,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Pull down to refresh',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          final active = routes
              .where((r) => r.status == 'in_progress' || r.status == 'dropping_off')
              .toList();
          final assigned =
              routes.where((r) => r.status == 'assigned').toList();
          final completed =
              routes.where((r) => r.status == 'completed').toList();

          return RefreshIndicator(
            onRefresh: () => ref.read(todayRoutesProvider.notifier).refresh(),
            child: ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              children: [
                if (active.isNotEmpty) ...[
                  _buildSectionHeader('Active', active.length),
                  ...active.map((r) => _buildRouteCard(context, r)),
                ],
                if (assigned.isNotEmpty) ...[
                  _buildSectionHeader('Assigned', assigned.length),
                  ...assigned.map((r) => _buildRouteCard(context, r)),
                ],
                if (completed.isNotEmpty) ...[
                  _buildSectionHeader('Completed', completed.length),
                  ...completed.map((r) => _buildRouteCard(context, r)),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Failed to load routes',
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () =>
                    ref.read(todayRoutesProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteCard(BuildContext context, DriverRoute route) {
    return RouteCard(
      route: route,
      onTap: () => context.push('/route/${route.id}'),
    );
  }
}
