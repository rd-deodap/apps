import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class HowItWorksScreen extends StatefulWidget {
  const HowItWorksScreen({Key? key}) : super(key: key);

  @override
  State<HowItWorksScreen> createState() => _HowItWorksScreenState();
}

class _HowItWorksScreenState extends State<HowItWorksScreen> {
  // Blue theme
  final Color primaryBlue = const Color(0xFF1E5EFF);
  final Color bg = const Color(0xFFF2F6FF); // soft bluish background

  @override
  Widget build(BuildContext context) {
    final Color cardBorder = Colors.grey.shade200;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ===== iOS-style curved header =====
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: back + title
                  Row(
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minSize: 32,
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: Container(
                          height: 36,
                          width: 36,
                          decoration: BoxDecoration(
                            color: primaryBlue.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: primaryBlue.withOpacity(0.12),
                            ),
                          ),
                          child: Icon(
                            CupertinoIcons.back,
                            color: primaryBlue,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'How the App Works',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'This app helps warehouse staff scan orders, capture packing proof, count quantity, and dispatch shipments quickly.',
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.62),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // ===== Body =====
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main card
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: cardBorder),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Packing & Dispatch – Step-by-step',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Follow this flow for every packed shipment to ensure correct scanning, proof upload, and dispatch.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black.withOpacity(0.62),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 1) Login
                          _stepHeader(
                            primaryBlue: primaryBlue,
                            icon: CupertinoIcons.person_crop_circle,
                            title: 'Step 1: Login (Employee + Warehouse)',
                          ),
                          const SizedBox(height: 6),
                          _bullet('Log in using your Employee ID and Password.'),
                          _bullet('Select your assigned warehouse from the warehouse dropdown.'),
                          _bullet('After successful login, the Home screen will open.'),
                          const SizedBox(height: 16),

                          // 2) Scan Order (QR/Barcode)
                          _stepHeader(
                            primaryBlue: primaryBlue,
                            icon: CupertinoIcons.qrcode_viewfinder,
                            title: 'Step 2: Scan Order (QR / Barcode)',
                          ),
                          const SizedBox(height: 6),
                          _bullet('Open the scanner from Home screen (Order Scan / Packing Scanner).'),
                          _bullet('Scan the order label QR code or barcode.'),
                          _bullet('After scan, order details screen will open (Order No, buyer details, amount, status, etc.).'),
                          _bullet('If wrong order is scanned, re-scan until it matches the physical label.'),
                          const SizedBox(height: 16),

                          // 3) Packing Proof Photo
                          _stepHeader(
                            primaryBlue: primaryBlue,
                            icon: CupertinoIcons.camera,
                            title: 'Step 3: Take Packing Proof Photos (Attachments)',
                          ),
                          const SizedBox(height: 6),
                          _bullet('On order details screen, tap Attachment 1 / Attachment 2.'),
                          _bullet('Choose Camera or Gallery and upload packing proof photos.'),
                          _bullet('At least one attachment is recommended for packing verification.'),
                          const SizedBox(height: 16),

                          // 4) Count Quantity / Boxes
                          _stepHeader(
                            primaryBlue: primaryBlue,
                            icon: CupertinoIcons.cube_box,
                            title: 'Step 4: Count Quantity / Boxes',
                          ),
                          const SizedBox(height: 6),
                          _bullet('Select Total Box Count (1 to 9+).'),
                          _bullet('If boxes are more than 9, choose 9+ and enter exact number.'),
                          _bullet('This ensures correct shipment package count before dispatch.'),
                          const SizedBox(height: 16),

                          // 5) Submit / Dispatch
                          _stepHeader(
                            primaryBlue: primaryBlue,
                            icon: CupertinoIcons.paperplane,
                            title: 'Step 5: Submit (Packing Completed → Ready to Dispatch)',
                          ),
                          const SizedBox(height: 6),
                          _bullet('Tap **SUBMIT** after photos and box count are selected.'),
                          _bullet('The app sends packing data to server (attachments + shipment packages count).'),
                          _bullet('After success, the order is marked packed/processed and can be dispatched.'),
                          const SizedBox(height: 18),

                          Divider(height: 24, color: Colors.grey.shade200),

                          const Text(
                            'Slip / Report Viewing (Optional)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),

                          _stepHeader(
                            primaryBlue: primaryBlue,
                            icon: CupertinoIcons.doc_text,
                            title: 'Slip 1 / Slip 2 (Packing Slip / Invoice)',
                          ),
                          const SizedBox(height: 6),
                          _bullet('There is a separate scanner option to view packing slips / reports.'),
                          _bullet('Scan QR once → choose Slip 1 or Slip 2.'),
                          _bullet('Slip 1 usually opens as PDF and Slip 2 as HTML in the in-app web view.'),
                          _bullet('The link is not shown to user; only the output is displayed inside app.'),
                          const SizedBox(height: 14),

                          _stepHeader(
                            primaryBlue: primaryBlue,
                            icon: CupertinoIcons.doc_plaintext,
                            title: 'Reports / Tracking Related View (If enabled)',
                          ),
                          const SizedBox(height: 6),
                          _bullet('Employee can scan again using report scanner to view order slip/report details.'),
                          _bullet('Useful for checking order info before dispatch and for audit verification.'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Quick summary card
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: cardBorder),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Quick Summary',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _bullet('Login → Select Warehouse'),
                          _bullet('Scan QR/Barcode → Open Order Details'),
                          _bullet('Capture packing photos (Attachment 1/2)'),
                          _bullet('Select box count / quantity'),
                          _bullet('Submit → Packing completed → Ready to dispatch'),
                          _bullet('Optional: Scan again to view Slip 1/Slip 2 or order report'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== Helper widgets =====

  static Widget _stepHeader({
    required Color primaryBlue,
    required IconData icon,
    required String title,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          height: 30,
          width: 30,
          decoration: BoxDecoration(
            color: primaryBlue.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: primaryBlue.withOpacity(0.12)),
          ),
          child: Icon(
            icon,
            size: 18,
            color: primaryBlue,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  static Widget _bullet(String text) {
    final parts = _splitBold(text);

    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(fontSize: 14, color: Colors.black.withOpacity(0.85))),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: Colors.black.withOpacity(0.88),
                  fontWeight: FontWeight.w600,
                ),
                children: parts,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static List<TextSpan> _splitBold(String text) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'\*\*(.*?)\*\*');
    int last = 0;

    for (final m in regex.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      spans.add(
        TextSpan(
          text: m.group(1),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      );
      last = m.end;
    }

    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last)));
    }
    return spans;
  }
}
