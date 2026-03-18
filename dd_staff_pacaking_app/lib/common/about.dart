import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AboutUsScreen extends StatefulWidget {
  const AboutUsScreen({Key? key}) : super(key: key);

  @override
  State<AboutUsScreen> createState() => _AboutUsScreenState();
}

class _AboutUsScreenState extends State<AboutUsScreen> {
  // Theme
  final Color _bluePrimary = const Color(0xFF1E5EFF);
  final Color _blueSoft = const Color(0xFFE9F0FF);
  final Color _bg = const Color(0xFFF2F6FF);

  bool isLoading = true;
  bool _hasError = false;

  String company = "";
  String website = "";
  String type = "";
  String description = "";
  String mission = "";
  List<dynamic> planOfAction = [];
  String indiaOperations = "";
  String achievement = "";
  String presence = "";
  String businessModel = "";
  Map<String, dynamic> contact = {};
  String warehouse = "";

  @override
  void initState() {
    super.initState();
    fetchAboutData();
  }

  Future<void> fetchAboutData() async {
    setState(() {
      isLoading = true;
      _hasError = false;
    });

    final url = Uri.parse(
      "https://customprint.deodap.com/common-page/about-us.php?action=get_about_us",
    );

    try {
      final response = await http.get(url);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final data = jsonData["data"] ?? {};

        setState(() {
          company = (data["company"] ?? "").toString();
          website = (data["website"] ?? "").toString();
          type = (data["type"] ?? "").toString();
          description = (data["description"] ?? "").toString();
          mission = (data["mision"] ?? "").toString();
          planOfAction = (data["plan_of_action"] ?? []) as List<dynamic>;
          indiaOperations = (data["india_operations"] ?? "").toString();
          achievement = (data["achievement"] ?? "").toString();
          presence = (data["presence"] ?? "").toString();
          businessModel = (data["business_model"] ?? "").toString();
          contact = (data["contact"] ?? {}) as Map<String, dynamic>;
          warehouse = (data["warehouse"] ?? "").toString();

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

  bool get _isAllEmpty {
    return company.isEmpty &&
        website.isEmpty &&
        type.isEmpty &&
        description.isEmpty &&
        mission.isEmpty &&
        planOfAction.isEmpty &&
        indiaOperations.isEmpty &&
        achievement.isEmpty &&
        presence.isEmpty &&
        businessModel.isEmpty &&
        (contact.isEmpty) &&
        warehouse.isEmpty;
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
                onRefresh: fetchAboutData,
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
              "About Us",
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
          const SizedBox(width: 72),
        ],
      ),
    );
  }

  Widget _buildBody() {
    // ListView so pull-to-refresh works even on short content
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      children: [
        if (_hasError) _errorCard(),
        if (!_hasError && _isAllEmpty) _emptyCard(),
        if (!_hasError && !_isAllEmpty) ...[
          _companyCard(),
          const SizedBox(height: 14),
          _sectionCard(
            title: "About Company",
            icon: Icons.apartment_rounded,
            children: [
              _para(type),
              _para(description),
            ],
          ),
          _sectionCard(
            title: "Mission",
            icon: Icons.flag_rounded,
            children: [
              _para(mission),
            ],
          ),
          if (planOfAction.isNotEmpty)
            _sectionCard(
              title: "Plan of Action",
              icon: Icons.checklist_rounded,
              children: planOfAction.map((e) => _bullet(e.toString())).toList(),
            ),
          _sectionCard(
            title: "India Operations",
            icon: Icons.public_rounded,
            children: [
              _para(indiaOperations),
            ],
          ),
          _sectionCard(
            title: "Achievement",
            icon: Icons.emoji_events_rounded,
            children: [
              _para(achievement),
            ],
          ),
          _sectionCard(
            title: "Presence",
            icon: Icons.location_on_rounded,
            children: [
              _para(presence),
            ],
          ),
          _sectionCard(
            title: "Business Model",
            icon: Icons.auto_graph_rounded,
            children: [
              _para(businessModel),
            ],
          ),
          _sectionCard(
            title: "Contact Details",
            icon: Icons.support_agent_rounded,
            children: [
              _kvRow("Address", (contact['address'] ?? "").toString(), icon: Icons.place_rounded),
              _kvRow("Phone", (contact['phone'] ?? "").toString(), icon: Icons.phone_rounded),
              _kvRow("Email", (contact['email'] ?? "").toString(), icon: Icons.mail_rounded),
              _kvRow("Support Hours", (contact['support_hours'] ?? "").toString(), icon: Icons.schedule_rounded),
            ],
          ),
          _sectionCard(
            title: "Warehouse",
            icon: Icons.warehouse_rounded,
            children: [
              _para(warehouse),
            ],
          ),
        ],
      ],
    );
  }

  // =======================
  // Cards
  // =======================

  Widget _companyCard() {
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
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _blueSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.verified_rounded, color: _bluePrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  company.isNotEmpty ? company : "Company",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  website.isNotEmpty ? website : "DeoDap",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.black.withOpacity(0.55),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    // Hide card if no meaningful children
    final visibleChildren = children.where((w) => w is! SizedBox).toList();
    if (visibleChildren.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _blueSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: _bluePrimary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: Colors.grey.shade200),
          const SizedBox(height: 10),
          ...visibleChildren,
        ],
      ),
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
                  "Unable to load About Us",
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
              onPressed: fetchAboutData,
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
            child: Icon(Icons.info_outline_rounded, color: _bluePrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "About us information not available.",
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

  // =======================
  // Typography helpers
  // =======================

  Widget _para(String text) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14.8,
          height: 1.55,
          color: Colors.black.withOpacity(0.84),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _bullet(String text) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "•  ",
            style: TextStyle(
              fontSize: 14.8,
              height: 1.55,
              color: _bluePrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14.8,
                height: 1.55,
                color: Colors.black.withOpacity(0.84),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kvRow(String label, String value, {required IconData icon}) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _blueSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _bluePrimary, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.black.withOpacity(0.55),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14.6,
                    height: 1.45,
                    color: Colors.black.withOpacity(0.84),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
