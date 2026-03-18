// order_slip_details_screen.dart
//
// ✅ What you asked (done):
// 1) Scan QR -> DIRECTLY opens bottom sheet with 2 options (PDF / HTML)
// 2) Removed the "Last scanned order hash" card screen (no intermediate UI)
// 3) Still supports auto-scan when opened from Home:
//    Get.toNamed(Routes.orderSlipDetailsRoute, arguments: {"autoScan": true})
// 4) Clean iOS-like UI + scanner fullscreen
//
// REQUIREMENTS:
// - mobile_scanner
// - webview_flutter
// - syncfusion_flutter_pdfviewer
// - get
//
// IMPORTANT:
// - Update `Routes.homeRoute` to your actual home route constant

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../utils/routes.dart';

class OrderSlipDetailsScreen extends StatefulWidget {
  const OrderSlipDetailsScreen({Key? key}) : super(key: key);

  @override
  State<OrderSlipDetailsScreen> createState() => _OrderSlipDetailsScreenState();
}

class _OrderSlipDetailsScreenState extends State<OrderSlipDetailsScreen> {
  // Base URLs
  static const String _slip1Base =
      "https://support.vacalvers.com/global_services/print/order_packing_slip/";
  static const String _slip2Base =
      "https://support.vacalvers.com/global_services/print/order_packing_slip_2/";

  // Theme
  Color get _bluePrimary => const Color(0xFF1E5EFF);
  Color get _violet => const Color(0xFF6D5DF6);
  Color get _teal => const Color(0xFF14B8A6);
  Color get _bgSoft => const Color(0xFFF6F8FF);
  Color get _textDark => const Color(0xFF101828);

  bool _openingScanner = false;
  bool _autoScanDone = false;

  @override
  void initState() {
    super.initState();

    // ✅ Auto open scanner if requested
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = Get.arguments;
      final bool autoScan = args is Map && (args["autoScan"] == true);
      if (autoScan && !_autoScanDone) {
        _autoScanDone = true;
        _openScanner();
      }
    });
  }

  // ---------- Hash extraction ----------
  String _extractOrderHash(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return "";

    // If last token is numeric, take it
    final m = RegExp(r'(\d+)\s*$').firstMatch(v);
    if (m != null && (m.group(1) ?? "").isNotEmpty) return m.group(1)!;

    // Else if URL-like, take tail after last slash
    final idx = v.lastIndexOf("/");
    if (idx >= 0 && idx < v.length - 1) {
      final tail = v.substring(idx + 1).trim();
      if (tail.isNotEmpty) return tail;
    }

    return v;
  }

  // ---------- UI helpers ----------
  Widget _niceCard({
    required Widget child,
    List<Color>? gradient,
    VoidCallback? onTap,
  }) {
    final box = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: gradient == null
            ? null
            : LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        color: gradient == null ? Colors.white : null,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) return box;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: box,
      ),
    );
  }

  Future<void> _openScanner() async {
    if (_openingScanner) return;
    _openingScanner = true;

    final String? scanResult = await Get.to<String?>(
          () => _SlipScanScreen(
        title: "Scan Order QR",
        bluePrimary: _bluePrimary,
      ),
      transition: Transition.cupertino,
      fullscreenDialog: true,
    );

    _openingScanner = false;

    if (!mounted) return;
    if (scanResult == null || scanResult.trim().isEmpty) return;

    final hash = _extractOrderHash(scanResult);
    if (hash.isEmpty) return;

    _showSlipOptions(hash);
  }

  void _showSlipOptions(String hash) {
    HapticFeedback.mediumImpact();

    Get.bottomSheet(
      SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _bgSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.receipt_long_rounded, color: _bluePrimary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Select Slip Type",
                      style: TextStyle(
                        color: _textDark,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _optionTile(
                title: "Slip 1 (PDF)",
                subtitle: "Packing slip PDF preview",
                icon: Icons.picture_as_pdf_rounded,
                iconColor: Colors.red.shade700,
                onTap: () {
                  Get.back();
                  _openSlip1Pdf(hash);
                },
              ),
              const SizedBox(height: 10),
              _optionTile(
                title: "Slip 2 (HTML)",
                subtitle: "Packing slip HTML view",
                icon: Icons.public_rounded,
                iconColor: _teal,
                onTap: () {
                  Get.back();
                  _openSlip2Html(hash);
                },
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _optionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: _textDark,
                        fontSize: 13.8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade500),
            ],
          ),
        ),
      ),
    );
  }

  void _openSlip1Pdf(String hash) {
    final url = "$_slip1Base$hash";
    Get.to(
          () => _PdfSlipViewer(
        title: "Slip 1 (PDF)",
        url: url,
        bluePrimary: _bluePrimary,
      ),
      transition: Transition.cupertino,
    );
  }

  void _openSlip2Html(String hash) {
    final url = "$_slip2Base$hash";
    Get.to(
          () => _HtmlSlipViewer(
        title: "Slip 2 (HTML)",
        url: url,
        bluePrimary: _bluePrimary,
      ),
      transition: Transition.cupertino,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgSoft,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _bgSoft,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        centerTitle: true,
        title: Text(
          "Order Slip Details",
          style: TextStyle(
            color: _textDark,
            fontSize: 14.5,
            fontWeight: FontWeight.w900,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          color: _textDark,
          onPressed: () => Get.back(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
        children: [
          _niceCard(
            gradient: [_bluePrimary, _violet],
            onTap: _openScanner,
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.22)),
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Scan Order QR",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "After scan, you will directly get Slip 1 / Slip 2 options",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.92),
                          fontSize: 12.6,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withOpacity(0.95),
                  size: 16,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _niceCard(
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _teal.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.lock_rounded, color: _teal),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Note: The URL will not be displayed. Only slip output is shown inside the app.",
                    style: TextStyle(
                      color: Colors.grey.shade800,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================
// FULLSCREEN SCANNER (MobileScanner) - iOS look
// =========================================================
class _SlipScanScreen extends StatefulWidget {
  final String title;
  final Color bluePrimary;

  const _SlipScanScreen({
    required this.title,
    required this.bluePrimary,
  });

  @override
  State<_SlipScanScreen> createState() => _SlipScanScreenState();
}

class _SlipScanScreenState extends State<_SlipScanScreen>
    with WidgetsBindingObserver {
  late final MobileScannerController _controller;

  bool _torchOn = false;
  bool _isPopping = false;
  String? _lastValue;
  DateTime _lastHit = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
      formats: const <BarcodeFormat>[
        BarcodeFormat.qrCode,
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        BarcodeFormat.code93,
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
        BarcodeFormat.itf,
        BarcodeFormat.dataMatrix,
        BarcodeFormat.aztec,
        BarcodeFormat.pdf417,
      ],
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller.start();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _controller.stop();
    }
  }

  Future<void> _returnResult(String value) async {
    if (_isPopping) return;
    _isPopping = true;

    try {
      await _controller.stop();
    } catch (_) {}

    if (!mounted) return;
    Get.back(result: value);
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isPopping) return;

    final now = DateTime.now();
    if (now.difference(_lastHit).inMilliseconds < 650) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final v = (barcodes.first.rawValue ?? "").trim();
    if (v.isEmpty) return;

    if (_lastValue == v && now.difference(_lastHit).inSeconds < 2) return;

    _lastValue = v;
    _lastHit = now;

    HapticFeedback.mediumImpact();
    _returnResult(v);
  }

  Widget _topBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Get.back(),
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.20)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.arrow_back_ios_new_rounded,
                        size: 16, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      "Back",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14.5,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            const SizedBox(width: 10),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                await _controller.toggleTorch();
                if (!mounted) return;
                setState(() => _torchOn = !_torchOn);
              },
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.20)),
                ),
                child: Icon(
                  _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scanFrame() {
    return Center(
      child: Container(
        width: Get.width * 0.78,
        height: Get.width * 0.78,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white.withOpacity(0.90), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.30),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.08),
                        Colors.transparent,
                        Colors.white.withOpacity(0.08),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.40),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.16)),
                  ),
                  child: const Text(
                    "Align QR inside the frame",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _darkMask() {
    return IgnorePointer(
      child: Container(color: Colors.black.withOpacity(0.35)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: MobileScanner(
              controller: _controller,
              fit: BoxFit.cover,
              onDetect: _onDetect,
              errorBuilder: (context, error, child) {
                return Container(
                  color: Colors.black,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    "Camera error: ${error.errorDetails?.message ?? error.toString()}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    widget.bluePrimary.withOpacity(0.92),
                    widget.bluePrimary.withOpacity(0.35),
                    Colors.transparent,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Positioned.fill(child: _darkMask()),
          _scanFrame(),
          _topBar(),
        ],
      ),
    );
  }
}

// =========================================================
// PDF VIEWER (Slip 1) - Back -> HOME
// =========================================================
class _PdfSlipViewer extends StatefulWidget {
  final String title;
  final String url;
  final Color bluePrimary;

  const _PdfSlipViewer({
    required this.title,
    required this.url,
    required this.bluePrimary,
  });

  @override
  State<_PdfSlipViewer> createState() => _PdfSlipViewerState();
}

class _PdfSlipViewerState extends State<_PdfSlipViewer> {
  final PdfViewerController _pdfController = PdfViewerController();
  bool _loading = true;

  Future<bool> _goHome() async {
    Get.offAllNamed(Routes.homeRoute);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _goHome,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          title: Text(
            widget.title,
            style: const TextStyle(
              color: Color(0xFF101828),
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          leading: IconButton(
            onPressed: _goHome,
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            color: const Color(0xFF101828),
          ),
          actions: [
            IconButton(
              onPressed: () => _pdfController.zoomLevel = 1.0,
              icon: Icon(Icons.refresh_rounded, color: widget.bluePrimary),
              tooltip: "Reset zoom",
            ),
          ],
        ),
        body: Stack(
          children: [
            SfPdfViewer.network(
              widget.url,
              controller: _pdfController,
              onDocumentLoaded: (_) => setState(() => _loading = false),
              onDocumentLoadFailed: (details) {
                setState(() => _loading = false);
                Get.snackbar(
                  "Failed",
                  details.error,
                  snackPosition: SnackPosition.BOTTOM,
                );
              },
            ),
            if (_loading)
              const Center(
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}

// =========================================================
// HTML VIEWER (Slip 2) - Back -> HOME
// =========================================================
class _HtmlSlipViewer extends StatefulWidget {
  final String title;
  final String url;
  final Color bluePrimary;

  const _HtmlSlipViewer({
    required this.title,
    required this.url,
    required this.bluePrimary,
  });

  @override
  State<_HtmlSlipViewer> createState() => _HtmlSlipViewerState();
}

class _HtmlSlipViewerState extends State<_HtmlSlipViewer> {
  late final WebViewController _controller;
  bool _loading = true;

  Future<bool> _goHome() async {
    Get.offAllNamed(Routes.homeRoute);
    return false;
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _loading = true),
          onPageFinished: (_) => setState(() => _loading = false),
          onWebResourceError: (_) => setState(() => _loading = false),
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _goHome,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          title: Text(
            widget.title,
            style: const TextStyle(
              color: Color(0xFF101828),
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          leading: IconButton(
            onPressed: _goHome,
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            color: const Color(0xFF101828),
          ),
          actions: [
            IconButton(
              tooltip: "Reload",
              onPressed: () => _controller.reload(),
              icon: Icon(Icons.refresh_rounded, color: widget.bluePrimary),
            ),
          ],
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_loading)
              const Center(
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}
