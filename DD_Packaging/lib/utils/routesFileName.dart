import 'package:deodap/pages/auth/login.dart';
import 'package:deodap/pages/auth/profile.dart';
import 'package:deodap/pages/order/order_screen.dart';
import 'package:deodap/pages/splash/splash.dart';
import 'package:deodap/utils/routes.dart';
import 'package:get/get.dart';

import '../pages/home/home_page.dart';

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
      name: Routes.profileRoute,
      page: () => Profile(),
    ),
  ];
}
