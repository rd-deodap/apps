// lib/home/home.dart
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';

// IMPORTANT: Ensure these imports point to your actual file locations
import '../route/app_route.dart';
import '../data/constants/app_constants.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// Cross-platform Home
/// - New stable header (no overlap / no blur blobs)
/// - Staggered animations for tiles
/// - Cleaner drawer & consistent spacing
class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  String _userName = '';
  String _userPhone = '';
  String _warehouseLabel = '';
  bool _isReadonly = false;

  // Time & Location
  DateTime _now = DateTime.now();
  Timer? _clockTimer;

  String? _locationText;
  bool _locationLoading = false;

  // Animations
  late final AnimationController _pageCtrl;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideIn;

  late final AnimationController _tilesCtrl;

  @override
  void initState() {
    super.initState();

    _pageCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );

    _fadeIn = CurvedAnimation(
      parent: _pageCtrl,
      curve: Curves.easeOutCubic,
    );

    _slideIn = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOutCubic),
    );

    _tilesCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _loadSession();
    _startClock();
    _fetchLocation();

    _pageCtrl.forward();
    _tilesCtrl.forward();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _pageCtrl.dispose();
    _tilesCtrl.dispose();
    super.dispose();
  }

  // -----------------------
  // COMMON SNACKBAR HELPER
  // -----------------------
  void _showSnack(
      String message, {
        String? title,
        bool isError = false,
      }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              size: 18,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title != null ? '$title\n$message' : message,
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        backgroundColor: isError ? Colors.red.shade700 : Colors.black87,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // -----------------------
  // SESSION / SECURITY
  // -----------------------
  Future<void> _loadSession() async {
    final p = await SharedPreferences.getInstance();
    final isLoggedIn = p.getBool('isLoggedIn') ?? false;

    if (!isLoggedIn) {
      if (!mounted) return;
      // Get.offAllNamed(AppRoutes.login);
      return;
    }

    if (!mounted) return;
    setState(() {
      _userName = p.getString('userName')?.trim() ?? '';
      _userPhone = p.getString('userPhone')?.trim() ?? '';
      _warehouseLabel = p.getString('currentWarehouseLabel')?.trim() ?? '';
      _isReadonly = (p.getInt('isReadonly') ?? 0) == 1;
    });
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout Confirmation'),
        content: const Text('Are you sure you want to sign out from your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final p = await SharedPreferences.getInstance();
    await p.setBool('isLoggedIn', false);
    await p.remove('authToken');
    await p.remove('currentUser');
    await p.remove('currentWarehouse');
    await p.remove('currentWarehouseLabel');
    await p.remove('loginTime');

    if (!mounted) return;
    _showSnack('You have been logged out securely.');
    Get.offAllNamed(AppRoutes.login);
  }

  void _startClock() {
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  Future<void> _fetchLocation() async {
    if (_locationLoading) return;
    setState(() => _locationLoading = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() => _locationText = 'Location services disabled');
          _showSnack(
            'Location services are turned off. Please enable GPS to see your current location.',
            isError: true,
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() => _locationText = 'Location permission denied');
          _showSnack('Location permission denied. You can enable it from app settings.',
              isError: true);
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      String formatted = '';

      try {
        final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final parts = <String>[];

          if ((p.locality ?? '').trim().isNotEmpty) parts.add(p.locality!.trim());
          if ((p.subLocality ?? '').trim().isNotEmpty) parts.add(p.subLocality!.trim());
          if ((p.administrativeArea ?? '').trim().isNotEmpty) {
            parts.add(p.administrativeArea!.trim());
          }

          if (parts.isNotEmpty) formatted = parts.take(3).join(', ');
        }
      } catch (_) {
        // ignore & fall back
      }

      formatted = formatted.isNotEmpty
          ? formatted
          : 'Lat ${pos.latitude.toStringAsFixed(4)}, Lng ${pos.longitude.toStringAsFixed(4)}';

      if (!mounted) return;
      setState(() => _locationText = formatted);
    } catch (_) {
      if (!mounted) return;
      setState(() => _locationText = 'Location unavailable');
      _showSnack('Unable to fetch location. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _locationLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color background = Color(0xFFF6F7FB);
    const Color brand = Color(0xFF2F3A4A);
    const Color brandSoft = Color(0xFFEEF2F7);

    return Scaffold(
      backgroundColor: background,
      drawer: _HomeDrawer(
        brand: brand,
        userName: _userName,
        userPhone: _userPhone,
        warehouseLabel: _warehouseLabel,
        isReadonly: _isReadonly,
        onLogout: _logout,
        now: _now,
        locationText: _locationText,
        appVersion: AppConstants.APP_VERSION,
      ),
      body: SafeArea(
        child: Builder(
          builder: (ctx) {
            return RefreshIndicator(
              onRefresh: () async {
                await _loadSession();
                await _fetchLocation();
              },
              color: brand,
              backgroundColor: Colors.white,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(
                    child: FadeTransition(
                      opacity: _fadeIn,
                      child: SlideTransition(
                        position: _slideIn,
                        child: Column(
                          children: [
                            // NEW STABLE HEADER
                            _HomeHeaderV2(
                              brand: brand,
                              brandSoft: brandSoft,
                              userName: _userName,
                              now: _now,
                              warehouseLabel: _warehouseLabel,
                              locationLoading: _locationLoading,
                              locationText: _locationText,
                              onOpenDrawer: () => Scaffold.of(ctx).openDrawer(),
                              onProfile: () => Get.toNamed(AppRoutes.profile),
                              onLocationRetry: _fetchLocation,
                            ),

                            const SizedBox(height: 14),

                            // Content
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const _SectionTitle(title: 'Operations'),
                                  const SizedBox(height: 12),

                                  _Stagger(
                                    controller: _tilesCtrl,
                                    index: 0,
                                    child: _ActionCard(
                                      brand: brand,
                                      title: 'CLO Packaging Scanner',
                                      subtitle: 'Scan QR to start order processing and slips',
                                      icon: Icons.qr_code_scanner,
                                      onTap: () => Get.toNamed(AppRoutes.unifiedScanner),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  _Stagger(
                                    controller: _tilesCtrl,
                                    index: 1,
                                    child: _ActionCard(
                                      brand: brand,
                                      title: 'Slip Viewer',
                                      subtitle: 'Scan or open slips directly for verification',
                                      icon: Icons.receipt_long,
                                      onTap: () => Get.toNamed(AppRoutes.slipScanner),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  _Stagger(
                                    controller: _tilesCtrl,
                                    index: 2,
                                    child: _ActionCard(
                                      brand: brand,
                                      title: 'Inter-Warehouse Transfer',
                                      subtitle: 'Scan QR to initiate inventory transfer between warehouses',
                                      icon: Icons.swap_horiz_rounded,
                                      onTap: () => Get.toNamed(AppRoutes.iwtScanner),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  _Stagger(
                                    controller: _tilesCtrl,
                                    index: 2,
                                    child: _ActionCard(
                                      brand: brand,
                                      title: 'How It Works',
                                      subtitle: 'Learn the correct packing workflow and steps',
                                      icon: Icons.help_outline_rounded,
                                      onTap: () => Get.toNamed(AppRoutes.HowItWorksScreen),
                                    ),
                                  ),

                                  const SizedBox(height: 18),

                                  _Stagger(
                                    controller: _tilesCtrl,
                                    index: 3,
                                    child: _InfoPanel(
                                      brand: brand,
                                      isReadonly: _isReadonly,
                                      version: AppConstants.APP_VERSION,
                                      warehouseLabel: _warehouseLabel,
                                    ),
                                  ),

                                  const SizedBox(height: 18),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// =====================
/// NEW HEADER (V2) - NO OVERLAP DESIGN
/// =====================
class _HomeHeaderV2 extends StatelessWidget {
  final Color brand;
  final Color brandSoft;

  final String userName;
  final DateTime now;

  final String warehouseLabel;
  final bool locationLoading;
  final String? locationText;

  final VoidCallback onOpenDrawer;
  final VoidCallback onProfile;
  final VoidCallback onLocationRetry;

  const _HomeHeaderV2({
    required this.brand,
    required this.brandSoft,
    required this.userName,
    required this.now,
    required this.warehouseLabel,
    required this.locationLoading,
    required this.locationText,
    required this.onOpenDrawer,
    required this.onProfile,
    required this.onLocationRetry,
  });

  @override
  Widget build(BuildContext context) {
    final hour = now.hour;
    String greeting = 'Good Morning';
    if (hour >= 12 && hour < 17) {
      greeting = 'Good Afternoon';
    } else if (hour >= 17) {
      greeting = 'Good Evening';
    }

    final timeStr = DateFormat('hh:mm a').format(now);
    final dateStr = DateFormat('EEE, d MMM yyyy').format(now);

    final safeTop = MediaQuery.of(context).padding.top;
    final headerHeight = 220.0; // stable height; prevents clipping/overlap

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: SizedBox(
        height: headerHeight - (safeTop > 0 ? 0 : 0),
        child: Stack(
          children: [
            // Background panel
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        brand,
                        brand.withOpacity(0.92),
                        const Color(0xFF1F2733),
                      ],
                    ),
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),

            // Subtle accent (small, safe, never overlaps content)
            Positioned(
              right: -40,
              top: -30,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              left: -30,
              bottom: -40,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
              ),
            ),

            // Content
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Row
                    Row(
                      children: [
                        _IconPillButton(
                          onTap: onOpenDrawer,
                          icon: CupertinoIcons.line_horizontal_3,
                          background: Colors.white.withOpacity(0.14),
                          iconColor: Colors.white,
                        ),
                        const Spacer(),
                        Text(
                          'CLO Packaging',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.92),
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: onProfile,
                          child: const _ProfileAvatar(
                            radius: 18,
                            backgroundColor: Colors.white24,
                            iconColor: Colors.white,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Greeting
                    Text(
                      userName.isNotEmpty ? '$greeting, $userName' : greeting,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 6),

                    Text(
                      'DeoDap CLO Packaging Management System',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.82),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Icon(CupertinoIcons.time, size: 16, color: Colors.white.withOpacity(0.85)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '$timeStr • $dateStr',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // Bottom “info strip” (card style, stable)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.16)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              if (warehouseLabel.isNotEmpty)
                                _GlassChip(
                                  icon: CupertinoIcons.cube_box,
                                  text: warehouseLabel,
                                  onTap: null,
                                ),
                              _LocationGlassChip(
                                loading: locationLoading,
                                text: locationText,
                                onTap: onLocationRetry,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// =====================
/// SECTION TITLE
/// =====================
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Colors.black87,
        ),
      ),
    );
  }
}

/// =====================
/// STAGGER ANIMATION WRAPPER
/// =====================
class _Stagger extends StatelessWidget {
  final AnimationController controller;
  final int index;
  final Widget child;

  const _Stagger({
    required this.controller,
    required this.index,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final start = (index * 0.12).clamp(0.0, 1.0);
    final end = (start + 0.45).clamp(0.0, 1.0);

    final anim = CurvedAnimation(
      parent: controller,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(anim),
        child: child,
      ),
    );
  }
}

/// =====================
/// ACTION CARD (CROSS-PLATFORM)
/// =====================
class _ActionCard extends StatefulWidget {
  final Color brand;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionCard({
    required this.brand,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final borderColor = Colors.black.withOpacity(0.06);

    return AnimatedScale(
      scale: _pressed ? 0.985 : 1.0,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_pressed ? 0.04 : 0.06),
              blurRadius: _pressed ? 10 : 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: widget.onTap,
            onHighlightChanged: (v) => setState(() => _pressed = v),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: widget.brand.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(widget.icon, color: widget.brand, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.subtitle,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.black.withOpacity(0.62),
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    CupertinoIcons.chevron_forward,
                    color: Colors.black.withOpacity(0.30),
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// =====================
/// INFO PANEL
/// =====================
class _InfoPanel extends StatelessWidget {
  final Color brand;
  final bool isReadonly;
  final String version;
  final String warehouseLabel;

  const _InfoPanel({
    required this.brand,
    required this.isReadonly,
    required this.version,
    required this.warehouseLabel,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = isReadonly
        ? 'Readonly mode is enabled. Some actions may be restricted.'
        : 'You have full access to packing operations.';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: brand.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isReadonly ? Icons.visibility_outlined : Icons.verified_outlined,
              color: brand,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isReadonly ? 'Restricted Access' : 'System Status',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.black.withOpacity(0.62),
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MiniPill(text: 'v$version'),
                    if (warehouseLabel.isNotEmpty) _MiniPill(text: warehouseLabel),
                    _MiniPill(text: 'Powered by DeoDap'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final String text;
  const _MiniPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: Colors.black.withOpacity(0.65),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// =====================
/// ICON PILL BUTTON
/// =====================
class _IconPillButton extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final Color background;
  final Color iconColor;

  const _IconPillButton({
    required this.onTap,
    required this.icon,
    required this.background,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
      ),
    );
  }
}

/// =====================
/// GLASS CHIP (HEADER)
/// =====================
class _GlassChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  const _GlassChip({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withOpacity(0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white.withOpacity(0.92)),
            const SizedBox(width: 7),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.92),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationGlassChip extends StatelessWidget {
  final bool loading;
  final String? text;
  final VoidCallback onTap;

  const _LocationGlassChip({
    required this.loading,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: !loading ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(loading ? 0.18 : 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withOpacity(0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.location_solid,
              size: 14,
              color: Colors.white.withOpacity(0.92),
            ),
            const SizedBox(width: 7),
            if (loading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240),
                child: Text(
                  (text == null || text!.trim().isEmpty) ? 'Tap to fetch location' : text!,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.92),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// =====================
/// PROFILE AVATAR (HEADER/DRAWER)
/// =====================
class _ProfileAvatar extends StatelessWidget {
  final double radius;
  final Color backgroundColor;
  final Color iconColor;

  const _ProfileAvatar({
    super.key,
    required this.radius,
    required this.backgroundColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      child: ClipOval(
        child: Image.asset(
          'assets/images/profile.png',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return Icon(CupertinoIcons.person_fill, color: iconColor, size: radius);
          },
        ),
      ),
    );
  }
}

/// =====================
/// DRAWER (REFINED)
/// =====================
class _HomeDrawer extends StatelessWidget {
  final Color brand;
  final String userName;
  final String userPhone;
  final String warehouseLabel;
  final bool isReadonly;
  final VoidCallback onLogout;
  final DateTime now;
  final String? locationText;
  final String appVersion;

  const _HomeDrawer({
    required this.brand,
    required this.userName,
    required this.userPhone,
    required this.warehouseLabel,
    required this.isReadonly,
    required this.onLogout,
    required this.now,
    required this.locationText,
    required this.appVersion,
  });

  @override
  Widget build(BuildContext context) {
    const Color background = Color(0xFFF6F7FB);
    const Color surface = Colors.white;

    final timeStr = DateFormat('hh:mm a').format(now);
    final dateStr = DateFormat('EEE, d MMM').format(now);

    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.76,
      child: Drawer(
        backgroundColor: background,
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 30, 16, 16),
              decoration: BoxDecoration(
                color: surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo area
                  SizedBox(
                    width: double.infinity,
                    child: Image.asset(
                      'assets/drawerlogo.png',
                      height: 10,
                      fit: BoxFit.fitWidth,
                      errorBuilder: (context, error, stackTrace) {
                        return Row(
                          children: [
                            Icon(Icons.storefront_rounded, size: 26, color: brand),
                            const SizedBox(width: 10),
                            Text(
                              'DeoDap CLO Packaging',
                              style: TextStyle(
                                color: brand,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName.isNotEmpty ? userName : 'DeoDap Employee',
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (userPhone.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                userPhone,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black.withOpacity(0.62),
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),

                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _DrawerPill(icon: CupertinoIcons.time, text: '$timeStr • $dateStr'),
                                if (warehouseLabel.isNotEmpty)
                                  _DrawerPill(icon: CupertinoIcons.cube_box, text: warehouseLabel),
                                if (locationText != null && locationText!.trim().isNotEmpty)
                                  _DrawerPill(icon: CupertinoIcons.location_solid, text: locationText!),
                              ],
                            ),

                            if (isReadonly) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.10),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.orange.withOpacity(0.25)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.visibility_outlined, size: 14, color: Colors.orange.shade700),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Readonly Mode',
                                      style: TextStyle(
                                        color: Colors.orange.shade800,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      const _ProfileAvatar(
                        radius: 22,
                        backgroundColor: Color(0xFF2F3A4A),
                        iconColor: Colors.white,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Menu
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 10),
                children: [
                  _DrawerMenuItem(
                    icon: CupertinoIcons.square_grid_2x2,
                    title: 'Dashboard',
                    onTap: () => Navigator.pop(context),
                  ),
                  _DrawerMenuItem(
                    icon: CupertinoIcons.person,
                    title: 'Profile',
                    onTap: () {
                      Navigator.pop(context);
                      Get.toNamed(AppRoutes.profile);
                    },
                  ),
                  _DrawerMenuItem(
                    icon: CupertinoIcons.qrcode_viewfinder,
                    title: 'QR Scanner (Packing)',
                    onTap: () {
                      Navigator.pop(context);
                      Get.toNamed(AppRoutes.unifiedScanner);
                    },
                  ),
                  _DrawerMenuItem(
                    icon: Icons.receipt_long,
                    title: 'Slip Viewer',
                    onTap: () {
                      Navigator.pop(context);
                      Get.toNamed(AppRoutes.slipScanner);
                    },
                  ),
                  const Divider(height: 26, thickness: 0.5),
                  _DrawerMenuItem(
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    onTap: () {
                      Navigator.pop(context);
                      Get.toNamed(AppRoutes.settings);
                    },
                  ),
                  _DrawerMenuItem(
                    icon: Icons.policy_outlined,
                    title: 'Privacy Policy',
                    onTap: () {
                      Navigator.pop(context);
                      Get.toNamed(AppRoutes.privacyPolicy);
                    },
                  ),
                  _DrawerMenuItem(
                    icon: Icons.description_outlined,
                    title: 'Terms & Conditions',
                    onTap: () {
                      Navigator.pop(context);
                      Get.toNamed(AppRoutes.termconditions);
                    },
                  ),
                  _DrawerMenuItem(
                    icon: Icons.info_outline,
                    title: 'How It Works',
                    onTap: () {
                      Navigator.pop(context);
                      Get.toNamed(AppRoutes.HowItWorksScreen);
                    },
                  ),
                ],
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 14),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        onLogout();
                      },
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('Logout'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '$appVersion • Powered by DeoDap',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.black.withOpacity(0.55),
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _DrawerPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.black.withOpacity(0.55)),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 210),
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                color: Colors.black.withOpacity(0.65),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// =====================
/// DRAWER MENU ITEM
/// =====================
class _DrawerMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _DrawerMenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 22, color: Colors.black.withOpacity(0.62)),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
      ),
      onTap: onTap,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      hoverColor: Colors.black.withOpacity(0.03),
    );
  }
}
