// lib/profile/profile_screen.dart
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_color.dart';

// API CONFIG
const String kApiBaseUrl = 'https://api.vacalvers.com/api-clo-packaging-app';
const String kAppId = '2';
const String kApiKey = '022782f3-c4aa-443a-9f14-7698c648a137';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true;
  String? _error;

  int? _id;
  int? _warehouseId;
  String? _code;
  String? _name;
  String? _phone;
  String? _type;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken');

      if (token == null || token.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'No session token found. Please login again.';
        });
        return;
      }

      final uri = Uri.parse('$kApiBaseUrl/auth/user');

      final req = http.Request('GET', uri)
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode({
          'app_id': kAppId,
          'api_key': kApiKey,
          'token': token,
        });

      final streamed = await req.send();
      final resp = await http.Response.fromStream(streamed);

      if (resp.statusCode != 200) {
        setState(() {
          _loading = false;
          _error = 'Server error: ${resp.statusCode}';
        });
        return;
      }

      final Map<String, dynamic> json = jsonDecode(resp.body);

      if (json['status'] != 'success') {
        setState(() {
          _loading = false;
          _error = json['message']?.toString() ?? 'Unknown error';
        });
        return;
      }

      final data = json['data'] as Map<String, dynamic>;

      setState(() {
        _id = data['id'] as int?;
        _warehouseId = data['warehouse_id'] as int?;
        _code = data['code']?.toString();
        _name = data['name']?.toString();
        _phone = data['phone']?.toString();
        _type = data['type']?.toString();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Something went wrong. Please try again.\n$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color brand = AppColors.navyblue; // main accent color
    const Color background = Color(0xFFF2F2F7); // iOS-style light grey
    final Color cardBorder = Colors.grey.shade200;

    return Scaffold(
      backgroundColor: background,
      body: CupertinoTheme(
        data: CupertinoTheme.of(context).copyWith(primaryColor: brand),
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              CupertinoSliverRefreshControl(onRefresh: _fetchProfile),

              SliverToBoxAdapter(
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
                          // Top row: back button, title, refresh
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
                                  'Profile',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                minSize: 32,
                                onPressed: _fetchProfile,
                                child: Icon(
                                  CupertinoIcons.refresh,
                                  color: Colors.grey.shade600,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Avatar
                              CircleAvatar(
                                radius: 32,
                                backgroundColor: brand.withOpacity(0.06),
                                child: Text(
                                  _initials(_name),
                                  style: TextStyle(
                                    color: brand,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 22,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Name + phone + code chip
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _name ?? 'Employee',
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    if (_phone != null && _phone!.trim().isNotEmpty)
                                      Text(
                                        _phone!,
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    if (_code != null && _code!.trim().isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: brand.withOpacity(0.06),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                            border: Border.all(
                                              color: brand.withOpacity(0.25),
                                            ),
                                          ),
                                          child: Text(
                                            'Code: ${_code!}',
                                            style: TextStyle(
                                              color: brand,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ===== Body content (cards) =====
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildBody(
                        surface: Colors.white,
                        borderColor: cardBorder,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===================== BODY / CARDS =====================

  Widget _buildBody({
    required Color surface,
    required Color borderColor,
  }) {
    if (_loading) {
      return _buildSkeleton(surface, borderColor);
    }

    if (_error != null) {
      return _buildErrorCard(surface, borderColor);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Account'),
        const SizedBox(height: 8),
        _infoCard(
          surface: surface,
          borderColor: borderColor,
          title: 'Basic Details',
          subtitle: 'Your login and identification details',
          rows: [
            _infoRow('Name', _name ?? '-'),
            _infoRow('Phone', _phone ?? '-'),
            _infoRow('Employee Code', _code ?? '-'),
            _infoRow('User ID', _id?.toString() ?? '-'),
          ],
        ),
        const SizedBox(height: 20),
        _sectionLabel('Work'),
        const SizedBox(height: 8),
        _infoCard(
          surface: surface,
          borderColor: borderColor,
          title: 'Warehouse & Role',
          subtitle: 'Your work location and permission level',
          rows: [
            _infoRow('Warehouse ID', _warehouseId?.toString() ?? '-'),
            _infoRow('Role / Type', _type ?? '-'),
          ],
        ),
      ],
    );
  }

  Widget _buildSkeleton(Color surface, Color borderColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Loading profile'),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(
              4,
              (index) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ShimmerLine(
                  widthFactor: index.isEven ? 0.9 : 0.6,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorCard(Color surface, Color borderColor) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Error',
            style: TextStyle(
              color: Colors.redAccent,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Unknown error',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 38,
            child: CupertinoButton(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
              color: Colors.redAccent,
              borderRadius: BorderRadius.circular(999),
              onPressed: _fetchProfile,
              child: const Text(
                'Retry',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.grey.shade700,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _infoCard({
    required Color surface,
    required Color borderColor,
    required String title,
    required String subtitle,
    required List<Widget> rows,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + subtitle
          Text(
            title,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 6),
          ...rows,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return 'DD';
    final parts = name.trim().split(' ');
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

/// Simple light skeleton line (no external packages)
class ShimmerLine extends StatelessWidget {
  final double widthFactor;

  const ShimmerLine({super.key, this.widthFactor = 1.0});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: 14,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}
