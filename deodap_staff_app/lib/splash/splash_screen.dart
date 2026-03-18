import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import "package:deodap_staff_app/home_screen.dart";
import 'package:deodap_staff_app/onboarding/onboarding_screen.dart';
import 'splash_data.dart';
import 'package:deodap_staff_app/app_theme.dart';

class Splashscreen extends StatefulWidget {
  const Splashscreen({super.key});

  @override
  State<Splashscreen> createState() => _SplashscreenState();
}

class _SplashscreenState extends State<Splashscreen> {
  static const String keyLogin = 'isLoggedIn';
  static const String apiUrl =
      'https://customprint.deodap.com/common-page/selfi_punch_app.php';

  final AppUpdateService _updateService = const AppUpdateService(apiUrl: apiUrl);

  String _version = '—';

  @override
  void initState() {
    super.initState();
    _initAndCheck();
  }

  Future<void> _initAndCheck() async {
    // 1) App Version
    final info = await PackageInfo.fromPlatform();
    final currentVersion = info.version;

    if (mounted) setState(() => _version = currentVersion);

    // 2) Update / Maintenance Check (dialog may block flow)
    final result = await _updateService.checkAndHandle(
      context: context,
      currentVersion: currentVersion,
      onContinue: _continueAppFlow,
    );

    if (result.blocked) return;

    // 3) Continue to normal flow
    await _continueAppFlow();
  }

  Future<void> _continueAppFlow() async {
    final prefs = await SharedPreferences.getInstance();
    final bool isLoggedIn = prefs.getBool(keyLogin) ?? false;

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    _goNext(isLoggedIn ? const MyHomePage() : const OnboardingScreen());
  }

  void _goNext(Widget screen) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      CupertinoPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppTheme.nearlyWhite,
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/splash_image.png',
                    width: 260,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
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
                      children: [
                        Icon(
                          CupertinoIcons.briefcase,
                          size: 16,
                          color: AppTheme.darkText,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Powered by vacalvers.com',
                          style: AppTheme.caption.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.darkText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Version: $_version',
                      style: AppTheme.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.lightText,
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
