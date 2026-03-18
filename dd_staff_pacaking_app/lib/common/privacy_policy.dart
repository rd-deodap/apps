import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({Key? key}) : super(key: key);

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  // Theme
  final Color _bluePrimary = const Color(0xFF1E5EFF);
  final Color _blueSoft = const Color(0xFFE9F0FF);
  final Color _bg = const Color(0xFFF2F6FF);

  bool isLoading = true;
  bool _hasError = false;

  String content = "";
  String company = "";
  String website = "";

  @override
  void initState() {
    super.initState();
    fetchPrivacyPolicy();
  }

  Future<void> fetchPrivacyPolicy() async {
    setState(() {
      isLoading = true;
      _hasError = false;
    });

    try {
      final response = await http.get(
        Uri.parse(
          "https://customprint.deodap.com/common-page/policy.php?action=get_privacy_policy",
        ),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        setState(() {
          company = (jsonData["data"]?["company"] ?? "").toString();
          website = (jsonData["data"]?["website"] ?? "").toString();
          content = (jsonData["data"]?["content"] ?? "").toString();
          isLoading = false;
          _hasError = false;
        });
      } else {
        setState(() {
          isLoading = false;
          _hasError = true;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildIOSHeader(context),
            Expanded(
              child: isLoading
                  ? const Center(child: CupertinoActivityIndicator())
                  : RefreshIndicator(
                color: _bluePrimary,
                onRefresh: fetchPrivacyPolicy,
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIOSHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _bluePrimary,
            const Color(0xFF2A7BFF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: _bluePrimary.withOpacity(0.18),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          // iOS-style back button
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.16),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.18)),
              ),
              child: const Row(
                children: [
                  Icon(CupertinoIcons.chevron_back, size: 18, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    "Back",
                    style: TextStyle(
                      fontSize: 13.5,
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 10),

          const Expanded(
            child: Text(
              "Privacy Policy",
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
          ),

          const SizedBox(width: 72), // visual balance for back button
        ],
      ),
    );
  }

  Widget _buildBody() {
    // Use ListView so RefreshIndicator works even when content is short
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      children: [
        if (_hasError) _errorCard(),
        if (!_hasError && (content.isEmpty && company.isEmpty && website.isEmpty))
          _emptyCard(),

        if (!_hasError && (content.isNotEmpty || company.isNotEmpty || website.isNotEmpty))
          _contentCard(),
      ],
    );
  }

  Widget _errorCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _blueSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.wifi_off_rounded, color: _bluePrimary),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "Unable to load privacy policy",
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "Please check your internet connection and try again.",
            style: TextStyle(
              fontSize: 13,
              color: Colors.black.withOpacity(0.62),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: fetchPrivacyPolicy,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text(
                "Retry",
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _bluePrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _blueSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.policy_rounded, color: _bluePrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Privacy policy not available.",
              style: TextStyle(
                fontSize: 14,
                color: Colors.black.withOpacity(0.70),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contentCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _blueSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.verified_user_rounded, color: _bluePrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      company.isNotEmpty ? company : "Privacy Policy",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      website.isNotEmpty ? website : "DeoDap",
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.black.withOpacity(0.55),
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: Colors.grey.shade200),
          const SizedBox(height: 12),

          // Comfortable reading
          SelectableText(
            content.replaceAll("\\n", "\n"),
            style: TextStyle(
              fontSize: 15.5,
              height: 1.55,
              color: Colors.black.withOpacity(0.86),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
