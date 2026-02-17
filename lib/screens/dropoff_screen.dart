import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/routes_provider.dart';
import '../widgets/status_badge.dart';

class DropoffScreen extends ConsumerStatefulWidget {
  final String routeId;

  const DropoffScreen({super.key, required this.routeId});

  @override
  ConsumerState<DropoffScreen> createState() => _DropoffScreenState();
}

class _DropoffScreenState extends ConsumerState<DropoffScreen> {
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(routeDetailProvider(widget.routeId));
    final route = state.route;

    if (route == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Drop-off'),
          backgroundColor: const Color(0xFF111827),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final bags = state.bags;
    final completedStops =
        state.stops.where((s) => s.status == 'completed').length;
    final totalStops = state.stops.length;
    final isCompleted = route.status == 'completed' || _confirmed;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laundry Facility Drop-off'),
        backgroundColor: const Color(0xFF111827),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Route info header
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          route.routeNumber ?? 'Route',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      StatusBadge(
                        status: isCompleted ? 'completed' : 'dropping_off',
                      ),
                    ],
                  ),
                  if (route.scheduledDate != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      route.scheduledDate!,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Summary card
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _summaryRow('Total Bags', '${bags.length}'),
                  const Divider(height: 16),
                  _summaryRow(
                      'Stops Completed', '$completedStops of $totalStops'),
                  const Divider(height: 16),
                  _summaryRow('Route Type',
                      (route.routeType ?? 'pickup').toUpperCase()),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Bags list
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bags to Drop Off',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (bags.isEmpty)
                    const Text(
                      'No bags on this route.',
                      style: TextStyle(color: Color(0xFF6B7280)),
                    )
                  else
                    ...bags.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final bag = entry.value;
                      final category = bag.orderId != null
                          ? state.orderCategories[bag.orderId!]
                          : null;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 24,
                              child: Text(
                                '${idx + 1}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Row(
                                children: [
                                  Text(
                                    bag.bagCode ?? 'Unknown',
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (category != null) ...[
                                    const SizedBox(width: 6),
                                    CategoryBadge(category: category),
                                  ],
                                ],
                              ),
                            ),
                            if (bag.weight != null)
                              Text(
                                '${bag.weight} lbs',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            const SizedBox(width: 8),
                            StatusBadge(status: bag.status ?? 'tagged'),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Info note
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFDBEAFE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Color(0xFF1E40AF), size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'The facility will scan to receive',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E40AF),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'After you drop off the bags, the facility will scan each bag to confirm receipt. Make sure all bags are accounted for before leaving.',
                        style:
                            TextStyle(fontSize: 13, color: Color(0xFF1E40AF)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Confirm/Success
          if (isCompleted) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Icon(Icons.check_circle,
                      color: Color(0xFF065F46), size: 48),
                  const SizedBox(height: 12),
                  const Text(
                    'Drop-off Confirmed',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF065F46),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${bags.length} bag(s) dropped off successfully. Route complete!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF065F46),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.go('/routes'),
                    child: const Text(
                      'Back to My Routes',
                      style: TextStyle(color: Color(0xFF065F46)),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: bags.isEmpty || state.isLoading
                    ? null
                    : () async {
                        await ref
                            .read(
                                routeDetailProvider(widget.routeId).notifier)
                            .completeRoute();
                        if (mounted) setState(() => _confirmed = true);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFD1D5DB),
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
                        bags.isEmpty
                            ? 'No bags to drop off'
                            : 'Confirm Drop-off (${bags.length} bags)',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
        Text(value,
            style:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      ],
    );
  }
}
