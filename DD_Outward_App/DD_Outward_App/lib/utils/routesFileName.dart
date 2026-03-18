import 'package:deodap/pages/auth/login.dart';
import 'package:deodap/pages/auth/profile.dart';
import 'package:deodap/pages/order/order_detail_screen.dart';
import 'package:deodap/pages/order/order_screen.dart';
import 'package:deodap/pages/rto/rto_page.dart';
import 'package:deodap/pages/splash/splash.dart';
import 'package:deodap/utils/routes.dart';
import 'package:get/get.dart';

import '../pages/courier/courier_list.dart';
import '../pages/home/MobileScannerScreen.dart';
import '../pages/home/home_page.dart';
import '../pages/home/scan_page.dart';
import '../pages/order/order_filter_screen.dart';
import '../pages/pendingOrder/pending_order_screen.dart';

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
      name: Routes.pendingOrderScreenRoute,
      page: () => PendingOrderScreen(),
    ),
    GetPage(
      name: Routes.courierScreenRoute,
      page: () => CourierList(),
    ),
    GetPage(
      name: Routes.filterOrderScreenRoute,
      page: () => OrderFilterScreen(),
    ),
    GetPage(
      name: Routes.scanRoute,
      page: () => ScanPage(),
    ),
    GetPage(
      name: Routes.scanNewRoute,
      page: () => MobileScannerScreen(),
    ),
    GetPage(
      name: Routes.rtoRoute,
      page: () => RTOPage(),
    ),
    GetPage(
      name: Routes.orderDetailScreenRoute,
      page: () => OrderDetailScreen(),
    ),
    GetPage(
      name: Routes.profileRoute,
      page: () => Profile(),
    ),
  ];
}
