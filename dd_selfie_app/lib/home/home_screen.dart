// lib/home/homescreen.dart
import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dd_selfie_app/home/session_manager.dart';
import 'package:dd_selfie_app/selfie_punch/selfie.dart';
import 'package:dd_selfie_app/selfie_punch/selfie_punch_details.dart';
import 'package:dd_selfie_app/profile/profile.dart';
import 'package:dd_selfie_app/onboarding/onboarding_screen.dart';
import '../common/settings.dart';

/// ═══════════════════════════════════════════════════════
///  CREAM WHITE BLUE THEME — WARM & PREMIUM
/// ═══════════════════════════════════════════════════════
class AppTheme {
  AppTheme._();

  // ── Surface & Backgrounds — Warm Cream White ──
  static const Color scaffoldBg = Color(0xFFFDFCF9);
  static const Color surfaceWhite = Color(0xFFFDFCFA);
  static const Color surfaceTinted = Color(0xFFF8F7F2);
  static const Color surfaceWarm = Color(0xFFF2F0E8);
  static const Color surfaceMuted = Color(0xFFEBE8DF);
  static const Color surfaceCreme = Color(0xFFE4E0D5);
  static const Color surfaceOverlay = Color(0xFFFAF9F5);

  // ── Brand / Accent ──
  static const Color brandPrimary = Color(0xFF2563EB);
  static const Color brandLight = Color(0xFF4F86F7);
  static const Color brandDark = Color(0xFF1A4FBF);
  static const Color brandSubtle = Color(0xFFEAEFF9);
  static const Color brandMist = Color(0xFFF3F6FD);

  // ── Accent Spectrum — Vivid & Distinct ──
  static const Color accentTeal = Color(0xFF2BAFA0);
  static const Color accentTealBg = Color(0xFFE2F7F4);
  static const Color accentTealSoft = Color(0xFFB3ECE5);

  static const Color accentBlue = Color(0xFF4A8FE7);
  static const Color accentBlueBg = Color(0xFFE3EEFB);
  static const Color accentBlueSoft = Color(0xFFA8CDF5);

  static const Color accentCoral = Color(0xFFE8685A);
  static const Color accentCoralBg = Color(0xFFFDEBE8);
  static const Color accentCoralSoft = Color(0xFFF5B5AE);

  static const Color accentAmber = Color(0xFFE5A12B);
  static const Color accentAmberBg = Color(0xFFFFF4DC);
  static const Color accentAmberSoft = Color(0xFFF5D48A);

  static const Color accentViolet = Color(0xFF8B6BD4);
  static const Color accentVioletBg = Color(0xFFEDE7F9);
  static const Color accentVioletSoft = Color(0xFFC5B2EB);

  static const Color accentLime = Color(0xFF6DAD3C);
  static const Color accentLimeBg = Color(0xFFECF5E2);

  static const Color accentPink = Color(0xFFE06CA5);
  static const Color accentPinkBg = Color(0xFFFCE8F2);

  static const Color accentCyan = Color(0xFF38BCD8);
  static const Color accentCyanBg = Color(0xFFE0F5FA);

  // ── Text ──
  static const Color textDark = Color(0xFF1A1820);
  static const Color textPrimary = Color(0xFF2A2826);
  static const Color textSecondary = Color(0xFF6B6660);
  static const Color textTertiary = Color(0xFF9E9890);
  static const Color textHint = Color(0xFFC4BCB4);
  static const Color textOnBrand = Color(0xFFFFFFFF);

  // ── Borders & Dividers ──
  static const Color border = Color(0xFFE5E2DA);
  static const Color borderLight = Color(0xFFEEEBE4);
  static const Color borderFocus = Color(0xFFC8C3B8);
  static const Color divider = Color(0xFFE9E6DF);

  // ── Shadows ──
  static const Color shadow1 = Color(0x08000000);
  static const Color shadow2 = Color(0x10000000);
  static const Color shadow3 = Color(0x18000000);
  static const Color shadowBrand = Color(0x182563EB);

  // ── Gradients ──
  static const List<Color> brandGradient = [
    Color(0xFF2563EB),
    Color(0xFF4F86F7),
  ];
  static const List<Color> heroGradient = [
    Color(0xFF1A3A9F),
    Color(0xFF2563EB),
    Color(0xFF4F86F7),
  ];
  static const List<Color> warmSurfaceGradient = [
    Color(0xFFFDFCF9),
    Color(0xFFF2F0E8),
  ];
  static const List<Color> tealGradient = [
    Color(0xFF2BAFA0),
    Color(0xFF3DC4B5),
  ];
  static const List<Color> coralGradient = [
    Color(0xFFE8685A),
    Color(0xFFED8A7F),
  ];
  static const List<Color> blueGradient = [
    Color(0xFF4A8FE7),
    Color(0xFF6AAAF0),
  ];
  static const List<Color> violetGradient = [
    Color(0xFF8B6BD4),
    Color(0xFFA68AE0),
  ];
  static const List<Color> amberGradient = [
    Color(0xFFE5A12B),
    Color(0xFFF0BD55),
  ];

  // ── Radii ──
  static const double r8 = 8;
  static const double r12 = 12;
  static const double r16 = 16;
  static const double r20 = 20;
  static const double r24 = 24;
  static const double r28 = 28;
  static const double r32 = 32;

  // ── Box Shadows Presets ──
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
        color: shadow2, blurRadius: 24, offset: const Offset(0, 8)),
    BoxShadow(
        color: shadow1, blurRadius: 6, offset: const Offset(0, 2)),
  ];
  static List<BoxShadow> get softShadow => [
    BoxShadow(
        color: shadow1, blurRadius: 14, offset: const Offset(0, 4)),
  ];
  static List<BoxShadow> get elevatedShadow => [
    BoxShadow(
        color: shadow3, blurRadius: 34, offset: const Offset(0, 12)),
    BoxShadow(
        color: shadow1, blurRadius: 8, offset: const Offset(0, 3)),
  ];

  static List<BoxShadow> colorShadow(Color c, [double opacity = 0.22]) => [
    BoxShadow(
      color: c.withOpacity(opacity),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];
}

/// ═══════════════════════════════════════════
///  HELPER: Frost Glass Card
/// ═══════════════════════════════════════════
class _FrostCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final List<BoxShadow>? shadow;
  final Color? bgColor;
  final Border? border;

  const _FrostCard({
    required this.child,
    this.padding,
    this.margin,
    this.radius = AppTheme.r24,
    this.shadow,
    this.bgColor,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: bgColor ?? AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(radius),
        border:
        border ?? Border.all(color: AppTheme.borderLight, width: 0.7),
        boxShadow: shadow ?? AppTheme.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(18),
          child: child,
        ),
      ),
    );
  }
}

/// ═══════════════════════════════════════════
///  HELPER: Gradient Icon Box
/// ═══════════════════════════════════════════
class _GradientIconBox extends StatelessWidget {
  final IconData icon;
  final List<Color> gradient;
  final double size;
  final double iconSize;
  final double radius;

  const _GradientIconBox({
    required this.icon,
    required this.gradient,
    this.size = 42,
    this.iconSize = 20,
    this.radius = 13,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: AppTheme.colorShadow(gradient.first, 0.30),
      ),
      child: Icon(icon, color: Colors.white, size: iconSize),
    );
  }
}

/// ═══════════════════════════════════════════
///  AppShell — Main Entry with Bottom Tabs
/// ═══════════════════════════════════════════
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  static const double _drawerWidth = 295;

  Map<String, dynamic>? payload;
  int _currentTab = 0;
  String _drawerSelected = "home";

  late AnimationController _fabController;
  late Animation<double> _fabAnimation;

  @override
  void initState() {
    super.initState();
    _loadSession();

    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabController,
      curve: Curves.elasticOut,
    );
    _fabController.forward();
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  Future<void> _loadSession() async {
    final p = await SessionManager.getLoginPayload();
    if (!mounted) return;
    setState(() => payload = p);
  }

  void _openDrawer() => _scaffoldKey.currentState?.openDrawer();

  void _selectDrawerMenu(String key) {
    setState(() => _drawerSelected = key);
    Navigator.of(context).pop();

    if (key == "selfie_punch") {
      Navigator.of(context).push(
        CupertinoPageRoute(builder: (_) => const SelfiePunchPage()),
      );
      return;
    }
    if (key == "punch_details") {
      Navigator.of(context).push(
        CupertinoPageRoute(builder: (_) => const PunchLogsScreen()),
      );
      return;
    }
    if (key == "profile") {
      Navigator.of(context).push(
        CupertinoPageRoute(builder: (_) => const ProfileTabsScreen()),
      );
      return;
    }
    if (key == "settings") {
      Navigator.of(context).push(
        CupertinoPageRoute(builder: (_) => SettingsScreen()),
      );
      return;
    }

    const map = {
      "home": 0,
      "selfie_punch": 1,
      "punch_details": 2,
      "profile": 3,
      "settings": 4,
    };
    if (map.containsKey(key)) setState(() => _currentTab = map[key]!);
  }

  void _onTabChanged(int index) {
    HapticFeedback.lightImpact();
    if (index == 3) {
      Navigator.of(context).push(
        CupertinoPageRoute(builder: (_) => const ProfileTabsScreen()),
      );
      setState(() => _drawerSelected = "profile");
      return;
    }
    if (index == 4) {
      Navigator.of(context).push(
        CupertinoPageRoute(builder: (_) => SettingsScreen()),
      );
      setState(() => _drawerSelected = "settings");
      return;
    }
    const keys = [
      "home",
      "selfie_punch",
      "punch_details",
      "profile",
      "settings"
    ];
    setState(() {
      _currentTab = index;
      _drawerSelected = keys[index];
    });
  }

  Future<void> _logout() async {
    // Get token before clearing session
    final data = payload;
    final token = (data?["token"] ?? "").toString().trim();

    // Call logout API if token exists
    if (token.isNotEmpty) {
      await DashboardApi.logout(token: token);
    }

    // Clear local session
    await SessionManager.clear();
    if (!mounted) return;

    // Navigate to onboarding screen
    Navigator.of(context).pushAndRemoveUntil(
      CupertinoPageRoute(builder: (_) => const OnboardingScreen()),
      (route) => false, // Remove all previous routes
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = payload;
    final user = (data?["user"] is Map) ? (data?["user"] as Map) : null;
    final name = (user?["name"] ?? "User").toString();
    final code = (user?["code"] ?? "-").toString();
    final phone = (user?["phone"] ?? "-").toString();
    final whId =
    (user?["warehouse_id"] ?? user?["wh_id"] ?? "-").toString();
    final token = (data?["token"] ?? "").toString().trim();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'SF Pro',
        colorScheme: const ColorScheme.light(
          primary: AppTheme.brandPrimary,
          secondary: AppTheme.brandLight,
          surface: AppTheme.surfaceWhite,
          onPrimary: Colors.white,
          onSurface: AppTheme.textPrimary,
        ),
        scaffoldBackgroundColor: AppTheme.scaffoldBg,
        splashColor: AppTheme.brandSubtle,
        highlightColor: Colors.transparent,
      ),
      home: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: AppTheme.surfaceWhite,
        ),
        child: Scaffold(
          key: _scaffoldKey,
          backgroundColor: AppTheme.scaffoldBg,
          drawer: _PremiumDrawer(
            width: _drawerWidth,
            selectedKey: _drawerSelected,
            userName: name,
            userCode: code,
            onSelect: _selectDrawerMenu,
            onLogout: _logout,
          ),
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                if (_currentTab == 0)
                  _PremiumTopBar(
                    title: _titleForTab(_currentTab),
                    onMenuTap: _openDrawer,
                    onNotificationTap: () => HapticFeedback.lightImpact(),
                  ),
                Expanded(
                  child: _buildTabBody(
                    userName: name,
                    empCode: code,
                    phone: phone,
                    warehouseId: whId,
                    token: token,
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: _PremiumBottomNav(
            currentIndex: _currentTab,
            onTap: _onTabChanged,
          ),
        ),
      ),
    );
  }

  String _titleForTab(int i) {
    const t = [
      "Dashboard",
      "Selfie Punch",
      "Punch Details",
      "My Profile",
      "Settings"
    ];
    return t[i.clamp(0, t.length - 1)];
  }

  Widget _buildTabBody({
    required String userName,
    required String empCode,
    required String phone,
    required String warehouseId,
    required String token,
  }) {
    if (payload == null) {
      return const Center(child: CupertinoActivityIndicator(radius: 16));
    }
    if (token.isEmpty) {
      return _SessionExpiredView(onLogout: _logout);
    }
    switch (_currentTab) {
      case 0:
        return _HomeDashboard(
          userName: userName,
          empCode: empCode,
          phone: phone,
          warehouseId: warehouseId,
          token: token,
          onSelfiePunchTap: () => _onTabChanged(1),
        );
      case 1:
        return const SelfiePunchPage();
      case 2:
        return const ProfileTabsScreen();
      case 3:
        return const ProfileTabsScreen();
      case 4:
        return SettingsScreen();
      default:
        return const SizedBox.shrink();
    }
  }
}

/// ═══════════════════════════════════════════
///  PREMIUM BOTTOM NAVIGATION BAR
/// ═══════════════════════════════════════════
class _PremiumBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _PremiumBottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
            top: BorderSide(color: AppTheme.border, width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadow2,
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(
            top: 6, bottom: bottomPad + 6, left: 6, right: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
                icon: CupertinoIcons.house_fill,
                label: "Home",
                isActive: currentIndex == 0,
                gradient: AppTheme.brandGradient,
                color: AppTheme.brandPrimary,
                onTap: () => onTap(0)),
            _NavItem(
                icon: CupertinoIcons.camera_fill,
                label: "Selfie",
                isActive: currentIndex == 1,
                gradient: AppTheme.coralGradient,
                color: AppTheme.accentCoral,
                onTap: () => onTap(1)),
            _NavItem(
                icon: CupertinoIcons.clock_fill,
                label: "Punches",
                isActive: currentIndex == 2,
                gradient: AppTheme.amberGradient,
                color: AppTheme.accentAmber,
                onTap: () => onTap(2)),
            _NavItem(
                icon: CupertinoIcons.person_fill,
                label: "Profile",
                isActive: currentIndex == 3,
                gradient: AppTheme.tealGradient,
                color: AppTheme.accentTeal,
                onTap: () => onTap(3)),
            _NavItem(
                icon: CupertinoIcons.gear_solid,
                label: "Settings",
                isActive: currentIndex == 4,
                gradient: AppTheme.blueGradient,
                color: AppTheme.accentBlue,
                onTap: () => onTap(4)),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color color;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.color,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
            horizontal: isActive ? 16 : 10, vertical: 8),
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(
            colors: [
              color.withOpacity(0.10),
              color.withOpacity(0.04),
            ],
          )
              : null,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              padding: const EdgeInsets.all(2),
              child: isActive
                  ? ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: gradient,
                ).createShader(bounds),
                child: Icon(icon, size: 25, color: Colors.white),
              )
                  : Icon(icon, size: 22, color: AppTheme.textHint),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 280),
              style: TextStyle(
                fontSize: isActive ? 10.5 : 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? color : AppTheme.textHint,
              ),
              child: Text(label),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              margin: const EdgeInsets.only(top: 4),
              width: isActive ? 5 : 0,
              height: isActive ? 5 : 0,
              decoration: BoxDecoration(
                gradient: isActive
                    ? LinearGradient(colors: gradient)
                    : null,
                shape: BoxShape.circle,
                boxShadow: isActive
                    ? [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 6,
                  )
                ]
                    : [],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ═══════════════════════════════════════════
///  PREMIUM TOP BAR
/// ═══════════════════════════════════════════
class _PremiumTopBar extends StatelessWidget {
  final String title;
  final VoidCallback onMenuTap;
  final VoidCallback onNotificationTap;

  const _PremiumTopBar({
    required this.title,
    required this.onMenuTap,
    required this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite.withOpacity(0.97),
        border: Border(
            bottom: BorderSide(color: AppTheme.border, width: 0.5)),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        children: [
          _iconBtn(
            icon: CupertinoIcons.bars,
            onTap: onMenuTap,
            bgColor: AppTheme.surfaceWarm,
            iconColor: AppTheme.brandPrimary,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textDark,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 1),
                const Text(
                  "Welcome back! 👋",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          // Notification bell
          GestureDetector(
            onTap: onNotificationTap,
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.brandPrimary.withOpacity(0.10),
                        AppTheme.brandLight.withOpacity(0.06),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppTheme.brandPrimary.withOpacity(0.12),
                      width: 0.5,
                    ),
                  ),
                  child: const Icon(
                    CupertinoIcons.bell_fill,
                    size: 21,
                    color: AppTheme.brandPrimary,
                  ),
                ),
                Positioned(
                  right: 7,
                  top: 7,
                  child: Container(
                    width: 8.5,
                    height: 8.5,
                    decoration: BoxDecoration(
                      color: AppTheme.accentCoral,
                      shape: BoxShape.circle,
                      border:
                      Border.all(color: Colors.white, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentCoral.withOpacity(0.4),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconBtn({
    required IconData icon,
    required VoidCallback onTap,
    required Color bgColor,
    required Color iconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border, width: 0.5),
        ),
        child: Icon(icon, size: 21, color: iconColor),
      ),
    );
  }
}

/// ═══════════════════════════════════════════
///  PREMIUM SIDEBAR DRAWER
/// ═══════════════════════════════════════════
class _PremiumDrawer extends StatelessWidget {
  final double width;
  final String selectedKey;
  final String userName;
  final String userCode;
  final void Function(String key) onSelect;
  final Future<void> Function() onLogout;

  const _PremiumDrawer({
    required this.width,
    required this.selectedKey,
    required this.userName,
    required this.userCode,
    required this.onSelect,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: width,
      backgroundColor: AppTheme.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 22),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: AppTheme.heroGradient,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Column(
                children: [
                  // Logo
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Image.asset(
                      "assets/images/logo.png",
                      height: 42,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        CupertinoIcons.building_2_fill,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // User info row
                  Row(
                    children: [
                      _avatarCircle(userName, 50, 22),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "EMP $userCode",
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
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
            const SizedBox(height: 10),
            // ── Menu Items ──
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: [
                  _menuTile("Dashboard", CupertinoIcons.house_fill,
                      "home", AppTheme.brandPrimary, AppTheme.brandGradient),
                  _menuTile(
                      "Selfie Punch",
                      CupertinoIcons.camera_fill,
                      "selfie_punch",
                      AppTheme.accentCoral,
                      AppTheme.coralGradient),
                  _menuTile(
                      "Punch Details",
                      CupertinoIcons.clock_fill,
                      "punch_details",
                      AppTheme.accentAmber,
                      AppTheme.amberGradient),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Divider(
                        thickness: 0.8, color: AppTheme.divider),
                  ),
                  _menuTile(
                      "My Profile",
                      CupertinoIcons.person_crop_circle_fill,
                      "profile",
                      AppTheme.accentTeal,
                      AppTheme.tealGradient),
                  _menuTile("Settings", CupertinoIcons.gear_solid,
                      "settings", AppTheme.accentBlue, AppTheme.blueGradient),
                ],
              ),
            ),
            // ── Logout ──
            Padding(
              padding: const EdgeInsets.all(14),
              child: GestureDetector(
                onTap: () async {
                  // Close drawer first for smooth transition
                  Navigator.of(context).pop();
                  // Then logout
                  await onLogout();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: AppTheme.coralGradient),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AppTheme.colorShadow(
                        AppTheme.accentCoral, 0.28),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.square_arrow_right,
                          size: 19, color: Colors.white),
                      SizedBox(width: 8),
                      Text("Logout",
                          style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuTile(String title, IconData icon, String key, Color color,
      List<Color> gradient) {
    final active = selectedKey == key;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: GestureDetector(
        onTap: () => onSelect(key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: active
                ? color.withOpacity(0.07)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: active
                ? Border.all(
                color: color.withOpacity(0.10), width: 0.5)
                : null,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: active
                      ? LinearGradient(colors: gradient)
                      : null,
                  color: active ? null : AppTheme.surfaceWarm,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: active
                      ? AppTheme.colorShadow(color, 0.25)
                      : [],
                ),
                child: Icon(icon,
                    size: 19,
                    color: active ? Colors.white : AppTheme.textHint),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active
                        ? AppTheme.textPrimary
                        : AppTheme.textSecondary,
                  ),
                ),
              ),
              if (active)
                Container(
                  width: 3.5,
                  height: 22,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: gradient,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatarCircle(String name, double size, double fontSize) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.22),
        borderRadius: BorderRadius.circular(size / 2.6),
        border: Border.all(
            color: Colors.white.withOpacity(0.28), width: 1.5),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : "U",
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// ═══════════════════════════════════════════
///  HOME DASHBOARD
/// ═══════════════════════════════════════════
class _HomeDashboard extends StatefulWidget {
  final String userName, empCode, phone, warehouseId, token;
  final VoidCallback onSelfiePunchTap;

  const _HomeDashboard({
    required this.userName,
    required this.empCode,
    required this.phone,
    required this.warehouseId,
    required this.token,
    required this.onSelfiePunchTap,
  });

  @override
  State<_HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<_HomeDashboard>
    with TickerProviderStateMixin {
  late Future<DashboardData> _todayFuture;
  late Future<MonthlyData> _monthlyFuture;
  late DateTime _currentTime;
  String? _profileImageUrl;

  late AnimationController _pieAnimCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();
    _loadData();
    _startClock();
    _fetchProfileImage();

    _pieAnimCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..forward();

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2400))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 750))
      ..forward();
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
            .animate(
          CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic),
        );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pieAnimCtrl.dispose();
    _pulseCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchProfileImage() async {
    try {
      final p = await ProfileApi.fetchProfile(
        empCode: widget.empCode,
        token: widget.token,
      );
      if (!mounted) return;
      final url = p.imageUrls["profile_image"];
      if (url != null && url.isNotEmpty) {
        setState(() => _profileImageUrl = url);
      }
    } catch (_) {}
  }

  void _loadData() {
    final today = _fmtDate(_currentTime);
    _todayFuture = DashboardApi.fetchTodayData(
        date: today, token: widget.token, empCode: widget.empCode);
    _monthlyFuture = DashboardApi.fetchMonthlyStats(
        token: widget.token, empCode: widget.empCode);
  }

  void _startClock() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() => _currentTime = DateTime.now());
        _startClock();
      }
    });
  }

  String _fmtDate(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}";

  String _fmtTime(DateTime d) {
    final h = d.hour > 12
        ? d.hour - 12
        : (d.hour == 0 ? 12 : d.hour);
    final ap = d.hour >= 12 ? "PM" : "AM";
    return "${h.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')} $ap";
  }

  String _fmtDisplayDate(DateTime d) {
    const m = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December"
    ];
    const w = [
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
      "Friday",
      "Saturday",
      "Sunday"
    ];
    return "${w[d.weekday - 1]}, ${d.day} ${m[d.month - 1]} ${d.year}";
  }

  String _greeting() {
    final h = _currentTime.hour;
    if (h < 12) return "Good Morning";
    if (h < 17) return "Good Afternoon";
    return "Good Evening";
  }

  String _greetEmoji() {
    final h = _currentTime.hour;
    if (h < 12) return "☀️";
    if (h < 17) return "🌤️";
    return "🌙";
  }

  Future<void> _refresh() async {
    _pieAnimCtrl.reset();
    _pieAnimCtrl.forward();
    setState(() => _loadData());
    await Future.wait([_todayFuture, _monthlyFuture]);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppTheme.brandPrimary,
      backgroundColor: AppTheme.surfaceWhite,
      onRefresh: _refresh,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
            children: [
              _buildHeroCard(),
              const SizedBox(height: 16),
              _buildSelfiePunchCTA(),
              const SizedBox(height: 18),
              _buildQuickStats(),
              const SizedBox(height: 20),
              _sectionHeader("Today's Attendance",
                  CupertinoIcons.clock_fill, AppTheme.accentAmber,
                  AppTheme.amberGradient),
              const SizedBox(height: 10),
              FutureBuilder<DashboardData>(
                future: _todayFuture,
                builder: (_, s) {
                  if (s.connectionState == ConnectionState.waiting) {
                    return _shimmerBox(170);
                  }
                  if (s.hasError) {
                    return _errorCard(s.error.toString());
                  }
                  if (s.data == null) return _emptyCard();
                  return _todayCard(s.data!);
                },
              ),
              const SizedBox(height: 20),
              FutureBuilder<MonthlyData>(
                future: _monthlyFuture,
                builder: (_, s) {
                  if (s.connectionState == ConnectionState.waiting) {
                    return _shimmerBox(420);
                  }
                  if (s.hasError) {
                    return _errorCard(s.error.toString());
                  }
                  if (s.data == null) return _emptyCard();
                  return _monthlyCard(s.data!);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ── HERO WELCOME CARD ──
  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppTheme.heroGradient,
        ),
        borderRadius: BorderRadius.circular(AppTheme.r28),
        boxShadow: [
          ...AppTheme.colorShadow(AppTheme.brandPrimary, 0.30),
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.26), width: 1.5),
                ),
                clipBehavior: Clip.antiAlias,
                child: _profileImageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: _profileImageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, p) => Center(
                          child: Text(
                            widget.userName.isNotEmpty
                                ? widget.userName[0].toUpperCase()
                                : "U",
                            style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: Colors.white),
                          ),
                        ),
                        errorWidget: (_, e, st) => Center(
                          child: Text(
                            widget.userName.isNotEmpty
                                ? widget.userName[0].toUpperCase()
                                : "U",
                            style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: Colors.white),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          widget.userName.isNotEmpty
                              ? widget.userName[0].toUpperCase()
                              : "U",
                          style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Colors.white),
                        ),
                      ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(_greeting(),
                            style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withOpacity(0.85))),
                        const SizedBox(width: 4),
                        Text(_greetEmoji(),
                            style: const TextStyle(fontSize: 15)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.userName,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.3),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Date & Time Pill
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(16),
              border:
              Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(CupertinoIcons.calendar,
                      color: Colors.white, size: 15),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _fmtDisplayDate(_currentTime),
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withOpacity(0.9)),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        "Have a productive day! 🚀",
                        style: TextStyle(
                            fontSize: 10.5,
                            color: Colors.white.withOpacity(0.55)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 13, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.12)),
                  ),
                  child: Text(
                    _fmtTime(_currentTime),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── SELFIE PUNCH CTA ──
  Widget _buildSelfiePunchCTA() {
    return ScaleTransition(
      scale: _pulseAnim,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          widget.onSelfiePunchTap();
        },
        child: _FrostCard(
          padding:
          const EdgeInsets.symmetric(vertical: 17, horizontal: 20),
          shadow: [
            ...AppTheme.colorShadow(AppTheme.brandPrimary, 0.10),
            ...AppTheme.softShadow,
          ],
          border: Border.all(
              color: AppTheme.brandPrimary.withOpacity(0.16),
              width: 1.2),
          child: Row(
            children: [
              _GradientIconBox(
                icon: CupertinoIcons.camera_fill,
                gradient: AppTheme.brandGradient,
                size: 50,
                iconSize: 25,
                radius: 15,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Selfie Punch",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textDark),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      "Tap to mark your attendance",
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textTertiary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppTheme.brandSubtle,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppTheme.brandPrimary.withOpacity(0.15)),
                ),
                child: const Icon(CupertinoIcons.arrow_right,
                    color: AppTheme.brandPrimary, size: 17),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── QUICK STATS ──
  Widget _buildQuickStats() {
    return FutureBuilder<MonthlyData>(
      future: _monthlyFuture,
      builder: (_, s) {
        final d = s.data;
        return Row(
          children: [
            Expanded(
                child: _statChip(
                    "Present",
                    d?.totalPresent ?? "-",
                    AppTheme.accentTeal,
                    AppTheme.accentTealBg,
                    AppTheme.tealGradient,
                    CupertinoIcons.checkmark_circle_fill)),
            const SizedBox(width: 9),
            Expanded(
                child: _statChip(
                    "Absent",
                    d?.totalAbsent ?? "-",
                    AppTheme.accentCoral,
                    AppTheme.accentCoralBg,
                    AppTheme.coralGradient,
                    CupertinoIcons.xmark_circle_fill)),
            const SizedBox(width: 9),
            Expanded(
                child: _statChip(
                    "Late",
                    d?.totalLate ?? "-",
                    AppTheme.accentAmber,
                    AppTheme.accentAmberBg,
                    AppTheme.amberGradient,
                    CupertinoIcons.exclamationmark_circle_fill)),
            const SizedBox(width: 9),
            Expanded(
                child: _statChip(
                    "Leave",
                    d?.totalLeave ?? "-",
                    AppTheme.accentViolet,
                    AppTheme.accentVioletBg,
                    AppTheme.violetGradient,
                    CupertinoIcons.calendar_badge_minus)),
          ],
        );
      },
    );
  }

  Widget _statChip(String label, String val, Color c, Color bg,
      List<Color> gradient, IconData icon) {
    return _FrostCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      radius: AppTheme.r20,
      shadow: [
        BoxShadow(
            color: c.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 5)),
        ...AppTheme.softShadow,
      ],
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  c.withOpacity(0.15),
                  c.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: c.withOpacity(0.08)),
            ),
            child: Icon(icon, size: 17, color: c),
          ),
          const SizedBox(height: 9),
          Text(val,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: c)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textTertiary)),
        ],
      ),
    );
  }

  // ── TODAY'S PUNCH ──
  Widget _todayCard(DashboardData data) {
    return _FrostCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                  child: _punchBox(
                      "Punch In",
                      data.punchIn ?? "--:--",
                      CupertinoIcons.arrow_right_circle_fill,
                      AppTheme.accentTeal,
                      AppTheme.accentTealBg,
                      AppTheme.tealGradient)),
              const SizedBox(width: 12),
              Expanded(
                  child: _punchBox(
                      "Punch Out",
                      data.punchOut ?? "--:--",
                      CupertinoIcons.arrow_left_circle_fill,
                      AppTheme.accentCoral,
                      AppTheme.accentCoralBg,
                      AppTheme.coralGradient)),
            ],
          ),
          const SizedBox(height: 14),
          // Total work time
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppTheme.surfaceMuted,
                AppTheme.surfaceWarm,
              ]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppTheme.brandPrimary.withOpacity(0.10)),
            ),
            child: Row(
              children: [
                _GradientIconBox(
                  icon: CupertinoIcons.timer,
                  gradient: AppTheme.brandGradient,
                  size: 44,
                  iconSize: 20,
                  radius: 13,
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Total Work Time",
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textTertiary)),
                    const SizedBox(height: 2),
                    Text(
                      data.totalWorktime ?? "0 hrs",
                      style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.brandPrimary),
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

  Widget _punchBox(String label, String time, IconData icon, Color c,
      Color bg, List<Color> gradient) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.withOpacity(0.10)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              borderRadius: BorderRadius.circular(10),
              boxShadow: AppTheme.colorShadow(c, 0.25),
            ),
            child: Icon(icon, size: 21, color: Colors.white),
          ),
          const SizedBox(height: 9),
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textTertiary)),
          const SizedBox(height: 3),
          Text(time,
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800, color: c)),
        ],
      ),
    );
  }

  // ── MONTHLY STATS WITH PIE ──
  Widget _monthlyCard(MonthlyData data) {
    final present = int.tryParse(data.totalPresent ?? '0') ?? 0;
    final absent = int.tryParse(data.totalAbsent ?? '0') ?? 0;
    final lateCount = int.tryParse(data.totalLate ?? '0') ?? 0;
    final leave = int.tryParse(data.totalLeave ?? '0') ?? 0;
    final weekoff = int.tryParse(data.totalWeekoff ?? '0') ?? 0;
    final totalDays =
        int.tryParse(data.totalDaysInMonth ?? '30') ?? 30;

    final colors = [
      AppTheme.accentTeal,
      AppTheme.accentCoral,
      AppTheme.accentAmber,
      AppTheme.accentViolet,
      AppTheme.accentBlue,
    ];
    final gradients = [
      AppTheme.tealGradient,
      AppTheme.coralGradient,
      AppTheme.amberGradient,
      AppTheme.violetGradient,
      AppTheme.blueGradient,
    ];

    final chart = [
      ChartData('Present', present.toDouble(), colors[0]),
      ChartData('Absent', absent.toDouble(), colors[1]),
      ChartData('Late', lateCount.toDouble(), colors[2]),
      ChartData('Leave', leave.toDouble(), colors[3]),
      ChartData('Week Off', weekoff.toDouble(), colors[4]),
    ];

    final nonZero = chart.where((d) => d.value > 0).toList();

    return _FrostCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
              "Monthly Statistics",
              CupertinoIcons.chart_pie_fill,
              AppTheme.accentViolet,
              AppTheme.violetGradient),
          const SizedBox(height: 20),
          // Donut
          if (nonZero.isNotEmpty) ...[
            Center(
              child: AnimatedBuilder(
                animation: _pieAnimCtrl,
                builder: (_, __) => SizedBox(
                  height: 200,
                  width: 200,
                  child: CustomPaint(
                    painter: _DonutPainter(
                        data: nonZero,
                        animVal: _pieAnimCtrl.value,
                        centerValue: present),
                  ),
                ),
              ),
            ),
          ] else ...[
            Center(
              child: Container(
                height: 200,
                width: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.surfaceWarm,
                  border:
                  Border.all(color: AppTheme.border, width: 1.5),
                ),
                child: const Center(
                  child: Text("No Data",
                      style: TextStyle(
                          fontSize: 15,
                          color: AppTheme.textTertiary,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          // Legend
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: List.generate(chart.length, (i) {
              if (chart[i].value <= 0) return const SizedBox.shrink();
              return _legendPill(chart[i].label,
                  chart[i].value.toInt(), chart[i].color, gradients[i]);
            }),
          ),
          const SizedBox(height: 18),
          // Summary Grid
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: AppTheme.surfaceWarm,
              borderRadius: BorderRadius.circular(18),
              border:
              Border.all(color: AppTheme.border, width: 0.5),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                        child: _summaryTile(
                            "Present", "$present", AppTheme.accentTeal)),
                    Expanded(
                        child: _summaryTile(
                            "Absent", "$absent", AppTheme.accentCoral)),
                    Expanded(
                        child: _summaryTile(
                            "Late", "$lateCount", AppTheme.accentAmber)),
                    Expanded(
                        child: _summaryTile(
                            "Leave", "$leave", AppTheme.accentViolet)),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                        child: _summaryTile("Week Off", "$weekoff",
                            AppTheme.accentBlue)),
                    Expanded(
                        child: _summaryTile("Total Days",
                            "$totalDays", AppTheme.textPrimary)),
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: AppTheme.brandGradient),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: AppTheme.colorShadow(
                              AppTheme.brandPrimary, 0.22),
                        ),
                        child: Column(
                          children: [
                            const Text("Total Work",
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white70)),
                            const SizedBox(height: 2),
                            Text(data.totalWorktime ?? "0 hrs",
                                style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white)),
                          ],
                        ),
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

  Widget _legendPill(
      String label, int val, Color c, List<Color> gradient) {
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: c.withOpacity(0.35), blurRadius: 4)
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text("$label: $val",
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: c)),
        ],
      ),
    );
  }

  Widget _summaryTile(String label, String val, Color c) {
    return Column(
      children: [
        Text(val,
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w800, color: c)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: AppTheme.textTertiary),
            textAlign: TextAlign.center),
      ],
    );
  }

  // ── SECTION HEADER ──
  Widget _sectionHeader(
      String title, IconData icon, Color c, List<Color> gradient) {
    return Row(
      children: [
        _GradientIconBox(
          icon: icon,
          gradient: gradient,
          size: 34,
          iconSize: 16,
          radius: 10,
        ),
        const SizedBox(width: 10),
        Text(title,
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark)),
      ],
    );
  }

  // ── UTILITY WIDGETS ──
  Widget _shimmerBox(double h) {
    return Container(
      height: h,
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(AppTheme.r24),
        border:
        Border.all(color: AppTheme.borderLight, width: 0.5),
        boxShadow: AppTheme.softShadow,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CupertinoActivityIndicator(radius: 13),
            const SizedBox(height: 12),
            Text("Loading...",
                style: TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.textTertiary,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _errorCard(String msg) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.accentCoralBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: AppTheme.accentCoral.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: AppTheme.coralGradient),
              borderRadius: BorderRadius.circular(10),
              boxShadow:
              AppTheme.colorShadow(AppTheme.accentCoral, 0.20),
            ),
            child: const Icon(
                CupertinoIcons.exclamationmark_triangle_fill,
                color: Colors.white,
                size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              msg.replaceFirst('Exception:', '').trim(),
              style: TextStyle(
                  fontSize: 12.5,
                  color: AppTheme.accentCoral,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard() {
    return _FrostCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                color: AppTheme.surfaceWarm,
                shape: BoxShape.circle),
            child: const Icon(CupertinoIcons.clock,
                size: 38, color: AppTheme.textHint),
          ),
          const SizedBox(height: 14),
          const Text("No data available",
              style: TextStyle(
                  fontSize: 14.5,
                  color: AppTheme.textTertiary,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

/// ═══════════════════════════════════════════
///  ANIMATED BUILDER WRAPPER (Fixed)
/// ═══════════════════════════════════════════
class AnimatedBuilder extends StatelessWidget {
  final Listenable animation;
  final Widget Function(BuildContext context, Widget? child) builder;
  final Widget? child;

  const AnimatedBuilder({
    super.key,
    required this.animation,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder2(
      listenable: animation,
      builder: builder,
      child: child,
    );
  }
}

class AnimatedBuilder2 extends AnimatedWidget {
  final Widget Function(BuildContext context, Widget? child) builder;
  final Widget? child;

  const AnimatedBuilder2({
    super.key,
    required super.listenable,
    required this.builder,
    this.child,
  }) : super();

  @override
  Listenable get listenable => super.listenable;

  @override
  Widget build(BuildContext context) {
    return builder(context, child);
  }
}

/// ═══════════════════════════════════════════
///  DONUT CHART PAINTER (White Blue Theme)
/// ═══════════════════════════════════════════
class _DonutPainter extends CustomPainter {
  final List<ChartData> data;
  final double animVal;
  final int centerValue;

  _DonutPainter({
    required this.data,
    required this.animVal,
    required this.centerValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final total = data.fold(0.0, (s, i) => s + i.value);
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    const stroke = 28.0;
    const gap = 0.04;
    final rect =
    Rect.fromCircle(center: center, radius: radius - stroke / 2);

    // Background track
    final bgPaint = Paint()
      ..color = const Color(0xFFEDE9E0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, radius - stroke / 2, bgPaint);

    double startAngle = -pi / 2;
    for (final item in data) {
      final sweep = (item.value / total) * 2 * pi * animVal;
      final p = Paint()
        ..color = item.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke - 2
        ..strokeCap = StrokeCap.round;
      if (sweep > gap) {
        canvas.drawArc(
            rect, startAngle + gap / 2, sweep - gap, false, p);
      }
      startAngle += sweep;
    }

    // Center shadow
    final sp = Paint()
      ..color = Colors.black.withOpacity(0.02)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(center, radius - stroke - 5, sp);

    // Center white
    canvas.drawCircle(
        center, radius - stroke - 2, Paint()..color = Colors.white);

    // Center ring
    canvas.drawCircle(
      center,
      radius - stroke - 2,
      Paint()
        ..color = const Color(0xFFE8E4DC)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Center text - Show Present count
    final ts = TextSpan(
      children: [
        TextSpan(
          text: "$centerValue\n",
          style: const TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w800,
              color: AppTheme.accentTeal,
              height: 1.2),
        ),
        const TextSpan(
          text: "Present",
          style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.textTertiary),
        ),
      ],
    );
    final tp = TextPainter(
        text: ts,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center)
      ..layout();
    tp.paint(canvas,
        Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

/// ═══════════════════════════════════════════
///  CHART DATA MODEL
/// ═══════════════════════════════════════════
class ChartData {
  final String label;
  final double value;
  final Color color;
  ChartData(this.label, this.value, this.color);
}

/// ═══════════════════════════════════════════
///  PROFILE SCREEN
/// ═══════════════════════════════════════════
class _ProfileScreen extends StatelessWidget {
  final String userName, empCode, phone, warehouseId;

  const _ProfileScreen({
    required this.userName,
    required this.empCode,
    required this.phone,
    required this.warehouseId,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Avatar
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: AppTheme.brandGradient),
              shape: BoxShape.circle,
              boxShadow:
              AppTheme.colorShadow(AppTheme.brandPrimary, 0.28),
            ),
            child: Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle),
              child: Center(
                child: Text(
                  userName.isNotEmpty
                      ? userName[0].toUpperCase()
                      : "U",
                  style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.brandPrimary),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(userName,
              style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textDark)),
          const SizedBox(height: 6),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: AppTheme.brandGradient),
              borderRadius: BorderRadius.circular(20),
              boxShadow:
              AppTheme.colorShadow(AppTheme.brandPrimary, 0.20),
            ),
            child: Text("EMP $empCode",
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
          ),
          const SizedBox(height: 28),
          _profileField(CupertinoIcons.person_fill, "Full Name",
              userName, AppTheme.brandPrimary, AppTheme.brandGradient),
          _profileField(CupertinoIcons.number, "Employee Code",
              empCode, AppTheme.accentTeal, AppTheme.tealGradient),
          _profileField(CupertinoIcons.phone_fill, "Phone Number",
              phone, AppTheme.accentAmber, AppTheme.amberGradient),
          _profileField(
              CupertinoIcons.building_2_fill,
              "Warehouse ID",
              warehouseId,
              AppTheme.accentBlue,
              AppTheme.blueGradient),
        ],
      ),
    );
  }

  Widget _profileField(IconData icon, String label, String val,
      Color c, List<Color> gradient) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: _FrostCard(
        padding: const EdgeInsets.all(15),
        radius: AppTheme.r20,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    c.withOpacity(0.12),
                    c.withOpacity(0.04),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: c.withOpacity(0.08), width: 0.5),
              ),
              child: Icon(icon, color: c, size: 19),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textTertiary)),
                  const SizedBox(height: 2),
                  Text(val,
                      style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ═══════════════════════════════════════════
///  SESSION EXPIRED VIEW
/// ═══════════════════════════════════════════
class _SessionExpiredView extends StatelessWidget {
  final Future<void> Function() onLogout;
  const _SessionExpiredView({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        child: _FrostCard(
          padding: const EdgeInsets.all(30),
          radius: AppTheme.r28,
          shadow: [
            BoxShadow(
                color: AppTheme.accentCoral.withOpacity(0.08),
                blurRadius: 28,
                offset: const Offset(0, 12)),
            ...AppTheme.softShadow,
          ],
          border: Border.all(
              color: AppTheme.accentCoral.withOpacity(0.12)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: AppTheme.accentCoralBg,
                    shape: BoxShape.circle),
                child: const Icon(
                    CupertinoIcons.exclamationmark_triangle_fill,
                    size: 46,
                    color: AppTheme.accentCoral),
              ),
              const SizedBox(height: 24),
              const Text("Session Expired",
                  style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textDark)),
              const SizedBox(height: 8),
              const Text(
                "Please logout and login again\nto continue using the app",
                style: TextStyle(
                    fontSize: 13.5,
                    color: AppTheme.textTertiary,
                    height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              GestureDetector(
                onTap: () => onLogout(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: AppTheme.coralGradient),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AppTheme.colorShadow(
                        AppTheme.accentCoral, 0.28),
                  ),
                  child: const Center(
                    child: Text("Logout & Re-login",
                        style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ═══════════════════════════════════════════
///  API + DATA MODELS
/// ═══════════════════════════════════════════
class DashboardApi {
  static const String _base =
      "https://staff.deodap.in/api/admin/dashboard";
  static const String _logoutUrl =
      "https://staff.deodap.in/api/admin/logout";

  static Future<DashboardData> fetchTodayData({
    required String date,
    required String token,
    String? empCode,
  }) async {
    if (date.trim().isEmpty) throw Exception("Date is empty");
    if (token.trim().isEmpty) {
      throw Exception("Session token is missing");
    }
    final t = token.trim();
    final qp = <String, String>{
      "date": date.trim(),
      "api_token": t,
    };
    if ((empCode ?? "").trim().isNotEmpty) {
      qp["emp_code"] = empCode!.trim();
    }
    final uri = Uri.parse(_base).replace(queryParameters: qp);
    final res = await http.get(uri, headers: {
      "Accept": "application/json",
      "Authorization": "Bearer $t",
      "api_token": t,
    });
    if (res.statusCode == 401) {
      throw Exception("Authentication failed. Please login again.");
    }
    if (res.statusCode != 200) {
      String e = "HTTP ${res.statusCode}";
      try {
        final j = json.decode(res.body);
        if (j is Map && j["message"] != null) {
          e = j["message"].toString();
        }
      } catch (_) {
        e = res.body.length > 100
            ? res.body.substring(0, 100)
            : res.body;
      }
      throw Exception(e);
    }
    return DashboardData.fromJson(json.decode(res.body));
  }

  static Future<MonthlyData> fetchMonthlyStats({
    required String token,
    String? empCode,
  }) async {
    if (token.trim().isEmpty) {
      throw Exception("Session token is missing");
    }
    final t = token.trim();
    final qp = <String, String>{"api_token": t};
    if ((empCode ?? "").trim().isNotEmpty) {
      qp["emp_code"] = empCode!.trim();
    }
    final uri = Uri.parse(_base).replace(queryParameters: qp);
    final res = await http.get(uri, headers: {
      "Accept": "application/json",
      "Authorization": "Bearer $t",
      "api_token": t,
    });
    if (res.statusCode == 401) {
      throw Exception("Authentication failed. Please login again.");
    }
    if (res.statusCode != 200) {
      String e = "HTTP ${res.statusCode}";
      try {
        final j = json.decode(res.body);
        if (j is Map && j["message"] != null) {
          e = j["message"].toString();
        }
      } catch (_) {
        e = res.body.length > 100
            ? res.body.substring(0, 100)
            : res.body;
      }
      throw Exception(e);
    }
    return MonthlyData.fromJson(json.decode(res.body));
  }

  /// Logout API call
  /// POST /admin/logout
  static Future<void> logout({required String token}) async {
    if (token.trim().isEmpty) {
      // If no token, just return (already logged out)
      return;
    }

    final t = token.trim();
    try {
      final res = await http.post(
        Uri.parse(_logoutUrl),
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json",
          "Authorization": "Bearer $t",
          "api_token": t,
        },
        body: json.encode({"api_token": t}),
      );

      // Logout successful or already logged out (401)
      // Don't throw errors - just proceed with local logout
      if (res.statusCode == 200 || res.statusCode == 401) {
        return;
      }

      // For other status codes, log but don't fail
      print("Logout API returned ${res.statusCode}: ${res.body}");
    } catch (e) {
      // Network error - proceed with local logout anyway
      print("Logout API error: $e");
    }
  }
}

class DashboardData {
  final String? punchIn, punchOut, totalWorktime;

  DashboardData({this.punchIn, this.punchOut, this.totalWorktime});

  factory DashboardData.fromJson(Map<String, dynamic> j) {
    String? s(dynamic v) => v == null ? null : v.toString();
    return DashboardData(
      punchIn: s(j["Punch_In"]),
      punchOut: s(j["Punch_Out"]),
      totalWorktime: s(j["total_worktime"]),
    );
  }
}

class MonthlyData {
  final String? totalPresent,
      totalAbsent,
      totalLate,
      totalLeave,
      totalWeekoff,
      totalDaysInMonth,
      totalWorktime;

  MonthlyData({
    this.totalPresent,
    this.totalAbsent,
    this.totalLate,
    this.totalLeave,
    this.totalWeekoff,
    this.totalDaysInMonth,
    this.totalWorktime,
  });

  factory MonthlyData.fromJson(Map<String, dynamic> j) {
    String? s(dynamic v) => v == null ? null : v.toString();
    return MonthlyData(
      totalPresent: s(j["total_present"]),
      totalAbsent: s(j["total_absent"]),
      totalLate: s(j["total_late"]),
      totalLeave: s(j["total_leave"]),
      totalWeekoff: s(j["total_weekoff"]),
      totalDaysInMonth: s(j["Total_days_in_month"]),
      totalWorktime: s(j["total_worktime"]),
    );
  }
}
