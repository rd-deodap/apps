import 'dart:convert';
import 'dart:io';

import 'package:deodap/commonmodule/appConstant.dart';
import 'package:deodap/pages/splash/DeviceConfigVO.dart';
import 'package:deodap/widgets/extensions.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response, FormData, MultipartFile;
import 'package:get_storage/get_storage.dart';
import 'package:package_info/package_info.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../commonmodule/appString.dart';
import '../../utils/routes.dart';
import '../../widgets/all_widget.dart';

class Splash extends StatefulWidget {
  const Splash({Key? key}) : super(key: key);

  @override
  _SplashState createState() => _SplashState();
}

class _SplashState extends State<Splash> {
  var storage = GetStorage();
  DeviceConfigVO? deviceConfigVO;
  List storageList = [];
  String? versionCode;
  bool isOfflineApp = false;
  String? msg = '';
  var response;

  @override
  void initState() {
    super.initState();
    getVersion();
    if (storage.read(AppConstant.IS_LOGIN) != null) {
      AppConstant.isLogin = storage.read(AppConstant.IS_LOGIN) != null
          ? storage.read(AppConstant.IS_LOGIN)
          : false;
    }
    check().then((intenet) {
      if (intenet != null && intenet) {
        // Internet Present Case
        callAPI();
      } else {
        // No-Internet Case
        toastError(AppString.no_internet);
      }
    });
  }

  getVersion() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      versionCode = packageInfo.buildNumber;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Container(
          child: isOfflineApp
              ? Column(
                  children: [
                    Spacer(),
                    Center(
                      child: Column(
                        children: [
                          ClipRect(
                            child: Image.asset(
                              'assets/images/ic_offline.png',
                              height: 200,
                              width: 200,
                            ),
                          ),
                          SizedBox(
                            height: 10,
                          ),
                          Text(
                            msg!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    Spacer(),
                  ],
                )
              : Column(
                  children: [
                    Spacer(),
                    Center(
                      child: ClipRect(
                        child: Image.asset(
                          'assets/images/splash.png',
                          height: 200,
                          width: 200,
                        ),
                      ),
                    ),
                    Spacer(),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        "Version: " + versionCode.toString(),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  void nextScreen() {
    if (deviceConfigVO!.data!.isOffline == 0) {
      if (versionCode == deviceConfigVO!.data!.version!.toString()) {
        homeRoute();
      } else {
        if (int.parse(versionCode!) <
            int.parse(deviceConfigVO!.data!.version!)) {
          dialogUpdateApp();
        } else {
          homeRoute();
        }
      }
    } else {
      msg = response.data['message'];
      isOfflineApp = true;
      setState(() {});
    }
  }

  dialogUpdateApp() {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(AppString.appName),
          content: Text('You need to update the App'),
          actions: [
            TextButton(
              child: Text('Update'),
              onPressed: () {
                Navigator.of(context).pop();
                if (Platform.isAndroid || Platform.isIOS) {
                  final appId = Platform.isAndroid
                      ? 'com.deodap.gallery'
                      : 'com.deodap.gallery';
                  Platform.isAndroid
                      ? _launchURL(
                          'https://play.google.com/store/apps/details?id=$appId')
                      : _launchURL('https://apps.apple.com/app/id1661765661');
                }
              },
            ),
            /*TextButton(
              child: Text('SKIP'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),*/
          ],
        );
      },
    );
  }

  _launchURL(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      throw 'Could not launch $url';
    }
  }

  void homeRoute() {
    if (AppConstant.isLogin) {
      Get.toNamed(Routes.homeRoute);
    } else {
      Get.toNamed(Routes.loginRoute);
    }
  }

  callAPI() async {
    showProgress();
    try {
      response = await apiCall().get(AppConstant.WS_DEVICE_CONFIG,
          queryParameters: {
            "app_id": AppConstant.APP_ID,
            "api_key": AppConstant.APP_KEY
          });
      if (response.statusCode == AppConstant.STATUS_CODE) {
        deviceConfigVO =
            DeviceConfigVO.fromJson(jsonDecode(response.toString()));
        if (deviceConfigVO != null &&
            deviceConfigVO!.status == AppConstant.APP_SUCCESS) {
          hideProgressBar();
          storage.write(AppConstant.PREF_APP_INFO, deviceConfigVO!.toJson());
          nextScreen();
        } else {
          hideProgressBar();
          setState(() {});
        }
      } else {
        hideProgressBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Oops! Something went wrong...'),
          ),
        );
      }
      // hideProgressBar();
      //Navigator.of(context).pop();
    } catch (e) {
      print('Error: $e');
      hideProgressBar();
    }
  }
}
