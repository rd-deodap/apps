import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AboutUsScreen extends StatefulWidget {
  const AboutUsScreen({super.key});

  @override
  State<AboutUsScreen> createState() => _AboutUsScreenState();
}

class _AboutUsScreenState extends State<AboutUsScreen> {
  bool isLoading = true;

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
    final url = Uri.parse(
      "https://customprint.deodap.com/common-page/about-us.php?action=get_about_us",
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final data = jsonData["data"];

        setState(() {
          company = data["company"] ?? "";
          website = data["website"] ?? "";
          type = data["type"] ?? "";
          description = data["description"] ?? "";
          mission = data["mision"] ?? "";
          planOfAction = data["plan_of_action"] ?? [];
          indiaOperations = data["india_operations"] ?? "";
          achievement = data["achievement"] ?? "";
          presence = data["presence"] ?? "";
          businessModel = data["business_model"] ?? "";
          contact = data["contact"] ?? {};
          warehouse = data["warehouse"] ?? "";
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  // ---- Reusable section widgets ----

  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget sectionText(String text) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          height: 1.4,
          color: Colors.black87,
        ),
      ),
    );
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
                  : _buildBody(),
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
              "About Us",
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(width: 40), // balance back button width
        ],
      ),
    );
  }

  Widget _buildBody() {
    // If everything is empty
    if (company.isEmpty &&
        website.isEmpty &&
        type.isEmpty &&
        description.isEmpty &&
        mission.isEmpty) {
      return const Center(
        child: Text(
          "About us information not available.",
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
            // Company + website
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
              const SizedBox(height: 12),
            ],
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Sections
            sectionTitle("About Company"),
            sectionText(type),
            sectionText(description),

            sectionTitle("Mission"),
            sectionText(mission),

            if (planOfAction.isNotEmpty) ...[
              sectionTitle("Plan of Action"),
              ...planOfAction.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    "• $e",
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.3,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
            ],

            sectionTitle("India Operations"),
            sectionText(indiaOperations),

            sectionTitle("Achievement"),
            sectionText(achievement),

            sectionTitle("Presence"),
            sectionText(presence),

            sectionTitle("Business Model"),
            sectionText(businessModel),

            sectionTitle("Contact Details"),
            sectionText("📍 Address: ${contact['address'] ?? ''}"),
            sectionText("📞 Phone: ${contact['phone'] ?? ''}"),
            sectionText("✉️ Email: ${contact['email'] ?? ''}"),
            sectionText(
              "⏱ Support Hours: ${contact['support_hours'] ?? ''}",
            ),

            sectionTitle("Warehouse"),
            sectionText(warehouse),
          ],
        ),
      ),
    );
  }
}
