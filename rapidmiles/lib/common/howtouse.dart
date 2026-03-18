import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class HowItWorksScreen extends StatelessWidget {
  const HowItWorksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color background = Color(0xFFF2F2F7); // iOS-style light grey
    final Color cardBorder = Colors.grey.shade200;

    return Scaffold(
      backgroundColor: background,
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
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
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
                          height: 34,
                          width: 34,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            CupertinoIcons.back,
                            color: Colors.grey.shade800,
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
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 46), // balance back button width
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'CLO Packing Scanner flow for warehouse staff (Primary + Secondary order locking).',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
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
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CLO Packing Scanner – Step-by-step',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Follow this flow for every packed shipment to ensure correct scanning and locking.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 1) Login
                          _stepHeader(
                            icon: CupertinoIcons.person_crop_circle,
                            title: 'Step 1: Login (Employee + Warehouse)',
                          ),
                          const SizedBox(height: 4),
                          _bullet('Log in using your Employee ID and Password.'),
                          _bullet('Select warehouse **135** (or your assigned warehouse).'),
                          _bullet(
                            'After successful login, the Home screen will open.',
                          ),
                          const SizedBox(height: 16),

                          // 2) Open CLO Packing Scanner
                          _stepHeader(
                            icon: CupertinoIcons.house,
                            title: 'Step 2: Open CLO Packing Scanner',
                          ),
                          const SizedBox(height: 4),
                          _bullet('On the Home screen, tap **CLO Packing Scanner**.'),
                          _bullet('The scanner will open for **Primary Order Scanning**.'),
                          const SizedBox(height: 16),

                          // 3) Scan Primary Order
                          _stepHeader(
                            icon: CupertinoIcons.qrcode_viewfinder,
                            title: 'Step 3: Scan Primary Order (Primary QR)',
                          ),
                          const SizedBox(height: 4),
                          _bullet('Scan the **Primary Order QR** using the camera scanner.'),
                          _bullet(
                            'After scanning, the app will show **Primary Order Details** (e.g., order number and location).',
                          ),
                          _bullet(
                            'If the QR is incorrect or unreadable, re-scan until it matches the label.',
                          ),
                          const SizedBox(height: 16),

                          // 4) Confirm Primary Details -> open second screen
                          _stepHeader(
                            icon: CupertinoIcons.doc_text,

                            title: 'Step 4: Confirm Details & Open Secondary List',
                          ),
                          const SizedBox(height: 4),
                          _bullet(
                            'Tap anywhere on the displayed primary order details.',
                          ),
                          _bullet(
                            'Confirm when prompted. After confirmation, the **second screen** will open.',
                          ),
                          _bullet(
                            'The second screen shows: **Primary order info + Secondary order list**.',
                          ),
                          const SizedBox(height: 16),

                          // 5) Scan secondary one by one and lock
                          _stepHeader(
                            icon: CupertinoIcons.list_bullet,
                            title: 'Step 5: Scan Secondary Orders (Lock One-by-one)',
                          ),
                          const SizedBox(height: 4),
                          _bullet(
                            'On the second screen, scan each **Secondary Order QR** one by one.',
                          ),
                          _bullet(
                            'After each successful scan, that order will be **locked** and marked as **Completed**.',
                          ),
                          _bullet(
                            'If a scanned QR does **not** belong to the list, it should **not** lock any order.',
                          ),
                          _bullet(
                            'Continue scanning until **all** secondary orders are successfully locked.',
                          ),
                          const SizedBox(height: 16),

                          // 6) Done enabled only after all scanned
                          _stepHeader(
                            icon: CupertinoIcons.checkmark_seal,
                            title: 'Step 6: Done (Final Submit)',
                          ),
                          const SizedBox(height: 4),
                          _bullet(
                            'The **Done** button will remain **disabled** until all secondary orders are locked.',
                          ),
                          _bullet(
                            'Once all orders are scanned and locked, **Done** becomes active.',
                          ),
                          _bullet(
                            'Tap **Done** to mark the order as **Successfully Packed**.',
                          ),
                          const SizedBox(height: 20),

                          const Divider(height: 24),

                          // Purpose / Notes
                          const Text(
                            'Key Notes',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _bullet('Always scan **Primary** first, then scan **Secondary** orders.'),
                          _bullet('Do not proceed if location/order number looks wrong—re-scan.'),
                          _bullet('Done must be tapped only after all orders are locked.'),
                          _bullet('This ensures correct packing confirmation and prevents missing items.'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Optional mini card (quick summary)
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: cardBorder),
                      ),
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Quick Summary',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _bullet('Login (Employee ID + Password + Warehouse 135)'),
                          _bullet('Home → CLO Packing Scanner'),
                          _bullet('Scan Primary → Confirm Details'),
                          _bullet('Second Screen → Scan all Secondary → Lock each'),
                          _bullet('Done enabled → Tap Done → Packed Completed'),
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

  static Widget _stepHeader({required IconData icon, required String title}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          height: 28,
          width: 28,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.08),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            icon,
            size: 18,
            color: Colors.blueAccent,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  static Widget _bullet(String text) {
    // lightweight “bold” support via **text** without needing packages
    final parts = _splitBold(text);

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 14)),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: Colors.black,
                ),
                children: parts,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Supports **bold** segments inside bullet text (simple parser).
  static List<TextSpan> _splitBold(String text) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'\*\*(.*?)\*\*');
    int last = 0;

    for (final m in regex.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      spans.add(TextSpan(
        text: m.group(1),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ));
      last = m.end;
    }

    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last)));
    }
    return spans;
  }
}
