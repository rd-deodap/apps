import 'package:deodap/utils/routes.dart';
import 'package:deodap/utils/routesFileName.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_clean_architecture/flutter_clean_architecture.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:overlay_support/overlay_support.dart';


Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Handling a background message codec: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])
      .then((_) {
    runApp(const MyApp());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    FlutterCleanArchitecture.debugModeOn();
    return OverlaySupport(
      child: GetMaterialApp(
        debugShowCheckedModeBanner: false,
        getPages: RoutesFileName.routes,
        initialRoute: Routes.splashRoute,
      ),
    );
  }
}
