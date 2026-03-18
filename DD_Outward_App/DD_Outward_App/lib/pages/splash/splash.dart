import 'dart:convert';
import 'dart:io';

import 'package:deodap/commonmodule/appConstant.dart';
import 'package:deodap/pages/splash/DeviceConfigVO.dart';
import 'package:deodap/widgets/extensions.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response, FormData, MultipartFile;
import 'package:get_storage/get_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../commonmodule/appString.dart';
import '../../utils/routes.dart';
import '../../widgets/all_widget.dart';
import '../auth/LoginVo.dart';

class Splash extends StatefulWidget {
  const Splash({Key? key}) : super(key: key);

  @override
  _SplashState createState() => _SplashState();
}

class _SplashState extends State<Splash> {
  var storage = GetStorage();
  DeviceConfigVO? deviceConfigVO;
  List storageList = [];

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
      if (AppConstant.isLogin) {
        AppConstant.loginVo =
            LoginVo.fromJson(storage.read(AppConstant.PREF_APP_INFO_LOGIN));
      }
    }
    check().then((intenet) {
      if (intenet) {
        // Internet Present Case
        homeRoute();
      } else {
        // No-Internet Case
        toastError(AppString.no_internet);
      }
    });
  }

  getVersion() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      AppConstant.versionCode = packageInfo.buildNumber;
      AppConstant.versionCodeName = packageInfo.version+' - '+packageInfo.buildNumber;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Container(
          child: Column(
            children: [
              Spacer(),
              Center(
                child: ClipRect(
                  child: Image.asset(
                    'assets/images/icon.png',
                  ),
                ),
              ),
              Spacer(),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  "Version: " + AppConstant.versionCode.toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.black),
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
      if (AppConstant.versionCode == deviceConfigVO!.data!.version!.toString()) {
        homeRoute();
      } else {
        if (int.parse(AppConstant.versionCode!) <
            int.parse(deviceConfigVO!.data!.version!)) {
          dialogUpdateApp();
        } else {
          homeRoute();
        }
      }
    } else {
      msg = response.data['message'];
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

  Future<void> homeRoute() async {
    await Future.delayed(Duration(seconds: 2));
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
          nextScreen();
        } else {
          hideProgressBar();
          setState(() {});
        }
      } else {
        hideProgressBar();
        showSuccessSnackbar('Oops! Something went wrong...');
      }
      // hideProgressBar();
      //Navigator.of(context).pop();
    } catch (e) {
      print('Error: $e');
      hideProgressBar();
    }
  }
}
