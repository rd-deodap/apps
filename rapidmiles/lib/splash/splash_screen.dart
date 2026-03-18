import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // App band karva mate
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:rapidmiles/home/home_screen.dart';
import 'package:rapidmiles/login/login_screen.dart';
import 'package:rapidmiles/onboarding/onboarding_screen.dart';
import 'package:rapidmiles/profile/profile.dart';

class SplashscreenView extends StatefulWidget {
  const SplashscreenView({super.key});

  @override
  State<SplashscreenView> createState() => _SplashscreenState();
}

class _SplashscreenState extends State<SplashscreenView> {
  static const String KEY_LOGIN = 'isLoggedIn';
  static const String API_URL =
      'https://customprint.deodap.com/common-page/rapidmiles';

  String _version = '—';
  bool _isBlocked = false; // Aa true hase to screen navigation atki jase

  @override
  void initState() {
    super.initState();
    _initAndCheck();
  }

  Future<void> _initAndCheck() async {
    // 1. Version melvo
    final info = await PackageInfo.fromPlatform();
    final currentVersion = info.version;
    setState(() => _version = currentVersion);

    // 2. Update/Maintenance Check karo
    await _checkForUpdate(currentVersion);

    // Jo Maintenance ke Update dialog khulyo hoy, to aagal na vadho
    if (_isBlocked) return;

    // 3. Login Check & Navigation
    final prefs = await SharedPreferences.getInstance();
    final bool isLoggedIn = prefs.getBool(KEY_LOGIN) ?? false;

    // Refresh permissions in background while splash is showing
    if (isLoggedIn) {
      await Future.wait([
        _refreshPermissions(prefs),
        Future.delayed(const Duration(seconds: 2)),
      ]);
    } else {
      await Future.delayed(const Duration(seconds: 2));
    }

    if (!mounted) return;

    if (isLoggedIn) {
      _goNext(const DashboardScreen());
    } else {
      _goNext(const OnboardingScreen());
    }
  }

  Future<void> _refreshPermissions(SharedPreferences prefs) async {
    try {
      final token = prefs.getString(SessionKeys.token) ?? "";
      if (token.isEmpty) return;

      final res = await http.get(
        Uri.parse("https://rapidmiles.in/api/shipment/v1/profile"),
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return;

      final decoded = json.decode(res.body);
      if (decoded is! Map || decoded["success"] != true) return;

      final data = decoded["data"] as Map<String, dynamic>? ?? {};
      final rawPermissions = data["permissions"];
      if (rawPermissions == null) return;

      final permissions = (rawPermissions is List)
          ? rawPermissions.map((e) => e.toString()).toList()
          : <String>[];

      final hasRtoDelivered = permissions.contains("rto-delivered");

      await prefs.setString(
        SessionKeys.permissionsJson,
        json.encode(permissions),
      );
      await prefs.setBool(SessionKeys.hasRtoDelivered, hasRtoDelivered);

      debugPrint('Permissions refreshed: $permissions');
    } catch (e) {
      debugPrint('Permission refresh failed (non-blocking): $e');
    }
  }

  Future<void> _checkForUpdate(String currentVersion) async {
    try {
      final response = await http.get(Uri.parse(API_URL));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        final String latestVersion = data['latest_version'] ?? '0.0.0';
        final String downloadLink = data['download_link'] ?? '';
        final bool forceUpdate = data['force_update'] ?? false;
        final String message = data['message'] ?? 'Update available';

        // Version compare karo
        if (_isNewVersion(latestVersion, currentVersion)) {
          setState(() {
            _isBlocked = true; // Navigation rokva mate
          });

          // LOGIC: Jo download link khali hoy to Maintenance Mode ganvo
          if (downloadLink.isEmpty) {
            _showMaintenanceDialog(message);
          } else {
            _showUpdateDialog(
              latestVersion,
              downloadLink,
              forceUpdate,
              message,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking update: $e');
    }
  }

  bool _isNewVersion(String latest, String current) {
    try {
      final List<int> latestParts = latest.split('.').map(int.parse).toList();
      final List<int> currentParts = current.split('.').map(int.parse).toList();

      for (int i = 0; i < latestParts.length; i++) {
        if (latestParts[i] > currentParts.elementAt(i)) return true;
        if (latestParts[i] < currentParts.elementAt(i)) return false;
      }
    } catch (e) {
      return false;
    }
    return false;
  }

  void _goNext(Widget screen) {
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(CupertinoPageRoute(builder: (_) => screen));
  }

  // --- DIALOG 1: MAINTENANCE (No Update Button) ---
  void _showMaintenanceDialog(String message) {
    if (!mounted) return;
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return PopScope(
          canPop: false,
          child: CupertinoAlertDialog(
            title: const Text('Server Maintenance ⚠️'),
            content: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(message, style: const TextStyle(fontSize: 14)),
            ),
            actions: [
              CupertinoDialogAction(
                child: const Text('Try Again'),
                onPressed: () {
                  Navigator.pop(context); // Dialog bandh karo
                  setState(() => _isBlocked = false); // Block hatavo
                  _initAndCheck(); // Farithi check karo
                },
              ),
              // Optional: App bandh karvanu button
              CupertinoDialogAction(
                isDestructiveAction: true,
                child: const Text('Exit App'),
                onPressed: () => SystemNavigator.pop(),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- DIALOG 2: UPDATE (With Update Button) ---
  void _showUpdateDialog(
    String latestVersion,
    String downloadLink,
    bool forceUpdate,
    String message,
  ) {
    if (!mounted) return;

    showCupertinoDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (context) {
        return PopScope(
          canPop: !forceUpdate,
          child: CupertinoAlertDialog(
            title: const Text('Update Available 🚀'),
            content: Text('$message\n\nv$latestVersion'),
            actions: [
              if (!forceUpdate)
                CupertinoDialogAction(
                  child: const Text('Skip'),
                  onPressed: () async {
                    Navigator.pop(context);
                    final prefs = await SharedPreferences.getInstance();
                    final bool isLoggedIn = prefs.getBool(KEY_LOGIN) ?? false;
                    _goNext(
                      isLoggedIn
                          ? const DashboardScreen()
                          : const OnboardingScreen(),
                    );
                  },
                ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () => _openDownloadLink(downloadLink),
                child: const Text('Update Now'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openDownloadLink(String url) async {
    try {
      if (url.isEmpty) throw 'URL is empty';
      if (!url.startsWith('http')) url = 'https://$url';

      final uri = Uri.parse(url);
      debugPrint('Attempting to launch URL: $url');

      // Try external application mode first
      if (await canLaunchUrl(uri)) {
        debugPrint('URL is launchable, opening with externalApplication mode');
        final success = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (success) {
          debugPrint('URL launched successfully');
          return;
        }
      }

      // Fallback: Try platform default mode
      debugPrint('Trying fallback with platformDefault mode');
      final success = await launchUrl(uri, mode: LaunchMode.platformDefault);
      if (success) {
        debugPrint('URL launched successfully with platformDefault');
        return;
      }

      // If all else fails
      throw 'Could not launch $url with any available method';
    } catch (e) {
      debugPrint('Error launching URL: $e');
      if (mounted) {
        _showErrorDialog(
          'Failed to Open Link',
          'Could not open the update link:\n\n$e\n\nPlease visit the link manually or check your internet connection.',
        );
      }
    }
  }

  void _showErrorDialog(String title, String message) {
    if (!mounted) return;
    showCupertinoDialog(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/logo2.png',
                    width: 260,
                    fit: BoxFit.contain,
                    errorBuilder: (c, o, s) =>
                        const Icon(Icons.image_not_supported, size: 100),
                  ),
                  const SizedBox(height: 30),
                  const CupertinoActivityIndicator(radius: 15.0),
                ],
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(
                          CupertinoIcons.briefcase,
                          size: 16,
                          color: Colors.black87,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Powered by DeoDap',
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Version: $_version',
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
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
}
