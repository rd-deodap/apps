import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../login/login_screen.dart';
import 'package:rapidmiles/common/settings.dart'; // SessionKeys
import 'package:rapidmiles/common/app_drawer.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // ==========================
  // THEME (same as dashboard)
  // ==========================
  static const Color _bg = Color(0xFFFFFBF2);
  static const Color _card = Colors.white;
  static const Color _stroke = Color(0xFFEFE7D6);

  static const Color _text = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _muted2 = Color(0xFF94A3B8);

  static const Color _danger = Color(0xFFB91C1C);
  static const Color _primary = Color(0xFF2563EB);
  static const Color _success = Color(0xFF059669);
  static const Color _amber = Color(0xFFD97706);
  static const Color _violet = Color(0xFF7C3AED);

  bool _loading = true;
  String? _error;

  // profile
  int _id = 0;
  String _name = "";
  String _email = "";
  String? _contact;

  // stats
  int _todayDeliveries = 0;
  int _pendingOrders = 0;
  double _walletBalance = 0;
  double _outstanding = 0;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  // ==========================
  // API
  // ==========================
  Future<void> _fetchProfile() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final sp = await SharedPreferences.getInstance();
      final token = sp.getString(SessionKeys.token) ?? "";

      if (token.isEmpty) {
        _goLoginReplace();
        return;
      }

      final res = await http.get(
        Uri.parse("https://rapidmiles.in/api/shipment/v1/profile"),
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },
      );

      final decoded = json.decode(res.body);
      final body = (decoded is Map<String, dynamic>)
          ? decoded
          : <String, dynamic>{};

      if (body["success"] != true) {
        setState(() {
          _loading = false;
          _error = (body["message"] ?? "Failed to load profile").toString();
        });
        return;
      }

      final data = body["data"] as Map<String, dynamic>? ?? {};
      final user = data["user"] as Map<String, dynamic>? ?? {};
      final stats = data["stats"] as Map<String, dynamic>? ?? {};

      setState(() {
        _id = _toInt(user["id"]);
        _name = (user["name"] ?? "").toString();
        _email = (user["email"] ?? "").toString();
        _contact = user["contact"]?.toString();

        _todayDeliveries = _toInt(stats["today_deliveries"]);
        _pendingOrders = _toInt(stats["pending_orders"]);
        _walletBalance = _toDouble(stats["wallet_balance"]);
        _outstanding = _toDouble(stats["outstanding"]);

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Something went wrong: ${e.toString()}";
      });
    }
  }

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  double _toDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  String _formatCurrency(double value) {
    final abs = value.abs();
    final formatted = abs == abs.toInt().toDouble()
        ? abs.toInt().toString()
        : abs.toStringAsFixed(2);
    return "${value < 0 ? "-" : ""}₹$formatted";
  }

  // ==========================
  // LOGOUT
  // ==========================
  Future<void> _logout() async {
    final sp = await SharedPreferences.getInstance();
    await sp.clear();

    if (!mounted) return;
    _goLoginReplace();
  }

  void _goLoginReplace() {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
          (_) => false,
    );
  }

  // ==========================
  // UI
  // ==========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: _card,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: _text),
        title: const Text(
          "Profile",
          style: TextStyle(
            color: _text,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _fetchProfile,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: "Refresh",
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) return _errorView();

    return RefreshIndicator(
      onRefresh: _fetchProfile,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _profileHeaderCard(),
          const SizedBox(height: 12),
          _statsGrid(),
          const SizedBox(height: 14),
          _accountSection(),
          const SizedBox(height: 14),
          _dangerSection(),
        ],
      ),
    );
  }

  Widget _profileHeaderCard() {
    final initials = _getInitials(_name);

    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _stroke),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: _text,
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _name.isNotEmpty ? _name : "User",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _email.isNotEmpty ? _email : "No email",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 13.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _pill(
                      icon: Icons.badge_rounded,
                      text: "ID: $_id",
                    ),
                    const SizedBox(width: 8),
                    if (_contact != null && _contact!.trim().isNotEmpty)
                      Expanded(
                        child: _pill(
                          icon: Icons.call_rounded,
                          text: _contact!.trim(),
                          expand: true,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill({
    required IconData icon,
    required String text,
    bool expand = false,
  }) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _stroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _muted),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _muted,
                fontSize: 12.3,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );

    if (!expand) return child;
    return Row(children: [Expanded(child: child)]);
  }

  Widget _statsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.55,
      children: [
        _statTile(
          icon: Icons.local_shipping_rounded,
          label: "Today Deliveries",
          value: _todayDeliveries.toString(),
          color: _primary,
          bgColor: const Color(0xFFEFF6FF),
        ),
        _statTile(
          icon: Icons.pending_actions_rounded,
          label: "Pending Orders",
          value: _pendingOrders.toString(),
          color: _amber,
          bgColor: const Color(0xFFFFFBEB),
        ),
        _statTile(
          icon: Icons.account_balance_wallet_rounded,
          label: "Wallet Balance",
          value: _formatCurrency(_walletBalance),
          color: _walletBalance >= 0 ? _success : _danger,
          bgColor: _walletBalance >= 0
              ? const Color(0xFFECFDF5)
              : const Color(0xFFFEF2F2),
        ),
        _statTile(
          icon: Icons.receipt_long_rounded,
          label: "Outstanding",
          value: _formatCurrency(_outstanding),
          color: _violet,
          bgColor: const Color(0xFFF5F3FF),
        ),
      ],
    );
  }

  Widget _statTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _stroke),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: _muted,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _accountSection() {
    return _sectionCard(
      title: "Account",
      children: [
        _rowItem(
          icon: Icons.person_rounded,
          title: "Name",
          subtitle: _name.isNotEmpty ? _name : "-",
        ),
        _divider(),
        _rowItem(
          icon: Icons.email_rounded,
          title: "Email",
          subtitle: _email.isNotEmpty ? _email : "-",
        ),
        _divider(),
        _rowItem(
          icon: Icons.call_rounded,
          title: "Contact",
          subtitle:
          (_contact != null && _contact!.trim().isNotEmpty) ? _contact! : "-",
        ),
      ],
    );
  }

  Widget _dangerSection() {
    return _sectionCard(
      title: "Security",
      children: [
        _dangerButton(
          icon: Icons.logout_rounded,
          title: "Logout",
          subtitle: "Sign out from this device",
          onTap: _logout,
        ),
      ],
    );
  }

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _stroke),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _text,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _rowItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _stroke),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: _muted),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 12.2,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _text,
                  fontSize: 14.2,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dangerButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 18, color: _danger),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: _danger,
                          fontSize: 14.2,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: _danger,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: _danger, size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _divider() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Container(height: 1, color: _stroke),
  );

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: _muted),
            const SizedBox(height: 14),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _muted,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: _text,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text("Try Again"),
            ),
          ],
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final n = name.trim();
    if (n.isEmpty) return "?";
    final parts = n.split(RegExp(r"\s+")).where((e) => e.isNotEmpty).toList();
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}
