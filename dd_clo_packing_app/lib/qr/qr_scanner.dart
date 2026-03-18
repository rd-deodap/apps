import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Color, Divider;
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:audioplayers/audioplayers.dart';

// IMPORTANT: Update this import to your real HomeScreen path:
import '../home/home.dart';

/// =========================================================
/// AUDIO SERVICE (success.mp3 / failed.mp3)
/// =========================================================
class AppAudio {
  AppAudio._();
  static final AppAudio instance = AppAudio._();

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

  void dispose() {
    _player.dispose();
  }
}

/// =========================================================
/// SAFE QR PARSER
/// - Supports raw hash
/// - Supports URL QR: .../something/<hash>
/// - Supports query param: ?order_hash=XXXX
/// - Supports caret-separated: 193^62832221^92472357478234 → 62832221
/// =========================================================
String normalizeOrderHash(String raw) {
  final v = raw.trim();
  if (v.isEmpty) return v;

  // Handle caret-separated format: extract second part as order number
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
/// API CLIENT
/// - Uses GET with JSON BODY (matches your Postman screenshot)
/// - Avoids leaking credentials in query params
/// =========================================================
class ApiClient {
  final String apiBaseUrl;
  final String appId;
  final String apiKey;

  const ApiClient({
    required this.apiBaseUrl,
    required this.appId,
    required this.apiKey,
  });

  Future<void> ensureInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isEmpty || result.first.rawAddress.isEmpty) {
        throw const SocketException('No active internet connection');
      }
    } on SocketException {
      throw const SocketException('No internet connection. Please check your network.');
    }
  }

  Future<Map<String, dynamic>> getPrimaryInfo({
    required String token,
    required String orderHash,
  }) async {
    await ensureInternet();

    final uri = Uri.parse('$apiBaseUrl/order/get_primary_info');

    final payload = {
      "app_id": appId,
      "api_key": apiKey,
      "token": token,
      "order_hash": orderHash,
    };

    final req = http.Request('GET', uri);
    req.headers['Content-Type'] = 'application/json';
    req.headers['Accept'] = 'application/json';
    req.body = jsonEncode(payload);

    final streamed = await req.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      throw HttpException('Server error (${response.statusCode}).');
    }

    final Map<String, dynamic> jsonResponse = jsonDecode(response.body);

    final status = (jsonResponse['status'] ?? '').toString().toLowerCase();
    if (status != 'success') {
      throw Exception((jsonResponse['message'] ?? 'Invalid Order. Please try again.').toString());
    }

    return jsonResponse;
  }
}

/// =========================================================
/// MODELS
/// =========================================================
class PrimaryOrderDetails {
  final int primaryOrderId;
  final String primaryOrderNo;
  final String formattedOrderNo;
  final String secondaryLocation;
  final int totalParts;
  final String status;

  PrimaryOrderDetails({
    required this.primaryOrderId,
    required this.primaryOrderNo,
    required this.formattedOrderNo,
    required this.secondaryLocation,
    required this.totalParts,
    required this.status,
  });

  factory PrimaryOrderDetails.fromJson(Map<String, dynamic> json) {
    return PrimaryOrderDetails(
      primaryOrderId: json['primary_order_id'] ?? 0,
      primaryOrderNo: (json['primary_order_no'] ?? 'N/A').toString(),
      formattedOrderNo: (json['primary_order_no_formatted'] ?? 'N/A').toString(),
      secondaryLocation: (json['primary_order_all_secondary_clo_location'] ?? 'N/A').toString(),
      totalParts: json['primary_order_clo_total_parts'] ?? 0,
      status: (json['primary_order_clo_status'] ?? 'UNKNOWN').toString(),
    );
  }

  Color get statusColor {
    switch (status.toUpperCase()) {
      case 'READY':
        return CupertinoColors.systemGreen;
      case 'PENDING':
        return CupertinoColors.systemOrange;
      case 'COMPLETED':
        return CupertinoColors.activeBlue;
      case 'CANCELLED':
        return CupertinoColors.systemRed;
      default:
        return CupertinoColors.label;
    }
  }
}

class SecondaryOrderPart {
  final int secondaryOrderId;
  final String secondaryOrderNo; // order hash used for locking (backend)
  final String formattedSecondaryOrderNo;
  final dynamic pickedUp;
  final int received;

  SecondaryOrderPart({
    required this.secondaryOrderId,
    required this.secondaryOrderNo,
    required this.formattedSecondaryOrderNo,
    required this.pickedUp,
    required this.received,
  });

  factory SecondaryOrderPart.fromJson(Map<String, dynamic> json) {
    return SecondaryOrderPart(
      secondaryOrderId: json['secondary_order_id'] ?? 0,
      secondaryOrderNo: (json['secondary_order_no'] ?? 'N/A').toString(),
      formattedSecondaryOrderNo: (json['secondary_order_no_formatted'] ?? 'N/A').toString(),
      pickedUp: json['secondary_order_picked_up'],
      received: json['secondary_order_received'] ?? 0,
    );
  }

  bool get isReceived => received == 1;
  String get pickedUpText => pickedUp == null ? 'Not picked' : pickedUp.toString();
}

class PrimaryOrderPartsResponse {
  final PrimaryOrderDetails primary;
  final List<SecondaryOrderPart> parts;

  PrimaryOrderPartsResponse({required this.primary, required this.parts});

  factory PrimaryOrderPartsResponse.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] ?? {}) as Map<String, dynamic>;
    final primary = PrimaryOrderDetails.fromJson(data);

    final rawParts = (data['primary_order_clo_parts'] ?? []) as List<dynamic>;
    final parts = rawParts.map((e) => SecondaryOrderPart.fromJson(e as Map<String, dynamic>)).toList();

    return PrimaryOrderPartsResponse(primary: primary, parts: parts);
  }
}

/// =========================================================
/// UI HELPERS
/// =========================================================
TextStyle _noUnderline(TextStyle base) => base.copyWith(decoration: TextDecoration.none);

Widget _cupertinoCard({
  required Widget child,
  EdgeInsets padding = const EdgeInsets.all(16),
  Color? background,
}) {
  return Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: background ?? CupertinoColors.systemBackground,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: CupertinoColors.systemGrey5),
      boxShadow: [
        BoxShadow(
          color: CupertinoColors.black.withOpacity(0.06),
          blurRadius: 22,
          offset: const Offset(0, 12),
        ),
      ],
    ),
    child: child,
  );
}

Widget _sectionTitle(String text) {
  return Text(
    text,
    style: _noUnderline(const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w800,
      color: CupertinoColors.label,
    )),
  );
}

Widget _subtleText(String text, {TextAlign align = TextAlign.left}) {
  return Text(
    text,
    textAlign: align,
    style: _noUnderline(const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: CupertinoColors.secondaryLabel,
    )),
  );
}

Widget _pill({
  required String text,
  required Color color,
  IconData? icon,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withOpacity(0.25)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
        ],
        Text(
          text,
          style: _noUnderline(TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 12,
            letterSpacing: 0.2,
          )),
        ),
      ],
    ),
  );
}

Widget _kvRow(String label, String value, {double labelWidth = 140}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        SizedBox(
          width: labelWidth,
          child: Text(
            label,
            style: _noUnderline(const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: CupertinoColors.secondaryLabel,
            )),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: _noUnderline(const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: CupertinoColors.label,
            )),
          ),
        ),
      ],
    ),
  );
}

Widget _infoBadge({
  required IconData icon,
  required String title,
  required String value,
}) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: CupertinoColors.systemGrey6,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: CupertinoColors.systemGrey5),
    ),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: CupertinoColors.systemGrey5),
          ),
          child: Icon(icon, size: 18, color: CupertinoColors.activeBlue),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: _noUnderline(const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: CupertinoColors.secondaryLabel,
                )),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: _noUnderline(const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: CupertinoColors.label,
                )),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// =========================================================
/// WEBVIEW / PDF SCREEN
/// =========================================================
class WebViewScreen extends StatefulWidget {
  final String url;
  final String title;
  final bool isPdf;

  const WebViewScreen({
    super.key,
    required this.url,
    required this.title,
    this.isPdf = false,
  });

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  WebViewController? _webViewController;
  final PdfViewerController _pdfViewerController = PdfViewerController();

  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();

    if (!widget.isPdf) {
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0x00000000))
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (_) {
              if (!mounted) return;
              setState(() {
                _isLoading = true;
                _error = null;
              });
            },
            onPageFinished: (_) async {
              try {
                await _webViewController?.runJavaScript('''
                  (function() {
                    var style = document.createElement('style');
                    style.type = 'text/css';
                    style.innerHTML = `
                      * { text-decoration: none !important; }
                      a, a * { text-decoration: none !important; }
                    `;
                    document.head.appendChild(style);
                  })();
                ''');
              } catch (_) {}
              if (!mounted) return;
              setState(() => _isLoading = false);
            },
            onWebResourceError: (WebResourceError error) {
              if (!mounted) return;
              setState(() {
                _isLoading = false;
                _error = 'Failed to load page: ${error.description}';
              });
            },
          ),
        )
        ..loadRequest(Uri.parse(widget.url));
    } else {
      _isLoading = true;
      _error = null;
    }
  }

  void _retry() {
    setState(() {
      _error = null;
      _isLoading = true;
    });
    if (widget.isPdf) {
      setState(() {});
    } else {
      _webViewController?.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(widget.title, style: _noUnderline(const TextStyle(fontWeight: FontWeight.w700))),
        backgroundColor: CupertinoColors.systemBackground,
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _retry,
          child: const Icon(CupertinoIcons.refresh, size: 22),
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            if (widget.isPdf)
              SfPdfViewer.network(
                widget.url,
                controller: _pdfViewerController,
                onDocumentLoaded: (_) {
                  if (!mounted) return;
                  setState(() => _isLoading = false);
                },
                onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
                  if (!mounted) return;
                  setState(() {
                    _isLoading = false;
                    _error = "PDF Error: ${details.error}";
                  });
                },
              )
            else
              WebViewWidget(controller: _webViewController!),
            if (_isLoading) const Center(child: CupertinoActivityIndicator(radius: 16)),
            if (_error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: _cupertinoCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          CupertinoIcons.exclamationmark_triangle_fill,
                          color: CupertinoColors.systemRed,
                          size: 42,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: _noUnderline(const TextStyle(
                            color: CupertinoColors.systemRed,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          )),
                        ),
                        const SizedBox(height: 14),
                        CupertinoButton.filled(
                          onPressed: _retry,
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                          child: Text('Retry', style: _noUnderline(const TextStyle(fontWeight: FontWeight.w800))),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// =========================================================
/// SECOND SCREEN (Order Parts)
/// =========================================================
class SecondScreen extends StatefulWidget {
  final Map<String, dynamic> fullJson;
  final String orderHash; // backend only (do not show in UI)

  const SecondScreen({
    super.key,
    required this.fullJson,
    required this.orderHash,
  });

  @override
  State<SecondScreen> createState() => _SecondScreenState();
}

class _SecondScreenState extends State<SecondScreen> {
  late final PrimaryOrderPartsResponse _parsed;
  late final PrimaryOrderDetails _primary;
  late final List<SecondaryOrderPart> _parts;

  final Set<String> _lockedHashes = <String>{};

  String? _toast;
  Color _toastColor = CupertinoColors.label;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    _parsed = PrimaryOrderPartsResponse.fromJson(widget.fullJson);
    _primary = _parsed.primary;
    _parts = List<SecondaryOrderPart>.from(_parsed.parts);
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }

  void _showToast(String msg, {required Color color}) {
    _toastTimer?.cancel();
    setState(() {
      _toast = msg;
      _toastColor = color;
    });
    _toastTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _toast = null);
    });
  }

  bool get _allLocked => _parts.isNotEmpty && _lockedHashes.length == _parts.length;

  Future<void> _showFailDialog({
    required String message,
    required VoidCallback onRetry,
  }) async {
    await showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Scan Failed'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(message),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.of(context).pop();
              onRetry();
            },
            child: const Text('Please Try Again'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _openScannerForSpecific(String expectedHash) async {
    final result = await showCupertinoModalPopup<_ScanResult>(
      context: context,
      builder: (_) => _ScanBottomSheet(
        title: 'Scan Secondary Order',
        subtitle: 'Scan QR for this selected secondary order to lock it.',
        expectedHash: expectedHash,
        mode: _ScanMode.specific,
      ),
    );

    if (!mounted || result == null) return;

    if (result.success && result.matchedHash != null) {
      await AppAudio.instance.success();
      _lockHash(result.matchedHash!);
      _showToast('Locked successfully', color: CupertinoColors.systemGreen);
    } else {
      await AppAudio.instance.failed();
      await _showFailDialog(
        message: result.message ?? 'Scan failed.',
        onRetry: () => _openScannerForSpecific(expectedHash),
      );
    }
  }

  Future<void> _openScannerForAny() async {
    final result = await showCupertinoModalPopup<_ScanResult>(
      context: context,
      builder: (_) => _ScanBottomSheet(
        title: 'Scan Secondary Order',
        subtitle: 'Scan any secondary order QR to lock one by one.',
        expectedHash: null,
        mode: _ScanMode.any,
      ),
    );

    if (!mounted || result == null) return;

    if (result.success && result.matchedHash != null) {
      final ok = _lockHash(result.matchedHash!);
      if (ok) {
        await AppAudio.instance.success();
        _showToast('Locked successfully', color: CupertinoColors.systemGreen);
      } else {
        await AppAudio.instance.failed();
        await _showFailDialog(
          message: 'This QR does not belong to any secondary order in this list.',
          onRetry: _openScannerForAny,
        );
      }
    } else {
      await AppAudio.instance.failed();
      await _showFailDialog(
        message: result.message ?? 'Scan failed.',
        onRetry: _openScannerForAny,
      );
    }
  }

  bool _lockHash(String raw) {
    final hash = normalizeOrderHash(raw);

    final exists = _parts.any((p) => p.secondaryOrderNo == hash);
    if (!exists) return false;

    if (_lockedHashes.contains(hash)) {
      _showToast('Already locked', color: CupertinoColors.systemOrange);
      return true;
    }

    setState(() => _lockedHashes.add(hash));
    return true;
  }

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      CupertinoPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final receivedCount = _lockedHashes.length;
    final totalParts = _parts.length;
    final progress = totalParts <= 0 ? 0.0 : (receivedCount / totalParts).clamp(0.0, 1.0);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('Order Parts', style: _noUnderline(const TextStyle(fontWeight: FontWeight.w800))),
        backgroundColor: CupertinoColors.systemBackground,
      ),
      child: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    children: [
                      // ===== Header Card (Primary Summary) =====
                      _cupertinoCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(child: _sectionTitle('Primary Order')),
                                _pill(
                                  text: _primary.status.toUpperCase(),
                                  color: _primary.statusColor,
                                  icon: CupertinoIcons.check_mark_circled_solid,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _infoBadge(
                                    icon: CupertinoIcons.number,
                                    title: 'Order',
                                    value: _primary.formattedOrderNo,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _infoBadge(
                                    icon: CupertinoIcons.cube_box,
                                    title: 'Parts',
                                    value: totalParts.toString(),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _infoBadge(
                              icon: CupertinoIcons.location_solid,
                              title: 'Secondary Location',
                              value: _primary.secondaryLocation,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _pill(
                                    text: _allLocked ? 'All locked' : 'Locked $receivedCount / $totalParts',
                                    color: _allLocked ? CupertinoColors.systemGreen : CupertinoColors.systemOrange,
                                    icon: CupertinoIcons.lock_fill,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                _pill(
                                  text: 'ID: ${_primary.primaryOrderId}',
                                  color: CupertinoColors.activeBlue,
                                  icon: CupertinoIcons.person_crop_circle_badge_checkmark,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                height: 10,
                                decoration: BoxDecoration(
                                  color: CupertinoColors.systemGrey5,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: FractionallySizedBox(
                                    widthFactor: progress,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: _allLocked ? CupertinoColors.systemGreen : CupertinoColors.systemOrange,
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            _subtleText(
                              _allLocked
                                  ? 'All secondary orders are locked. Tap Done to finish.'
                                  : 'Tap a secondary order to scan, or use Scan QR below.',
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // ===== Section Header =====
                      _cupertinoCard(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            const Icon(CupertinoIcons.list_bullet, color: CupertinoColors.activeBlue, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Secondary Orders',
                                    style: _noUnderline(const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: CupertinoColors.label,
                                    )),
                                  ),
                                  const SizedBox(height: 2),
                                  _subtleText('Scan and lock each secondary order.'),
                                ],
                              ),
                            ),
                            _pill(
                              text: '$receivedCount / $totalParts',
                              color: CupertinoColors.secondaryLabel,
                              icon: CupertinoIcons.chart_bar_alt_fill,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      ..._parts.map(_secondaryTile).toList(),
                      const SizedBox(height: 92),
                    ],
                  ),
                ),

                _BottomActionBar(
                  doneEnabled: _allLocked,
                  lockedCount: _lockedHashes.length,
                  totalCount: _parts.length,
                  onScanPressed: _openScannerForAny,
                  onDonePressed: _allLocked ? _goHome : null,
                ),
              ],
            ),

            // Toast
            if (_toast != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 100,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemBackground,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: CupertinoColors.systemGrey5),
                    boxShadow: [
                      BoxShadow(
                        color: CupertinoColors.black.withOpacity(0.10),
                        blurRadius: 18,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _toastColor == CupertinoColors.systemGreen
                            ? CupertinoIcons.checkmark_alt_circle_fill
                            : _toastColor == CupertinoColors.systemOrange
                            ? CupertinoIcons.exclamationmark_circle_fill
                            : CupertinoIcons.xmark_circle_fill,
                        color: _toastColor,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _toast!,
                          style: _noUnderline(TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: _toastColor,
                          )),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _secondaryTile(SecondaryOrderPart part) {
    final locked = _lockedHashes.contains(part.secondaryOrderNo);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: locked ? null : () => _openScannerForSpecific(part.secondaryOrderNo),
        child: _cupertinoCard(
          padding: const EdgeInsets.all(14),
          background: locked ? CupertinoColors.systemGreen.withOpacity(0.06) : CupertinoColors.systemBackground,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: locked ? CupertinoColors.systemGreen.withOpacity(0.14) : CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: locked ? CupertinoColors.systemGreen.withOpacity(0.25) : CupertinoColors.systemGrey5,
                  ),
                ),
                child: Icon(
                  locked ? CupertinoIcons.lock_fill : CupertinoIcons.qrcode_viewfinder,
                  color: locked ? CupertinoColors.systemGreen : CupertinoColors.label,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            part.formattedSecondaryOrderNo,
                            style: _noUnderline(const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: CupertinoColors.label,
                            )),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _pill(
                          text: locked ? 'LOCKED' : 'SCAN',
                          color: locked ? CupertinoColors.systemGreen : CupertinoColors.systemOrange,
                          icon: locked ? CupertinoIcons.lock_fill : CupertinoIcons.qrcode_viewfinder,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _subtleText('Secondary ID: ${part.secondaryOrderId}'),
                        ),
                        _subtleText('Picked Up: ${part.pickedUpText}'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _subtleText(
                      locked ? 'Locked successfully.' : 'Tap to scan and lock this order.',
                    ),
                    // IMPORTANT: Order Hash is intentionally NOT shown to user
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom action bar
class _BottomActionBar extends StatelessWidget {
  final bool doneEnabled;
  final int lockedCount;
  final int totalCount;
  final VoidCallback onScanPressed;
  final VoidCallback? onDonePressed;

  const _BottomActionBar({
    required this.doneEnabled,
    required this.lockedCount,
    required this.totalCount,
    required this.onScanPressed,
    required this.onDonePressed,
  });

  @override
  Widget build(BuildContext context) {
    final statusText = totalCount == 0
        ? 'No secondary orders found.'
        : doneEnabled
        ? 'All locked ($lockedCount/$totalCount)'
        : 'Locked $lockedCount/$totalCount';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        border: const Border(top: BorderSide(color: CupertinoColors.systemGrey5)),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(CupertinoIcons.lock_shield, size: 18, color: CupertinoColors.secondaryLabel),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    statusText,
                    style: _noUnderline(const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: CupertinoColors.secondaryLabel,
                    )),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Requirement: Done appears only after all are locked.
            if (!doneEnabled) ...[
              CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 14),
                color: CupertinoColors.activeBlue,
                onPressed: onScanPressed,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(CupertinoIcons.qrcode_viewfinder, size: 18, color: CupertinoColors.white),
                    const SizedBox(width: 8),
                    Text('Scan QR', style: _noUnderline(const TextStyle(fontWeight: FontWeight.w900))),
                  ],
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      color: CupertinoColors.activeBlue,
                      onPressed: onScanPressed,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(CupertinoIcons.qrcode_viewfinder, size: 18, color: CupertinoColors.white),
                          const SizedBox(width: 8),
                          Text('Scan QR', style: _noUnderline(const TextStyle(fontWeight: FontWeight.w900))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      color: CupertinoColors.systemGreen,
                      onPressed: onDonePressed,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(CupertinoIcons.checkmark_seal_fill, size: 18, color: CupertinoColors.white),
                          const SizedBox(width: 8),
                          Text(
                            'Done',
                            style: _noUnderline(const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: CupertinoColors.white,
                            )),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// =========================================================
/// SCANNER MODAL
/// =========================================================
enum _ScanMode { any, specific }

class _ScanResult {
  final bool success;
  final String? matchedHash;
  final String? message;

  const _ScanResult({
    required this.success,
    this.matchedHash,
    this.message,
  });
}

class _ScanBottomSheet extends StatefulWidget {
  final String title;
  final String subtitle;
  final _ScanMode mode;
  final String? expectedHash;

  const _ScanBottomSheet({
    required this.title,
    required this.subtitle,
    required this.mode,
    required this.expectedHash,
  });

  @override
  State<_ScanBottomSheet> createState() => _ScanBottomSheetState();
}

class _ScanBottomSheetState extends State<_ScanBottomSheet> {
  late final MobileScannerController _controller;
  bool _torchOn = false;

  String? _last;
  DateTime? _lastTime;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      formats: [BarcodeFormat.qrCode],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _shouldAccept(String code) {
    if (code.isEmpty) return false;
    if (_last == code) return false;

    final now = DateTime.now();
    if (_lastTime != null && now.difference(_lastTime!).inMilliseconds < 900) return false;

    _last = code;
    _lastTime = now;
    return true;
  }

  void _finish(_ScanResult result) {
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.78;
    final cut = MediaQuery.of(context).size.width * 0.72;

    return CupertinoPopupSurface(
      isSurfacePainted: true,
      child: Container(
        height: height,
        color: CupertinoColors.systemBackground,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: _noUnderline(const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: CupertinoColors.label,
                          )),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.subtitle,
                          style: _noUnderline(const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: CupertinoColors.secondaryLabel,
                          )),
                        ),
                      ],
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => _finish(const _ScanResult(success: false, message: 'Cancelled')),
                    child: const Icon(CupertinoIcons.xmark_circle_fill, size: 26, color: CupertinoColors.systemGrey),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  MobileScanner(
                    controller: _controller,
                    onDetect: (capture) {
                      if (capture.barcodes.isEmpty) return;
                      final raw = capture.barcodes.first.rawValue;
                      if (raw == null) return;

                      final code = normalizeOrderHash(raw);
                      if (!_shouldAccept(code)) return;

                      if (widget.mode == _ScanMode.specific) {
                        final expected = widget.expectedHash ?? '';
                        if (code == expected) {
                          _finish(_ScanResult(success: true, matchedHash: code));
                        } else {
                          _finish(const _ScanResult(
                            success: false,
                            message: 'Scanned QR does not match this secondary order.',
                          ));
                        }
                      } else {
                        _finish(_ScanResult(success: true, matchedHash: code));
                      }
                    },
                  ),
                  IgnorePointer(
                    ignoring: true,
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _ScannerOverlayPainter(cutOutSize: cut, borderRadius: 22),
                    ),
                  ),
                  Positioned(
                    top: 14,
                    right: 14,
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () async {
                        await _controller.toggleTorch();
                        if (!mounted) return;
                        setState(() => _torchOn = !_torchOn);
                      },
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: CupertinoColors.black.withOpacity(0.55),
                          shape: BoxShape.circle,
                          border: Border.all(color: CupertinoColors.white.withOpacity(0.18)),
                        ),
                        child: Icon(
                          _torchOn ? CupertinoIcons.bolt_fill : CupertinoIcons.bolt_slash_fill,
                          color: CupertinoColors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: _cupertinoCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.qrcode_viewfinder, color: CupertinoColors.activeBlue, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.mode == _ScanMode.specific
                                  ? 'Scan the QR of the selected secondary order.'
                                  : 'Scan any secondary order QR from the list.',
                              style: _noUnderline(const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: CupertinoColors.label,
                              )),
                            ),
                          ),
                        ],
                      ),
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

/// =========================================================
/// SCREEN 1: ORDER DETAILS (Primary Order Info)
/// - Keeps only App Bar items
/// - Removes Quick Actions section entirely
/// - Improves error message styling
/// - Improves Order Details UI/layout
/// =========================================================
enum ConfirmSelection { orderNumber, location, totalParts }

class OrderDetailsScreen extends StatefulWidget {
  final PrimaryOrderDetails orderDetails;
  final String originalOrderHash; // backend only (do not show)

  const OrderDetailsScreen({
    super.key,
    required this.orderDetails,
    required this.originalOrderHash,
  });

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  ConfirmSelection? _selected;
  bool _confirmLoading = false;
  String? _confirmError;

  final ApiClient _api = const ApiClient(
    apiBaseUrl: "https://api.vacalvers.com/api-clo-packaging-app",
    appId: "2",
    apiKey: "022782f3-c4aa-443a-9f14-7698c648a137",
  );

  void _openInWebView(BuildContext context, String url, String title, {bool isPdf = false}) {
    Navigator.of(context).push(
      CupertinoPageRoute(builder: (context) => WebViewScreen(url: url, title: title, isPdf: isPdf)),
    );
  }

  Future<void> _confirmAndOpenSecondScreen() async {
    if (_selected == null) {
      setState(() => _confirmError = 'Select one detail (Order / Location / Parts) to confirm.');
      return;
    }

    setState(() {
      _confirmLoading = true;
      _confirmError = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken');

      if (token == null || token.isEmpty) {
        setState(() {
          _confirmLoading = false;
          _confirmError = 'Login token not found. Please log in again.';
        });
        await AppAudio.instance.failed();
        return;
      }

      final jsonResponse = await _api.getPrimaryInfo(
        token: token,
        orderHash: widget.originalOrderHash,
      );

      if (!mounted) return;

      await Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) => SecondScreen(fullJson: jsonResponse, orderHash: widget.originalOrderHash),
        ),
      );

      if (!mounted) return;
      setState(() => _confirmLoading = false);
    } on TimeoutException {
      setState(() {
        _confirmLoading = false;
        _confirmError = 'Request timed out. Please check your network.';
      });
      await AppAudio.instance.failed();
    } on SocketException catch (e) {
      setState(() {
        _confirmLoading = false;
        _confirmError = e.message;
      });
      await AppAudio.instance.failed();
    } catch (e) {
      setState(() {
        _confirmLoading = false;
        _confirmError = e.toString().replaceFirst('Exception: ', '');
      });
      await AppAudio.instance.failed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final details = widget.orderDetails;

    final slipUrl =
        'https://support.vacalvers.com/global_services/print/order_packing_slip/${widget.originalOrderHash}';
    final slip2Url =
        'https://support.vacalvers.com/global_services/print/order_packing_slip_2/${widget.originalOrderHash}';

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('Primary Order Info', style: _noUnderline(const TextStyle(fontWeight: FontWeight.w800))),
        backgroundColor: CupertinoColors.systemBackground,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              onPressed: () => _openInWebView(context, slip2Url, 'Packing Slip 2', isPdf: false),
              child: const Icon(CupertinoIcons.doc_text, size: 22),
            ),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              onPressed: () => _openInWebView(context, slipUrl, 'Packing Slip PDF', isPdf: true),
              child: const Icon(CupertinoIcons.doc_on_clipboard, size: 22),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildPrimaryInfoCard(details),
                    const SizedBox(height: 14),

                    // Improved error card (smaller font, more professional)
                    if (_confirmError != null)
                      _cupertinoCard(
                        background: CupertinoColors.systemRed.withOpacity(0.06),
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              CupertinoIcons.exclamationmark_triangle_fill,
                              color: CupertinoColors.systemRed,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _confirmError!,
                                style: _noUnderline(const TextStyle(
                                  color: CupertinoColors.systemRed,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12.5,
                                  height: 1.2,
                                )),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: CupertinoButton.filled(
                padding: const EdgeInsets.symmetric(vertical: 14),
                onPressed: _confirmLoading ? null : _confirmAndOpenSecondScreen,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_confirmLoading) ...[
                      const CupertinoActivityIndicator(radius: 10),
                      const SizedBox(width: 10),
                    ] else ...[
                      const Icon(CupertinoIcons.checkmark_seal, size: 18),
                      const SizedBox(width: 10),
                    ],
                    Text(
                      'Confirm & Next',
                      style: _noUnderline(const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryInfoCard(PrimaryOrderDetails details) {
    return _cupertinoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _sectionTitle('Order Details')),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: details.statusColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: details.statusColor.withOpacity(0.25)),
                ),
                child: Text(
                  details.status.toUpperCase(),
                  style: _noUnderline(TextStyle(
                    color: details.statusColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                    letterSpacing: 0.2,
                  )),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _subtleText(
                  'Select one detail to confirm the physical match before proceeding.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 18),

          // Improved layout: clear selection tiles
          _tapDetailRow(
            icon: CupertinoIcons.number,
            label: 'Order',
            value: details.formattedOrderNo,
            isLarge: true,
            selected: _selected == ConfirmSelection.orderNumber,
            onTap: () => setState(() {
              _selected = ConfirmSelection.orderNumber;
              _confirmError = null;
            }),
          ),
          const SizedBox(height: 10),
          _tapDetailRow(
            icon: CupertinoIcons.location_solid,
            label: 'Location',
            value: details.secondaryLocation,
            selected: _selected == ConfirmSelection.location,
            onTap: () => setState(() {
              _selected = ConfirmSelection.location;
              _confirmError = null;
            }),
          ),
          const SizedBox(height: 10),
          _tapDetailRow(
            icon: CupertinoIcons.cube_box,
            label: 'Parts',
            value: details.totalParts.toString(),
            selected: _selected == ConfirmSelection.totalParts,
            onTap: () => setState(() {
              _selected = ConfirmSelection.totalParts;
              _confirmError = null;
            }),
          ),

          const SizedBox(height: 12),

          // Compact internal ID row (still OK to show)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey6,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: CupertinoColors.systemGrey5),
            ),
            child: Row(
              children: [
                const Icon(CupertinoIcons.lock_shield, size: 18, color: CupertinoColors.secondaryLabel),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Internal ID',
                    style: _noUnderline(const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: CupertinoColors.secondaryLabel,
                    )),
                  ),
                ),
                Text(
                  details.primaryOrderId.toString(),
                  style: _noUnderline(const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: CupertinoColors.label,
                  )),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          _subtleText(
            _selected == null ? 'Nothing selected yet.' : 'Selected: ${_selected!.name}',
          ),
        ],
      ),
    );
  }

  Widget _tapDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required bool selected,
    required VoidCallback onTap,
    bool isLarge = false,
  }) {
    final bg = selected ? CupertinoColors.activeBlue.withOpacity(0.08) : CupertinoColors.systemBackground;
    final border = selected ? CupertinoColors.activeBlue.withOpacity(0.35) : CupertinoColors.systemGrey5;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selected ? CupertinoColors.activeBlue.withOpacity(0.12) : CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: selected ? CupertinoColors.activeBlue.withOpacity(0.25) : border),
              ),
              child: Icon(icon, size: 18, color: selected ? CupertinoColors.activeBlue : CupertinoColors.label),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: _noUnderline(const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: CupertinoColors.secondaryLabel,
                    )),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _noUnderline(TextStyle(
                      fontSize: isLarge ? 18 : 15,
                      color: CupertinoColors.label,
                      fontWeight: isLarge ? FontWeight.w900 : FontWeight.w800,
                    )),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              selected ? CupertinoIcons.check_mark_circled_solid : CupertinoIcons.circle,
              color: selected ? CupertinoColors.activeBlue : CupertinoColors.systemGrey2,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

/// =========================================================
/// PRIMARY QR SCANNER SCREEN
/// =========================================================
class OrderScannerScreen extends StatefulWidget {
  const OrderScannerScreen({super.key});

  @override
  State<OrderScannerScreen> createState() => _OrderScannerScreenState();
}

class _OrderScannerScreenState extends State<OrderScannerScreen> {
  final MobileScannerController scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    formats: [BarcodeFormat.qrCode],
  );

  bool _isLoading = false;
  String? _error;
  bool _isScanning = true;
  String? _lastScannedHash;
  bool _isTorchOn = false;
  String? _userToken;
  DateTime? _lastScanTime;

  final ApiClient _api = const ApiClient(
    apiBaseUrl: "https://api.vacalvers.com/api-clo-packaging-app",
    appId: "2",
    apiKey: "022782f3-c4aa-443a-9f14-7698c648a137",
  );

  @override
  void initState() {
    super.initState();
    _loadTokenFromSharedPreferences();
  }

  Future<void> _loadTokenFromSharedPreferences() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      _userToken = prefs.getString('authToken');

      if (_userToken == null || _userToken!.isEmpty) {
        setState(() => _error = 'Login Token not found. Please log in again.');
        await AppAudio.instance.failed();
      }
    } catch (e) {
      setState(() => _error = 'Error loading token: ${e.toString()}');
      await AppAudio.instance.failed();
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchPrimaryOrderDetails(String rawHash) async {
    if (_userToken == null || _userToken!.isEmpty) {
      setState(() => _error = 'Cannot fetch order: Login Token is missing.');
      await AppAudio.instance.failed();
      _resumeScanning();
      return;
    }

    final orderHash = normalizeOrderHash(rawHash);

    _stopScanning();
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final jsonResponse = await _api.getPrimaryInfo(
        token: _userToken!,
        orderHash: orderHash,
      );

      final orderDetails = PrimaryOrderDetails.fromJson(jsonResponse['data'] ?? {});
      await AppAudio.instance.success();

      if (!mounted) return;

      Navigator.of(context)
          .push(
        CupertinoPageRoute(
          builder: (_) => OrderDetailsScreen(
            orderDetails: orderDetails,
            originalOrderHash: orderHash,
          ),
        ),
      )
          .then((_) {
        _resumeScanning();
        if (!mounted) return;
        setState(() => _lastScannedHash = null);
      });
    } on SocketException catch (e) {
      setState(() => _error = e.message);
      await AppAudio.instance.failed();
      _resumeScanning();
    } on TimeoutException {
      setState(() => _error = 'Request timed out. Please check network.');
      await AppAudio.instance.failed();
      _resumeScanning();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      await AppAudio.instance.failed();
      _resumeScanning();
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _stopScanning() {
    if (_isScanning) {
      scannerController.stop();
      setState(() => _isScanning = false);
    }
  }

  void _resumeScanning() {
    if (!_isScanning) {
      scannerController.start();
      setState(() => _isScanning = true);
    }
  }

  @override
  void dispose() {
    scannerController.dispose();
    super.dispose();
  }

  bool _shouldAcceptScan(String code) {
    if (!_isScanning) return false;
    if (code.isEmpty) return false;
    if (code == _lastScannedHash) return false;

    final now = DateTime.now();
    if (_lastScanTime != null && now.difference(_lastScanTime!).inMilliseconds < 900) return false;

    _lastScanTime = now;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final frameSize = size.width * 0.74;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('QR Order Scanner', style: _noUnderline(const TextStyle(fontWeight: FontWeight.w900))),
        backgroundColor: CupertinoColors.systemBackground,
      ),
      child: SafeArea(
        child: Stack(
          children: [
            MobileScanner(
              controller: scannerController,
              onDetect: (capture) {
                if (capture.barcodes.isEmpty) return;
                final raw = capture.barcodes.first.rawValue;
                if (raw == null) return;

                final code = normalizeOrderHash(raw);
                if (_shouldAcceptScan(code)) {
                  setState(() => _lastScannedHash = code);
                  _fetchPrimaryOrderDetails(code);
                }
              },
            ),
            IgnorePointer(
              ignoring: true,
              child: CustomPaint(
                size: Size.infinite,
                painter: _ScannerOverlayPainter(
                  cutOutSize: frameSize,
                  borderRadius: 22,
                ),
              ),
            ),
            Positioned(
              top: 18,
              left: 16,
              right: 16,
              child: _cupertinoCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.qrcode_viewfinder, color: CupertinoColors.activeBlue, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Align the QR code inside the frame',
                        style: _noUnderline(const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: CupertinoColors.label,
                        )),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 90,
              right: 18,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () async {
                  await scannerController.toggleTorch();
                  if (!mounted) return;
                  setState(() => _isTorchOn = !_isTorchOn);
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: CupertinoColors.black.withOpacity(0.55),
                    shape: BoxShape.circle,
                    border: Border.all(color: CupertinoColors.white.withOpacity(0.18)),
                  ),
                  child: Icon(
                    _isTorchOn ? CupertinoIcons.bolt_fill : CupertinoIcons.bolt_slash_fill,
                    color: CupertinoColors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
            if (_isLoading || _error != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 18,
                child: _cupertinoCard(
                  padding: const EdgeInsets.all(16),
                  child: _buildStatusContent(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusContent() {
    if (_isLoading) {
      return Row(
        children: [
          const CupertinoActivityIndicator(radius: 14),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Fetching Order Info...',
              style: _noUnderline(const TextStyle(
                color: CupertinoColors.secondaryLabel,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              )),
            ),
          ),
        ],
      );
    }

    if (_error != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(CupertinoIcons.exclamationmark_circle_fill, color: CupertinoColors.systemRed, size: 44),
          const SizedBox(height: 10),
          Text(
            _error!,
            style: _noUnderline(const TextStyle(
              color: CupertinoColors.systemRed,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            )),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          CupertinoButton.filled(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
            onPressed: () {
              setState(() {
                _error = null;
                _lastScannedHash = null;
                _lastScanTime = null;
              });
              _resumeScanning();
            },
            child: Text(
              'Please Try Again',
              style: _noUnderline(const TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}

/// =========================================================
/// OVERLAY PAINTER
/// =========================================================
class _ScannerOverlayPainter extends CustomPainter {
  final double cutOutSize;
  final double borderRadius;

  _ScannerOverlayPainter({
    required this.cutOutSize,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = CupertinoColors.black.withOpacity(0.55);

    final center = Offset(size.width / 2, size.height / 2);
    final cutOutRect = Rect.fromCenter(
      center: center,
      width: cutOutSize,
      height: cutOutSize,
    );
    final cutOutRRect = RRect.fromRectAndRadius(cutOutRect, Radius.circular(borderRadius));

    final overlayPath = Path()..addRect(Offset.zero & size);
    final cutOutPath = Path()..addRRect(cutOutRRect);

    final finalPath = Path.combine(PathOperation.difference, overlayPath, cutOutPath);
    canvas.drawPath(finalPath, paint);

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = CupertinoColors.activeBlue.withOpacity(0.92);

    canvas.drawRRect(cutOutRRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) {
    return oldDelegate.cutOutSize != cutOutSize || oldDelegate.borderRadius != borderRadius;
  }
}
