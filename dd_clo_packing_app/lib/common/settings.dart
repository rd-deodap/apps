// lib/common/settings.dart
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show Colors, PopupMenuItem, RelativeRect, showMenu; // for popup menu
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../route/app_route.dart';

// Theme Colors
const Color kIOSPurple = Color(0xFF011D3E);
const Color kIOSPurpleLight = Color(0xFFE3E9F3);
const Color kIOSPurpleDark =  Color(0xFF001528);
const Color kBg = Color(0xFFF7F8FA);

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

  // Profile variables (basic only – no image upload)
  String _userName = '';
  String _userEmail = '';
  String _employeeCode = '';

  // API Configuration (kept for future use)
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

  Color get _primaryBlue => kIOSPurple;

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
        setState(() {
          _currentVersion = info.version;
        });
      }
    } catch (_) {
      // Keep default version if package info fails
    }
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _hapticsEnabled = prefs.getBool('hapticsEnabled') ?? true;
          _textScaleFactor = prefs.getDouble('textScaleFactor') ?? 1.0;

          // Load user profile data
          _userName = prefs.getString('userName') ?? 'wms user';
          _userEmail = prefs.getString('userEmail') ?? '';
          _employeeCode = prefs.getString('employeeCode') ?? '';

          _userProfile = {};
        });
      }
    } catch (_) {
      // Keep defaults if loading fails
    }
    await _checkPermissions();
  }

  Future<void> _saveHapticsSetting(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hapticsEnabled', value);
      if (mounted) {
        setState(() {
          _hapticsEnabled = value;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveTextScaleFactor(double value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('textScaleFactor', value);
      if (mounted) {
        setState(() {
          _textScaleFactor = value;
        });
      }
    } catch (_) {}
  }

  // =========================
  // PERMISSIONS
  // =========================

  Future<void> _checkPermissions() async {
    final cameraStatus = await Permission.camera.status;
    final storageStatus = await Permission.storage.status;
    final locationStatus = await Permission.location.status;
    final notificationStatus = await Permission.notification.status;

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

    if (permissionType != null) {
      final currentStatus = await permissionType.status;

      if (currentStatus.isGranted) {
        _showPermissionDialog(
          permission,
          'This permission is currently allowed. To deny this permission, you need to go to app settings.',
          showSettingsOption: true,
        );
      } else {
        _showRequestPermissionDialog(permission, permissionType);
      }
    }
  }

  void _showRequestPermissionDialog(
      String permission, Permission permissionType) {
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

  Future<void> _requestPermission(
      String permission, Permission permissionType) async {
    final status = await permissionType.request();
    setState(() {
      _permissions[permission] = status.isGranted;
    });

    if (status.isGranted) {
      _showPermissionStatus(
        '✅ ${permission.toUpperCase()} permission allowed successfully!',
      );
    } else if (status.isPermanentlyDenied) {
      _showPermissionDialog(
        permission,
        '${permission.toUpperCase()} permission was permanently denied. Please enable it in app settings to use this feature.',
        showSettingsOption: true,
      );
    } else {
      _showPermissionStatus('❌ ${permission.toUpperCase()} permission denied');
    }
  }

  void _showPermissionDialog(String permission, String message,
      {bool showSettingsOption = false}) {
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
            child: const Text('Cancel'),
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
      Future.delayed(const Duration(seconds: 1), () {
        _checkPermissions();
      });
    });
  }

  // =========================
  // UPDATE CHECK
  // =========================

  Future<void> _checkForUpdate() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.post(
        Uri.parse('https://api.vacalvers.com/api-packaging-app'),
        body: {'version': _appVersion},
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          _updateStatus = data['status'] == 'success' ? 'success' : 'error';
        });
      } else {
        setState(() => _updateStatus = 'error');
      }
    } catch (_) {
      setState(() => _updateStatus = 'error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showLanguageSheet() async {
    await showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoTheme(
        data: CupertinoTheme.of(context).copyWith(primaryColor: _primaryBlue),
        child: CupertinoActionSheet(
          title: const Text('Select your Language'),
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
      ),
    );
  }

  void _showTextScaleDialog() async {
    await showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoTheme(
        data: CupertinoTheme.of(context).copyWith(primaryColor: _primaryBlue),
        child: CupertinoActionSheet(
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
      ),
    );
  }
  void _showAppInfoDialog() async {
    await showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoTheme(
        data: CupertinoTheme.of(context).copyWith(primaryColor: _primaryBlue),
        child: CupertinoAlertDialog(
          title: const Text(
            'App Information',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CupertinoColors.secondarySystemGroupedBackground,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _iosInfoRow('Company', 'Deodap International Pvt Ltd'),
                    const SizedBox(height: 12),
                    _iosInfoRow('Application',
                        'DeoDap Staff Packaging Management System'),
                    const SizedBox(height: 12),
                    _iosInfoRow('Version', _currentVersion),
                    const SizedBox(height: 12),
                    _iosInfoRow(
                        'Copyright', '© 2025 vacalvers.com Inc.'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'OK',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iosInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: CupertinoColors.systemBlue,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            color: CupertinoColors.label,
            fontWeight: FontWeight.w400,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }

  Future<void> _signOut() async {
    final yes = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Sign Out?'),
        content: const Text(
          'Are you sure you want to Sign Out from DeoDap Staff Packaging App?',
        ),
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
      if (mounted) {
        Get.offAllNamed(AppRoutes.onboarding);
      }
    }
  }
  void _openPopupMenu() async {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final RenderBox button = context.findRenderObject() as RenderBox;
    final Offset buttonPosition =
        button.localToGlobal(Offset.zero, ancestor: overlay);

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
              Icon(CupertinoIcons.person_circle,
                  size: 20, color: _primaryBlue),
              const SizedBox(width: 12),
              const Text('Profile'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'reset_password',
          child: Row(
            children: [
              Icon(CupertinoIcons.lock_shield_fill,
                  size: 20, color: _primaryBlue),
              const SizedBox(width: 12),
              const Text('Reset Password'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'help',
          child: Row(
            children: [
              Icon(CupertinoIcons.question_circle_fill,
                  size: 20, color: _primaryBlue),
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
      if (value != null) {
        switch (value) {
          case 'profile':
            Get.toNamed(AppRoutes.profile);
            break;
          case 'reset_password':
            _showResetPasswordDialog();
            break;
          case 'help':
            _showHelpCenter();
            break;
        }
      }
    });
  }
  

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

  void _showAboutDialog() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('About DeoDap Staff Packaging App'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'DeoDap Staff Packaging App v1.0.0\n',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.none,
                ),
              ),
              Text(
                'DeoDap is a privately owned Indian trading and distribution company with years of experience in importing and distributing products. Our core expertise is to source, market, and distribute the best-selling products from both domestic and international markets.\n\n',
                style: TextStyle(
                  fontSize: 14,
                  decoration: TextDecoration.none,
                ),
              ),
              Text(
                'Our Mission:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.none,
                ),
              ),
              Text(
                '• Support the Make in India initiative\n'
                '• Identify high-demand imported products\n'
                '• Help Indian manufacturers produce similar products\n'
                '• Build a strong distribution network\n\n',
                style: TextStyle(
                  fontSize: 14,
                  decoration: TextDecoration.none,
                ),
              ),
              Text(
                'Our Achievements:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.none,
                ),
              ),
              Text(
                '• 10,000,000+ orders fulfilled\n'
                '• Presence on Amazon, Flipkart, and Meesho\n'
                '• Direct partnerships with resellers\n'
                '• Own inventory for better pricing and faster supply\n\n',
                style: TextStyle(
                  fontSize: 14,
                  decoration: TextDecoration.none,
                ),
              ),
              Text(
                ' 2025 DeoDap International Pvt Ltd.\nAll rights reserved.',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
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

  Future<void> _launchContactWhatsApp() async {
    await _launchWhatsApp(
      '919638666602',
      'Hello DeoDap International Pvt Ltd',
    );
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    await _launchUrlExternal(uri);
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    await _launchUrlExternal(uri);
  }

  void _showContactDialog() {
    final address =
        '📍 Address:\nDeoDap International Pvt. Ltd.\n'
        'Plot No. 1 to 10, Next to Patanjali Warehouse\n'
        'RUDA Transport Area, Near Saat Hanuman Mandir\n'
        'Opp. Rangoli Masala, Village Navagam\n'
        'Rajkot – 360003, Gujarat, India';

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Contact Us'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'We\'re here to help you with any questions or issues.\n',
              ),
              const SizedBox(height: 8),
              Text(address),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => _launchUrlExternal(
                  Uri.parse('https://maps.app.goo.gl/dXzcBqTx5DHY87U77'),
                ),
                child: const Row(
                  children: [
                    Icon(CupertinoIcons.map_fill,
                        size: 16, color: CupertinoColors.activeBlue),
                    SizedBox(width: 4),
                    Text(
                      'View on Map',
                      style: TextStyle(
                        color: CupertinoColors.activeBlue,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: _launchContactWhatsApp,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.chat_bubble_2_fill, size: 20),
                SizedBox(width: 8),
                Text('WhatsApp'),
              ],
            ),
          ),
          CupertinoDialogAction(
            onPressed: () => _launchPhone('+919638666602'),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.phone_fill, size: 20),
                SizedBox(width: 8),
                Text('Call Us'),
              ],
            ),
          ),
          CupertinoDialogAction(
            onPressed: () => _launchEmail('care@deodap.com'),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.mail_solid, size: 18),
                SizedBox(width: 8),
                Text('Email Us'),
              ],
            ),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            isDestructiveAction: true,
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Simple profile info dialog (optional – routes already go to ProfileScreen)
  void _showProfileDialog() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoTheme(
        data: CupertinoTheme.of(context).copyWith(primaryColor: _primaryBlue),
        child: CupertinoAlertDialog(
          title: const Text(
            'Profile',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Icon(
                CupertinoIcons.person_circle_fill,
                size: 60,
                color: _primaryBlue,
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CupertinoColors.secondarySystemGroupedBackground,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Username',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.systemBlue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _userProfile['user']?['name'] ?? _userName,
                      style: const TextStyle(
                        fontSize: 16,
                        color: CupertinoColors.label,
                      ),
                    ),
                    if (_employeeCode.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Employee Code',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.systemBlue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _employeeCode,
                        style: const TextStyle(
                          fontSize: 16,
                          color: CupertinoColors.label,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Text(
                      'Email',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.systemBlue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _userProfile['user']?['email'] ?? _userEmail,
                      style: const TextStyle(
                        fontSize: 16,
                        color: CupertinoColors.label,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Close',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetPasswordDialog() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoTheme(
        data: CupertinoTheme.of(context).copyWith(primaryColor: _primaryBlue),
        child: CupertinoAlertDialog(
          title: const Text(
            'Reset Password',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 16),
              Icon(
                CupertinoIcons.lock_shield_fill,
                size: 48,
                color: CupertinoColors.systemOrange,
              ),
              SizedBox(height: 16),
              Text(
                'Please contact System Administrator for password reset.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: CupertinoColors.label,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'No password reset allowed from app side',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: CupertinoColors.systemGrey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'OK',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLegalDocument(String title, String content) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSocialMediaDialog() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Connect With Us'),
        content: const Text('Follow us on our social media platforms'),
        actions: [
          CupertinoDialogAction(
            onPressed: () {
              _launchUrlExternal(Uri.parse(
                  'https://www.youtube.com/@OnlineBusinessIdeasbyDeoDap'));
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.play_rectangle_fill,
                    color: Colors.red, size: 20),
                SizedBox(width: 8),
                Text('YouTube'),
              ],
            ),
          ),
          CupertinoDialogAction(
            onPressed: () {
              _launchUrlExternal(
                  Uri.parse('https://www.facebook.com/deodap/'));
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.arrow_up_right_square_fill,
                    color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Text('Facebook'),
              ],
            ),
          ),
          CupertinoDialogAction(
            onPressed: () {
              _launchUrlExternal(Uri.parse(
                  'https://www.instagram.com/deodap_india/'));
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.arrow_up_right_square_fill,
                    color: Colors.purple, size: 20),
                SizedBox(width: 8),
                Text('Instagram'),
              ],
            ),
          ),
          CupertinoDialogAction(
            onPressed: () {
              _launchUrlExternal(Uri.parse('https://t.me/s/DeoDap'));
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.paperclip,
                    color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Text('Telegram'),
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

  // =========================
  // LIST CELLS / GROUPS
  // =========================

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          letterSpacing: 0.4,
          color: CupertinoColors.systemGrey,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.none,
        ),
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
      top: isFirst ? const Radius.circular(12) : Radius.zero,
      bottom: isLast ? const Radius.circular(12) : Radius.zero,
    );

    return ClipRRect(
      borderRadius: radius,
      child: Container(
        color: CupertinoColors.systemBackground,
        child: CupertinoButton(
          onPressed: onTap,
          padding: EdgeInsets.zero,
          pressedOpacity: 0.6,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: isLast
                    ? BorderSide.none
                    : const BorderSide(
                        color: CupertinoColors.separator,
                        width: 0.3,
                      ),
              ),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Center(
                    child: IconTheme(
                      data: IconThemeData(color: _primaryBlue),
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
                          color: titleColor ?? CupertinoColors.label,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      if (subtitle != null && subtitle.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            subtitle,
                            style: const TextStyle(
                              fontSize: 13,
                              color: CupertinoColors.systemGrey,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
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
      ),
    );
  }

  Widget _group(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: CupertinoColors.secondarySystemGroupedBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: children),
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

    return ClipRRect(
      borderRadius: BorderRadius.vertical(
        top: isFirst ? const Radius.circular(12) : Radius.zero,
        bottom: isLast ? const Radius.circular(12) : Radius.zero,
      ),
      child: Container(
        color: CupertinoColors.systemBackground,
        child: CupertinoButton(
          onPressed: () => _togglePermission(permission),
          padding: EdgeInsets.zero,
          pressedOpacity: 0.6,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: isLast
                    ? BorderSide.none
                    : const BorderSide(
                        color: CupertinoColors.separator,
                        width: 0.3,
                      ),
              ),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Center(
                    child: IconTheme(
                      data: IconThemeData(color: _primaryBlue),
                      child: Icon(icon),
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
                        style: const TextStyle(
                          fontSize: 16,
                          color: CupertinoColors.label,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: CupertinoColors.systemGrey,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isGranted
                        ? _primaryBlue.withOpacity(0.1)
                        : _primaryBlue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isGranted
                          ? _primaryBlue.withOpacity(0.3)
                          : _primaryBlue.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isGranted
                            ? CupertinoIcons.check_mark_circled_solid
                            : CupertinoIcons.add_circled,
                        size: 12,
                        color: _primaryBlue,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isGranted ? 'Allowed' : 'Tap to Allow',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _primaryBlue,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  isGranted
                      ? CupertinoIcons.settings
                      : CupertinoIcons.plus_circle,
                  size: 16,
                  color: _primaryBlue,
                ),
              ],
            ),
          ),
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
          subtitle: _permissionsExpanded
              ? 'Tap to minimize permissions'
              : 'Camera, Storage, Location, Notifications',
          trailing: Icon(
            _permissionsExpanded
                ? CupertinoIcons.chevron_up
                : CupertinoIcons.chevron_down,
            size: 16,
            color: _primaryBlue,
          ),
          onTap: () {
            setState(() {
              _permissionsExpanded = !_permissionsExpanded;
            });
          },
        ),
        if (_permissionsExpanded) ...[
          _permissionCell(
            permission: 'camera',
            title: 'Camera',
            description: 'Access camera for features in app',
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
            isLast: true,
            permission: 'notifications',
            title: 'Notifications',
            description: 'Receive app notifications',
            icon: CupertinoIcons.bell,
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
          subtitle: _legalSupportExpanded
              ? 'Tap to minimize section'
              : 'Help, Contact, Terms, Privacy, About',
          trailing: Icon(
            _legalSupportExpanded
                ? CupertinoIcons.chevron_up
                : CupertinoIcons.chevron_down,
            size: 16,
            color: _primaryBlue,
          ),
          onTap: () {
            setState(() {
              _legalSupportExpanded = !_legalSupportExpanded;
            });
          },
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
            onTap: _showContactDialog,
          ),
          _cell(
            leading: const Icon(CupertinoIcons.doc_text_fill),
            title: 'Terms & Conditions',
            // ROUTE to separate TermsConditionsScreen
            onTap: () => Get.toNamed(AppRoutes.termsAndConditions),
          ),
          _cell(
            leading: const Icon(CupertinoIcons.lock_shield_fill),
            title: 'Privacy Policy',
            // ROUTE to separate PrivacyPolicyScreen
            onTap: () => Get.toNamed(AppRoutes.privacyPolicy),
          ),
          _cell(
            leading: const Icon(CupertinoIcons.info_circle_fill),
            title: 'About App / Credits',
            // ROUTE to separate AboutUsScreen
            onTap: () => Get.toNamed(AppRoutes.aboutUs),
          ),
          _cell(
            isLast: true,
            leading: const Icon(CupertinoIcons.app_badge),
            title: 'App Info',
            subtitle: 'Version $_currentVersion',
            // ROUTE to separate AppInfoScreen
            onTap: () => Get.toNamed(AppRoutes.appinfo),
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
    final theme = CupertinoTheme.of(context);
    return CupertinoTheme(
      data: theme.copyWith(primaryColor: _primaryBlue),
      child: CupertinoPageScaffold(
        backgroundColor: kBg,
        navigationBar: CupertinoNavigationBar(
          border: null,
          middle: const Text('Settings'),
          previousPageTitle: 'Back',
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _openPopupMenu,
            child: Icon(
              CupertinoIcons.ellipsis_circle,
              size: 24,
              color: _primaryBlue,
            ),
          ),
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.of(context).maybePop(),
            child: Icon(
              CupertinoIcons.chevron_back,
              size: 22,
              color: _primaryBlue,
            ),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              CupertinoSliverRefreshControl(
                onRefresh: _checkForUpdate,
                builder: (context, mode, pulledExtent,
                    refreshTriggerPullDistance, refreshIndicatorExtent) {
                  return const Center(
                    child: CupertinoActivityIndicator(),
                  );
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
                    leading:
                        const Icon(CupertinoIcons.square_stack_3d_up),
                    title: 'Storage and Data',
                    subtitle: 'Network usage, Permissions',
                    onTap: () {
                      // Future screen placeholder
                    },
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
                    leading: const Icon(
                        CupertinoIcons.device_phone_portrait),
                    title: 'Haptics & Sounds',
                    trailing: CupertinoSwitch(
                      value: _hapticsEnabled,
                      onChanged: _saveHapticsSetting,
                      activeColor: _primaryBlue,
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
                    leading: const Icon(
                        CupertinoIcons.arrow_down_square),
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _primaryBlue,
                                  borderRadius:
                                      BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  '1',
                                  style: TextStyle(
                                    color: CupertinoColors.white,
                                    fontSize: 12,
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

              // SIGN OUT
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

              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }
}
