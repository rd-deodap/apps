import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../route/app_route.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // ----------------------------
  // CONFIG (move to AppConstants if you want)
  // ----------------------------
  static const String KEY_LOGIN = 'isLoggedIn';

  // Your API config
  static const String apiBaseUrl = 'https://api.vacalvers.com/api-clo-packaging-app'; // <-- set this
  static const String appInfoPath = '/app_info';
  static const String appId = '2';
  static const String apiKey = '022782f3-c4aa-443a-9f14-7698c648a137';

  // Fallback update link if API does not provide update_url
  static const String fallbackUpdateUrl = 'https://vacalvers.com';

  String _localVersion = '—';
  bool _loading = true;

  // API state
  String? _apiVersion;
  String? _apiUpdateUrl;
  bool _isOfflineFromApi = false;

  @override
  void initState() {
    super.initState();
    _initAndCheck();
  }

  Future<void> _initAndCheck() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool isLoggedIn = prefs.getBool(KEY_LOGIN) ?? false;

      // Local app version
      final info = await PackageInfo.fromPlatform();
      _localVersion = info.version;

      // Splash minimum visible duration
      final splashDelay = Future.delayed(const Duration(seconds: 2));

      // Fetch API app_info (with timeout)
      final apiFuture = _fetchAppInfo().timeout(const Duration(seconds: 12));

      await Future.wait([splashDelay, apiFuture]);

      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      // 1) If API says offline/maintenance
      if (_isOfflineFromApi) {
        return; // UI already shows maintenance screen
      }

      // 2) If update is required
      if (_apiVersion != null && _isUpdateRequired(_localVersion, _apiVersion!)) {
        return; // UI already shows update screen
      }

      // 3) Normal navigation
      if (isLoggedIn) {
        Get.offNamed(AppRoutes.home);
      } else {
        Get.offNamed(AppRoutes.onboarding);
      }
    } catch (_) {
      // If anything fails (API down, timeout, etc.), proceed normally after splash
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      final prefs = await SharedPreferences.getInstance();
      final bool isLoggedIn = prefs.getBool(KEY_LOGIN) ?? false;

      if (isLoggedIn) {
        Get.offNamed(AppRoutes.home);
      } else {
        Get.offNamed(AppRoutes.onboarding);
      }
    }
  }

  Future<void> _fetchAppInfo() async {
    final uri = Uri.parse('$apiBaseUrl$appInfoPath');

    final req = http.Request('GET', uri)
      ..headers.addAll({
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      })
      ..body = jsonEncode({
        'app_id': appId,
        'api_key': apiKey,
      });

    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('app_info failed: ${resp.statusCode}');
    }

    final decoded = jsonDecode(resp.body);
    final data = decoded is Map<String, dynamic> ? decoded['data'] : null;

    if (data is! Map<String, dynamic>) return;

    final version = data['version']?.toString();
    final isOffline = data['is_offline']?.toString() == '1';

    // OPTIONAL: ask backend to add "update_url" in API response
    final updateUrl = (data['update_url'] ?? data['apk_url'] ?? data['play_store_url'])?.toString();

    _apiVersion = version;
    _isOfflineFromApi = isOffline;
    _apiUpdateUrl = updateUrl;
  }

  bool _isUpdateRequired(String local, String remote) {
    // returns true if remote > local
    return _compareVersions(remote, local) > 0;
  }

  /// Compare semantic-ish versions like:
  /// "1", "1.0", "1.0.3", "2.1.0+5" etc.
  /// Returns:
  ///  1 if a>b, 0 if equal, -1 if a<b
  int _compareVersions(String a, String b) {
    // remove build metadata like +5
    final aClean = a.split('+').first.trim();
    final bClean = b.split('+').first.trim();

    List<int> parseParts(String v) {
      return v
          .split('.')
          .map((e) => int.tryParse(e.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
          .toList();
    }

    final ap = parseParts(aClean);
    final bp = parseParts(bClean);

    final maxLen = ap.length > bp.length ? ap.length : bp.length;
    for (int i = 0; i < maxLen; i++) {
      final ai = i < ap.length ? ap[i] : 0;
      final bi = i < bp.length ? bp[i] : 0;
      if (ai > bi) return 1;
      if (ai < bi) return -1;
    }
    return 0;
  }

  Future<void> _openUpdateLink() async {
    final url = _apiUpdateUrl?.trim().isNotEmpty == true ? _apiUpdateUrl!.trim() : fallbackUpdateUrl;
    final uri = Uri.parse(url);

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      // If launch fails, do nothing (or show snackbar if you want)
    }
  }

  @override
  Widget build(BuildContext context) {
    // If API said maintenance
    if (!_loading && _isOfflineFromApi) {
      return _MaintenanceView(localVersion: _localVersion);
    }

    // If update required
    final updateRequired =
        !_loading && _apiVersion != null && _isUpdateRequired(_localVersion, _apiVersion!);

    if (updateRequired) {
      return _UpdateView(
        localVersion: _localVersion,
        apiVersion: _apiVersion!,
        onUpdate: _openUpdateLink,
      );
    }

    // Normal splash
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),

            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/splash.png',
                  width: 260,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 16),
                if (_loading)
                  const CupertinoActivityIndicator(radius: 12),
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
                      Icon(CupertinoIcons.briefcase, size: 16, color: Colors.black87),
                      SizedBox(width: 6),
                      Text(
                        'Powered by vacalvers.com',
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
                    'Version: $_localVersion',
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
    );
  }
}

class _UpdateView extends StatelessWidget {
  final String localVersion;
  final String apiVersion;
  final VoidCallback onUpdate;

  const _UpdateView({
    required this.localVersion,
    required this.apiVersion,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(CupertinoIcons.arrow_down_circle, size: 54),
                  const SizedBox(height: 12),
                  const Text(
                    'Update Required',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your app version is $localVersion.\nNew version available: $apiVersion.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, height: 1.3),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: onUpdate,
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Update Now'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Please update to continue using the app.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
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

class _MaintenanceView extends StatelessWidget {
  final String localVersion;

  const _MaintenanceView({required this.localVersion});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(CupertinoIcons.exclamationmark_triangle, size: 54),
                  const SizedBox(height: 12),
                  const Text(
                    'Temporarily Unavailable',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'The system is currently offline for maintenance.\nPlease try again later.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, height: 1.3),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Version: $localVersion',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
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
