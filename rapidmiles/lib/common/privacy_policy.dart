import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  bool isLoading = true;
  String content = "";
  String company = "";
  String website = "";

  @override
  void initState() {
    super.initState();
    fetchPrivacyPolicy();
  }

  Future<void> fetchPrivacyPolicy() async {
    try {
      final response = await http.get(
        Uri.parse(
          "https://customprint.deodap.com/common-page/policy.php?action=get_privacy_policy",
        ),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        setState(() {
          company = jsonData["data"]["company"] ?? "";
          website = jsonData["data"]["website"] ?? "";
          content = jsonData["data"]["content"] ?? "";
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // iOS-style light grey background
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Column(
          children: [
            _buildIOSHeader(context),
            const Divider(height: 0, thickness: 0.4),
            Expanded(
              child: isLoading
                  ? const Center(child: CupertinoActivityIndicator())
                  : _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIOSHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        // slight curved bottom like iOS large title area
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 8,
            offset: Offset(0, 2),
            color: Colors.black12,
          ),
        ],
      ),
      child: Row(
        children: [
          // iOS-style back button
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 32,
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Row(
              children: [
                Icon(
                  CupertinoIcons.back,
                  size: 22,
                  color: Colors.black87,
                ),
                SizedBox(width: 2),
                Text(
                  "Back",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              "Privacy Policy",
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(width: 40), // balance the back button width visually
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (content.isEmpty && company.isEmpty && website.isEmpty) {
      return const Center(
        child: Text(
          "Privacy policy not available.",
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              blurRadius: 10,
              offset: Offset(0, 4),
              color: Colors.black12,
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (company.isNotEmpty) ...[
              Text(
                company,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
            ],
            if (website.isNotEmpty) ...[
              Text(
                website,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
            ],
            const Divider(height: 1),
            const SizedBox(height: 12),
            // iOS feel: slightly larger text, comfortable line-height
            SelectableText(
              content.replaceAll("\\n", "\n"),
              style: const TextStyle(
                fontSize: 16,
                height: 1.5,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
