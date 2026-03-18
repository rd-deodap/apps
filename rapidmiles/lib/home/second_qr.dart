import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rapidmiles/home/actions/deliver_screen.dart';
import 'package:rapidmiles/home/actions/ndr_screen.dart';
import 'package:rapidmiles/home/actions/retry_screen.dart';
import 'package:rapidmiles/home/actions/rto_screen.dart';
import 'package:rapidmiles/home/actions/rto_delivered.dart';
import 'package:rapidmiles/login/login_screen.dart';


/// QR scanner that shows action buttons (Deliver, NDR, Retry, RTO) after scanning
class SecondQRScanner extends StatefulWidget {
  const SecondQRScanner({super.key});

  @override
  State<SecondQRScanner> createState() => _SecondQRScannerState();
}

class _SecondQRScannerState extends State<SecondQRScanner>
    with WidgetsBindingObserver {
  // ===== Theme (same premium cream style) =====
  static const Color cremeBg = Color(0xFFF6F1E8);
  static const Color surface = Color(0xFFFFFBF4);
  static const Color border = Color(0xFFE8DDCF);
  static const Color titleText = Color(0xFF1F2937);
  static const Color mutedText = Color(0xFF6B7280);
  static const Color accent = Color(0xFF7A4E2D);

  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  bool _scanned = false;
  bool _lockDetect = false;
  bool _torchOn = false;
  bool _loadingDetails = false;
  bool _hasRtoPermission = false;
  String? _detailsError;

  String? _scannedAwb;
  Map<String, dynamic>? _scannedPayload;
  Map<String, dynamic>? _orderDetails;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadRtoPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _controller.stop();
    } else if (state == AppLifecycleState.resumed) {
      if (!_scanned) _controller.start();
    }
  }

  // ---------- Parse AWB ----------
  String? _extractAwb(String? raw) {
    if (raw == null) return null;
    final text = raw.trim();
    if (text.isEmpty) return null;

    // JSON QR: {"awb":"..."} or {"order_no":"..."}
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) {
        final awb = (decoded['awb'] ?? decoded['order_no'])?.toString().trim();
        if (awb != null && awb.isNotEmpty) return awb;
      }
    } catch (_) {}

    // Plain AWB token (IMPORTANT: add $)
    final ok = RegExp(r'^[A-Za-z0-9._\-]{2,64}$').hasMatch(text);
    if (ok) return text;

    return null;
  }

  void _onDetect(BarcodeCapture capture) {
    if (!mounted) return;
    if (_scanned || _lockDetect) return;
    if (capture.barcodes.isEmpty) return;

    final b = capture.barcodes.first;
    final raw = b.rawValue ?? b.displayValue;

    final awb = _extractAwb(raw);
    if (awb == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid QR — scan a valid Order QR / AWB'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    Map<String, dynamic>? payload;
    try {
      final decoded = jsonDecode((raw ?? '').trim());
      if (decoded is Map) payload = Map<String, dynamic>.from(decoded);
    } catch (_) {}

    _showActionButtons(awb, payload);
  }

  void _showActionButtons(String awb, Map<String, dynamic>? payload) {
    _lockDetect = true;
    HapticFeedback.mediumImpact();

    setState(() {
      _scanned = true;
      _scannedAwb = awb;
      _scannedPayload = payload;
      _loadingDetails = true;
      _detailsError = null;
      _orderDetails = null;
    });

    _controller.stop();
    _fetchOrderDetails(awb);
  }

  Future<void> _manualEnter() async {
    if (_scanned) return;

    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) {
        final tc = TextEditingController();
        return AlertDialog(
          backgroundColor: surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Enter AWB / Order No',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: TextField(
            controller: tc,
            decoration: const InputDecoration(hintText: 'AWB or Order number'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(ctx, tc.text.trim()),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    final awb = (result ?? '').trim();
    if (awb.isNotEmpty) {
      _showActionButtons(awb, null);
    }
  }

  void _resetScanner() {
    setState(() {
      _scanned = false;
      _lockDetect = false;
      _scannedAwb = null;
      _scannedPayload = null;
      _orderDetails = null;
      _loadingDetails = false;
      _detailsError = null;
    });
    _controller.start();
  }

  Future<void> _loadRtoPermission() async {
    final sp = await SharedPreferences.getInstance();
    final has = sp.getBool(SessionKeys.hasRtoDelivered) ?? false;
    if (mounted) setState(() => _hasRtoPermission = has);
  }

  Future<void> _fetchOrderDetails(String awb) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(SessionKeys.token) ?? "";

      if (token.isEmpty) {
        setState(() {
          _loadingDetails = false;
          _detailsError = "Authentication required";
        });
        return;
      }

      // Try endpoint with AWB parameter
      var uri = Uri.parse(
        "https://rapidmiles.in/api/shipment/v1/orders/search",
      ).replace(queryParameters: {"awb": awb});

      var res = await http
          .get(
            uri,
            headers: {
              "Authorization": "Bearer $token",
              "Accept": "application/json",
            },
          )
          .timeout(const Duration(seconds: 10));

      // If search endpoint fails, try fetching all orders and filtering
      if (res.statusCode != 200) {
        uri = Uri.parse(
          "https://rapidmiles.in/api/shipment/v1/orders/my-orders",
        );
        res = await http
            .get(
              uri,
              headers: {
                "Authorization": "Bearer $token",
                "Accept": "application/json",
              },
            )
            .timeout(const Duration(seconds: 10));
      }

      if (res.statusCode == 200) {
        final decoded = json.decode(res.body);

        // Handle direct order response
        if (decoded is Map && decoded["success"] == true) {
          var orderData;

          // Check if response has direct data
          if (decoded["data"] is Map) {
            orderData = decoded["data"];
          }
          // Check if response has orders array and find matching AWB
          else if (decoded["data"] is List) {
            final orders = decoded["data"] as List;
            orderData = orders.firstWhere(
              (o) =>
                  (o is Map) &&
                  ((o["awb"]?.toString() == awb) ||
                      (o["order_no"]?.toString() == awb)),
              orElse: () => null,
            );
          }

          if (orderData is Map) {
            setState(() {
              _orderDetails = Map<String, dynamic>.from(orderData);
              _loadingDetails = false;
              _detailsError = null;
            });
            return;
          }
        }
      }

      setState(() {
        _loadingDetails = false;
        _detailsError = "Order '$awb' not found. Try another AWB.";
      });
    } catch (e) {
      setState(() {
        _loadingDetails = false;
        _detailsError = "Network error: Check your connection";
      });
    }
  }

  Future<void> _navigateToAction(String action) async {
    if (_scannedAwb == null) return;
    final actionPayload = _orderDetails ?? _scannedPayload;

    Widget screen;
    switch (action) {
      case 'deliver':
        screen = DeliverScreen(awb: _scannedAwb!, payload: actionPayload);
        break;
      case 'ndr':
        screen = NDRScreen(awb: _scannedAwb!, payload: actionPayload);
        break;
      case 'retry':
        screen = RetryScreen(awb: _scannedAwb!, payload: actionPayload);
        break;
      case 'rto':
        screen = RTOScreen(awb: _scannedAwb!, payload: actionPayload);
        break;
      case 'rto_delivered':
        screen = RTODeliveredScreen(awb: _scannedAwb!, payload: actionPayload);
        break;
      default:
        return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );

    // If action completed -> pop, else reset and scan again
    if (!mounted) return;

    if (result != null && result is Map && result['success'] == true) {
      Navigator.of(context).pop(result);
    } else {
      _resetScanner();
    }
  }

  Future<void> _toggleTorch() async {
    if (_scanned) return;
    try {
      await _controller.toggleTorch();
      setState(() => _torchOn = !_torchOn);
    } catch (_) {}
  }

  Future<void> _switchCamera() async {
    if (_scanned) return;
    try {
      await _controller.switchCamera();
    } catch (_) {}
  }

  Widget _buildActions() {
    final status =
        (_orderDetails?['order_status'] ?? '').toString().toUpperCase();
    final isDelivered = status == 'DELIVERED' || status == 'RTO_DELIVERED';
    final isRto = _orderDetails?['is_rto'] == true;
    final isNdr = _orderDetails?['is_ndr'] == true;

    if (isDelivered) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFE5F8EA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF86EFAC)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF1E7A3A)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Order already completed. No actions available.',
                style: TextStyle(
                  color: Color(0xFF1E7A3A),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final deliverCard = _ActionCard(
      icon: Icons.check_circle_outline_rounded,
      label: 'Deliver',
      subtitle: 'Mark as successfully delivered',
      bg: const Color(0xFFE5F8EA),
      fg: const Color(0xFF1E7A3A),
      onTap: () => _navigateToAction('deliver'),
    );
    final ndrCard = _ActionCard(
      icon: Icons.warning_amber_rounded,
      label: 'NDR',
      subtitle: 'Non delivery report',
      bg: const Color(0xFFFFF3D6),
      fg: const Color(0xFFB26A00),
      onTap: () => _navigateToAction('ndr'),
    );
    final retryCard = _ActionCard(
      icon: Icons.replay_rounded,
      label: 'Retry',
      subtitle: 'Attempt delivery again',
      bg: const Color(0xFFE7F1FF),
      fg: const Color(0xFF1E63B5),
      onTap: () => _navigateToAction('retry'),
    );
    final rtoCard = _ActionCard(
      icon: Icons.assignment_return_outlined,
      label: 'RTO',
      subtitle: 'Return to origin',
      bg: const Color(0xFFFFE4E7),
      fg: const Color(0xFFB4232C),
      onTap: () => _navigateToAction('rto'),
    );
    final rtoDeliverCard = _hasRtoPermission
        ? _ActionCard(
            icon: Icons.inventory_2_outlined,
            label: 'RTO Deliver',
            subtitle: 'Deliver returned shipment',
            bg: const Color(0xFFFFF3DC),
            fg: const Color(0xFFB26A00),
            onTap: () => _navigateToAction('rto_delivered'),
          )
        : null;

    if (isRto) {
      if (rtoDeliverCard == null) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFE4E7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFBCC4)),
          ),
          child: const Row(
            children: [
              Icon(Icons.lock_outline, color: Color(0xFFB4232C)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'This order is in RTO. No actions available for your role.',
                  style: TextStyle(
                    color: Color(0xFFB4232C),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        );
      }
      return rtoDeliverCard;
    }

    if (isNdr) {
      return Column(
        children: [
          deliverCard,
          retryCard,
          rtoCard,
          if (rtoDeliverCard != null) rtoDeliverCard,
        ],
      );
    }

    return Column(
      children: [
        deliverCard,
        ndrCard,
        retryCard,
        rtoCard,
        if (rtoDeliverCard != null) rtoDeliverCard,
      ],
    );
  }

  Widget _buildOrderInfo() {
    if (_loadingDetails) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
        ),
        child: const Column(
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            SizedBox(height: 10),
            Text(
              'Loading order details...',
              style: TextStyle(
                color: mutedText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (_detailsError != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFE8EA),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFFC2C8)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: Color(0xFFB4232C),
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _scannedAwb ?? '',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: titleText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _detailsError ?? 'Error loading details',
                    style: const TextStyle(
                      color: Color(0xFFB4232C),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_orderDetails == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AWB',
              style: TextStyle(
                color: mutedText,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _scannedAwb ?? '',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: titleText,
              ),
            ),
          ],
        ),
      );
    }

    final od = _orderDetails!;
    final status = od['order_status']?.toString() ?? 'N/A';
    final isCod =
        od['payment_type'] == 'COD' || od['collectable_amount'] != null;

    Color statusBg, statusFg;
    final su = status.toUpperCase();
    if (su == 'DELIVERED') {
      statusBg = const Color(0xFFE5F8EA);
      statusFg = const Color(0xFF1E7A3A);
    } else if (su.contains('RTO')) {
      statusBg = const Color(0xFFFFE4E7);
      statusFg = const Color(0xFFB4232C);
    } else if (su.contains('NDR') || su.contains('PENDING')) {
      statusBg = const Color(0xFFFFF3D6);
      statusFg = const Color(0xFFB26A00);
    } else {
      statusBg = const Color(0xFFE7F1FF);
      statusFg = const Color(0xFF1E63B5);
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: cremeBg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(17)),
              border:
                  Border(bottom: BorderSide(color: border.withValues(alpha:.6))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Order No',
                        style: TextStyle(
                          color: mutedText,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        (od['order_no'] ?? _scannedAwb) ?? '',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: titleText,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: statusFg,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _InfoChip(
                      label: 'AWB',
                      value: od['awb'] ?? _scannedAwb ?? 'N/A',
                    ),
                    const SizedBox(width: 12),
                    _InfoChip(
                      label: 'Amount',
                      value: '₹${od['order_amount'] ?? '0'}',
                      valueColor: const Color(0xFF0F766E),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _InfoChip(
                      label: 'Payment',
                      value: od['payment_type'] ?? 'N/A',
                    ),
                    const SizedBox(width: 12),
                    _InfoChip(
                      label: 'Items',
                      value:
                          '${((od['items'] as List?)?.length ?? 0)} item(s)',
                    ),
                  ],
                ),
                if (isCod) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3D6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFD7A6)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'COD Collectable',
                          style: TextStyle(
                            color: Color(0xFFB26A00),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '₹${od['collectable_amount'] ?? od['order_amount'] ?? '0'}',
                          style: const TextStyle(
                            color: Color(0xFFB26A00),
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cremeBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: border.withValues(alpha:.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ship To',
                        style: TextStyle(
                          color: mutedText,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        od['ship_to_name'] ?? 'N/A',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: titleText,
                        ),
                      ),
                      if ((od['ship_to_address'] ?? '').toString().isNotEmpty)
                        ...[
                          const SizedBox(height: 2),
                          Text(
                            od['ship_to_address'] ?? '',
                            style: const TextStyle(
                              fontSize: 11,
                              color: mutedText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      const SizedBox(height: 2),
                      Text(
                        '${od['ship_to_city'] ?? 'N/A'}, ${od['ship_to_state'] ?? 'N/A'} — ${od['ship_to_pincode'] ?? ''}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: mutedText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: cremeBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: surface,
        surfaceTintColor: surface,
        centerTitle: true,
        title: const Text(
          'Scan Order QR',
          style: TextStyle(fontWeight: FontWeight.w900, color: titleText),
        ),
        actions: [
          IconButton(
            tooltip: 'Torch',
            icon: Icon(_torchOn ? Icons.flash_off : Icons.flash_on),
            onPressed: _toggleTorch,
          ),
          IconButton(
            tooltip: 'Switch camera',
            icon: const Icon(Icons.cameraswitch),
            onPressed: _switchCamera,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera view
          Positioned.fill(
            child: MobileScanner(controller: _controller, onDetect: _onDetect),
          ),

          // Dark mask + premium frame
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _ScannerMaskPainter()),
            ),
          ),

          // Hint
          if (!_scanned)
            Positioned(
              left: 16,
              right: 16,
              top: 24,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xCCFFFFFF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0x22FFFFFF)),
                  ),
                  child: const Text(
                    "Align QR inside the frame",
                    style: TextStyle(
                      color: Color(0xFF111827),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),

          // Bottom controls (when NOT scanned)
          if (!_scanned)
            Positioned(
              left: 14,
              right: 14,
              bottom: 14 + bottomSafe,
              child: SafeArea(
                top: false,
                child: _BottomBar(
                  leftText: "Enter manually",
                  leftIcon: Icons.keyboard,
                  leftOnTap: _manualEnter,
                  rightText: "Cancel",
                  rightIcon: Icons.close,
                  rightOnTap: () => Navigator.of(context).pop(),
                ),
              ),
            ),

          // Action sheet overlay (when scanned)
          if (_scanned) ...[
            Positioned.fill(
              child: GestureDetector(
                onTap: _resetScanner,
                child: Container(color: const Color(0xB0000000)),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.88,
                ),
                decoration: const BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 24,
                      offset: Offset(0, -8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag handle
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 4),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1D5DB),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 8, 0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFE6C7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.qr_code_2,
                              color: accent,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Select Action',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    color: titleText,
                                  ),
                                ),
                                if (_scannedAwb != null)
                                  Text(
                                    _scannedAwb!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: mutedText,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: _resetScanner,
                            icon: const Icon(
                              Icons.close_rounded,
                              color: mutedText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Divider(height: 20, color: border.withValues(alpha:.7)),
                    ),
                    // Scrollable content
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildOrderInfo(),
                            const SizedBox(height: 16),
                            _buildActions(),
                            const SizedBox(height: 4),
                            SizedBox(
                              width: double.infinity,
                              child: TextButton.icon(
                                icon: const Icon(
                                  Icons.qr_code_scanner,
                                  size: 18,
                                ),
                                label: const Text('Scan Another Order'),
                                style: TextButton.styleFrom(
                                  foregroundColor: mutedText,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                onPressed: _resetScanner,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------- Bottom bar widget ----------
class _BottomBar extends StatelessWidget {
  final String leftText;
  final IconData leftIcon;
  final VoidCallback leftOnTap;

  final String rightText;
  final IconData rightIcon;
  final VoidCallback rightOnTap;

  const _BottomBar({
    required this.leftText,
    required this.leftIcon,
    required this.leftOnTap,
    required this.rightText,
    required this.rightIcon,
    required this.rightOnTap,
  });

  static const Color accent = _SecondQRScannerState.accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xEFFFFFFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x22FFFFFF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 16,
            offset: Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: Icon(leftIcon),
              label: Text(leftText),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: leftOnTap,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              icon: Icon(rightIcon),
              label: Text(rightText),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF374151),
                side: const BorderSide(color: Color(0xFFE5E7EB)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                backgroundColor: const Color(0xFFF9FAFB),
              ),
              onPressed: rightOnTap,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Action card ----------
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.bg,
    required this.fg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: fg.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: fg.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 22, color: fg),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: fg,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: fg.withValues(alpha: 0.65),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: fg.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- Info chip ----------
class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoChip({required this.label, required this.value, this.valueColor});

  static const Color mutedText = _SecondQRScannerState.mutedText;
  static const Color titleText = _SecondQRScannerState.titleText;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: mutedText,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: valueColor ?? titleText,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ---------- Premium scanner mask ----------
class _ScannerMaskPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xB0000000);

    final frameSize = (size.shortestSide * 0.72).clamp(240.0, 320.0);
    final frameRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: frameSize,
      height: frameSize,
    );

    final overlay = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final hole = Path()
      ..addRRect(RRect.fromRectAndRadius(frameRect, const Radius.circular(22)));
    final masked = Path.combine(PathOperation.difference, overlay, hole);

    canvas.drawPath(masked, paint);

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha:0.9);
    canvas.drawRRect(
      RRect.fromRectAndRadius(frameRect, const Radius.circular(22)),
      borderPaint,
    );

    final cornerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = Colors.white;

    const corner = 32.0;
    final r = frameRect;

    canvas.drawLine(
      Offset(r.left, r.top + corner),
      Offset(r.left, r.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(r.left, r.top),
      Offset(r.left + corner, r.top),
      cornerPaint,
    );

    canvas.drawLine(
      Offset(r.right - corner, r.top),
      Offset(r.right, r.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(r.right, r.top),
      Offset(r.right, r.top + corner),
      cornerPaint,
    );

    canvas.drawLine(
      Offset(r.left, r.bottom - corner),
      Offset(r.left, r.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(r.left, r.bottom),
      Offset(r.left + corner, r.bottom),
      cornerPaint,
    );

    canvas.drawLine(
      Offset(r.right - corner, r.bottom),
      Offset(r.right, r.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(r.right, r.bottom - corner),
      Offset(r.right, r.bottom),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
