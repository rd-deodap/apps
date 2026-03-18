import 'package:deodap/common/term.dart';
import 'package:deodap/pages/auth/login.dart';
import 'package:deodap/pages/auth/profile.dart';
import 'package:deodap/pages/order/order_screen.dart';
import 'package:deodap/pages/splash/splash.dart';
import 'package:deodap/utils/routes.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import '../pages/order/order_details_screen.dart';
import '../pages/home/home_page.dart';
import 'package:deodap/common/howtouse.dart';
import 'package:deodap/common/about.dart';
import 'package:deodap/common/privacy_policy.dart';
import 'package:deodap/common/settings.dart';
import 'package:deodap/common/term.dart';
class RoutesFileName {
  static final routes = [
    GetPage(
      name: Routes.splashRoute,
      page: () => Splash(),
    ),
    GetPage(
      name: Routes.homeRoute,
      page: () => HomePage(),
    ),
    GetPage(
      name: Routes.loginRoute,
      page: () => Login(),
    ),
    GetPage(
      name: Routes.orderScreenRoute,
      page: () => OrderScreen(),
    ),
    GetPage(
        name: Routes.orderDetailRoute,
        page: () => OrderSlipDetailsScreen()
    ),
    GetPage(
      name: Routes.profileRoute,
      page: () => Profile()
        ),
    GetPage(
    name: Routes.HowToUseRoute,
     page: () => HowItWorksScreen()
  ),
    GetPage(
        name: Routes.termsRoute,
        page: () => TermsScreen()
    ),
    GetPage(
        name: Routes.aboutRoute,
        page: () => AboutUsScreen()
    ),
    GetPage(
        name: Routes.privacyRoute,
        page: () => PrivacyPolicyScreen()
    ),

    GetPage(
        name: Routes.settingsRoute,
        page: () => SettingsScreen()
    ),
  ];

}
