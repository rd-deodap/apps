// lib/common/settings.dart
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show Colors, PopupMenuItem, RelativeRect, RoundedRectangleBorder, showMenu;
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

// Your screens
import 'package:rapidmiles/onboarding/onboarding_screen.dart';
import 'package:rapidmiles/common/term.dart';
import 'package:rapidmiles/common/privacy_policy.dart';
import 'package:rapidmiles/common/about.dart';

// ✅ Home screen import (UPDATE PATH if different in your project)
import 'package:rapidmiles/home/home_screen.dart';
import 'package:rapidmiles/home/profile_screen.dart';
import 'package:rapidmiles/common/app_info.dart';
/// ===============================
/// WHITE THEME (as requested)
/// ===============================
const Color kPageBg = Color(0xFFFFFFFF); // ✅ full white background
const Color kInk = Color(0xFF111827);
const Color kCardWhite = Color(0xFFFFFFFF);
const Color kDivider = Color(0xFFE5E7EB);
const Color kMuted = Color(0xFF6B7280);

/// Optional: use a very soft cream in shadows / accents only (not background)
const Color kShadowTint = Color(0xFFFEF8DD);

/// Brand primary
const Color kPrimary = Color(0xFF011D3E);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsCupertinoScreenState();
}

class _SettingsCupertinoScreenState extends State<SettingsScreen> {
  bool _isLoading = false;
  String _updateStatus = ''; // 'success' or 'error' or ''
  String _currentLanguage = 'English';
  String _currentVersion = '1.0.0';
  final String _appVersion = '1.0.0';
  bool _hapticsEnabled = true;
  double _textScaleFactor = 1.0;

  // Profile variables (basic only)
  String _userName = '';
  String _userEmail = '';
  String _employeeCode = '';

  // API Configuration (kept)
  static const String _baseUrl = 'https://api.vacalvers.com/api-packaging-app';
  static const String _appId = '1';
  static const String _apiKey = 'c77b74df-59f6-4257-b0ee-9b81e30026b1';

  Map<String, dynamic> _userProfile = {};

  // Permission states
  final Map<String, bool> _permissions = {
    'camera': false,
    'storage': false,
    'location': false,
    'notifications': false,
  };

  // UI states
  bool _permissionsExpanded = false;
  bool _legalSupportExpanded = false;

  Color get _primary => kPrimary;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    _loadSettings();
    _checkForUpdate();
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _currentVersion = info.version);
      }
    } catch (_) {}
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _hapticsEnabled = prefs.getBool('hapticsEnabled') ?? true;
          _textScaleFactor = prefs.getDouble('textScaleFactor') ?? 1.0;

          _userName = prefs.getString('userName') ?? 'wms user';
          _userEmail = prefs.getString('userEmail') ?? '';
          _employeeCode = prefs.getString('employeeCode') ?? '';

          _userProfile = {};
        });
      }
    } catch (_) {}
    await _checkPermissions();
  }

  Future<void> _saveHapticsSetting(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hapticsEnabled', value);
      if (mounted) setState(() => _hapticsEnabled = value);
    } catch (_) {}
  }

  Future<void> _saveTextScaleFactor(double value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('textScaleFactor', value);
      if (mounted) setState(() => _textScaleFactor = value);
    } catch (_) {}
  }

  // =========================
  // PERMISSIONS
  // =========================

  Future<void> _checkPermissions() async {
    final cameraStatus = await Permission.camera.status;
    final storageStatus = await Permission.storage.status; // legacy
    final locationStatus = await Permission.location.status;
    final notificationStatus = await Permission.notification.status;

    if (!mounted) return;
    setState(() {
      _permissions['camera'] = cameraStatus.isGranted;
      _permissions['storage'] = storageStatus.isGranted;
      _permissions['location'] = locationStatus.isGranted;
      _permissions['notifications'] = notificationStatus.isGranted;
    });
  }

  Future<void> _togglePermission(String permission) async {
    Permission? permissionType;

    switch (permission) {
      case 'camera':
        permissionType = Permission.camera;
        break;
      case 'storage':
        permissionType = Permission.storage;
        break;
      case 'location':
        permissionType = Permission.location;
        break;
      case 'notifications':
        permissionType = Permission.notification;
        break;
    }

    if (permissionType == null) return;

    final currentStatus = await permissionType.status;

    if (currentStatus.isGranted) {
      _showPermissionDialog(
        permission,
        'This permission is already allowed. To deny it, open App Settings.',
        showSettingsOption: true,
      );
    } else {
      _showRequestPermissionDialog(permission, permissionType);
    }
  }

  void _showRequestPermissionDialog(String permission, Permission permissionType) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Allow ${permission.toUpperCase()} Permission?'),
        content: Text(
          'This app needs access to your $permission to function properly. Allow this permission?',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            onPressed: () async {
              Navigator.pop(context);
              await _requestPermission(permission, permissionType);
            },
            isDefaultAction: true,
            child: const Text('Allow'),
          ),
        ],
      ),
    );
  }

  Future<void> _requestPermission(String permission, Permission permissionType) async {
    final status = await permissionType.request();

    if (!mounted) return;
    setState(() {
      _permissions[permission] = status.isGranted;
    });

    if (status.isGranted) {
      _showPermissionStatus('${permission.toUpperCase()} permission allowed successfully.');
    } else if (status.isPermanentlyDenied) {
      _showPermissionDialog(
        permission,
        '${permission.toUpperCase()} permission is permanently denied. Please enable it in App Settings.',
        showSettingsOption: true,
      );
    } else {
      _showPermissionStatus('${permission.toUpperCase()} permission denied.');
    }
  }

  void _showPermissionDialog(
      String permission,
      String message, {
        bool showSettingsOption = false,
      }) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('${permission.toUpperCase()} Permission'),
        content: Text(message),
        actions: [
          if (showSettingsOption)
            CupertinoDialogAction(
              onPressed: () {
                Navigator.pop(context);
                _openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPermissionStatus(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Permission Status'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _openAppSettings() {
    openAppSettings().then((_) {
      Future.delayed(const Duration(milliseconds: 700), () {
        _checkPermissions();
      });
    });
  }

  // =========================
  // UPDATE CHECK
  // =========================

  Future<void> _checkForUpdate() async {
    if (mounted) setState(() => _isLoading = true);

    try {
      final res = await http.post(
        Uri.parse(_baseUrl),
        body: {'version': _appVersion, 'app_id': _appId, 'api_key': _apiKey},
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          _updateStatus = data['status'] == 'success' ? 'success' : 'error';
        });
      } else {
        setState(() => _updateStatus = 'error');
      }
    } catch (_) {
      if (mounted) setState(() => _updateStatus = 'error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showLanguageSheet() async {
    await showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Select Language'),
        message: const Text('More languages coming soon.'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _currentLanguage = 'English');
              Navigator.pop(ctx);
            },
            isDefaultAction: true,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(CupertinoIcons.globe, size: 18),
                SizedBox(width: 8),
                Text('English'),
                SizedBox(width: 6),
                Icon(CupertinoIcons.check_mark_circled_solid, size: 18),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showTextScaleDialog() async {
    await showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Text Size'),
        message: const Text('Adjust the text size for better readability'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              _saveTextScaleFactor(0.8);
              Navigator.pop(ctx);
            },
            child: const Text('Small (80%)'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              _saveTextScaleFactor(1.0);
              Navigator.pop(ctx);
            },
            child: const Text('Normal (100%)'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              _saveTextScaleFactor(1.2);
              Navigator.pop(ctx);
            },
            child: const Text('Large (120%)'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              _saveTextScaleFactor(1.5);
              Navigator.pop(ctx);
            },
            child: const Text('Extra Large (150%)'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    final yes = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Sign Out?'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (yes == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        CupertinoPageRoute(builder: (_) => const OnboardingScreen()),
            (_) => false,
      );
    }
  }

  // =========================
  // ✅ BACK TO HOME (forced)
  // =========================
  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      CupertinoPageRoute(builder: (_) => const DashboardScreen()),
          (_) => false,
    );
  }

  // =========================
  // POPUP MENU
  // =========================

  void _openPopupMenu() async {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final RenderBox button = context.findRenderObject() as RenderBox;
    final Offset buttonPosition = button.localToGlobal(Offset.zero, ancestor: overlay);

    await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        buttonPosition.dx + button.size.width - 200,
        buttonPosition.dy - 250,
        buttonPosition.dx + button.size.width,
        buttonPosition.dy,
      ),
      items: [
        PopupMenuItem<String>(
          value: 'profile',
          child: Row(
            children: [
              Icon(CupertinoIcons.person_circle, size: 20, color: _primary),
              const SizedBox(width: 12),
              const Text('Profile'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'reset_password',
          child: Row(
            children: [
              Icon(CupertinoIcons.lock_shield_fill, size: 20, color: _primary),
              const SizedBox(width: 12),
              const Text('Reset Password'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'help',
          child: Row(
            children: [
              Icon(CupertinoIcons.question_circle_fill, size: 20, color: _primary),
              const SizedBox(width: 12),
              const Text('Help'),
            ],
          ),
        ),
      ],
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ).then((value) {
      if (!mounted || value == null) return;

      switch (value) {
        case 'profile':
          Navigator.of(context).push(
            CupertinoPageRoute(builder: (_) => const ProfileScreen()),
          );
          break;
        case 'reset_password':
          _showResetPasswordDialog();
          break;
        case 'help':
          _showHelpCenter();
          break;
      }
    });
  }

  // =========================
  // HELP / CONTACT / LAUNCHERS
  // =========================

  void _showHelpCenter() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Help & Support'),
        content: const Text('How can we help you today?'),
        actions: [
          CupertinoDialogAction(
            onPressed: _launchHelpWhatsApp,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.chat_bubble_2_fill, size: 18),
                SizedBox(width: 8),
                Text('Chat on WhatsApp'),
              ],
            ),
          ),
          CupertinoDialogAction(
            onPressed: () => _launchPhone('+919889663378'),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.phone_fill, size: 18),
                SizedBox(width: 8),
                Text('Call Support'),
              ],
            ),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            isDefaultAction: true,
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showResetPasswordDialog() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Reset Password'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 14),
            Icon(
              CupertinoIcons.lock_shield_fill,
              size: 44,
              color: CupertinoColors.systemOrange,
            ),
            SizedBox(height: 14),
            Text(
              'Please contact System Administrator for password reset.',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'No password reset allowed from app side.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: CupertinoColors.systemGrey,
                fontStyle: FontStyle.italic,
                fontSize: 13,
              ),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrlExternal(Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Error'),
          content: Text('Could not open: ${uri.toString()}'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _launchWhatsApp(String phone, String message) async {
    final encoded = Uri.encodeFull(message);
    final uri = Uri.parse('https://wa.me/$phone?text=$encoded');
    await _launchUrlExternal(uri);
  }

  Future<void> _launchHelpWhatsApp() async {
    await _launchWhatsApp(
      '919889663378',
      'Hello DeoDap Support / Administrator team, can you chat regarding warehouse management system app related issues?',
    );
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    await _launchUrlExternal(uri);
  }

  // =========================
  // UI HELPERS
  // =========================

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 10),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          letterSpacing: 0.6,
          color: kMuted,
          fontWeight: FontWeight.w700,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }

  Widget _group(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: kCardWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kDivider, width: 1),
          boxShadow: [
            // ✅ keep shadow, with a soft cream tint feel
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: kShadowTint.withOpacity(0.25),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(children: children),
      ),
    );
  }

  Widget _cell({
    required Widget leading,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    bool isFirst = false,
    bool isLast = false,
    Color? titleColor,
  }) {
    final radius = BorderRadius.vertical(
      top: isFirst ? const Radius.circular(14) : Radius.zero,
      bottom: isLast ? const Radius.circular(14) : Radius.zero,
    );

    return ClipRRect(
      borderRadius: radius,
      child: CupertinoButton(
        onPressed: onTap,
        padding: EdgeInsets.zero,
        pressedOpacity: 0.65,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: kCardWhite,
            border: Border(
              bottom: isLast ? BorderSide.none : const BorderSide(color: kDivider, width: 0.6),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Center(
                  child: IconTheme(
                    data: IconThemeData(color: _primary),
                    child: leading,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        color: titleColor ?? kInk,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    if (subtitle != null && subtitle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 13,
                            color: kMuted,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              trailing ??
                  (onTap != null
                      ? const Icon(
                    CupertinoIcons.chevron_forward,
                    size: 18,
                    color: CupertinoColors.systemGrey2,
                  )
                      : const SizedBox.shrink()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _permissionCell({
    required String permission,
    required String title,
    required String description,
    required IconData icon,
    bool isFirst = false,
    bool isLast = false,
  }) {
    final isGranted = _permissions[permission] ?? false;

    return _cell(
      isFirst: isFirst,
      isLast: isLast,
      leading: Icon(icon),
      title: title,
      subtitle: description,
      onTap: () => _togglePermission(permission),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isGranted ? _primary.withOpacity(0.08) : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isGranted ? _primary.withOpacity(0.25) : Colors.black.withOpacity(0.10),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isGranted ? CupertinoIcons.check_mark_circled_solid : CupertinoIcons.plus_circle,
              size: 14,
              color: _primary,
            ),
            const SizedBox(width: 6),
            Text(
              isGranted ? 'Allowed' : 'Allow',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _primary,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _collapsiblePermissionsSection() {
    return SliverToBoxAdapter(
      child: _group([
        _cell(
          isFirst: true,
          isLast: !_permissionsExpanded,
          leading: const Icon(CupertinoIcons.lock_shield),
          title: 'Permissions',
          subtitle: _permissionsExpanded ? 'Tap to minimize permissions' : 'Camera, Storage, Location, Notifications',
          trailing: Icon(
            _permissionsExpanded ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down,
            size: 16,
            color: _primary,
          ),
          onTap: () => setState(() => _permissionsExpanded = !_permissionsExpanded),
        ),
        if (_permissionsExpanded) ...[
          _permissionCell(
            permission: 'camera',
            title: 'Camera',
            description: 'Access camera for app features',
            icon: CupertinoIcons.camera,
          ),
          _permissionCell(
            permission: 'storage',
            title: 'Storage',
            description: 'Access device storage for files',
            icon: CupertinoIcons.folder,
          ),
          _permissionCell(
            permission: 'location',
            title: 'Location',
            description: 'Access device location',
            icon: CupertinoIcons.location,
          ),
          _permissionCell(
            permission: 'notifications',
            title: 'Notifications',
            description: 'Receive app notifications',
            icon: CupertinoIcons.bell,
            isLast: true,
          ),
        ],
      ]),
    );
  }

  Widget _collapsibleLegalSupportSection() {
    return SliverToBoxAdapter(
      child: _group([
        _cell(
          isFirst: true,
          isLast: !_legalSupportExpanded,
          leading: const Icon(CupertinoIcons.question_circle_fill),
          title: 'Legal & Support',
          subtitle: _legalSupportExpanded ? 'Tap to minimize section' : 'Help, Contact, Terms, Privacy, About',
          trailing: Icon(
            _legalSupportExpanded ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down,
            size: 16,
            color: _primary,
          ),
          onTap: () => setState(() => _legalSupportExpanded = !_legalSupportExpanded),
        ),
        if (_legalSupportExpanded) ...[
          _cell(
            leading: const Icon(CupertinoIcons.question_circle_fill),
            title: 'Help Center / FAQs',
            onTap: _showHelpCenter,
          ),
          _cell(
            leading: const Icon(CupertinoIcons.chat_bubble_2_fill),
            title: 'Contact Support',
            subtitle: 'Email/WhatsApp/Phone',
            onTap: _launchHelpWhatsApp,
          ),
          _cell(
            leading: const Icon(CupertinoIcons.doc_text_fill),
            title: 'Terms & Conditions',
            onTap: () {
              Navigator.of(context).push(
                CupertinoPageRoute(builder: (_) => const TermsScreen()),
              );
            },
          ),
          _cell(
            leading: const Icon(CupertinoIcons.lock_shield_fill),
            title: 'Privacy Policy',
            onTap: () {
              Navigator.of(context).push(
                CupertinoPageRoute(builder: (_) => const PrivacyPolicyScreen()),
              );
            },
          ),
          _cell(
            leading: const Icon(CupertinoIcons.info_circle_fill),
            title: 'About App / Credits',
            onTap: () {
              Navigator.of(context).push(
                CupertinoPageRoute(builder: (_) => const AboutUsScreen()),
              );
            },
          ),
          _cell(
            isLast: true,
            leading: const Icon(CupertinoIcons.app_badge),
            title: 'App Info',
            subtitle: 'Version $_currentVersion',
            onTap: () {
              Navigator.of(context).push(
                CupertinoPageRoute(builder: (_) => const HowItWorksScreen()),
              );
            },
          ),
        ],
      ]),
    );
  }

  // =========================
  // BUILD
  // =========================

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final scaled = media.copyWith(textScaler: TextScaler.linear(_textScaleFactor));

    return MediaQuery(
      data: scaled,
      child: CupertinoPageScaffold(
        backgroundColor: kPageBg, // ✅ full white
        navigationBar: CupertinoNavigationBar(
          backgroundColor: kPageBg, // ✅ white nav
          border: null,
          middle: const Text('Settings'),
          previousPageTitle: 'Back',
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            // ✅ back button now goes to HomeScreen (not pop)
            onPressed: _goHome,
            child: Icon(
              CupertinoIcons.chevron_back,
              size: 22,
              color: _primary,
            ),
          ),
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _openPopupMenu,
            child: Icon(
              CupertinoIcons.ellipsis_circle,
              size: 24,
              color: _primary,
            ),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              CupertinoSliverRefreshControl(
                onRefresh: _checkForUpdate,
                builder: (context, mode, pulledExtent, refreshTriggerPullDistance, refreshIndicatorExtent) {
                  return const Center(child: CupertinoActivityIndicator());
                },
              ),

              // COMMON
              SliverToBoxAdapter(child: _sectionHeader('Common')),
              SliverToBoxAdapter(
                child: _group([
                  _cell(
                    isFirst: true,
                    leading: const Icon(CupertinoIcons.globe),
                    title: 'Language',
                    subtitle: _currentLanguage,
                    onTap: _showLanguageSheet,
                  ),
                  _cell(
                    isLast: true,
                    leading: const Icon(CupertinoIcons.textformat_size),
                    title: 'Text Size',
                    subtitle: 'Adjust readability',
                    onTap: _showTextScaleDialog,
                  ),
                ]),
              ),

              // PERMISSIONS
              SliverToBoxAdapter(child: _sectionHeader('Permissions')),
              _collapsiblePermissionsSection(),

              // LEGAL & SUPPORT
              SliverToBoxAdapter(child: _sectionHeader('Legal & Support')),
              _collapsibleLegalSupportSection(),

              // ACCESSIBILITY
              SliverToBoxAdapter(child: _sectionHeader('Accessibility')),
              SliverToBoxAdapter(
                child: _group([
                  _cell(
                    isFirst: true,
                    isLast: true,
                    leading: const Icon(CupertinoIcons.device_phone_portrait),
                    title: 'Haptics & Sounds',
                    trailing: CupertinoSwitch(
                      value: _hapticsEnabled,
                      onChanged: _saveHapticsSetting,
                      activeColor: _primary,
                    ),
                    onTap: () => _saveHapticsSetting(!_hapticsEnabled),
                  ),
                ]),
              ),

              // MISC
              SliverToBoxAdapter(child: _sectionHeader('Misc')),
              SliverToBoxAdapter(
                child: _group([
                  _cell(
                    isFirst: true,
                    isLast: true,
                    leading: const Icon(CupertinoIcons.arrow_down_square),
                    title: 'App Updates',
                    subtitle: _isLoading
                        ? 'Checking…'
                        : _updateStatus == 'success'
                        ? 'Update available'
                        : 'You’re up to date',
                    trailing: _isLoading
                        ? const CupertinoActivityIndicator()
                        : (_updateStatus == 'success'
                        ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        '1',
                        style: TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    )
                        : const Icon(
                      CupertinoIcons.check_mark_circled,
                      color: CupertinoColors.activeGreen,
                    )),
                    onTap: _checkForUpdate,
                  ),
                ]),
              ),

              // ACCOUNT
              SliverToBoxAdapter(child: _sectionHeader('Account')),
              SliverToBoxAdapter(
                child: _group([
                  _cell(
                    isFirst: true,
                    isLast: true,
                    leading: const Icon(
                      CupertinoIcons.square_arrow_right,
                      color: CupertinoColors.systemRed,
                    ),
                    title: 'Sign Out',
                    titleColor: CupertinoColors.systemRed,
                    onTap: _signOut,
                  ),
                ]),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 26)),
            ],
          ),
        ),
      ),
    );
  }
}
