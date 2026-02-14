import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/bag.dart';
import '../providers/routes_provider.dart';

class VerifyBagsScreen extends ConsumerStatefulWidget {
  final String routeId;
  final String stopId;

  const VerifyBagsScreen({
    super.key,
    required this.routeId,
    required this.stopId,
  });

  @override
  ConsumerState<VerifyBagsScreen> createState() => _VerifyBagsScreenState();
}

class _VerifyBagsScreenState extends ConsumerState<VerifyBagsScreen> {
  final MobileScannerController _controller = MobileScannerController();
  final Set<String> _verifiedBagIds = {};
  final Set<String> _processedCodes = {};
  bool _isProcessing = false;
  String? _lastMessage;
  bool? _lastSuccess;

  List<Bag> get _routeBags {
    final state = ref.read(routeDetailProvider(widget.routeId));
    return state.bags;
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

    // Find matching bag in route bags
    final bags = _routeBags;
    Bag? matched;
    try {
      matched = bags.firstWhere((b) => b.bagCode == code);
    } catch (_) {
      matched = null;
    }

    if (matched != null) {
      setState(() {
        _verifiedBagIds.add(matched!.id);
        _lastMessage = 'Bag verified: $code';
        _lastSuccess = true;
        _isProcessing = false;
      });
    } else {
      setState(() {
        _lastMessage = 'Unknown bag: $code';
        _lastSuccess = false;
        _isProcessing = false;
      });
      // Allow re-scanning unknown codes
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
    final bags = _routeBags;
    final totalBags = bags.length;
    final verifiedCount = _verifiedBagIds.length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Verify Bags ($verifiedCount/$totalBags)'),
        backgroundColor: const Color(0xFF111827),
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_verifiedBagIds.length),
            child: const Text(
              'Done',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress bar
          LinearProgressIndicator(
            value: totalBags > 0 ? verifiedCount / totalBags : 0,
            backgroundColor: const Color(0xFFE5E7EB),
            valueColor:
                const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
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

          // Bags verification list
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        const Text(
                          'Bags',
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
                            color: verifiedCount == totalBags && totalBags > 0
                                ? const Color(0xFF10B981)
                                : const Color(0xFF6B7280),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$verifiedCount/$totalBags verified',
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
                    child: bags.isEmpty
                        ? const Center(
                            child: Text(
                              'No bags on this route',
                              style: TextStyle(color: Color(0xFF9CA3AF)),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: bags.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final bag = bags[index];
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
                                        'Verified',
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
