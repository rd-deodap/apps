// lib/route/app_pages.dart
import 'package:get/get.dart';

// Common / Info
import 'package:dd_clo_packing_app/common/about.dart';
import 'package:dd_clo_packing_app/common/privacy_policy.dart';
import 'package:dd_clo_packing_app/common/term.dart';
import 'package:dd_clo_packing_app/common/settings.dart';
import 'package:dd_clo_packing_app/common/howtouse.dart';

// Auth
import 'package:dd_clo_packing_app/auth/login.dart';
import 'package:dd_clo_packing_app/auth/profile.dart';
import 'package:dd_clo_packing_app/auth/app_info.dart';

// Core / Flow
import 'package:dd_clo_packing_app/permission/permission_handler.dart';
import 'package:dd_clo_packing_app/splash/splash.dart';
import 'package:dd_clo_packing_app/splash/onboarding_screen.dart';
import 'package:dd_clo_packing_app/home/home.dart';
import 'package:dd_clo_packing_app/qr/qr_scanner_two.dart';
import "package:dd_clo_packing_app/qr/qr_scanner.dart";
import 'app_route.dart';

class AppPages {
  static final List<GetPage> pages = [
    // Permissions / startup
    GetPage(
      name: AppRoutes.permission,
      page: () => const PermissionScreen(),
    ),
    GetPage(
      name: AppRoutes.splash,
      page: () => const SplashScreen(),
    ),
    GetPage(
      name: AppRoutes.onboarding,
      page: () => const OnboardingScreen(),
    ),

    // Auth / main
    GetPage(
      name: AppRoutes.login,
      page: () => const LoginScreen(),
    ),
    GetPage(
      name: AppRoutes.home,
      page: () => const HomeScreen(),
    ),

    // // Core features
    GetPage(
       name: AppRoutes.qrScanner,
      page: () => const OrderScannerScreen(),
     ),
    GetPage(
      name: AppRoutes.slipScanner,
      page: () => const SipScannerScreen(),
    ),

    // Info / legal / settings
    GetPage(
      name: AppRoutes.privacyPolicy,
      page: () => const PrivacyPolicyScreen(),
    ),
    GetPage(
      name: AppRoutes.termconditions,
      page: () => const TermsScreen(),
    ),
    GetPage(
      name: AppRoutes.settings,
      page: () => const SettingsScreen(),
    ),
    GetPage(
      name: AppRoutes.aboutUs,
      page: () => const AboutUsScreen(),
    ),
    GetPage(
      name: AppRoutes.profile,
      page: () => const ProfileScreen(),
    ),
    GetPage(
      name: AppRoutes.appinfo,
      page: () => const AppInfoScreen(),
    ),
    GetPage(
      name: AppRoutes.HowItWorksScreen,
      page: () => const HowItWorksScreen(),
    ),
  ];
}
