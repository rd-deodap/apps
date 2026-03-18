import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class MobileScannerScreen extends StatefulWidget {
  const MobileScannerScreen({Key? key}) : super(key: key);

  @override
  State<MobileScannerScreen> createState() => _MobileScannerScreenState();
}

class _MobileScannerScreenState extends State<MobileScannerScreen> {
  bool isScannerOpen = false;
  String? scannedCode;

  void _toggleScanner() {
    setState(() {
      isScannerOpen = !isScannerOpen;
    });
  }

  void _onDetect(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String code = barcodes.first.rawValue ?? "Unknown";
      setState(() {
        scannedCode = code;
        isScannerOpen = false; // Close scanner after detecting
      });

      print("✅ Scanned code: $code");

      // 👉 same as your sendData()
      _sendData(code);
    }
  }

  void _sendData(String code) {
    // Replace with your API call
    // callAPISendQRCode();
    print("📡 Sending scanned code: $code");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Parcel Scanner"),
        actions: [
          IconButton(
            icon: Icon(isScannerOpen ? Icons.close : Icons.qr_code_scanner),
            onPressed: _toggleScanner,
          ),
        ],
      ),
      body: Column(
        children: [
          if (isScannerOpen)
            Expanded(
              child: MobileScanner(
                controller: MobileScannerController(
                  facing: CameraFacing.back,
                  torchEnabled: false,
                ),
                onDetect: _onDetect,
              ),
            )
          else
            Expanded(
              child: Center(
                child: scannedCode == null
                    ? const Text("Tap scan icon to start scanning")
                    : Text("Last scanned: $scannedCode"),
              ),
            ),
        ],
      ),
    );
  }
}