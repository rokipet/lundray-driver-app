import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../config/supabase.dart';
import '../models/bag.dart';
import '../models/stop.dart';
import '../providers/routes_provider.dart';

/// Screen for verifying bags at delivery stops.
/// Checks each scanned bag belongs to this stop's order, then marks it delivered.
class DeliveryScanScreen extends ConsumerStatefulWidget {
  final String routeId;
  final String stopId;

  const DeliveryScanScreen({
    super.key,
    required this.routeId,
    required this.stopId,
  });

  @override
  ConsumerState<DeliveryScanScreen> createState() => _DeliveryScanScreenState();
}

class _DeliveryScanScreenState extends ConsumerState<DeliveryScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  final Set<String> _processedCodes = {};
  final Set<String> _verifiedBagIds = {};
  bool _isProcessing = false;
  String? _lastMessage;
  bool? _lastSuccess;

  List<Bag> _expectedBags = [];
  bool _loadingExpected = true;
  String? _orderId;

  @override
  void initState() {
    super.initState();
    _loadExpectedBags();
  }

  RouteStop? _findStop(RouteDetailState state) {
    try {
      return state.stops.firstWhere((s) => s.id == widget.stopId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadExpectedBags() async {
    try {
      final state = ref.read(routeDetailProvider(widget.routeId));
      final stop = _findStop(state);
      _orderId = stop?.orderId;

      if (_orderId == null) {
        setState(() {
          _expectedBags = [];
          _loadingExpected = false;
        });
        return;
      }

      // Fetch all bags for this order
      final data = await supabase
          .from('bags')
          .select()
          .eq('order_id', _orderId!)
          .order('created_at', ascending: false);

      final bags = (data as List).map((j) => Bag.fromJson(j)).toList();
      // Pre-populate verified set with bags already marked delivered
      final alreadyDelivered = bags
          .where((b) => b.status == 'delivered')
          .map((b) => b.id)
          .toSet();

      // Also mark already-delivered bag codes as processed so scanner skips them
      final deliveredCodes = bags
          .where((b) => b.status == 'delivered' && b.bagCode != null)
          .map((b) => b.bagCode!)
          .toSet();

      setState(() {
        _expectedBags = bags;
        _verifiedBagIds.addAll(alreadyDelivered);
        _processedCodes.addAll(deliveredCodes);
        _loadingExpected = false;
      });
    } catch (e) {
      setState(() {
        _loadingExpected = false;
        _lastMessage = 'Failed to load bags';
        _lastSuccess = false;
      });
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    final code = barcode.rawValue!;
    if (_processedCodes.contains(code)) return;

    setState(() {
      _isProcessing = true;
      _lastMessage = null;
    });

    _processedCodes.add(code);

    // Step 1: Verify the bag belongs to this order
    Bag? matchedBag;
    try {
      matchedBag = _expectedBags.firstWhere((b) => b.bagCode == code);
    } catch (_) {
      matchedBag = null;
    }

    if (matchedBag == null) {
      setState(() {
        _lastMessage = 'Bag $code does not belong to this order';
        _lastSuccess = false;
        _isProcessing = false;
      });
      Future.delayed(const Duration(seconds: 2), () {
        _processedCodes.remove(code);
      });
      return;
    }

    if (_verifiedBagIds.contains(matchedBag.id)) {
      setState(() {
        _lastMessage = 'Bag $code already verified';
        _lastSuccess = false;
        _isProcessing = false;
      });
      return;
    }

    // Step 2: Call API to mark bag as delivered
    final bag = await ref
        .read(routeDetailProvider(widget.routeId).notifier)
        .deliverBag(code);

    if (bag != null) {
      setState(() {
        _verifiedBagIds.add(matchedBag!.id);
        _lastMessage = 'Bag $code delivered';
        _lastSuccess = true;
        _isProcessing = false;
      });
    } else {
      final error = ref.read(routeDetailProvider(widget.routeId)).error;
      setState(() {
        _lastMessage = error ?? 'Failed to deliver bag';
        _lastSuccess = false;
        _isProcessing = false;
      });
      Future.delayed(const Duration(seconds: 2), () {
        _processedCodes.remove(code);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalExpected = _expectedBags.length;
    final scannedCount = _verifiedBagIds.length;
    final allScanned = totalExpected > 0 && scannedCount == totalExpected;

    return Scaffold(
      appBar: AppBar(
        title: Text('Verify Delivery ($scannedCount/$totalExpected)'),
        backgroundColor: const Color(0xFF111827),
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(scannedCount),
            child: const Text(
              'Done',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
      body: _loadingExpected
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Progress bar
                LinearProgressIndicator(
                  value: totalExpected > 0 ? scannedCount / totalExpected : 0,
                  backgroundColor: const Color(0xFFE5E7EB),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    allScanned
                        ? const Color(0xFF10B981)
                        : const Color(0xFF3B82F6),
                  ),
                  minHeight: 4,
                ),

                // Scanner
                Expanded(
                  flex: 3,
                  child: Stack(
                    children: [
                      MobileScanner(
                        controller: _controller,
                        onDetect: _onDetect,
                      ),
                      Center(
                        child: Container(
                          width: 250,
                          height: 250,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: const Color(0xFF10B981),
                              width: 3,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      if (_lastMessage != null)
                        Positioned(
                          bottom: 16,
                          left: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: _lastSuccess == true
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _lastSuccess == true
                                      ? Icons.check_circle
                                      : Icons.error,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    _lastMessage!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (allScanned)
                        Positioned(
                          top: 16,
                          left: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle,
                                    color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'All bags delivered!',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (_isProcessing)
                        const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF10B981),
                          ),
                        ),
                    ],
                  ),
                ),

                // Bags checklist
                Expanded(
                  flex: 2,
                  child: Container(
                    color: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: Row(
                            children: [
                              const Text(
                                'Bags to Deliver',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: allScanned
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFF6B7280),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$scannedCount/$totalExpected',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: _expectedBags.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No bags found for this order',
                                    style:
                                        TextStyle(color: Color(0xFF9CA3AF)),
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  itemCount: _expectedBags.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final bag = _expectedBags[index];
                                    final isVerified =
                                        _verifiedBagIds.contains(bag.id);
                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: Icon(
                                        isVerified
                                            ? Icons.check_circle
                                            : Icons.radio_button_unchecked,
                                        color: isVerified
                                            ? const Color(0xFF10B981)
                                            : const Color(0xFFD1D5DB),
                                      ),
                                      title: Text(
                                        bag.bagCode ?? 'Unknown',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: isVerified
                                              ? Colors.black87
                                              : const Color(0xFF9CA3AF),
                                        ),
                                      ),
                                      trailing: isVerified
                                          ? const Text(
                                              'Delivered',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF10B981),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            )
                                          : const Text(
                                              'Pending',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF9CA3AF),
                                              ),
                                            ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
