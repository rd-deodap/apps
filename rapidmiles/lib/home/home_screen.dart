import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rapidmiles/utils/date_utils.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import 'package:rapidmiles/common/app_drawer.dart';
import 'package:rapidmiles/common/settings.dart';
import 'package:rapidmiles/home/pickup_qr.dart';
import 'package:rapidmiles/home/second_qr.dart';
import 'package:rapidmiles/home/wallet_screen.dart';

import '../login/login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // ==========================
  // PREMIUM CREAM THEME
  // ==========================
  static const Color bg = Color(0xFFFFFBF2); // cream
  static const Color card = Colors.white;
  static const Color stroke = Color(0xFFEFE7D6);

  static const Color text = Color(0xFF0F172A); // slate-900
  static const Color muted = Color(0xFF64748B); // slate-500
  static const Color muted2 = Color(0xFF94A3B8); // slate-400

  static const Color danger = Color(0xFFB91C1C);
  static const Color primary = Color(0xFF2563EB);
  static const Color success = Color(0xFF059669);
  static const Color amber = Color(0xFFD97706);
  static const Color violet = Color(0xFF7C3AED);

  // State
  bool _loading = true;
  String? _error;

  // User
  String _name = "";
  String _email = "";
  String? _contact;

  // Stats
  int _todayDeliveries = 0;
  int _pendingOrders = 0;
  double _walletBalance = 0;
  double _outstanding = 0;

  // Time
  DateTime _now = DateTime.now();
  Timer? _ticker;

  // Location
  bool _locLoading = true;
  String? _locError;
  String _locationText = "Detecting location...";
  DateTime? _locUpdatedAt;

  // Helpers (to avoid double fetch)
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _startClock();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // show cached location instantly (better UX)
    await _loadCachedLocation();
    await Future.wait([_fetchProfile(), _fetchLocation()]);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startClock() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  // ==========================
  // PROFILE API
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
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = "Session expired. Please login again.";
        });
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
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = (body["message"] ?? "Failed to load profile").toString();
        });
        return;
      }

      final data = body["data"] as Map<String, dynamic>? ?? {};
      final user = data["user"] as Map<String, dynamic>? ?? {};
      final stats = data["stats"] as Map<String, dynamic>? ?? {};

      if (!mounted) return;
      setState(() {
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

  void _goLoginReplace() {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
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
  // LOCATION (reliable)
  // - show cached value immediately
  // - use lastKnownPosition first
  // - then current position with timeout
  // - reverse geocode with guardrails
  // ==========================
  Future<void> _loadCachedLocation() async {
    final sp = await SharedPreferences.getInstance();
    final cached = sp.getString("dash_cached_location");
    final cachedTs = sp.getString("dash_cached_location_ts");
    if (cached != null && cached.trim().isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _locationText = cached;
        _locUpdatedAt = cachedTs != null ? DateTime.tryParse(cachedTs) : null;
        _locLoading = true; // still fetching fresh
      });
    }
  }

  Future<void> _cacheLocation(String value) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString("dash_cached_location", value);
    await sp.setString(
      "dash_cached_location_ts",
      DateTime.now().toIso8601String(),
    );
  }

  Future<void> _fetchLocation() async {
    if (!mounted) return;

    setState(() {
      _locLoading = true;
      _locError = null;
      if (_locationText.trim().isEmpty) _locationText = "Detecting location...";
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw "Location services are OFF";
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw "Location permission denied";
      }
      if (permission == LocationPermission.deniedForever) {
        throw "Location permission permanently denied";
      }

      Position? pos = await Geolocator.getLastKnownPosition();

      // Always try to get fresh position (with timeout)
      try {
        final fresh = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 10),
        );
        pos = fresh;
      } catch (_) {
        // keep lastKnown if fresh fails
      }

      if (pos == null) {
        throw "Could not read GPS position";
      }

      // Reverse geocode (also guarded)
      List<Placemark> placemarks = [];
      try {
        placemarks = await placemarkFromCoordinates(
          pos.latitude,
          pos.longitude,
        ).timeout(const Duration(seconds: 8));
      } catch (_) {
        // no crash; fallback below
      }

      String finalText = "Location not found";
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;

        final city = (p.locality ?? "").trim();
        final area = (p.subLocality ?? p.subAdministrativeArea ?? p.name ?? "")
            .trim();
        final state = (p.administrativeArea ?? "").trim();
        final country = (p.country ?? "").trim();

        final parts = <String>[];
        if (area.isNotEmpty && area != city) parts.add(area);
        if (city.isNotEmpty) parts.add(city);
        if (state.isNotEmpty && state != city) parts.add(state);
        if (country.isNotEmpty) parts.add(country);

        finalText = parts.isEmpty ? "Location not found" : parts.join(", ");
      } else {
        // fallback: lat/long short (better than nothing)
        finalText =
            "Lat ${pos.latitude.toStringAsFixed(3)}, Lng ${pos.longitude.toStringAsFixed(3)}";
      }

      await _cacheLocation(finalText);

      if (!mounted) return;
      setState(() {
        _locationText = finalText;
        _locUpdatedAt = DateTime.now();
        _locLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locError = e.toString();
        _locLoading = false;
        if (_locationText.trim().isEmpty)
          _locationText = "Location unavailable";
      });
    }
  }

  // ==========================
  // GREETING
  // ==========================
  String _greeting() {
    final h = _now.hour;
    if (h >= 5 && h < 12) return "Good Morning";
    if (h >= 12 && h < 16) return "Good Afternoon";
    if (h >= 16 && h < 20) return "Good Evening";
    return "Good Night";
  }

  String _dateText() => AppDate.formatDate(_now);
  String _timeText() => AppDate.formatTime(_now, withSeconds: true);

  // ==========================
  // ACTIONS
  // ==========================
  void _openWallet() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WalletScreen()),
    );
  }

  Future<void> _refreshAll() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      await Future.wait([_fetchProfile(), _fetchLocation()]);
    } finally {
      _refreshing = false;
    }
  }

  // ==========================
  // UI
  // ==========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: card,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: text),
        title: const Text(
          "Home",
          style: TextStyle(
            color: text,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: _chipButton(
              icon: Icons.account_balance_wallet_rounded,
              label: _formatCurrency(_walletBalance),
              onTap: _openWallet,
            ),
          ),
          IconButton(
            onPressed: _refreshAll,
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
      onRefresh: _refreshAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _headerCard(),
          const SizedBox(height: 12),
          _profileCard(),
          const SizedBox(height: 14),
          _statsGrid(),
          const SizedBox(height: 16),
          _primaryActionButton(
            colors: const [Color(0xFF2563EB), Color(0xFF1E40AF)],
            icon: Icons.qr_code_scanner_rounded,
            title: "Scan Pickup QR",
            subtitle: "Start pickup process instantly",
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PickupQRScanner()),
              );
              if (result != null) _fetchProfile();
            },
          ),
          const SizedBox(height: 12),
          _primaryActionButton(
            colors: const [Color(0xFF059669), Color(0xFF047857)],
            icon: Icons.qr_code_2_rounded,
            title: "Scan Order Actions",
            subtitle: "Mark delivery / update status",
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SecondQRScanner()),
              );
              if (result != null) _fetchProfile();
            },
          ),
        ],
      ),
    );
  }

  // Top premium header (looks more “UI done” than plain row)
  Widget _headerCard() {
    final firstName = _name.trim().isNotEmpty
        ? _name.trim().split(RegExp(r"\s+")).first
        : "User";

    final isDay = _now.hour >= 6 && _now.hour < 18;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: stroke),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFFFF7E6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
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
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: text,
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: Icon(
              isDay ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${_greeting()}, $firstName",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: text,
                    fontSize: 16.8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${_dateText()} • ${_timeText()}",
                  style: const TextStyle(
                    color: muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      size: 16,
                      color: muted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _locationText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (_locLoading)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: _fetchLocation,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: stroke),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.my_location_rounded,
                                size: 16,
                                color: muted,
                              ),
                              SizedBox(width: 6),
                              Text(
                                "Update",
                                style: TextStyle(
                                  color: muted,
                                  fontSize: 12.2,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                if (_locUpdatedAt != null && _locError == null) ...[
                  const SizedBox(height: 4),
                  Text(
                    "Updated: ${AppDate.formatTime(_locUpdatedAt!, withSeconds: false)}",
                    style: const TextStyle(
                      color: muted2,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                if (_locError != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _locError!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: danger,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileCard() {
    final initials = _getInitials(_name);

    return _elevCard(
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: text,
              borderRadius: BorderRadius.circular(18),
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
                    color: text,
                    fontSize: 16.8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _email.isNotEmpty ? _email : "No email",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: muted,
                    fontSize: 13.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (_contact != null && _contact!.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    _contact!.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: muted2,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
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
          color: primary,
          bgColor: const Color(0xFFEFF6FF),
        ),
        _statTile(
          icon: Icons.pending_actions_rounded,
          label: "Pending Orders",
          value: _pendingOrders.toString(),
          color: amber,
          bgColor: const Color(0xFFFFFBEB),
        ),
        _statTile(
          icon: Icons.account_balance_wallet_rounded,
          label: "Wallet Balance",
          value: _formatCurrency(_walletBalance),
          color: _walletBalance >= 0 ? success : danger,
          bgColor: _walletBalance >= 0
              ? const Color(0xFFECFDF5)
              : const Color(0xFFFEF2F2),
        ),
        _statTile(
          icon: Icons.receipt_long_rounded,
          label: "Outstanding",
          value: _formatCurrency(_outstanding),
          color: violet,
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
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: stroke),
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
              color: muted,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryActionButton({
    required List<Color> colors,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: colors.first.withOpacity(0.22),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.18)),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16.2,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.86),
                          fontSize: 12.8,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chipButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: stroke),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: text),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: text,
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _elevCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: stroke),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }

  String _getInitials(String name) {
    final n = name.trim();
    if (n.isEmpty) return "?";
    final parts = n.split(RegExp(r"\s+")).where((e) => e.isNotEmpty).toList();
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: muted),
            const SizedBox(height: 14),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: muted,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: text,
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
}
