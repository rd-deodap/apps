import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '/route/app_page.dart';
import '/route/app_route.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DEODAP CLO PACKAGING APP',
      initialRoute: AppRoutes.permission,
      getPages: AppPages.pages,
    );
  }
}
