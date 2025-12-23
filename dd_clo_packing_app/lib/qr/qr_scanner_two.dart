import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:webview_flutter/webview_flutter.dart';
// IMPORT THIS: New package for instant PDF
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class SipScannerScreen extends StatefulWidget {
  const SipScannerScreen({super.key});

  @override
  State<SipScannerScreen> createState() => _OrderScannerScreenState();
}

class _OrderScannerScreenState extends State<SipScannerScreen> {
  MobileScannerController scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    formats: [BarcodeFormat.qrCode],
  );

  bool _isScanning = true;
  String? _lastScannedHash;

  // URL setup
  final String _slipBaseUrl = "https://support.vacalvers.com/global_services/print";

  // --- Open Slip ---
  void _openSlipInWebView(String url, String title, {bool isPdf = false}) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => SlipViewerScreen(
          url: url,
          title: title,
          isPdf: isPdf,
        ),
      ),
    ).then((_) {
      _resumeScanning();
    });
  }

  // --- Slip Selection Dialog ---
  void _showSlipSelectionDialog(String orderHash) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return CupertinoActionSheet(
          title: const Text(
            'Select Packing Slip',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          message: Text(
            'Order Hash: $orderHash',
            style: const TextStyle(fontSize: 14, color: CupertinoColors.systemGrey),
          ),
          actions: <CupertinoActionSheetAction>[
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(context).pop();
                final url = '$_slipBaseUrl/order_packing_slip/$orderHash';
                // Slip 1 is marked as PDF
                _openSlipInWebView(url, 'Packing Slip 1', isPdf: true);
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.doc_text, color: CupertinoColors.activeBlue),
                  SizedBox(width: 8),
                  Text('Slip 1 (PDF)'),
                ],
              ),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(context).pop();
                final url = '$_slipBaseUrl/order_packing_slip_2/$orderHash';
                // Slip 2 is marked as Web
                _openSlipInWebView(url, 'Packing Slip 2', isPdf: false);
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.doc_text_fill, color: CupertinoColors.activeOrange),
                  SizedBox(width: 8),
                  Text('Slip 2'),
                ],
              ),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(context).pop();
              _resumeScanning();
            },
            child: const Text('Cancel'),
          ),
        );
      },
    );
  }

  // --- Scanning Control Functions ---
  void _stopScanning() {
    if (_isScanning) {
      scannerController.stop();
      setState(() {
        _isScanning = false;
      });
    }
  }

  void _resumeScanning() {
    if (!_isScanning) {
      setState(() {
        _lastScannedHash = null;
      });
      scannerController.start();
      setState(() {
        _isScanning = true;
      });
    }
  }

  @override
  void dispose() {
    scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('QR Order Scanner'),
        backgroundColor: CupertinoColors.systemBackground,
        border: Border(
          bottom: BorderSide(
            color: CupertinoColors.separator,
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            // Full Screen Scanner
            MobileScanner(
              controller: scannerController,
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                if (barcodes.isNotEmpty && _isScanning) {
                  final String? code = barcodes.first.rawValue;
                  if (code != null && code.isNotEmpty) {
                    _stopScanning();
                    setState(() {
                      _lastScannedHash = code;
                    });
                    _showSlipSelectionDialog(code);
                  }
                }
              },
            ),

            // Scanner Overlay
            Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.75,
                height: MediaQuery.of(context).size.width * 0.75,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: CupertinoColors.white.withOpacity(0.8),
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Stack(
                  children: [
                    Positioned(top: -2, left: -2, child: _buildCornerBracket(true, true)),
                    Positioned(top: -2, right: -2, child: _buildCornerBracket(true, false)),
                    Positioned(bottom: -2, left: -2, child: _buildCornerBracket(false, true)),
                    Positioned(bottom: -2, right: -2, child: _buildCornerBracket(false, false)),
                  ],
                ),
              ),
            ),

            // Top Instructions
            Positioned(
              top: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: CupertinoColors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Scan Order QR Code',
                    style: TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Status Card
            if (_lastScannedHash != null && !_isScanning)
              Positioned(
                bottom: 40,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemBackground.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: CupertinoColors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: _buildStatusContent(),
                ),
              ),

            // Flash Toggle Button
            Positioned(
              top: 100,
              right: 20,
              child: GestureDetector(
                onTap: () {
                  scannerController.toggleTorch();
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: CupertinoColors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.bolt_fill,
                    color: CupertinoColors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCornerBracket(bool isTop, bool isLeft) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        border: Border(
          top: isTop ? const BorderSide(color: CupertinoColors.systemBlue, width: 4) : BorderSide.none,
          left: isLeft ? const BorderSide(color: CupertinoColors.systemBlue, width: 4) : BorderSide.none,
          bottom: !isTop ? const BorderSide(color: CupertinoColors.systemBlue, width: 4) : BorderSide.none,
          right: !isLeft ? const BorderSide(color: CupertinoColors.systemBlue, width: 4) : BorderSide.none,
        ),
        borderRadius: BorderRadius.only(
          topLeft: isTop && isLeft ? const Radius.circular(20) : Radius.zero,
          topRight: isTop && !isLeft ? const Radius.circular(20) : Radius.zero,
          bottomLeft: !isTop && isLeft ? const Radius.circular(20) : Radius.zero,
          bottomRight: !isTop && !isLeft ? const Radius.circular(20) : Radius.zero,
        ),
      ),
    );
  }

  Widget _buildStatusContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          CupertinoIcons.checkmark_circle_fill,
          color: CupertinoColors.systemGreen,
          size: 48,
        ),
        const SizedBox(height: 12),
        const Text(
          'QR Code Scanned',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: CupertinoColors.label,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _lastScannedHash!,
          style: const TextStyle(
            fontSize: 13,
            color: CupertinoColors.secondaryLabel,
            decoration: TextDecoration.none,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 16),
        CupertinoButton.filled(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          onPressed: _resumeScanning,
          child: const Text(
            'Scan Next Order',
            style: TextStyle(decoration: TextDecoration.none),
          ),
        ),
      ],
    );
  }
}

// =========================================================
// SLIP VIEWER SCREEN (UPDATED FOR INSTANT PDF)
// =========================================================

class SlipViewerScreen extends StatefulWidget {
  final String url;
  final String title;
  final bool isPdf;

  const SlipViewerScreen({
    super.key,
    required this.url,
    required this.title,
    this.isPdf = false,
  });

  @override
  State<SlipViewerScreen> createState() => _SlipViewerScreenState();
}

class _SlipViewerScreenState extends State<SlipViewerScreen> {
  // WebView Controller (Only used if NOT PDF)
  WebViewController? _webViewController;

  // PDF Controller
  final PdfViewerController _pdfViewerController = PdfViewerController();

  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();

    // Setup logic based on Type
    if (!widget.isPdf) {
      // 1. Setup WebView for standard web pages
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (_) => setState(() { _isLoading = true; _error = null; }),
            onPageFinished: (_) => setState(() => _isLoading = false),
            onWebResourceError: (error) => setState(() {
              _isLoading = false;
              _error = 'Failed to load web page: ${error.description}';
            }),
          ),
        )
        ..loadRequest(Uri.parse(widget.url));
    } else {
      // 2. For PDF, we don't need init setup here, SfPdfViewer handles it in build
      // Just resetting state
      _isLoading = true;
      _error = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(widget.title),
        backgroundColor: CupertinoColors.systemBackground,
        border: const Border(
          bottom: BorderSide(
            color: CupertinoColors.separator,
            width: 0.5,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Refresh Button
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                setState(() { _error = null; _isLoading = true; });
                if (widget.isPdf) {
                  // Reload logic is handled by rebuilding the widget usually,
                  // or creating a new key, but simply set state to clear error works
                } else {
                  _webViewController?.reload();
                }
              },
              child: const Icon(CupertinoIcons.refresh, size: 24),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            // --- MAIN CONTENT ---
            if (widget.isPdf)
            // INSTANT PDF VIEWER (Native)
              SfPdfViewer.network(
                widget.url,
                controller: _pdfViewerController,
                onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                  setState(() {
                    _isLoading = false;
                  });
                },
                onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
                  setState(() {
                    _isLoading = false;
                    _error = "PDF Error: ${details.error}";
                  });
                },
              )
            else
            // WEBVIEW (For non-PDFs)
              WebViewWidget(controller: _webViewController!),

            // --- LOADING INDICATOR ---
            if (_isLoading)
              const Center(
                child: CupertinoActivityIndicator(radius: 16),
              ),

            // --- ERROR VIEW ---
            if (_error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemBackground,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: CupertinoColors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          CupertinoIcons.exclamationmark_circle,
                          color: CupertinoColors.systemRed,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          style: const TextStyle(
                            color: CupertinoColors.systemRed,
                            fontSize: 15,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        CupertinoButton.filled(
                          onPressed: () {
                            setState(() {
                              _error = null;
                              _isLoading = true;
                            });
                            if (widget.isPdf) {
                              // Rebuilds the widget
                            } else {
                              _webViewController?.reload();
                            }
                          },
                          child: const Text('Retry'),
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