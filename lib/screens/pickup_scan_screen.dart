import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../config/supabase.dart';
import '../models/bag.dart';
import '../providers/routes_provider.dart';

/// Screen for scanning clean bags at partner pickup stops.
/// Verifies each bag belongs to an order on this route before marking it picked up.
class PickupScanScreen extends ConsumerStatefulWidget {
  final String routeId;
  final String stopId;

  const PickupScanScreen({
    super.key,
    required this.routeId,
    required this.stopId,
  });

  @override
  ConsumerState<PickupScanScreen> createState() => _PickupScanScreenState();
}

class _PickupScanScreenState extends ConsumerState<PickupScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  final Set<String> _processedCodes = {};
  final Set<String> _verifiedBagIds = {};
  bool _isProcessing = false;
  String? _lastMessage;
  bool? _lastSuccess;

  // All bags expected for this route's orders (loaded once)
  List<Bag> _expectedBags = [];
  bool _loadingExpected = true;

  @override
  void initState() {
    super.initState();
    _loadExpectedBags();
  }

  /// Load all bags that belong to orders on this route.
  Future<void> _loadExpectedBags() async {
    try {
      final state = ref.read(routeDetailProvider(widget.routeId));
      // Get all order IDs from the route stops
      final orderIds = state.stops
          .where((s) => s.orderId != null)
          .map((s) => s.orderId!)
          .toSet()
          .toList();

      if (orderIds.isEmpty) {
        setState(() {
          _expectedBags = [];
          _loadingExpected = false;
        });
        return;
      }

      // Fetch all bags for these orders
      final data = await supabase
          .from('bags')
          .select()
          .inFilter('order_id', orderIds)
          .order('created_at', ascending: false);

      final bags = (data as List).map((j) => Bag.fromJson(j)).toList();
      // Pre-populate verified set with bags already picked up
      final alreadyPickedUp = bags
          .where((b) =>
              b.status == 'out_for_delivery' || b.status == 'delivered')
          .map((b) => b.id)
          .toSet();

      // Also mark already-picked-up bag codes as processed so scanner skips them
      final pickedUpCodes = bags
          .where((b) =>
              (b.status == 'out_for_delivery' || b.status == 'delivered') &&
              b.bagCode != null)
          .map((b) => b.bagCode!)
          .toSet();

      setState(() {
        _expectedBags = bags;
        _verifiedBagIds.addAll(alreadyPickedUp);
        _processedCodes.addAll(pickedUpCodes);
        _loadingExpected = false;
      });
    } catch (e) {
      setState(() {
        _loadingExpected = false;
        _lastMessage = 'Failed to load expected bags';
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

    // Step 1: Verify the bag belongs to this route's orders
    Bag? matchedBag;
    try {
      matchedBag = _expectedBags.firstWhere((b) => b.bagCode == code);
    } catch (_) {
      matchedBag = null;
    }

    if (matchedBag == null) {
      setState(() {
        _lastMessage = 'Bag $code does not belong to this route';
        _lastSuccess = false;
        _isProcessing = false;
      });
      // Allow re-scanning unknown codes
      Future.delayed(const Duration(seconds: 2), () {
        _processedCodes.remove(code);
      });
      return;
    }

    if (_verifiedBagIds.contains(matchedBag.id)) {
      setState(() {
        _lastMessage = 'Bag $code already scanned';
        _lastSuccess = false;
        _isProcessing = false;
      });
      return;
    }

    // Step 2: Call API to mark bag as picked up (out_for_delivery)
    final bag = await ref
        .read(routeDetailProvider(widget.routeId).notifier)
        .pickupCleanBag(code);

    if (bag != null) {
      setState(() {
        _verifiedBagIds.add(matchedBag!.id);
        _lastMessage = 'Bag $code verified & picked up';
        _lastSuccess = true;
        _isProcessing = false;
      });
    } else {
      final error = ref.read(routeDetailProvider(widget.routeId)).error;
      setState(() {
        _lastMessage = error ?? 'Failed to scan bag';
        _lastSuccess = false;
        _isProcessing = false;
      });
      // Allow retry
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
        title: Text('Verify Pickup ($scannedCount/$totalExpected)'),
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
                      // Scan overlay
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
                      // Status message
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
                      // All scanned banner
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
                                  'All bags verified!',
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
                      // Processing indicator
                      if (_isProcessing)
                        const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF10B981),
                          ),
                        ),
                    ],
                  ),
                ),

                // Expected bags checklist
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
                                'Bags to Pick Up',
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
                                    'No bags found for this route',
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
                                              'Picked up',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF10B981),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            )
                                          : const Text(
                                              'Waiting',
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
