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
class _IwtAudio {
  _IwtAudio._();
  static final _IwtAudio instance = _IwtAudio._();

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
String _normalizeHash(String raw) {
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
/// IWT API CLIENT
/// =========================================================
class _IwtApiClient {
  final String apiBaseUrl;
  final String appId;
  final String apiKey;
  final bool forceGet;

  const _IwtApiClient({
    required this.apiBaseUrl,
    required this.appId,
    required this.apiKey,
    this.forceGet = false,
  });

  Future<Map<String, dynamic>> initiateIwt({
    required String token,
    required String orderHash,
  }) async {
    final endpoint = Uri.parse('$apiBaseUrl/order/initiate_iwt');

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
        (decoded['message'] ?? 'IWT initiation failed. Please try again.')
            .toString(),
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
/// SCANNED ORDER MODEL
/// =========================================================
class _ScannedOrder {
  final String orderHash;
  final String message;
  final DateTime scannedAt;

  const _ScannedOrder({
    required this.orderHash,
    required this.message,
    required this.scannedAt,
  });
}

/// =========================================================
/// IWT SCANNER SCREEN
/// =========================================================
class IwtScannerScreen extends StatefulWidget {
  const IwtScannerScreen({super.key});

  @override
  State<IwtScannerScreen> createState() => _IwtScannerScreenState();
}

class _IwtScannerScreenState extends State<IwtScannerScreen>
    with WidgetsBindingObserver {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    formats: const [BarcodeFormat.qrCode],
  );

  final _IwtApiClient _api = const _IwtApiClient(
    apiBaseUrl: "https://api.vacalvers.com/api-clo-packaging-app",
    appId: "2",
    apiKey: "022782f3-c4aa-443a-9f14-7698c648a137",
    forceGet: false,
  );

  String? _userToken;

  DateTime? _lastScanTime;
  String? _lastScannedCode;
  bool _busyScan = false;

  bool _isTorchOn = false;
  bool _isLoading = false;
  String? _errorMessage;

  final List<_ScannedOrder> _scannedOrders = [];

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
    _IwtAudio.instance.dispose();
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

    final code = _normalizeHash(raw);
    if (!_shouldAcceptScan(code)) return;

    try {
      HapticFeedback.selectionClick();
    } catch (_) {}

    _busyScan = true;
    try {
      await _initiateIwt(code);
    } finally {
      _busyScan = false;
    }
  }

  Future<void> _initiateIwt(String orderHash) async {
    final token = _userToken;
    if (token == null || token.isEmpty) {
      await _IwtAudio.instance.failed();
      _showFeedback('Login token missing', success: false);
      return;
    }

    // Check if already scanned in this session
    if (_scannedOrders.any((o) => o.orderHash == orderHash)) {
      await _IwtAudio.instance.failed();
      _showFeedback('Order already scanned: $orderHash', success: false);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final jsonResponse = await _api.initiateIwt(
        token: token,
        orderHash: orderHash,
      );

      final message =
          (jsonResponse['message'] ?? 'IWT initiate done!').toString();

      await _IwtAudio.instance.success();

      if (!mounted) return;
      setState(() {
        _scannedOrders.insert(
          0,
          _ScannedOrder(
            orderHash: orderHash,
            message: message,
            scannedAt: DateTime.now(),
          ),
        );
        _isLoading = false;
      });

      _showFeedback(message, success: true);
    } on SocketException catch (e) {
      await _IwtAudio.instance.failed();
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
      _showFeedback('Network error', success: false);
    } on TimeoutException {
      await _IwtAudio.instance.failed();
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Request timed out. Check network.';
        _isLoading = false;
      });
      _showFeedback('Timeout', success: false);
    } catch (e) {
      await _IwtAudio.instance.failed();
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
      _showFeedback('IWT failed', success: false);
    }
  }

  void _clearHistory() {
    setState(() {
      _scannedOrders.clear();
      _lastScannedCode = null;
      _lastScanTime = null;
      _errorMessage = null;
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
    final t = Theme.of(context);
    final s = t.colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: _AdaptiveBackButton(color: s.onSurface),
        title: const Text('Inter-Warehouse Transfer'),
        centerTitle: true,
        elevation: 0,
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
          if (_scannedOrders.isNotEmpty)
            IconButton(
              tooltip: 'Clear History',
              onPressed: _clearHistory,
              icon: Icon(
                Icons.delete_sweep_rounded,
                color: s.onSurfaceVariant,
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
              errorMessage: _errorMessage,
            ),
            Expanded(
              child: _ScannedOrdersList(
                scannedOrders: _scannedOrders,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// =========================================================
/// Adaptive back button
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
  final String? errorMessage;

  const _ScannerPanel({
    required this.controller,
    required this.onDetect,
    required this.feedback,
    required this.isLoading,
    required this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final h = MediaQuery.of(context).size.height;
    final scannerHeight = (h * 0.42).clamp(260.0, 400.0);

    final instruction = isLoading
        ? 'Processing IWT...'
        : 'Scan QR for IWT Transfer';

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

/// =========================================================
/// Scanner overlay painter
/// =========================================================
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
    final cutRRect =
        RRect.fromRectAndRadius(cutRect, const Radius.circular(20));

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

/// =========================================================
/// Feedback state & toast
/// =========================================================
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
    final bg =
        state.success ? scheme.tertiaryContainer : scheme.errorContainer;
    final fg =
        state.success ? scheme.onTertiaryContainer : scheme.onErrorContainer;

    return Container(
      key: ValueKey('${state.success}-${state.message}'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.94),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fg.withOpacity(0.15)),
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

/// =========================================================
/// Instruction chip
/// =========================================================
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

/// =========================================================
/// Error strip
/// =========================================================
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
          Icon(Icons.warning_rounded,
              color: scheme.onErrorContainer, size: 18),
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
/// Scanned orders list (bottom panel)
/// =========================================================
class _ScannedOrdersList extends StatelessWidget {
  final List<_ScannedOrder> scannedOrders;

  const _ScannedOrdersList({required this.scannedOrders});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (scannedOrders.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
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
                  child: Icon(Icons.swap_horiz_rounded,
                      color: scheme.onPrimaryContainer, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ready to Scan',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: scheme.onSurface,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Scan an order QR code to initiate\nInter-Warehouse Transfer.',
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
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: scheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.history_rounded,
                    color: scheme.onTertiaryContainer, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'Scanned Orders',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: scheme.onSurface,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${scannedOrders.length}',
                  style: TextStyle(
                    color: scheme.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            itemCount: scannedOrders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              return _ScannedOrderCard(order: scannedOrders[i]);
            },
          ),
        ),
      ],
    );
  }
}

/// =========================================================
/// Scanned order card
/// =========================================================
class _ScannedOrderCard extends StatelessWidget {
  final _ScannedOrder order;
  const _ScannedOrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final timeStr =
        '${order.scannedAt.hour.toString().padLeft(2, '0')}:${order.scannedAt.minute.toString().padLeft(2, '0')}:${order.scannedAt.second.toString().padLeft(2, '0')}';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.tertiaryContainer.withOpacity(0.55),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: scheme.tertiary.withOpacity(0.35),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: scheme.tertiary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.check_rounded,
                color: scheme.onTertiary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.orderHash,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    order.message,
                    style: TextStyle(
                      color: scheme.tertiary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              timeStr,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
