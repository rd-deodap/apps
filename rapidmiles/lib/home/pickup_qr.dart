import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rapidmiles/login/login_screen.dart';
import 'package:rapidmiles/home/pickup_confirmation_screen.dart';

class PickupQRScanner extends StatefulWidget {
  const PickupQRScanner({super.key});

  @override
  State<PickupQRScanner> createState() => _PickupQRScannerState();
}

class _PickupQRScannerState extends State<PickupQRScanner>
    with WidgetsBindingObserver {
  // ===== Theme (Cream + Premium) =====
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

  bool _processing = false;
  bool _lockDetect = false;
  bool _torchOn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _controller.stop();
    } else if (state == AppLifecycleState.resumed) {
      if (!_processing && !_lockDetect) {
        _controller.start();
      }
    }
  }

  // ---------- AWB parsing ----------
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

    // Plain token
    final ok = RegExp(r'^[A-Za-z0-9._\-]{2,64}$').hasMatch(text);
    if (ok) return text;

    return null;
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (!mounted) return;
    if (_processing || _lockDetect) return;
    if (capture.barcodes.isEmpty) return;

    final b = capture.barcodes.first;
    final raw = b.rawValue ?? b.displayValue;

    final awb = _extractAwb(raw);
    if (awb == null) return;

    _lockDetect = true;
    setState(() => _processing = true);

    // Stop camera to prevent duplicate triggers
    try {
      await _controller.stop();
    } catch (_) {}

    final ok = await _performPickup(awb);

    if (!mounted) return;
    if (!ok) {
      setState(() => _processing = false);
      _lockDetect = false;
      try {
        await _controller.start();
      } catch (_) {}
    }
  }

  Future<bool> _performPickup(String awb) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final token = sp.getString(SessionKeys.token) ?? "";

      if (token.isEmpty) {
        _toast("Session expired — login again");
        if (!mounted) return false;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
              (r) => false,
        );
        return false;
      }

      final uri = Uri.parse('https://rapidmiles.in/api/shipment/v1/orders/$awb/action');

      final res = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
        body: {'awb': awb, 'action': 'pickup'},
      );

      if (res.statusCode == 401) {
        _toast("Unauthorized — login again");
        if (!mounted) return false;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
              (r) => false,
        );
        return false;
      }

      // Safe JSON decode (no crash if server sends HTML)
      Map<String, dynamic> body;
      try {
        final decoded = jsonDecode(res.body);
        body = decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{};
      } catch (_) {
        body = {
          "success": false,
          "message": "Invalid server response (${res.statusCode})",
          "raw": res.body,
        };
      }

      if (body['success'] == true) {
        HapticFeedback.mediumImpact();

        if (!mounted) return true;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PickupConfirmationScreen(orderData: body),
          ),
        );

        if (!mounted) return true;
        Navigator.of(context).pop({'awb': awb, 'response': body});
        return true;
      }

      _toast((body['message'] ?? 'Pickup failed').toString());
      return false;
    } catch (e) {
      _toast("Network error: $e");
      return false;
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _manualEnter() async {
    if (_processing) return;

    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) {
        final tc = TextEditingController();
        return AlertDialog(
          backgroundColor: surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx, tc.text.trim()),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    final awb = (result ?? "").trim();
    if (awb.isEmpty) return;

    _lockDetect = true;
    setState(() => _processing = true);

    try {
      await _controller.stop();
    } catch (_) {}

    final ok = await _performPickup(awb);

    if (!mounted) return;
    if (!ok) {
      setState(() => _processing = false);
      _lockDetect = false;
      try {
        await _controller.start();
      } catch (_) {}
    }
  }

  Future<void> _toggleTorch() async {
    if (_processing) return;
    try {
      await _controller.toggleTorch();
      setState(() => _torchOn = !_torchOn);
    } catch (_) {}
  }

  Future<void> _switchCamera() async {
    if (_processing) return;
    try {
      await _controller.switchCamera();
    } catch (_) {}
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
          "Scan Pickup QR",
          style: TextStyle(fontWeight: FontWeight.w900, color: titleText),
        ),
        actions: [
          IconButton(
            tooltip: "Torch",
            icon: Icon(_torchOn ? Icons.flash_off : Icons.flash_on),
            onPressed: _toggleTorch,
          ),
          IconButton(
            tooltip: "Switch camera",
            icon: const Icon(Icons.cameraswitch),
            onPressed: _switchCamera,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera
          Positioned.fill(
            child: MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
            ),
          ),

          // Dark mask + frame
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _ScannerMaskPainter(),
              ),
            ),
          ),

          // Hint text
          Positioned(
            left: 16,
            right: 16,
            top: 24,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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

          // Bottom bar (NO OVERFLOW)
          Positioned(
            left: 14,
            right: 14,
            bottom: 14 + bottomSafe,
            child: SafeArea(
              top: false,
              child: Container(
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
                        icon: const Icon(Icons.keyboard),
                        label: const Text("Enter manually"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _processing ? null : _manualEnter,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.close),
                        label: const Text("Cancel"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF374151),
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          backgroundColor: const Color(0xFFF9FAFB),
                        ),
                        onPressed: _processing ? null : () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Processing overlay
          if (_processing)
            Positioned.fill(
              child: Container(
                color: const Color(0xAA000000),
                alignment: Alignment.center,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xEEFFFFFF),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  padding: const EdgeInsets.all(18),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text(
                        "Processing pickup...",
                        style: TextStyle(
                          color: Color(0xFF111827),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Mask painter: dark outside, clear center + nice corners
class _ScannerMaskPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xB0000000);

    // Frame size (responsive)
    final frameSize = (size.shortestSide * 0.72).clamp(240.0, 320.0);
    final frameRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: frameSize,
      height: frameSize,
    );

    // Dark overlay
    final overlay = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final hole = Path()..addRRect(RRect.fromRectAndRadius(frameRect, const Radius.circular(22)));
    final masked = Path.combine(PathOperation.difference, overlay, hole);

    canvas.drawPath(masked, paint);

    // White border
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withOpacity(0.9);
    canvas.drawRRect(RRect.fromRectAndRadius(frameRect, const Radius.circular(22)), borderPaint);

    // Corner accents
    final cornerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = Colors.white;

    const corner = 32.0;
    final r = frameRect;

    // top-left
    canvas.drawLine(Offset(r.left, r.top + corner), Offset(r.left, r.top), cornerPaint);
    canvas.drawLine(Offset(r.left, r.top), Offset(r.left + corner, r.top), cornerPaint);
    // top-right
    canvas.drawLine(Offset(r.right - corner, r.top), Offset(r.right, r.top), cornerPaint);
    canvas.drawLine(Offset(r.right, r.top), Offset(r.right, r.top + corner), cornerPaint);
    // bottom-left
    canvas.drawLine(Offset(r.left, r.bottom - corner), Offset(r.left, r.bottom), cornerPaint);
    canvas.drawLine(Offset(r.left, r.bottom), Offset(r.left + corner, r.bottom), cornerPaint);
    // bottom-right
    canvas.drawLine(Offset(r.right - corner, r.bottom), Offset(r.right, r.bottom), cornerPaint);
    canvas.drawLine(Offset(r.right, r.bottom - corner), Offset(r.right, r.bottom), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
