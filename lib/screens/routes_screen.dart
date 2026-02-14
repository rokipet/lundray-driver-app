import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/routes_provider.dart';
import '../widgets/route_card.dart';

class RoutesScreen extends ConsumerWidget {
  const RoutesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routesAsync = ref.watch(allRoutesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Routes'),
        backgroundColor: const Color(0xFF111827),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: routesAsync.when(
        data: (routes) {
          if (routes.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => ref.read(allRoutesProvider.notifier).refresh(),
              child: ListView(
                children: const [
                  SizedBox(height: 120),
                  Icon(Icons.route, size: 64, color: Color(0xFFD1D5DB)),
                  SizedBox(height: 16),
                  Center(
                    child: Text(
                      'No routes found',
                      style: TextStyle(
                        fontSize: 18,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(allRoutesProvider.notifier).refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              itemCount: routes.length,
              itemBuilder: (context, index) {
                final route = routes[index];
                return RouteCard(
                  route: route,
                  onTap: () => context.push('/route/${route.id}'),
                );
              },
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
                    ref.read(allRoutesProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
