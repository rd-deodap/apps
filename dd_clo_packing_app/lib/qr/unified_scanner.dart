import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';

/// =========================================================
/// AUDIO SERVICE (singleton)
/// =========================================================
class ScanAudio {
  ScanAudio._();
  static final ScanAudio instance = ScanAudio._();

  final AudioPlayer _player = AudioPlayer();

  Future<void> success() async {
    try {
      await _player.stop();
      await _player.play(AssetSource('audio/success.mp3'));
    } catch (_) {}
  }

  Future<void> failed() async {
    try {
      await _player.stop();
      await _player.play(AssetSource('audio/failed.mp3'));
    } catch (_) {}
  }

  Future<void> dispose() async {
    try {
      await _player.dispose();
    } catch (_) {}
  }
}

/// =========================================================
/// QR HASH NORMALIZER
/// =========================================================
String normalizeHash(String raw) {
  final v = raw.trim();
  if (v.isEmpty) return v;

  // caret-separated format: "xxx^HASH^yyy"
  if (v.contains('^')) {
    final parts = v.split('^');
    if (parts.length >= 2 && parts[1].trim().isNotEmpty) {
      return parts[1].trim();
    }
  }

  Uri? uri;
  try {
    uri = Uri.tryParse(v);
  } catch (_) {
    uri = null;
  }

  if (uri != null && (uri.hasScheme || uri.host.isNotEmpty)) {
    final q = uri.queryParameters['order_hash'];
    if (q != null && q.trim().isNotEmpty) return q.trim();

    if (uri.pathSegments.isNotEmpty) {
      final last = uri.pathSegments.last.trim();
      if (last.isNotEmpty) return last;
    }
  }

  return v;
}

/// =========================================================
/// API CLIENT (405-safe, production-safe)
/// =========================================================
class ApiClient {
  final String apiBaseUrl;
  final String appId;
  final String apiKey;

  /// If you KNOW backend only supports GET, set true.
  /// Otherwise keep false and we auto-fallback on 405.
  final bool forceGet;

  const ApiClient({
    required this.apiBaseUrl,
    required this.appId,
    required this.apiKey,
    this.forceGet = false,
  });

  Future<Map<String, dynamic>> confirmIwt({
    required String token,
    required String orderHash,
  }) async {
    final endpoint = Uri.parse('$apiBaseUrl/order/confirm_iwt');

    final payload = <String, dynamic>{
      "app_id": appId,
      "api_key": apiKey,
      "token": token,
      "order_hash": orderHash,
    };

    http.Response response;

    if (forceGet) {
      response = await _doGet(endpoint, payload);
    } else {
      response = await _doPost(endpoint, payload);
      if (response.statusCode == 405) {
        response = await _doGet(endpoint, payload);
      }
    }

    if (response.statusCode != 200) {
      final allow = response.headers['allow'];
      final extra =
      (response.statusCode == 405 && allow != null && allow.isNotEmpty)
          ? ' Allowed: $allow'
          : '';
      throw HttpException('Server error (${response.statusCode}).$extra');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid server response.');
    }

    final status = (decoded['status'] ?? '').toString().toLowerCase();
    if (status != 'success') {
      throw Exception(
        (decoded['message'] ?? 'IWT confirmation failed.').toString(),
      );
    }

    return decoded;
  }

  Future<Map<String, dynamic>> getPrimaryInfo({
    required String token,
    required String orderHash,
  }) async {
    final endpoint = Uri.parse('$apiBaseUrl/order/get_primary_info');

    final payload = <String, dynamic>{
      "app_id": appId,
      "api_key": apiKey,
      "token": token,
      "order_hash": orderHash,
    };

    http.Response response;

    if (forceGet) {
      response = await _doGet(endpoint, payload);
    } else {
      // 1) try POST first (best practice)
      response = await _doPost(endpoint, payload);

      // 2) If backend rejects POST with 405, fallback to GET (query params)
      if (response.statusCode == 405) {
        response = await _doGet(endpoint, payload);
      }
    }

    // Still not OK
    if (response.statusCode != 200) {
      final allow = response.headers['allow'];
      final extra =
      (response.statusCode == 405 && allow != null && allow.isNotEmpty)
          ? ' Allowed: $allow'
          : '';
      throw HttpException('Server error (${response.statusCode}).$extra');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid server response.');
    }

    final status = (decoded['status'] ?? '').toString().toLowerCase();
    if (status != 'success') {
      throw Exception(
        (decoded['message'] ?? 'Invalid Order. Please try again.').toString(),
      );
    }

    return decoded;
  }

  Future<http.Response> _doPost(Uri uri, Map<String, dynamic> payload) async {
    return http
        .post(
      uri,
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(payload),
    )
        .timeout(const Duration(seconds: 20));
  }

  Future<http.Response> _doGet(Uri uri, Map<String, dynamic> payload) async {
    // Convert payload to query parameters (standard-compliant GET)
    final qp = payload.map((k, v) => MapEntry(k, v.toString()));
    final getUri = uri.replace(queryParameters: qp);

    return http
        .get(
      getUri,
      headers: const {
        'Accept': 'application/json',
      },
    )
        .timeout(const Duration(seconds: 20));
  }
}

/// =========================================================
/// MODELS
/// =========================================================
class PrimaryOrderInfo {
  final String primaryOrderNo;
  final String formattedOrderNo;
  final String secondaryLocation;
  final int totalParts;
  final String status;

  PrimaryOrderInfo({
    required this.primaryOrderNo,
    required this.formattedOrderNo,
    required this.secondaryLocation,
    required this.totalParts,
    required this.status,
  });

  factory PrimaryOrderInfo.fromJson(Map<String, dynamic> json) {
    return PrimaryOrderInfo(
      primaryOrderNo: (json['primary_order_no'] ?? 'N/A').toString(),
      formattedOrderNo:
      (json['primary_order_no_formatted'] ?? 'N/A').toString(),
      secondaryLocation:
      (json['primary_order_all_secondary_clo_location'] ?? 'N/A')
          .toString(),
      totalParts: _toInt(json['primary_order_clo_total_parts']),
      status: (json['primary_order_clo_status'] ?? 'UNKNOWN').toString(),
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}

class SecondaryOrderInfo {
  final String secondaryOrderNo;
  final String formattedSecondaryOrderNo;
  bool isScanned;

  SecondaryOrderInfo({
    required this.secondaryOrderNo,
    required this.formattedSecondaryOrderNo,
    this.isScanned = false,
  });

  factory SecondaryOrderInfo.fromJson(Map<String, dynamic> json) {
    return SecondaryOrderInfo(
      secondaryOrderNo: (json['secondary_order_no'] ?? 'N/A').toString(),
      formattedSecondaryOrderNo:
      (json['secondary_order_no_formatted'] ?? 'N/A').toString(),
    );
  }
}

/// =========================================================
/// UI THEME (single design system across iOS/Android)
/// =========================================================
class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0A84FF),
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: scheme.onSurface,
          letterSpacing: 0.2,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withOpacity(0.6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: scheme.outlineVariant.withOpacity(0.5),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: scheme.outlineVariant.withOpacity(0.4),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: scheme.primary.withOpacity(0.9),
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

/// =========================================================
/// UNIFIED SCANNER SCREEN (production-level)
/// =========================================================
class UnifiedScannerScreen extends StatefulWidget {
  const UnifiedScannerScreen({super.key});

  @override
  State<UnifiedScannerScreen> createState() => _UnifiedScannerScreenState();
}

class _UnifiedScannerScreenState extends State<UnifiedScannerScreen>
    with WidgetsBindingObserver {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    formats: const [BarcodeFormat.qrCode],
  );

  final ApiClient _api = const ApiClient(
    apiBaseUrl: "https://api.vacalvers.com/api-clo-packaging-app",
    appId: "2",
    apiKey: "022782f3-c4aa-443a-9f14-7698c648a137",
    // leave false. It will auto-fallback to GET if POST gets 405
    forceGet: false,
  );

  String? _userToken;

  DateTime? _lastScanTime;
  String? _lastScannedCode;
  bool _busyScan = false;

  bool _primaryScanned = false;
  PrimaryOrderInfo? _primaryOrder;
  final List<SecondaryOrderInfo> _secondaryOrders = <SecondaryOrderInfo>[];

  bool _isTorchOn = false;
  bool _isLoading = false;
  String? _errorMessage;

  final ValueNotifier<_FeedbackState?> _feedback =
  ValueNotifier<_FeedbackState?>(null);
  Timer? _feedbackTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadToken();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _feedbackTimer?.cancel();
    _feedback.dispose();
    _scannerController.dispose();
    ScanAudio.instance.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _scannerController.stop();
    } else if (state == AppLifecycleState.resumed) {
      _scannerController.start();
    }
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    final t = prefs.getString('authToken');
    if (!mounted) return;

    if (t == null || t.trim().isEmpty) {
      setState(() => _errorMessage = 'Login token not found. Please log in.');
      return;
    }
    setState(() {
      _userToken = t.trim();
      _errorMessage = null;
    });
  }

  bool _shouldAcceptScan(String code) {
    if (code.isEmpty) return false;
    if (_busyScan) return false;

    if (code == _lastScannedCode) return false;

    final now = DateTime.now();
    if (_lastScanTime != null &&
        now.difference(_lastScanTime!).inMilliseconds < 450) return false;

    _lastScanTime = now;
    _lastScannedCode = code;
    return true;
  }

  void _showFeedback(String message, {required bool success}) {
    _feedbackTimer?.cancel();
    _feedback.value = _FeedbackState(message: message, success: success);

    _feedbackTimer = Timer(const Duration(milliseconds: 1400), () {
      _feedback.value = null;
    });
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (capture.barcodes.isEmpty) return;
    final raw = capture.barcodes.first.rawValue;
    if (raw == null) return;

    final code = normalizeHash(raw);
    if (!_shouldAcceptScan(code)) return;

    try {
      HapticFeedback.selectionClick();
    } catch (_) {}

    _busyScan = true;
    try {
      if (!_primaryScanned) {
        await _scanPrimary(code);
      } else {
        await _scanSecondary(code);
      }
    } finally {
      _busyScan = false;
    }
  }

  Future<void> _scanPrimary(String orderHash) async {
    final token = _userToken;
    if (token == null || token.isEmpty) {
      await ScanAudio.instance.failed();
      _showFeedback('Login token missing', success: false);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final jsonResponse = await _api.getPrimaryInfo(
        token: token,
        orderHash: orderHash,
      );

      final data = (jsonResponse['data'] ?? {});
      if (data is! Map<String, dynamic>) {
        throw const FormatException('Invalid data format from server.');
      }

      final primary = PrimaryOrderInfo.fromJson(data);

      final rawParts = data['primary_order_clo_parts'];
      final List<dynamic> partsList =
      (rawParts is List) ? rawParts : const <dynamic>[];

      final secondaries = partsList
          .whereType<Map<String, dynamic>>()
          .map(SecondaryOrderInfo.fromJson)
          .toList();

      _secondaryOrders
        ..clear()
        ..addAll(secondaries);

      // Confirm IWT for the scanned primary order
      await _api.confirmIwt(
        token: token,
        orderHash: orderHash,
      );

      await ScanAudio.instance.success();

      if (!mounted) return;
      setState(() {
        _primaryScanned = true;
        _primaryOrder = primary;
        _isLoading = false;
      });

      _showFeedback('Primary scanned: ${primary.formattedOrderNo}',
          success: true);
    } on SocketException catch (e) {
      await ScanAudio.instance.failed();
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
      _showFeedback('Network error', success: false);
    } on TimeoutException {
      await ScanAudio.instance.failed();
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Request timed out. Check network.';
        _isLoading = false;
      });
      _showFeedback('Timeout', success: false);
    } catch (e) {
      await ScanAudio.instance.failed();
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
      _showFeedback('Scan failed', success: false);
    }
  }

  Future<void> _scanSecondary(String orderHash) async {
    final idx = _secondaryOrders.indexWhere(
          (s) => s.secondaryOrderNo == orderHash && !s.isScanned,
    );

    if (idx == -1) {
      await ScanAudio.instance.failed();
      _showFeedback('Not in list / already scanned', success: false);
      return;
    }

    _secondaryOrders[idx].isScanned = true;
    await ScanAudio.instance.success();

    try {
      HapticFeedback.lightImpact();
    } catch (_) {}

    if (!mounted) return;
    setState(() {});

    _showFeedback(
      'Secondary scanned: ${_secondaryOrders[idx].formattedSecondaryOrderNo}',
      success: true,
    );
  }

  bool get _allScanned =>
      _primaryScanned &&
          _secondaryOrders.isNotEmpty &&
          _secondaryOrders.every((s) => s.isScanned);

  int get _scannedCount => _secondaryOrders.where((s) => s.isScanned).length;

  void _reset() {
    setState(() {
      _primaryScanned = false;
      _primaryOrder = null;
      _secondaryOrders.clear();
      _errorMessage = null;
      _lastScanTime = null;
      _lastScannedCode = null;
      _busyScan = false;
    });
    _feedback.value = null;
  }

  Future<void> _toggleTorch() async {
    await _scannerController.toggleTorch();
    if (!mounted) return;
    setState(() => _isTorchOn = !_isTorchOn);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.light(),
      child: Builder(
        builder: (context) {
          final t = Theme.of(context);
          final s = t.colorScheme;

          return Scaffold(
            appBar: AppBar(
              leading: _AdaptiveBackButton(color: s.onSurface),
              title: const Text('Scan Orders'),
              actions: [
                IconButton(
                  tooltip: _isTorchOn ? 'Torch Off' : 'Torch On',
                  onPressed: _toggleTorch,
                  icon: Icon(
                    _isTorchOn
                        ? Icons.flash_on_rounded
                        : Icons.flash_off_rounded,
                    color: _isTorchOn ? s.primary : s.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 6),
              ],
            ),
            body: SafeArea(
              child: Column(
                children: [
                  _ScannerPanel(
                    controller: _scannerController,
                    onDetect: _onDetect,
                    feedback: _feedback,
                    isLoading: _isLoading,
                    primaryScanned: _primaryScanned,
                    errorMessage: _errorMessage,
                  ),
                  Expanded(
                    child: _BottomPanel(
                      primaryScanned: _primaryScanned,
                      primary: _primaryOrder,
                      secondaries: _secondaryOrders,
                      scannedCount: _scannedCount,
                      allScanned: _allScanned,
                      onReset: _allScanned ? _reset : null,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// =========================================================
/// Adaptive back button (iOS-style where possible)
/// =========================================================
class _AdaptiveBackButton extends StatelessWidget {
  final Color? color;
  const _AdaptiveBackButton({this.color});

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    if (!canPop) return const SizedBox.shrink();

    final platform = Theme.of(context).platform;
    final isIOS =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

    return IconButton(
      onPressed: () => Navigator.of(context).maybePop(),
      icon: Icon(
        isIOS ? Icons.arrow_back_ios_new_rounded : Icons.arrow_back_rounded,
        color: color,
        size: 20,
      ),
      tooltip: 'Back',
    );
  }
}

/// =========================================================
/// Scanner Panel
/// =========================================================
class _ScannerPanel extends StatelessWidget {
  final MobileScannerController controller;
  final Future<void> Function(BarcodeCapture capture) onDetect;
  final ValueNotifier<_FeedbackState?> feedback;
  final bool isLoading;
  final bool primaryScanned;
  final String? errorMessage;

  const _ScannerPanel({
    required this.controller,
    required this.onDetect,
    required this.feedback,
    required this.isLoading,
    required this.primaryScanned,
    required this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final h = MediaQuery.of(context).size.height;
    final scannerHeight = (h * 0.46).clamp(280.0, 420.0);

    final instruction = isLoading
        ? 'Loading order details...'
        : primaryScanned
        ? 'Scan SECONDARY order QR codes'
        : 'Scan PRIMARY order QR code';

    return Container(
      height: scannerHeight,
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            MobileScanner(
              controller: controller,
              onDetect: onDetect,
            ),
            IgnorePointer(
              child: CustomPaint(
                size: Size.infinite,
                painter: _ScannerOverlayPainter(
                  borderColor: scheme.primary,
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: ValueListenableBuilder<_FeedbackState?>(
                valueListenable: feedback,
                builder: (_, state, __) {
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: state == null
                        ? const SizedBox.shrink()
                        : _FeedbackToast(state: state),
                  );
                },
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: _InstructionChip(
                text: instruction,
                isLoading: isLoading,
              ),
            ),
            if (errorMessage != null && errorMessage!.trim().isNotEmpty)
              Positioned(
                left: 12,
                right: 12,
                bottom: 56,
                child: _ErrorStrip(message: errorMessage!),
              ),
          ],
        ),
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final Color borderColor;
  _ScannerOverlayPainter({required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()..color = Colors.black.withOpacity(0.62);

    final cutSize = size.width * 0.72;
    final center = Offset(size.width / 2, size.height / 2);
    final cutRect = Rect.fromCenter(
      center: center,
      width: cutSize,
      height: cutSize,
    );
    final cutRRect = RRect.fromRectAndRadius(cutRect, const Radius.circular(20));

    final overlayPath = Path()..addRect(Offset.zero & size);
    final cutPath = Path()..addRRect(cutRRect);
    final finalPath =
    Path.combine(PathOperation.difference, overlayPath, cutPath);
    canvas.drawPath(finalPath, overlayPaint);

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..color = borderColor.withOpacity(0.95);

    canvas.drawRRect(cutRRect, borderPaint);

    final cornerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withOpacity(0.95);

    const cornerLen = 36.0;

    void drawCorner(Offset a, Offset b, Offset c) {
      final p = Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(c.dx, c.dy);
      canvas.drawPath(p, cornerPaint);
    }

    drawCorner(
      Offset(cutRect.left, cutRect.top + cornerLen),
      Offset(cutRect.left, cutRect.top),
      Offset(cutRect.left + cornerLen, cutRect.top),
    );

    drawCorner(
      Offset(cutRect.right - cornerLen, cutRect.top),
      Offset(cutRect.right, cutRect.top),
      Offset(cutRect.right, cutRect.top + cornerLen),
    );

    drawCorner(
      Offset(cutRect.right, cutRect.bottom - cornerLen),
      Offset(cutRect.right, cutRect.bottom),
      Offset(cutRect.right - cornerLen, cutRect.bottom),
    );

    drawCorner(
      Offset(cutRect.left + cornerLen, cutRect.bottom),
      Offset(cutRect.left, cutRect.bottom),
      Offset(cutRect.left, cutRect.bottom - cornerLen),
    );
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) =>
      oldDelegate.borderColor != borderColor;
}

class _FeedbackState {
  final String message;
  final bool success;
  const _FeedbackState({required this.message, required this.success});
}

class _FeedbackToast extends StatelessWidget {
  final _FeedbackState state;
  const _FeedbackToast({required this.state});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = state.success ? scheme.tertiaryContainer : scheme.errorContainer;
    final fg =
    state.success ? scheme.onTertiaryContainer : scheme.onErrorContainer;

    return Container(
      key: ValueKey('${state.success}-${state.message}'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.94),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: fg.withOpacity(0.15),
        ),
      ),
      child: Row(
        children: [
          Icon(
            state.success ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: fg,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              state.message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InstructionChip extends StatelessWidget {
  final String text;
  final bool isLoading;

  const _InstructionChip({required this.text, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surface.withOpacity(0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.primary.withOpacity(0.25),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          if (isLoading)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
              ),
            )
          else
            Icon(
              Icons.qr_code_scanner_rounded,
              size: 18,
              color: scheme.primary,
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: scheme.onSurface,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorStrip extends StatelessWidget {
  final String message;
  const _ErrorStrip({required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withOpacity(0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.error.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_rounded, color: scheme.onErrorContainer, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: scheme.onErrorContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// =========================================================
/// Bottom panel (list + progress + action)
/// =========================================================
class _BottomPanel extends StatelessWidget {
  final bool primaryScanned;
  final PrimaryOrderInfo? primary;
  final List<SecondaryOrderInfo> secondaries;
  final int scannedCount;
  final bool allScanned;
  final VoidCallback? onReset;

  const _BottomPanel({
    required this.primaryScanned,
    required this.primary,
    required this.secondaries,
    required this.scannedCount,
    required this.allScanned,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    if (!primaryScanned) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
        child: _EmptyStateCard(
          title: 'Ready to Scan',
          subtitle: 'Scan the PRIMARY order QR to load parts list.',
          icon: Icons.qr_code_scanner_rounded,
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
                  child: Column(
                    children: [
                      _PrimaryCard(primary: primary!),
                      const SizedBox(height: 10),
                      _ProgressHeader(
                        scannedCount: scannedCount,
                        totalCount: secondaries.length,
                        allScanned: allScanned,
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                sliver: SliverList.separated(
                  itemCount: secondaries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    return _SecondaryCard(secondary: secondaries[i]);
                  },
                ),
              ),
            ],
          ),
        ),
        _BottomActionBar(
          allScanned: allScanned,
          scannedCount: scannedCount,
          totalCount: secondaries.length,
          onReset: onReset,
        ),
      ],
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _EmptyStateCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: scheme.onPrimaryContainer, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: scheme.onSurface,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  final int scannedCount;
  final int totalCount;
  final bool allScanned;

  const _ProgressHeader({
    required this.scannedCount,
    required this.totalCount,
    required this.allScanned,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pct =
    totalCount <= 0 ? 0.0 : (scannedCount / totalCount).clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: allScanned
                        ? scheme.tertiaryContainer
                        : scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    allScanned ? Icons.verified_rounded : Icons.list_alt_rounded,
                    color: allScanned
                        ? scheme.onTertiaryContainer
                        : scheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    allScanned
                        ? 'All secondary orders scanned'
                        : 'Secondary orders progress',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: scheme.onSurface,
                      fontSize: 15,
                    ),
                  ),
                ),
                _Pill(
                  text: '$scannedCount / $totalCount',
                  fg: scheme.primary,
                  bg: scheme.primaryContainer.withOpacity(0.7),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 10,
                value: pct,
                backgroundColor: scheme.surfaceContainerHighest.withOpacity(0.8),
                valueColor: AlwaysStoppedAnimation<Color>(
                  allScanned ? scheme.tertiary : scheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color fg;
  final Color bg;

  const _Pill({required this.text, required this.fg, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w900,
          fontSize: 12,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// =========================================================
/// Primary Card
/// =========================================================
class _PrimaryCard extends StatelessWidget {
  final PrimaryOrderInfo primary;
  const _PrimaryCard({required this.primary});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: scheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.inventory_2_rounded,
                    color: scheme.onTertiaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Primary Order',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                _Pill(
                  text: 'Scanned',
                  fg: scheme.tertiary,
                  bg: scheme.tertiaryContainer.withOpacity(0.7),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(label: 'Order No', value: primary.formattedOrderNo),
            _InfoRow(label: 'Location', value: primary.secondaryLocation),
            _InfoRow(label: 'Total Parts', value: primary.totalParts.toString()),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withOpacity(0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: scheme.outlineVariant.withOpacity(0.35),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: scheme.onSurface,
                fontWeight: FontWeight.w900,
                fontSize: 13.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// =========================================================
/// Secondary Card
/// =========================================================
class _SecondaryCard extends StatelessWidget {
  final SecondaryOrderInfo secondary;
  const _SecondaryCard({required this.secondary});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final bg = secondary.isScanned
        ? scheme.tertiaryContainer.withOpacity(0.55)
        : scheme.surface;

    final border = secondary.isScanned
        ? scheme.tertiary.withOpacity(0.35)
        : scheme.outlineVariant.withOpacity(0.35);

    return Card(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: secondary.isScanned
                    ? scheme.tertiary
                    : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                secondary.isScanned ? Icons.check_rounded : Icons.qr_code_2_rounded,
                color: secondary.isScanned
                    ? scheme.onTertiary
                    : scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    secondary.formattedSecondaryOrderNo,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    secondary.isScanned ? 'Scanned' : 'Waiting for scan',
                    style: TextStyle(
                      color: secondary.isScanned
                          ? scheme.tertiary
                          : scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            if (secondary.isScanned)
              Icon(Icons.verified_rounded, color: scheme.tertiary, size: 20),
          ],
        ),
      ),
    );
  }
}

/// =========================================================
/// Bottom action bar
/// =========================================================
class _BottomActionBar extends StatelessWidget {
  final bool allScanned;
  final int scannedCount;
  final int totalCount;
  final VoidCallback? onReset;

  const _BottomActionBar({
    required this.allScanned,
    required this.scannedCount,
    required this.totalCount,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(
            top: BorderSide(color: scheme.outlineVariant.withOpacity(0.35)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: allScanned
                            ? scheme.tertiaryContainer
                            : scheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        allScanned
                            ? Icons.check_circle_rounded
                            : Icons.timelapse_rounded,
                        color: allScanned
                            ? scheme.onTertiaryContainer
                            : scheme.onSecondaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        allScanned
                            ? 'All orders scanned!'
                            : 'Scanned $scannedCount / $totalCount',
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (allScanned) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: onReset,
                  icon: const Icon(Icons.playlist_add_check_rounded),
                  label: const Text(
                    'Complete & Scan Next',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}