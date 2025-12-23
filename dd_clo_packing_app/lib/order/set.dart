import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:webview_flutter/webview_flutter.dart';

// =========================================================
// MODELS
// =========================================================

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
      primaryOrderNo: json['primary_order_no'] ?? 'N/A',
      formattedOrderNo: json['primary_order_no_formatted'] ?? 'N/A',
      secondaryLocation: json['primary_order_all_secondary_clo_location'] ?? 'N/A',
      totalParts: json['primary_order_clo_total_parts'] ?? 0,
      status: json['primary_order_clo_status'] ?? 'UNKNOWN',
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
  final String secondaryOrderNo;
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
      secondaryOrderNo: json['secondary_order_no'] ?? 'N/A',
      formattedSecondaryOrderNo: json['secondary_order_no_formatted'] ?? 'N/A',
      pickedUp: json['secondary_order_picked_up'],
      received: json['secondary_order_received'] ?? 0,
    );
  }

  bool get isReceived => received == 1;

  String get pickedUpText {
    if (pickedUp == null) return 'Not picked';
    return pickedUp.toString();
  }
}

class PrimaryOrderPartsResponse {
  final PrimaryOrderDetails primary;
  final List<SecondaryOrderPart> parts;

  PrimaryOrderPartsResponse({
    required this.primary,
    required this.parts,
  });

  factory PrimaryOrderPartsResponse.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] ?? {}) as Map<String, dynamic>;
    final primary = PrimaryOrderDetails.fromJson(data);

    final rawParts = (data['primary_order_clo_parts'] ?? []) as List<dynamic>;
    final parts = rawParts
        .map((e) => SecondaryOrderPart.fromJson(e as Map<String, dynamic>))
        .toList();

    return PrimaryOrderPartsResponse(primary: primary, parts: parts);
  }
}

// =========================================================
// UI HELPERS
// =========================================================

TextStyle _noUnderline(TextStyle base) => base.copyWith(decoration: TextDecoration.none);

Widget _cupertinoCard({
  required Widget child,
  EdgeInsets padding = const EdgeInsets.all(16),
}) {
  return Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: CupertinoColors.systemBackground,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: CupertinoColors.systemGrey5),
      boxShadow: [
        BoxShadow(
          color: CupertinoColors.black.withOpacity(0.05),
          blurRadius: 18,
          offset: const Offset(0, 10),
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
      fontWeight: FontWeight.w700,
      color: CupertinoColors.label,
    )),
  );
}

Widget _subtleText(String text, {TextAlign align = TextAlign.left}) {
  return Text(
    text,
    textAlign: align,
    style: _noUnderline(const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: CupertinoColors.secondaryLabel,
    )),
  );
}

// =========================================================
// WEBVIEW / PDF SCREEN
// =========================================================

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
        middle: Text(
          widget.title,
          style: _noUnderline(const TextStyle(fontWeight: FontWeight.w600)),
        ),
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
                            fontWeight: FontWeight.w600,
                          )),
                        ),
                        const SizedBox(height: 14),
                        CupertinoButton.filled(
                          onPressed: _retry,
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                          child: Text(
                            'Retry',
                            style: _noUnderline(const TextStyle(fontWeight: FontWeight.w700)),
                          ),
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

// =========================================================
// SCREEN: PARTS (Screen 2)
// =========================================================

class PrimaryOrderPartsScreen extends StatelessWidget {
  final PrimaryOrderPartsResponse data;

  const PrimaryOrderPartsScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final primary = data.primary;
    final parts = data.parts;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          'Order Parts',
          style: _noUnderline(const TextStyle(fontWeight: FontWeight.w600)),
        ),
        backgroundColor: CupertinoColors.systemBackground,
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _cupertinoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _sectionTitle('Primary Order')),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: primary.statusColor.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: primary.statusColor.withOpacity(0.25)),
                        ),
                        child: Text(
                          primary.status,
                          style: _noUnderline(TextStyle(
                            color: primary.statusColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          )),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 18),
                  _infoRow('Order', primary.formattedOrderNo),
                  _infoRow('Location', primary.secondaryLocation),
                  _infoRow('Total Parts', primary.totalParts.toString()),
                  _infoRow('Internal ID', primary.primaryOrderId.toString()),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _cupertinoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('Parts (${parts.length})'),
                  const SizedBox(height: 6),
                  _subtleText('Secondary orders under this primary order.'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ...parts.map((p) => _partTile(p)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: _noUnderline(const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.secondaryLabel,
              )),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: _noUnderline(const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: CupertinoColors.label,
              )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _partTile(SecondaryOrderPart part) {
    final chipColor = part.isReceived ? CupertinoColors.systemGreen : CupertinoColors.systemOrange;
    final chipText = part.isReceived ? 'RECEIVED' : 'PENDING';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _cupertinoCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(CupertinoIcons.cube_box, color: CupertinoColors.label),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    part.formattedSecondaryOrderNo,
                    style: _noUnderline(const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: CupertinoColors.label,
                    )),
                  ),
                  const SizedBox(height: 6),
                  _subtleText('Secondary ID: ${part.secondaryOrderId}'),
                  _subtleText('Picked Up: ${part.pickedUpText}'),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: chipColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: chipColor.withOpacity(0.25)),
              ),
              child: Text(
                chipText,
                style: _noUnderline(TextStyle(
                  color: chipColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                )),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================
// SCREEN: ORDER DETAILS (Screen 1 in flow)
// =========================================================

enum ConfirmSelection { orderNumber, location, totalParts }

class OrderDetailsScreen extends StatefulWidget {
  final PrimaryOrderDetails orderDetails;
  final String originalOrderHash;

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

  final String _apiBaseUrl = "https://api.vacalvers.com/api-clo-packaging-app";
  final String _appId = "2";
  final String _apiKey = "022782f3-c4aa-443a-9f14-7698c648a137";

  void _openInWebView(BuildContext context, String url, String title, {bool isPdf = false}) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => WebViewScreen(url: url, title: title, isPdf: isPdf),
      ),
    );
  }

  Future<void> _fetchPartsAndOpenNextScreen() async {
    if (_selected == null) {
      setState(() => _confirmError = 'Please tap Order Number, Location, or Total Parts first.');
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
          _confirmError = 'Login Token not found. Please log in again.';
        });
        return;
      }

      try {
        final result = await InternetAddress.lookup('google.com');
        if (result.isEmpty || result.first.rawAddress.isEmpty) {
          throw const SocketException('No active internet connection');
        }
      } on SocketException {
        throw const SocketException('No internet connection. Please check your network.');
      }

      final uri = Uri.parse('$_apiBaseUrl/order/get_primary_info_with_parts')
          .replace(queryParameters: {
        "app_id": _appId,
        "api_key": _apiKey,
        "token": token,
        "order_hash": widget.originalOrderHash,
        "confirm_on": _selected!.name,
      });

      final response = await http.get(uri).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        setState(() {
          _confirmLoading = false;
          _confirmError = 'Server error (${response.statusCode}).';
        });
        return;
      }

      final Map<String, dynamic> jsonResponse = jsonDecode(response.body);

      if ((jsonResponse['status'] ?? '').toString().toLowerCase() != 'success') {
        setState(() {
          _confirmLoading = false;
          _confirmError = (jsonResponse['message'] ?? 'Unknown Error').toString();
        });
        return;
      }

      final parsed = PrimaryOrderPartsResponse.fromJson(jsonResponse);

      if (!mounted) return;
      await Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) => PrimaryOrderPartsScreen(data: parsed),
        ),
      );

      if (!mounted) return;
      setState(() {
        _confirmLoading = false;
      });
    } on TimeoutException {
      setState(() {
        _confirmLoading = false;
        _confirmError = 'Request timed out. Please check network.';
      });
    } on SocketException catch (e) {
      setState(() {
        _confirmLoading = false;
        _confirmError = e.message;
      });
    } catch (e) {
      setState(() {
        _confirmLoading = false;
        _confirmError = 'Error: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final details = widget.orderDetails;

    final String slipUrl =
        'https://support.vacalvers.com/global_services/print/order_packing_slip/${widget.originalOrderHash}';
    final String slip2Url =
        'https://support.vacalvers.com/global_services/print/order_packing_slip_2/${widget.originalOrderHash}';

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          'Primary Order Info',
          style: _noUnderline(const TextStyle(fontWeight: FontWeight.w600)),
        ),
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
                    _buildActionsCard(context, slip2Url, slipUrl),
                    const SizedBox(height: 14),
                    if (_confirmError != null)
                      _cupertinoCard(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            const Icon(CupertinoIcons.exclamationmark_circle_fill,
                                color: CupertinoColors.systemRed, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _confirmError!,
                                style: _noUnderline(const TextStyle(
                                  color: CupertinoColors.systemRed,
                                  fontWeight: FontWeight.w700,
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
                onPressed: _confirmLoading ? null : _fetchPartsAndOpenNextScreen,
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
                      style: _noUnderline(const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      )),
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
                  details.status,
                  style: _noUnderline(TextStyle(
                    color: details.statusColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 0.2,
                  )),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 18),
          _tapDetailRow(
            label: 'Order Number',
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
            label: 'Location (Secondary)',
            value: details.secondaryLocation,
            selected: _selected == ConfirmSelection.location,
            onTap: () => setState(() {
              _selected = ConfirmSelection.location;
              _confirmError = null;
            }),
          ),
          _tapDetailRow(
            label: 'Total Parts',
            value: details.totalParts.toString(),
            selected: _selected == ConfirmSelection.totalParts,
            onTap: () => setState(() {
              _selected = ConfirmSelection.totalParts;
              _confirmError = null;
            }),
          ),
          const SizedBox(height: 6),
          _plainDetailRow('Internal ID', details.primaryOrderId.toString()),
          const SizedBox(height: 8),
          _subtleText(
            _selected == null
                ? 'Tap Order Number / Location / Total Parts to select, then confirm.'
                : 'Selected: ${_selected!.name}',
          ),
        ],
      ),
    );
  }

  Widget _buildActionsCard(BuildContext context, String slip2Url, String slipUrl) {
    return _cupertinoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Quick Actions'),
          const SizedBox(height: 6),
          _subtleText('Open packing slips for verification and printing.'),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  color: CupertinoColors.systemGrey5,
                  onPressed: () => _openInWebView(context, slip2Url, 'Packing Slip 2', isPdf: false),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(CupertinoIcons.doc_text, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Slip (HTML)',
                        style: _noUnderline(const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: CupertinoColors.label,
                        )),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  color: CupertinoColors.activeBlue,
                  onPressed: () => _openInWebView(context, slipUrl, 'Packing Slip PDF', isPdf: true),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(CupertinoIcons.doc_on_clipboard, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Slip (PDF)',
                        style: _noUnderline(const TextStyle(
                          fontWeight: FontWeight.w800,
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
      ),
    );
  }

  Widget _tapDetailRow({
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
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 150,
              child: Text(
                label,
                style: _noUnderline(const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.secondaryLabel,
                )),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: _noUnderline(TextStyle(
                  fontSize: isLarge ? 18 : 15,
                  color: CupertinoColors.label,
                  fontWeight: isLarge ? FontWeight.w800 : FontWeight.w700,
                )),
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

  Widget _plainDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: _noUnderline(const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.secondaryLabel,
              )),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: _noUnderline(const TextStyle(
                fontSize: 15,
                color: CupertinoColors.label,
                fontWeight: FontWeight.w700,
              )),
            ),
          ),
        ],
      ),
    );
  }
}
