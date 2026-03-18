import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rapidmiles/login/login_screen.dart';
import 'package:rapidmiles/common/settings.dart';
import 'package:rapidmiles/home/my_orders_screen.dart';
import 'package:rapidmiles/home/wallet_screen.dart';
import 'package:rapidmiles/home/home_screen.dart';
import 'package:rapidmiles/home/profile_screen.dart';
class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  // =========================================================
  // STRICT THEME: White + Light Creme (NO BLACK THEME LOOK)
  // =========================================================
  static const Color _bg = Color(0xFFFFFBF2); // light creme base
  static const Color _surface = Colors.white; // cards
  static const Color _stroke = Color(0xFFEFE7D6); // soft border

  // Text colors (keep readable but not "black theme")
  static const Color _text = Color(0xFF2B2B2B); // soft charcoal (not pure black)
  static const Color _muted = Color(0xFF6B7280);
  static const Color _muted2 = Color(0xFF9CA3AF);

  // Accents (warm creme)
  static const Color _iconBg = Color(0xFFFFF1D6);
  static const Color _activeBg = Color(0xFFFFF5E6); // active tile background
  static const Color _activeStroke = Color(0xFFF3D9B5); // active border

  // Signout colors
  static const Color _danger = Color(0xFFB91C1C);
  static const Color _dangerBg = Color(0xFFFFE4E6);

  bool _loadingProfile = true;
  bool _loggingOut = false;

  String _name = "";
  String _email = "";
  String? _contact;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  // ===================== DATA =====================
  Future<void> _fetchUserData() async {
    if (!mounted) return;
    setState(() => _loadingProfile = true);

    try {
      final sp = await SharedPreferences.getInstance();
      final token = sp.getString(SessionKeys.token) ?? "";

      if (token.isEmpty) {
        if (!mounted) return;
        setState(() => _loadingProfile = false);
        return;
      }

      final res = await http.get(
        Uri.parse("https://rapidmiles.in/api/shipment/v1/profile"),
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },
      );

      if (res.statusCode == 401) {
        await _clearSession();
        if (!mounted) return;
        setState(() => _loadingProfile = false);
        return;
      }

      final decoded = json.decode(res.body);
      final body =
      (decoded is Map<String, dynamic>) ? decoded : <String, dynamic>{};

      if (body["success"] == true) {
        final data = body["data"] as Map<String, dynamic>? ?? {};
        final user = data["user"] as Map<String, dynamic>? ?? {};

        if (!mounted) return;
        setState(() {
          _name = (user["name"] ?? "").toString();
          _email = (user["email"] ?? "").toString();
          _contact = user["contact"]?.toString();
          _loadingProfile = false;
        });
      } else {
        if (!mounted) return;
        setState(() => _loadingProfile = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingProfile = false);
    }
  }

  Future<void> _clearSession() async {
    final sp = await SharedPreferences.getInstance();
    await sp.clear();
  }

  // ===================== NAV =====================
  void _navTo(Widget screen, {bool replace = false}) {
    Navigator.of(context).pop(); // close drawer first
    final route = MaterialPageRoute(builder: (_) => screen);
    if (replace) {
      Navigator.of(context).pushReplacement(route);
    } else {
      Navigator.of(context).push(route);
    }
  }

  bool _isActive(String key) {
    final current = ModalRoute.of(context)?.settings.name;
    if (current == null) return false;
    return current.contains(key);
  }

  // ===================== LOGOUT =====================
  Future<void> _logout() async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);

    try {
      final sp = await SharedPreferences.getInstance();
      final token = sp.getString(SessionKeys.token) ?? "";

      if (token.isNotEmpty) {
        final res = await http.get(
          Uri.parse("https://rapidmiles.in/api/logout"),
          headers: {
            "Authorization": "Bearer $token",
            "Accept": "application/json",
          },
        );

        if (res.statusCode != 200 && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  "Logout API failed (${res.statusCode}). Logged out locally."),
              backgroundColor: _danger,
            ),
          );
        }
      }

      await _clearSession();
      if (!mounted) return;

      Navigator.of(context).pop(); // close drawer

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
            (route) => false,
      );
    } catch (e) {
      await _clearSession();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Logout error: $e (Logged out locally)"),
          backgroundColor: _danger,
        ),
      );

      Navigator.of(context).pop();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
            (route) => false,
      );
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  Future<void> _confirmLogout() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text("Sign out"),
          content: const Text("Are you sure you want to sign out?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _danger,
                foregroundColor: Colors.white, // ✅ Sign out text white
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text("Sign out"),
            ),
          ],
        );
      },
    );

    if (result == true) await _logout();
  }


  // ===================== UI =====================
  @override
  Widget build(BuildContext context) {
    final initials = _getInitials(_name);

    return Drawer(
      width: 312,
      backgroundColor: _bg,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: _brandHeader(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _profileCard(initials),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
                children: [
                  _section("Navigation"),
                  const SizedBox(height: 8),
                  _menuCard(
                    children: [
                      _tile(
                        icon: Icons.home_rounded,
                        title: "Home",
                        subtitle: "Dashboard overview",
                        active: _isActive("Home") ||
                            _routeNameOf(const DashboardScreen())
                                .toLowerCase()
                                .contains("home"),
                        onTap: () => _navTo(const DashboardScreen(), replace: true),
                      ),
                      _divider(),
                      _tile(
                        icon: Icons.person_rounded,
                        title: "Profile",
                        subtitle: "Your account details",
                        active: _isActive("Profile"),
                        onTap: () => _navTo(const ProfileScreen()),
                      ),
                      _divider(),
                      _tile(
                        icon: Icons.inventory_2_rounded,
                        title: "My Orders",
                        subtitle: "Track your shipments",
                        active: _isActive("MyOrders") ||
                            _routeNameOf(const MyOrdersScreen())
                                .toLowerCase()
                                .contains("myorders"),
                        onTap: () => _navTo(const MyOrdersScreen()),
                      ),
                      _divider(),
                      _tile(
                        icon: Icons.account_balance_wallet_rounded,
                        title: "Wallet",
                        subtitle: "Balance & transactions",
                        active: _isActive("Wallet") ||
                            _routeNameOf(const WalletScreen())
                                .toLowerCase()
                                .contains("wallet"),
                        onTap: () => _navTo(const WalletScreen()),
                      ),
                      _divider(),
                      _tile(
                        icon: Icons.settings_rounded,
                        title: "Settings",
                        subtitle: "App preferences",
                        active: _isActive("Settings") ||
                            _routeNameOf(const SettingsScreen())
                                .toLowerCase()
                                .contains("settings"),
                        onTap: () => _navTo(const SettingsScreen()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _menuCard(
                    children: [
                      _infoRow(
                        icon: Icons.verified_rounded,
                        label: "Powered by DeoDap",
                        value: "Operations Suite",
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _signOutButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _routeNameOf(Widget w) => w.runtimeType.toString();

  // ---------- Pieces ----------
  Widget _brandHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _stroke),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset(
              "assets/images/logo2.png",
              width: 46,
              height: 46,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  "RapidMiles",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _text,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  "Shipment & delivery ops",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _muted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          // Container(
          //   width: 38,
          //   height: 38,
          //   decoration: BoxDecoration(
          //     color: _iconBg,
          //     borderRadius: BorderRadius.circular(14),
          //     border: Border.all(color: _stroke),
          //   ),
          //   // child: IconButton(
          //   //   padding: EdgeInsets.zero,
          //   //   onPressed: _fetchUserData,
          //   //   icon: const Icon(Icons.refresh_rounded,
          //   //       size: 18, color: _text),
          //   //   tooltip: "Refresh profile",
          //   // ),
          // ),
        ],
      ),
    );
  }

  Widget _profileCard(String initials) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _stroke),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: _iconBg, // creme avatar background (no dark block)
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _stroke),
            ),
            alignment: Alignment.center,
            child: _loadingProfile
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _text,
              ),
            )
                : Text(
              initials,
              style: const TextStyle(
                color: _text,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _loadingProfile
                ? const Text(
              "Loading profile...",
              style: TextStyle(
                color: _muted,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            )
                : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _name.isNotEmpty ? _name : "User",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _email.isNotEmpty ? _email : "No email",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (_contact != null && _contact!.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    _contact!.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _muted2,
                      fontSize: 12.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _iconBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _stroke),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              onPressed: () => _navTo(const SettingsScreen()),
              icon: const Icon(Icons.tune_rounded, size: 18, color: _text),
              tooltip: "Settings",
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _stroke),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(children: children),
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool active = false,
  }) {
    // NO DARK ACTIVE BACKGROUND — only creme highlight
    final Color bg = active ? _activeBg : Colors.transparent;
    final Color border = active ? _activeStroke : Colors.transparent;
    final Color titleColor = _text;
    final Color subColor = _muted;

    final Color iconBg = active ? const Color(0xFFFFE8C7) : _iconBg;
    final Color iconColor = _text;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          border: Border(
            left: BorderSide(
              color: border,
              width: active ? 3 : 0,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _stroke),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 14.8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: subColor,
                      fontSize: 12.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: active ? _text : _muted2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() => Divider(height: 1, thickness: 1, color: _stroke);

  Widget _section(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: _muted,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Divider(height: 1, thickness: 1, color: _stroke),
          ),
        ],
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF5E6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _stroke),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: _text),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 13.2,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12.2,
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

  Widget _signOutButton() {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _stroke),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _loggingOut ? null : _confirmLogout,
              icon: _loggingOut
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.logout_rounded, size: 18),
              label: Text(
                _loggingOut ? "Signing out..." : "Sign out",
                style: const TextStyle(
                  fontSize: 14.8,
                  fontWeight: FontWeight.w900,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _danger,
                side: const BorderSide(color: _danger, width: 1.2),
                backgroundColor: _dangerBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "You will be logged out from this device.",
            style: TextStyle(
              color: _muted,
              fontSize: 12.2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
