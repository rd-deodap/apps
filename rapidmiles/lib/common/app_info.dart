import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class HowItWorksScreen extends StatelessWidget {
  const HowItWorksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ===== Light cream theme =====
    const Color background = Color(0xFFFFF7E6); // soft cream
    const Color card = Color(0xFFFFFFFF);
    const Color accent = Color(0xFFB9782F); // warm caramel accent
    const Color accentSoft = Color(0x1AB9782F); // 10% opacity-ish
    final Color cardBorder = Colors.brown.withOpacity(0.10);

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
                color: card,
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
                            color: Colors.brown.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            CupertinoIcons.back,
                            color: Colors.brown.shade800,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'How RapidMiles Works',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 46), // balance back button width
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'RapidMiles helps you complete pickup confirmations fast and accurately. Follow the steps below for every shipment so each order is scanned, verified, and locked before final submission.',
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.65),
                      fontSize: 13,
                      height: 1.35,
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
                        color: card,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: cardBorder),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
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
                            'RapidMiles Pickup Confirmation Flow',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Use this flow for every pickup to avoid missed items and wrong confirmations.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black.withOpacity(0.60),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Step 1
                          _stepHeader(
                            icon: CupertinoIcons.person_crop_circle,
                            title: 'Step 1: Sign In',
                            accent: accent,
                            accentSoft: accentSoft,
                          ),
                          const SizedBox(height: 4),
                          _bullet('Log in using your **Email ID** and **Password**.'),
                          _bullet('After successful login, the **Home** screen will open.'),
                          const SizedBox(height: 16),

                          // Step 2
                          _stepHeader(
                            icon: CupertinoIcons.house,
                            title: 'Step 2: Open Pickup Scanner',
                            accent: accent,
                            accentSoft: accentSoft,
                          ),
                          const SizedBox(height: 4),
                          _bullet('From **Home**, open **Scan Pickup QR**.'),
                          _bullet('The camera scanner will open and wait for an **AWB QR**.'),
                          const SizedBox(height: 16),

                          // Step 3
                          _stepHeader(
                            icon: CupertinoIcons.qrcode_viewfinder,
                            title: 'Step 3: Select Action and Scan AWB',
                            accent: accent,
                            accentSoft: accentSoft,
                          ),
                          const SizedBox(height: 4),
                          _bullet('Select the action: **Deliver**, **NDR**, **Retry**, or **RTO**.'),
                          _bullet('Scan the **AWB QR code** on the pickup label.'),
                          _bullet(
                            '**Deliver**: If COD, enter the **collectable amount** (when asked), then scan.',
                          ),
                          _bullet('**NDR** and **Retry**: No collectable amount is required.'),
                          _bullet(
                            '**Retry**: Use when the first scan failed or you need to change the selected action.',
                          ),
                          _bullet(
                            '**RTO**: Select the **RTO reason**, then scan the AWB QR again.',
                          ),
                          const SizedBox(height: 16),

                          // Step 4
                          _stepHeader(
                            icon: CupertinoIcons.doc_text,
                            title: 'Step 4: Verify Order Details',
                            accent: accent,
                            accentSoft: accentSoft,
                          ),
                          const SizedBox(height: 4),
                          _bullet('After scanning, the app shows the **order details** for verification.'),
                          _bullet(
                            'Confirm all details (AWB, customer, address, COD amount) are correct.',
                          ),
                          _bullet(
                            'If anything looks wrong, **do not continue**. Go back and **re-scan** the AWB.',
                          ),
                          _bullet(
                            'After confirmation, the next screen opens with **all linked orders** under that AWB.',
                          ),
                          const SizedBox(height: 16),

                          // Step 5
                          _stepHeader(
                            icon: CupertinoIcons.list_bullet,
                            title: 'Step 5: Scan and Lock All Linked Orders',
                            accent: accent,
                            accentSoft: accentSoft,
                          ),
                          const SizedBox(height: 4),
                          _bullet(
                            'On the linked orders screen, scan each **Order QR** one by one.',
                          ),
                          _bullet(
                            'After every successful scan, that order becomes **Locked** and marked as **Completed**.',
                          ),
                          _bullet(
                            'If any order fails to lock, scan that order again until it is locked.',
                          ),
                          _bullet(
                            'Continue until **all linked orders** show **Completed**.',
                          ),
                          const SizedBox(height: 16),

                          // Step 6
                          _stepHeader(
                            icon: CupertinoIcons.checkmark_seal,
                            title: 'Step 6: Final Submit (Done)',
                            accent: accent,
                            accentSoft: accentSoft,
                          ),
                          const SizedBox(height: 4),
                          _bullet(
                            'The **Done** button stays **disabled** until all linked orders are locked.',
                          ),
                          _bullet('Once everything is locked, **Done** becomes active.'),
                          _bullet('Tap **Done** to mark the shipment as **Packed Successfully**.'),
                          const SizedBox(height: 18),

                          const Divider(height: 24),

                          // Key Notes
                          const Text(
                            'Key Notes',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _bullet('Always scan **AWB first**, then scan **all linked orders**.'),
                          _bullet('Never submit if details look wrong—**re-scan** immediately.'),
                          _bullet('Tap **Done** only when every linked order is **Completed**.'),
                          _bullet('This prevents missing items and incorrect pickup confirmations.'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Quick Summary card
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: card,
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
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _bullet('Sign in'),
                          _bullet('Home → **Scan Pickup QR**'),
                          _bullet('Select action → Scan **AWB QR**'),
                          _bullet('Verify details → Open linked orders'),
                          _bullet('Scan each linked order → **Lock** all'),
                          _bullet('Done enabled → Tap **Done** → Packed'),
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
    required IconData icon,
    required String title,
    required Color accent,
    required Color accentSoft,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          height: 28,
          width: 28,
          decoration: BoxDecoration(
            color: accentSoft,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            icon,
            size: 18,
            color: accent,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  static Widget _bullet(String text) {
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
      spans.add(
        TextSpan(
          text: m.group(1),
          style: const TextStyle(fontWeight: FontWeight.w800),
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
