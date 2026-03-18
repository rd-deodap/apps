// home_page.dart
//
// ✅ Changes done (as requested):
// 1) Drawer: current time/date REMOVED
// 2) Drawer: Good wish + Username shown
// 3) Drawer: Live location (Lat/Lng + optional address) with refresh
// 4) Home: Order Details card tap -> DIRECT scanner open in OrderSlipDetailsScreen
// 5) Premium UI + iOS-feel maintained
// 6) Existing logic kept: willPop, saveSetting, dialogSetting, callAPILogOut, updateData
// 7) Scanner uses MobileScanner with QR/Barcode mode filter
//
// REQUIRED PACKAGES:
// - mobile_scanner
// - image_picker
// - intl
// - get_storage
// - geolocator  (add)
// - geocoding   (optional but recommended for address)
//
// pubspec.yaml:
// dependencies:
//   geolocator: ^10.1.0
//   geocoding: ^2.1.1
//
// NOTE:
// Ensure your Routes.dart includes:
// - Routes.orderScreenRoute
// - Routes.orderDetailRoute
// - Routes.settingsRoute
// - Routes.profileRoute
// - Routes.HowToUseRoute (as per your project usage)
// - Routes.loginRoute

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:deodap/pages/auth/LogoutVO.dart';
import 'package:deodap/widgets/extensions.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart' hide Response, FormData;
import 'package:get_storage/get_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

// ✅ Location
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../../commonmodule/appConstant.dart';
import '../../commonmodule/appString.dart';
import '../../utils/routes.dart';
import '../../widgets/all_widget.dart';
import '../auth/LoginVo.dart';
import '../splash/DeviceConfigVO.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // -----------------------------
  // Storage / Models
  // -----------------------------
  final GetStorage storage = GetStorage();
  DeviceConfigVO? deviceConfigVO;
  LoginVo? loginVo;
  LogoutVO? logoutVO;

  // -----------------------------
  // Existing Vars (keep)
  // -----------------------------
  String _scanBarcode = 'Unknown';
  bool back = false;
  int time = 0;
  int duration = 1000;
  bool _switchValueNotification = false; // true => QR, false => Barcode

  // -----------------------------
  // Drawer Profile Image
  // -----------------------------
  static const String _kDrawerProfileImagePath = "drawer_profile_image_path";
  final ImagePicker _picker = ImagePicker();
  String? _profileImagePath;

  // -----------------------------
  // Home Clock (keep on home)
  // -----------------------------
  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  // -----------------------------
  // Live Location (Drawer)
  // -----------------------------
  bool _locLoading = false;
  String _locText = "Location: -";
  String _locSubText = "Tap refresh to fetch";

  // =========================================================
  // THEME / STYLES
  // =========================================================
  Color get _bluePrimary => const Color(0xFF1E5EFF);
  Color get _blue2 => const Color(0xFF2A7BFF);
  Color get _violet => const Color(0xFF6D5DF6);
  Color get _teal => const Color(0xFF14B8A6);
  Color get _orange => const Color(0xFFFF8A3D);

  Color get _blueSoft => const Color(0xFFE9F0FF);
  Color get _violetSoft => const Color(0xFFEDEBFF);
  Color get _tealSoft => const Color(0xFFE6FFFB);
  Color get _orangeSoft => const Color(0xFFFFF1E7);

  Color get _textDark => const Color(0xFF101828);
  Color get _muted => const Color(0xFF667085);

  TextStyle get _h1 => const TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.2,
  );

  TextStyle get _h2 => const TextStyle(
    fontSize: 14.5,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.2,
  );

  TextStyle get _body => const TextStyle(
    fontSize: 12.8,
    fontWeight: FontWeight.w700,
  );

  String _formatTime(DateTime dt) => DateFormat("hh:mm:ss a").format(dt);
  String _formatDate(DateTime dt) => DateFormat("EEE, dd MMM yyyy").format(dt);

  String _safeUserName() {
    final n = (loginVo?.data?.user?.name ?? "").toString().trim();
    return n.isEmpty ? "User" : n;
  }

  String _safeEmpCode() => (loginVo?.data?.user?.code ?? "-").toString();
  String _safePhone() => (loginVo?.data?.user?.phone ?? "-").toString();

  // Greeting for drawer
  String _goodWish() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    if (hour < 21) return "Good Evening";
    return "Good Night";
  }

  // Profile avatar fallback initials
  String _initialsFromName(String name) {
    final parts =
    name.trim().split(RegExp(r"\s+")).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return "U";
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  ImageProvider? _drawerAvatarProvider() {
    if (_profileImagePath == null) return null;
    final f = File(_profileImagePath!);
    if (!f.existsSync()) return null;
    return FileImage(f);
  }

  Future<void> _pickDrawerProfileImage() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (file == null) return;

      setState(() => _profileImagePath = file.path);
      storage.write(_kDrawerProfileImagePath, file.path);
    } catch (_) {
      toastError("Failed to pick image");
    }
  }

  Future<void> _removeDrawerProfileImage() async {
    setState(() => _profileImagePath = null);
    storage.remove(_kDrawerProfileImagePath);
  }

  // =========================================================
  // LIVE LOCATION
  // =========================================================
  Future<void> _refreshLocation() async {
    if (_locLoading) return;

    setState(() {
      _locLoading = true;
      _locText = "Fetching location...";
      _locSubText = "Please allow permission if asked";
    });

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        setState(() {
          _locLoading = false;
          _locText = "Location service is OFF";
          _locSubText = "Turn ON GPS and try again";
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        setState(() {
          _locLoading = false;
          _locText = "Permission denied";
          _locSubText = "Allow location permission to show live location";
        });
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locLoading = false;
          _locText = "Permission denied forever";
          _locSubText = "Enable permission from Settings";
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 12),
      );

      String addr = "";
      try {
        final placemarks =
        await placemarkFromCoordinates(pos.latitude, pos.longitude);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final parts = <String>[
            if ((p.locality ?? "").trim().isNotEmpty) p.locality!.trim(),
            if ((p.administrativeArea ?? "").trim().isNotEmpty)
              p.administrativeArea!.trim(),
            if ((p.postalCode ?? "").trim().isNotEmpty) p.postalCode!.trim(),
          ];
          addr = parts.join(", ");
        }
      } catch (_) {
        // reverse geocode optional
      }

      setState(() {
        _locLoading = false;
        _locText =
        "Lat: ${pos.latitude.toStringAsFixed(6)}  •  Lng: ${pos.longitude.toStringAsFixed(6)}";
        _locSubText = addr.isEmpty ? "Updated just now" : addr;
      });
    } catch (e) {
      setState(() {
        _locLoading = false;
        _locText = "Failed to fetch location";
        _locSubText = e.toString();
      });
    }
  }

  // =========================================================
  // LIFECYCLE
  // =========================================================
  @override
  void initState() {
    super.initState();

    loginVo = LoginVo.fromJson(storage.read(AppConstant.PREF_APP_INFO_LOGIN));

    // Load saved drawer profile image path
    _profileImagePath = storage.read(_kDrawerProfileImagePath);

    // Existing: Load setting (QR/Barcode switch)
    check().then((internet) {
      if (internet != null && internet) {
        _switchValueNotification =
            storage.read(AppConstant.PREF_SETTTING_QR) ?? false;
        setState(() {});
      } else {
        toastError(AppString.no_internet);
      }
    });

    // Home live clock update (every second)
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });

    // Optional: auto fetch location once on open
    _refreshLocation();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  // =========================================================
  // REUSABLE UI WIDGETS
  // =========================================================
  Widget _pill(String text,
      {required Color bg, required Color fg, IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: TextStyle(
              color: fg,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tileCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: gradient.first.withOpacity(0.18),
                blurRadius: 18,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.22)),
                ),
                child: Icon(icon, color: Colors.white, size: 30),
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
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.92),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(999),
                        border:
                        Border.all(color: Colors.white.withOpacity(0.18)),
                      ),
                      child: const Text(
                        "Tap to open",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withOpacity(0.95), size: 16),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // DRAWER
  // =========================================================
  Drawer _buildDrawer() {
    final avatarProvider = _drawerAvatarProvider();
    final name = _safeUserName();
    final emp = _safeEmpCode();
    final phone = _safePhone();

    return Drawer(
      width: Get.width * 0.82,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(22),
          bottomRight: Radius.circular(22),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header (curved + colorful)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_bluePrimary, _blue2, _violet],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius:
                const BorderRadius.only(topRight: Radius.circular(22)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(12),
                          border:
                          Border.all(color: Colors.white.withOpacity(0.18)),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.inventory_2_rounded,
                                color: Colors.white, size: 18),
                            SizedBox(width: 6),
                            Text(
                              "DeoDap",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Get.back(),
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ✅ Good wish + username
                  Text(
                    "${_goodWish()},",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.92),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 0.2,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: _pickDrawerProfileImage,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.white.withOpacity(0.20),
                              backgroundImage: avatarProvider,
                              child: avatarProvider == null
                                  ? Text(
                                _initialsFromName(name),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              )
                                  : null,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.edit_rounded,
                                    size: 14, color: _bluePrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _pill(
                              "Emp: $emp",
                              bg: Colors.white.withOpacity(0.16),
                              fg: Colors.white,
                              icon: Icons.badge_outlined,
                            ),
                            _pill(
                              phone.trim().isEmpty ? "No: -" : "No: $phone",
                              bg: Colors.white.withOpacity(0.16),
                              fg: Colors.white,
                              icon: Icons.phone_in_talk_outlined,
                            ),
                          ],
                        ),
                      ),
                      if (_profileImagePath != null)
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert_rounded,
                              color: Colors.white),
                          onSelected: (v) {
                            if (v == "remove") _removeDrawerProfileImage();
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: "remove",
                              child: Text("Remove profile image"),
                            ),
                          ],
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ✅ Live Location card (drawer)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.18)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_rounded,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _locText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12.8,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _locSubText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.92),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: _refreshLocation,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.18)),
                            ),
                            child: _locLoading
                                ? const Padding(
                              padding: EdgeInsets.all(10),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                                : const Icon(Icons.refresh_rounded,
                                color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Menu
            Expanded(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: ListView(
                  children: [
                    Text(
                      "Menu",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Profile ONLY in Drawer
                    _drawerTile(
                      icon: Icons.person_rounded,
                      title: "Profile",
                      subtitle: "View your profile details",
                      iconBg: _violetSoft,
                      iconColor: _violet,
                      onTap: () {
                        Get.back();
                        Get.toNamed(Routes.profileRoute);
                      },
                    ),
                    const SizedBox(height: 10),

                    _drawerTile(
                      icon: _switchValueNotification
                          ? Icons.qr_code_scanner_rounded
                          : Icons.document_scanner_rounded,
                      title: _switchValueNotification ? "Scan QR" : "Scan Barcode",
                      subtitle: "Start scan and open order screen",
                      iconBg: _blueSoft,
                      iconColor: _bluePrimary,
                      onTap: () {
                        Get.back();
                        scanQR();
                      },
                    ),
                    const SizedBox(height: 10),

                    // Order Details (optional in drawer)
                    _drawerTile(
                      icon: Icons.receipt_long_rounded,
                      title: "Order Details",
                      subtitle: "Scan and open slip options",
                      iconBg: _tealSoft,
                      iconColor: _teal,
                      onTap: () {
                        Get.back();
                        // ✅ direct scanner open
                        Get.toNamed(
                          Routes.orderDetailRoute,
                          arguments: {"autoScan": true},
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    _drawerTile(
                      icon: Icons.settings_accessibility_rounded,
                      title: "Settings",
                      subtitle: "Scan app settings",
                      iconBg: _orangeSoft,
                      iconColor: _orange,
                      onTap: () {
                        Get.back();
                        Get.toNamed(Routes.settingsRoute);
                      },
                    ),
                    const SizedBox(height: 10),

                    _drawerTile(
                      icon: Icons.help_rounded,
                      title: "How to Use",
                      subtitle: "App usage guide",
                      iconBg: _orangeSoft,
                      iconColor: _orange,
                      onTap: () {
                        Get.back();
                        Get.toNamed(Routes.HowToUseRoute);
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Logout ONLY in Drawer (bottom)
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Get.back();
                    callAPILogOut();
                  },
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text(
                    "Logout",
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconBg,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade500),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // HOME SECTIONS
  // =========================================================
  Widget _topWelcomeCard() {
    final name = _safeUserName();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            _bluePrimary.withOpacity(0.10),
            _violet.withOpacity(0.10),
            _teal.withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_bluePrimary, _violet]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.waving_hand_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Hello, $name",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _h2.copyWith(color: _textDark),
                ),
                const SizedBox(height: 4),
                Text(
                  "${_formatDate(_now)} • ${_formatTime(_now)}",
                  style: TextStyle(
                    fontSize: 12.5,
                    color: _muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _switchValueNotification
                      ? Icons.qr_code_2_rounded
                      : Icons.line_weight_rounded,
                  size: 16,
                  color: _bluePrimary,
                ),
                const SizedBox(width: 6),
                Text(
                  _switchValueNotification ? "QR" : "Barcode",
                  style: TextStyle(
                    color: _textDark,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _scanHeroCard() {
    final isQr = _switchValueNotification;

    return _tileCard(
      icon: isQr
          ? Icons.qr_code_scanner_rounded
          : Icons.document_scanner_rounded,
      title: isQr ? "Scan QR" : "Scan Barcode",
      subtitle: "Tap to start scanning and open order screen automatically",
      gradient: [_bluePrimary, _blue2, _violet],
      onTap: () => scanQR(),
    );
  }

  // ✅ Under Scan card: Order Details -> DIRECT scanner open
  Widget _orderDetailsCard() {
    return _tileCard(
      icon: Icons.receipt_long_rounded,
      title: "Order Details",
      subtitle: "Tap to scan order QR and open Slip 1 / Slip 2",
      gradient: [_teal, const Color(0xFF22C55E), _blue2],
      onTap: () => Get.toNamed(
        Routes.orderDetailRoute,
        arguments: {"autoScan": true},
      ),
    );
  }

  Widget _infoStrip() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _orangeSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.info_rounded, color: _orange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Tip: Change scan mode anytime from the switch below or Settings.",
              style: _body.copyWith(color: _textDark),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: willPop,
      child: Scaffold(
        backgroundColor: Colors.white,
        drawer: _buildDrawer(),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          centerTitle: true,
          leading: Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu_rounded, color: Colors.black),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
          title: Text(
            AppString.appName,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
          ),
          actions: [
            IconButton(
              tooltip: _switchValueNotification ? "Scan QR" : "Scan Barcode",
              onPressed: () => scanQR(),
              icon: Icon(
                _switchValueNotification
                    ? Icons.qr_code_scanner_rounded
                    : Icons.document_scanner_rounded,
                color: _bluePrimary,
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: SafeArea(
          child: Stack(
            children: [
              // Background
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _blueSoft.withOpacity(0.70),
                        _violetSoft.withOpacity(0.45),
                        _tealSoft.withOpacity(0.35),
                        Colors.white,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),

              Positioned(
                right: -60,
                top: -40,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        _violet.withOpacity(0.22),
                        _bluePrimary.withOpacity(0.18),
                        _teal.withOpacity(0.14),
                      ],
                    ),
                  ),
                ),
              ),

              Positioned(
                left: 0,
                right: 0,
                bottom: -18,
                child: Opacity(
                  opacity: 0.12,
                  child: Image.asset(
                    "assets/images/bg.png",
                    fit: BoxFit.fitWidth,
                    alignment: Alignment.bottomLeft,
                  ),
                ),
              ),

              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _topWelcomeCard(),
                    const SizedBox(height: 14),

                    Text("Main Actions", style: _h1.copyWith(color: _textDark)),
                    const SizedBox(height: 10),

                    _scanHeroCard(),
                    const SizedBox(height: 12),

                    // ✅ Direct scanner open
                    _orderDetailsCard(),
                    const SizedBox(height: 14),

                    _infoStrip(),
                    const SizedBox(height: 14),

                    Text("Quick Settings", style: _h1.copyWith(color: _textDark)),
                    const SizedBox(height: 10),

                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 14,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: _blueSoft,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(Icons.tune_rounded, color: _bluePrimary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Scan Mode",
                                  style: _h2.copyWith(color: _textDark),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _switchValueNotification
                                      ? "Currently: QR"
                                      : "Currently: Barcode",
                                  style: TextStyle(
                                    color: _muted,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Transform.scale(
                            scale: 0.9,
                            child: CupertinoSwitch(
                              value: _switchValueNotification,
                              activeColor: _bluePrimary,
                              trackColor: Colors.grey.shade400,
                              onChanged: (v) {
                                setState(() => _switchValueNotification = v);
                                saveSetting();
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // KEEP YOUR EXISTING LOGIC (UNCHANGED) + scanQR updated to MobileScanner
  // =========================================================
  updateData(pageName) async {
    var response = await Get.toNamed(pageName);
    if (response) {
      setState(() {
        scanQR();
      });
    }
    return response;
  }

  /// ✅ MobileScanner-based scan
  Future<void> scanQR() async {
    final String? result = await Get.to<String?>(
          () => ScanMobileScreen(
        isQrMode: _switchValueNotification,
        title: _switchValueNotification ? "Scan QR" : "Scan Barcode",
        bluePrimary: _bluePrimary,
      ),
      transition: Transition.cupertino,
      fullscreenDialog: true,
    );

    if (!mounted) return;

    if (result == null || result.trim().isEmpty) {
      setState(() {});
      return;
    }

    _scanBarcode = result.trim();
    AppConstant.SCAN_ID = _scanBarcode;
    updateData(Routes.orderScreenRoute);
  }

  callAPILogOut() async {
    showProgress();
    try {
      FormData formData = FormData.fromMap(<String, dynamic>{
        "app_id": AppConstant.APP_ID,
        "api_key": AppConstant.APP_KEY,
        "token": loginVo!.data!.token.toString(),
      });

      var _response =
      await apiCall().post(AppConstant.WS_EXIST_USER_LOGOUT, data: formData);

      if (_response.statusCode == AppConstant.STATUS_CODE) {
        hideProgressBar();
        logoutVO = LogoutVO.fromJson(jsonDecode(_response.toString()));
        storage.write(AppConstant.IS_LOGIN, false);
        Get.toNamed(Routes.loginRoute);
      } else {
        hideProgressBar();
        storage.write(AppConstant.IS_LOGIN, false);
        Get.toNamed(Routes.loginRoute);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Oops! Something went wrong...')),
        );
      }
    } catch (e) {
      storage.write(AppConstant.IS_LOGIN, false);
      Get.toNamed(Routes.loginRoute);
      // ignore: avoid_print
      print('Error: $e');
    }
  }

  Future<bool> willPop() async {
    int now = DateTime.now().millisecondsSinceEpoch;
    if (back && time >= now) {
      back = false;
      exit(0);
    } else {
      time = DateTime.now().millisecondsSinceEpoch + duration;
      back = true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Press again the button to exit")),
      );
    }
    return false;
  }

  dialogSetting() {
    Size size = MediaQuery.of(context).size;
    Get.bottomSheet(
      StatefulBuilder(builder: (context, setState) {
        return SafeArea(
          child: Container(
            height: size.height * 0.30,
            color: Colors.white,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: size.height * 0.20,
                  child: ListView(
                    children: [
                      Row(
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(left: 10, top: 10),
                            child: Text(
                              "SETTING",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.red,
                                fontFamily: 'anekgujarati',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: IconButton(
                              alignment: Alignment.topRight,
                              onPressed: () async {
                                if (Get.isBottomSheetOpen ?? false) {
                                  Get.back();
                                }
                              },
                              icon: const Icon(Icons.close_rounded, size: 30),
                            ),
                          ),
                        ],
                      ),
                      Divider(color: Colors.grey[300]),
                      const SizedBox(height: 10),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Switch to QR Scan',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Transform.scale(
                              transformHitTests: true,
                              scale: 0.8,
                              child: CupertinoSwitch(
                                value: _switchValueNotification,
                                activeColor: _bluePrimary,
                                trackColor: Colors.grey,
                                onChanged: (value) {
                                  setState(() =>
                                  _switchValueNotification = value);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    height: screenHeight(context),
                    alignment: FractionalOffset.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 5, right: 5),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                if (Get.isBottomSheetOpen ?? false) {
                                  Get.back();
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueGrey,
                              ),
                              child: const Text("CLOSE",
                                  style: TextStyle(color: Colors.white)),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: ElevatedButton(
                                onPressed: () {
                                  saveSetting();
                                  Get.back();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _bluePrimary,
                                ),
                                child: const Text("SAVE",
                                    style: TextStyle(color: Colors.white)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
      isScrollControlled: true,
    );
  }

  void saveSetting() {
    setState(() {
      storage.write(AppConstant.PREF_SETTTING_QR, _switchValueNotification);
    });
  }
}

// =========================================================
// SCANNER SCREEN (MobileScanner) - iOS look
// =========================================================
class ScanMobileScreen extends StatefulWidget {
  final bool isQrMode; // true = QR only, false = Barcode only
  final String title;
  final Color bluePrimary;

  const ScanMobileScreen({
    Key? key,
    required this.isQrMode,
    required this.title,
    required this.bluePrimary,
  }) : super(key: key);

  @override
  State<ScanMobileScreen> createState() => _ScanMobileScreenState();
}

class _ScanMobileScreenState extends State<ScanMobileScreen>
    with WidgetsBindingObserver {
  late final MobileScannerController _controller;

  bool _torchOn = false;
  bool _isPopping = false;
  String? _lastValue;
  DateTime _lastHit = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
      formats: const <BarcodeFormat>[
        BarcodeFormat.qrCode,
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        BarcodeFormat.code93,
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
        BarcodeFormat.itf,
        BarcodeFormat.dataMatrix,
        BarcodeFormat.aztec,
        BarcodeFormat.pdf417,
      ],
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller.start();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _controller.stop();
    }
  }

  bool _passesModeFilter(Barcode barcode) {
    final isQr = barcode.format == BarcodeFormat.qrCode;
    if (widget.isQrMode) return isQr;
    return !isQr;
  }

  Future<void> _returnResult(String value) async {
    if (_isPopping) return;
    _isPopping = true;

    try {
      await _controller.stop();
    } catch (_) {}

    if (!mounted) return;
    Get.back(result: value);
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isPopping) return;

    final now = DateTime.now();
    if (now.difference(_lastHit).inMilliseconds < 650) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    Barcode? hit;
    for (final b in barcodes) {
      if (_passesModeFilter(b)) {
        hit = b;
        break;
      }
    }
    if (hit == null) return;

    final v = (hit.rawValue ?? "").trim();
    if (v.isEmpty) return;

    if (_lastValue == v && now.difference(_lastHit).inSeconds < 2) return;

    _lastValue = v;
    _lastHit = now;

    HapticFeedback.mediumImpact();
    _returnResult(v);
  }

  Widget _topBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Get.back(),
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.20)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.arrow_back_ios_new_rounded,
                        size: 16, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      "Back",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14.5,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            const SizedBox(width: 10),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                await _controller.toggleTorch();
                setState(() => _torchOn = !_torchOn);
              },
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.20)),
                ),
                child: Icon(
                  _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomControls() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.14),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.20)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withOpacity(0.18)),
                ),
                child: Text(
                  widget.isQrMode ? "QR Mode" : "Barcode Mode",
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 12),
                ),
              ),
              const Spacer(),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Get.back(),
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "Cancel",
                    style: TextStyle(
                        color: widget.bluePrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 12.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scanFrame() {
    return Center(
      child: Container(
        width: Get.width * 0.78,
        height: Get.width * 0.78,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white.withOpacity(0.90), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.30),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.08),
                        Colors.transparent,
                        Colors.white.withOpacity(0.08),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.40),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.16)),
                  ),
                  child: Text(
                    widget.isQrMode
                        ? "Align QR inside the frame"
                        : "Align barcode inside the frame",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _darkMask() {
    return IgnorePointer(
      child: Container(
        color: Colors.black.withOpacity(0.35),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: MobileScanner(
              controller: _controller,
              fit: BoxFit.cover,
              onDetect: _onDetect,
              errorBuilder: (context, error, child) {
                return Container(
                  color: Colors.black,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    "Camera error: ${error.errorDetails?.message ?? error.toString()}",
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    widget.bluePrimary.withOpacity(0.92),
                    widget.bluePrimary.withOpacity(0.35),
                    Colors.transparent,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Positioned.fill(child: _darkMask()),
          _scanFrame(),
          _topBar(),
          Positioned(left: 0, right: 0, bottom: 0, child: _bottomControls()),
        ],
      ),
    );
  }
}
