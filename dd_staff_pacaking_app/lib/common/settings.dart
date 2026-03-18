// lib/common/settings.dart
import 'dart:convert';

import 'package:deodap/commonmodule/appString.dart';
import 'package:deodap/widgets/extensions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart' hide Response;
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../commonmodule/appConstant.dart';
import '../utils/routes.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final GetStorage _box = GetStorage();

  // -----------------------------
  // Theme (blue + white, colorful but clean)
  // -----------------------------
  Color get _bluePrimary => const Color(0xFF1E5EFF);
  Color get _blueSoft => const Color(0xFFE9F0FF);
  Color get _bgTop => const Color(0xFFF1F6FF);
  Color get _bgBottom => const Color(0xFFFFFFFF);
  Color get _textDark => const Color(0xFF101828);

  TextStyle get _titleStyle => const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.2,
  );

  TextStyle get _sectionStyle => TextStyle(
    fontSize: 12,
    color: Colors.grey.shade700,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.7,
  );

  TextStyle get _subStyle => TextStyle(
    fontSize: 12.5,
    color: Colors.grey.shade700,
    fontWeight: FontWeight.w600,
  );

  // -----------------------------
  // State
  // -----------------------------
  bool _isLoadingUpdate = false;
  String _updateStatus = ''; // 'success' / 'error' / ''

  String _currentVersion = '1.0.0';
  bool _hapticsEnabled = true;
  double _textScaleFactor = 1.0;

  bool _permissionsExpanded = false;
  bool _legalExpanded = false;

  final Map<String, bool> _permissions = {
    'camera': false,
    'storage': false,
    'location': false,
    'notifications': false,
  };

  // -----------------------------
  // Update check config
  // -----------------------------
  static const String _updateUrl = 'https://api.vacalvers.com/api-packaging-app';
  static const String _appId = '1';
  static const String _apiKey = 'c77b74df-59f6-4257-b0ee-9b81e30026b1';

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
      if (!mounted) return;
      setState(() => _currentVersion = info.version);
    } catch (_) {}
  }

  Future<void> _loadSettings() async {
    _hapticsEnabled = _box.read('hapticsEnabled') ?? true;
    _textScaleFactor = (_box.read('textScaleFactor') ?? 1.0).toDouble();
    if (mounted) setState(() {});
    await _checkPermissions();
  }

  Future<void> _saveHapticsSetting(bool value) async {
    _box.write('hapticsEnabled', value);
    if (!mounted) return;
    setState(() => _hapticsEnabled = value);
  }

  Future<void> _saveTextScaleFactor(double value) async {
    _box.write('textScaleFactor', value);
    if (!mounted) return;
    setState(() => _textScaleFactor = value);
  }

  // =========================
  // PERMISSIONS
  // =========================
  Future<void> _checkPermissions() async {
    final cameraStatus = await Permission.camera.status;
    final storageStatus = await Permission.storage.status;
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
    Permission? type;
    switch (permission) {
      case 'camera':
        type = Permission.camera;
        break;
      case 'storage':
        type = Permission.storage;
        break;
      case 'location':
        type = Permission.location;
        break;
      case 'notifications':
        type = Permission.notification;
        break;
    }
    if (type == null) return;

    final status = await type.status;
    if (status.isGranted) {
      _showDialog(
        title: '${permission.toUpperCase()} Permission',
        message: 'Already allowed. To deny, open app settings.',
        showSettings: true,
      );
      return;
    }

    final ok = await _askAllowDialog(permission);
    if (ok != true) return;

    final result = await type.request();
    if (!mounted) return;

    setState(() => _permissions[permission] = result.isGranted);

    if (result.isGranted) {
      _showDialog(title: 'Permission', message: '${permission.toUpperCase()} allowed.');
    } else if (result.isPermanentlyDenied) {
      _showDialog(
        title: 'Permission',
        message: '${permission.toUpperCase()} is permanently denied. Enable it in App Settings.',
        showSettings: true,
      );
    } else {
      _showDialog(title: 'Permission', message: '${permission.toUpperCase()} denied.');
    }
  }

  Future<bool?> _askAllowDialog(String permission) {
    return showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text('Allow ${permission.toUpperCase()}?'),
        content: Text('This app needs access to $permission for features to work properly.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Allow'),
          ),
        ],
      ),
    );
  }

  void _openAppSettings() {
    openAppSettings().then((_) {
      Future.delayed(const Duration(milliseconds: 700), () => _checkPermissions());
    });
  }

  void _showDialog({
    required String title,
    required String message,
    bool showSettings = false,
  }) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          if (showSettings)
            CupertinoDialogAction(
              onPressed: () {
                Navigator.pop(context);
                _openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // =========================
  // UPDATE CHECK
  // =========================
  Future<void> _checkForUpdate() async {
    if (mounted) setState(() => _isLoadingUpdate = true);

    try {
      final res = await http.post(
        Uri.parse(_updateUrl),
        body: {
          'version': _currentVersion,
          'app_id': _appId,
          'api_key': _apiKey,
        },
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final st = (data is Map && data['status'] != null) ? data['status'].toString() : '';
        setState(() => _updateStatus = st == 'success' ? 'success' : 'error');
      } else {
        setState(() => _updateStatus = 'error');
      }
    } catch (_) {
      if (mounted) setState(() => _updateStatus = 'error');
    } finally {
      if (mounted) setState(() => _isLoadingUpdate = false);
    }
  }

  // =========================
  // LAUNCHERS (Help)
  // =========================
  Future<void> _launchUrlExternal(Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      _showDialog(title: 'Error', message: 'Could not open: ${uri.toString()}');
    }
  }

  Future<void> _launchWhatsApp(String phone, String message) async {
    final encoded = Uri.encodeFull(message);
    await _launchUrlExternal(Uri.parse('https://wa.me/$phone?text=$encoded'));
  }

  Future<void> _launchHelpWhatsApp() async {
    await _launchWhatsApp(
      '919889663378',
      'Hello DeoDap Support team, I need help regarding the app.',
    );
  }

  Future<void> _launchPhone(String phone) async {
    await _launchUrlExternal(Uri.parse('tel:$phone'));
  }

  void _showHelpCenter() {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Help & Support'),
        content: const Text('How can we help you today?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () {
              Navigator.pop(context);
              _launchHelpWhatsApp();
            },
            child: const Text('Chat on WhatsApp'),
          ),
          CupertinoDialogAction(
            onPressed: () {
              Navigator.pop(context);
              _launchPhone('+919889663378');
            },
            child: const Text('Call Support'),
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

  // =========================
  // NAVIGATION (your Get routes)
  // =========================
  void _goHome() {
    Get.offAllNamed(Routes.homeRoute);
  }

  Future<void> _signOut() async {
    final yes = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Sign Out?'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (yes != true) return;

    _box.erase();
    _box.write(AppConstant.IS_LOGIN, false);
    Get.offAllNamed(Routes.loginRoute);
  }

  // =========================
  // UI HELPERS
  // =========================
  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
      child: Text(text.toUpperCase(), style: _sectionStyle),
    );
  }

  Widget _group({required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    bool isFirst = false,
    bool isLast = false,
    Color? titleColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.vertical(
        top: isFirst ? const Radius.circular(18) : Radius.zero,
        bottom: isLast ? const Radius.circular(18) : Radius.zero,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: isLast ? BorderSide.none : BorderSide(color: Colors.grey.shade200),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _blueSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: _bluePrimary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: titleColor ?? _textDark,
                      fontWeight: FontWeight.w900,
                      fontSize: 13.8,
                    ),
                  ),
                  if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(subtitle, style: _subStyle),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey.shade500,
                ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String text, {Color? bg, Color? fg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg ?? _bluePrimary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _bluePrimary.withOpacity(0.20)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg ?? _bluePrimary,
          fontWeight: FontWeight.w900,
          fontSize: 11.5,
        ),
      ),
    );
  }

  Widget _permissionRow(
      String key,
      String title,
      String desc,
      IconData icon, {
        bool isLast = false,
      }) {
    final granted = _permissions[key] ?? false;

    return _tile(
      icon: icon,
      title: title,
      subtitle: desc,
      isLast: isLast,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: granted ? _bluePrimary.withOpacity(0.08) : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: granted ? _bluePrimary.withOpacity(0.25) : Colors.black.withOpacity(0.10),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              granted ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
              size: 14,
              color: _bluePrimary,
            ),
            const SizedBox(width: 6),
            Text(
              granted ? "Allowed" : "Allow",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: _bluePrimary,
              ),
            ),
          ],
        ),
      ),
      onTap: () => _togglePermission(key),
    );
  }

  Future<void> _openTextSizeSheet() async {
    await showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: const Text('Text Size'),
        message: const Text('Adjust the text size for better readability'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              _saveTextScaleFactor(0.9);
              Navigator.pop(context);
            },
            child: const Text('Small (90%)'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              _saveTextScaleFactor(1.0);
              Navigator.pop(context);
            },
            isDefaultAction: true,
            child: const Text('Normal (100%)'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              _saveTextScaleFactor(1.2);
              Navigator.pop(context);
            },
            child: const Text('Large (120%)'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              _saveTextScaleFactor(1.4);
              Navigator.pop(context);
            },
            child: const Text('Extra Large (140%)'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
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
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          centerTitle: true,
          leading: IconButton(
            onPressed: _goHome,
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: _textDark, size: 18),
          ),
          title: Text(
            "Settings",
            style: TextStyle(color: _textDark, fontWeight: FontWeight.w900, fontSize: 14.5),
          ),
          actions: [
            PopupMenuButton<String>(
              icon: Icon(Icons.more_horiz_rounded, color: _textDark),
              onSelected: (v) {
                if (v == 'help') _showHelpCenter();
                if (v == 'profile') Get.toNamed(Routes.profileRoute);
                if (v == 'reset') {
                  _showDialog(
                    title: 'Reset Password',
                    message: 'Please contact System Administrator for password reset.',
                  );
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'profile',
                  child: Row(
                    children: [
                      Icon(Icons.person_rounded, color: _bluePrimary, size: 18),
                      const SizedBox(width: 10),
                      const Text('Profile'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'reset',
                  child: Row(
                    children: [
                      Icon(Icons.lock_reset_rounded, color: _bluePrimary, size: 18),
                      const SizedBox(width: 10),
                      const Text('Reset Password'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'help',
                  child: Row(
                    children: [
                      Icon(Icons.help_rounded, color: _bluePrimary, size: 18),
                      const SizedBox(width: 10),
                      const Text('Help'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: SafeArea(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_bgTop, _bgBottom, _bgBottom],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: RefreshIndicator(
              onRefresh: _checkForUpdate,
              color: _bluePrimary,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(0, 10, 0, 18),
                children: [
                  // header card
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: _bluePrimary.withOpacity(0.10),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: _blueSoft,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(Icons.settings_rounded, color: _bluePrimary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("App Settings", style: _titleStyle.copyWith(color: _textDark)),
                                const SizedBox(height: 4),
                                Text("Version: $_currentVersion", style: _subStyle),
                              ],
                            ),
                          ),
                          if (_isLoadingUpdate)
                            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          else if (_updateStatus == 'success')
                            _pill("Update", bg: _bluePrimary, fg: Colors.white)
                          else
                            Icon(Icons.check_circle_rounded, color: Colors.green.shade600),
                        ],
                      ),
                    ),
                  ),

                  // COMMON
                  _sectionHeader("Common"),
                  _group(
                    children: [
                      _tile(
                        icon: Icons.language_rounded,
                        title: "Language",
                        subtitle: "English (more coming soon)",
                        isFirst: true,
                        onTap: () {
                          _showDialog(title: "Language", message: "Only English is available currently.");
                        },
                      ),
                      _tile(
                        icon: Icons.text_fields_rounded,
                        title: "Text Size",
                        subtitle: "Adjust readability",
                        isLast: true,
                        onTap: _openTextSizeSheet,
                      ),
                    ],
                  ),

                  // PERMISSIONS
                  _sectionHeader("Permissions"),
                  _group(
                    children: [
                      _tile(
                        icon: Icons.security_rounded,
                        title: "Permissions",
                        subtitle: _permissionsExpanded ? "Tap to minimize" : "Camera, Storage, Location, Notifications",
                        isFirst: true,
                        isLast: !_permissionsExpanded,
                        trailing: Icon(
                          _permissionsExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                          color: _bluePrimary,
                        ),
                        onTap: () => setState(() => _permissionsExpanded = !_permissionsExpanded),
                      ),
                      if (_permissionsExpanded) ...[
                        _permissionRow('camera', "Camera", "Scan QR/Barcode & take photos", Icons.camera_alt_rounded),
                        _permissionRow('storage', "Storage", "Save / read files", Icons.folder_rounded),
                        _permissionRow('location', "Location", "Location access for app flow", Icons.location_on_rounded),
                        _permissionRow('notifications', "Notifications", "Receive app notifications", Icons.notifications_active_rounded, isLast: true),
                      ],
                    ],
                  ),

                  // LEGAL & SUPPORT
                  _sectionHeader("Legal & Support"),
                  _group(
                    children: [
                      _tile(
                        icon: Icons.help_center_rounded,
                        title: "Legal & Support",
                        subtitle: _legalExpanded ? "Tap to minimize" : "Help, Contact, Terms, Privacy, About",
                        isFirst: true,
                        isLast: !_legalExpanded,
                        trailing: Icon(
                          _legalExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                          color: _bluePrimary,
                        ),
                        onTap: () => setState(() => _legalExpanded = !_legalExpanded),
                      ),
                      if (_legalExpanded) ...[
                        _tile(
                          icon: Icons.question_answer_rounded,
                          title: "Help Center / FAQs",
                          onTap: _showHelpCenter,
                        ),
                        _tile(
                          icon: Icons.chat_rounded,
                          title: "Contact Support",
                          subtitle: "WhatsApp / Phone",
                          onTap: _launchHelpWhatsApp,
                        ),
                        _tile(
                          icon: Icons.article_rounded,
                          title: "Terms & Conditions",
                          onTap: () => Get.toNamed(Routes.termsRoute),
                        ),
                        _tile(
                          icon: Icons.privacy_tip_rounded,
                          title: "Privacy Policy",
                          onTap: () => Get.toNamed(Routes.privacyRoute),
                        ),
                        _tile(
                          icon: Icons.info_rounded,
                          title: "About App",
                          subtitle: "Version $_currentVersion",
                          isLast: true,
                          onTap: () => Get.toNamed(Routes.aboutRoute),
                        ),
                      ],
                    ],
                  ),

                  // ACCESSIBILITY
                  _sectionHeader("Accessibility"),
                  _group(
                    children: [
                      _tile(
                        icon: Icons.vibration_rounded,
                        title: "Haptics & Sounds",
                        subtitle: _hapticsEnabled ? "Enabled" : "Disabled",
                        isFirst: true,
                        isLast: true,
                        trailing: Switch(
                          value: _hapticsEnabled,
                          activeColor: _bluePrimary,
                          onChanged: _saveHapticsSetting,
                        ),
                        onTap: () => _saveHapticsSetting(!_hapticsEnabled),
                      ),
                    ],
                  ),

                  // MISC
                  _sectionHeader("Misc"),
                  _group(
                    children: [
                      _tile(
                        icon: Icons.system_update_alt_rounded,
                        title: "App Updates",
                        subtitle: _isLoadingUpdate
                            ? "Checking…"
                            : (_updateStatus == 'success'
                            ? "Update available"
                            : (_updateStatus == 'error' ? "Could not check update" : "You’re up to date")),
                        isFirst: true,
                        isLast: true,
                        trailing: _isLoadingUpdate
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : (_updateStatus == 'success'
                            ? _pill("1", bg: _bluePrimary, fg: Colors.white)
                            : Icon(Icons.check_circle_rounded, color: Colors.green.shade600)),
                        onTap: _checkForUpdate,
                      ),
                    ],
                  ),

                  // ACCOUNT
                  _sectionHeader("Account"),
                  _group(
                    children: [
                      _tile(
                        icon: Icons.logout_rounded,
                        title: "Sign Out",
                        subtitle: "Logout from this device",
                        isFirst: true,
                        isLast: true,
                        titleColor: Colors.red.shade700,
                        trailing: Icon(Icons.chevron_right_rounded, color: Colors.red.shade300),
                        onTap: _signOut,
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
