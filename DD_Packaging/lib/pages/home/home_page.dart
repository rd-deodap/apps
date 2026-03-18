import 'dart:convert';
import 'dart:io';

import 'package:deodap/commonmodule/HexColor.dart';
import 'package:deodap/pages/auth/LogoutVO.dart';
import 'package:deodap/widgets/extensions.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:get/get.dart' hide Response, FormData;
import 'package:get_storage/get_storage.dart';

import '../../commonmodule/appConstant.dart';
import '../../commonmodule/appString.dart';
import '../../utils/routes.dart';
import '../../widgets/all_widget.dart';
import '../auth/LoginVo.dart';
import '../splash/DeviceConfigVO.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  var storage = GetStorage();
  DeviceConfigVO? deviceConfigVO;
  LoginVo? loginVo;
  LogoutVO? logoutVO;
  String _scanBarcode = 'Unknown';

  /*Back*/
  bool back = false;
  int time = 0;
  int duration = 1000;
  bool _switchValueNotification = false;
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    loginVo = LoginVo.fromJson(storage.read(AppConstant.PREF_APP_INFO_LOGIN));
    check().then((intenet) {
      if (intenet != null && intenet) {
        _switchValueNotification = storage.read(AppConstant.PREF_SETTTING_QR);
        setState(() {

        });
      } else {
        // No-Internet Case
        toastError(AppString.no_internet);
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: willPop,
        child: Scaffold(
          backgroundColor: Colors.white,
          //resizeToAvoidBottomInset: true,
          appBar: AppBar(
            iconTheme: IconThemeData(color: Colors.black),
            automaticallyImplyLeading: false,
            title: Text(
              AppString.appName,
              style: TextStyle(fontSize: 14, color: Colors.white),
            ),
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [
                      const Color(0xFFBD8B5A),
                      const Color(0xFFBD8B5A),
                    ],
                    begin: const FractionalOffset(0.0, 0.0),
                    end: const FractionalOffset(1.0, 0.0),
                    stops: [0.0, 1.0],
                    tileMode: TileMode.clamp),
              ),
            ),
            elevation: 0,
            //backgroundColor: Colors.white,
          ),
          body: Stack(
            children: <Widget>[
              Positioned.fill(
                child: Image.asset(
                  "assets/images/bg.png",
                  fit: BoxFit.fitWidth,
                  alignment: Alignment.bottomLeft,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      scanQR();
                    },
                    child: Container(
                        margin:
                            EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                        width: Get.width,
                        height: 200,
                        decoration: BoxDecoration(
                            color: HexColor('#F6F6F6'),
                            border: Border.all(
                              color: HexColor('#F6F6F6'),
                            ),
                            borderRadius:
                                BorderRadius.all(Radius.circular(15))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              _switchValueNotification?"assets/images/qr.png":"assets/images/barcode.png",
                              width: 100,
                              height: 100,
                              color: Colors.black87,
                            ),
                            SizedBox(
                              height: 20,
                            ),
                            Text(
                              _switchValueNotification?'Scan QR':'Scan Barcode',
                              style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15),
                            )
                          ],
                        )),
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  GestureDetector(
                    onTap: () {
                      Get.toNamed(Routes.profileRoute);
                    },
                    child: Container(
                        margin: EdgeInsets.symmetric(horizontal: 20),
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        width: Get.width,
                        height: 60,
                        decoration: BoxDecoration(
                            color: HexColor('#F6F6F6'),
                            border: Border.all(
                              color: HexColor('#F6F6F6'),
                            ),
                            borderRadius:
                                BorderRadius.all(Radius.circular(15))),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Profile',
                              style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13),
                            ),
                            Icon(
                              Icons.person,
                              color: Colors.black54,
                            )
                          ],
                        )),
                  ),
                  SizedBox(
                    height: 20,
                  ),
                  GestureDetector(
                    onTap: () {
                      dialogSetting();
                    },
                    child: Container(
                        margin: EdgeInsets.symmetric(horizontal: 20),
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        width: Get.width,
                        height: 60,
                        decoration: BoxDecoration(
                            color: HexColor('#F6F6F6'),
                            border: Border.all(
                              color: HexColor('#F6F6F6'),
                            ),
                            borderRadius:
                                BorderRadius.all(Radius.circular(15))),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Setting',
                              style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13),
                            ),
                            Icon(
                              Icons.settings,
                              color: Colors.black54,
                            )
                          ],
                        )),
                  ),
                  SizedBox(
                    height: 20,
                  ),
                  GestureDetector(
                    onTap: () {
                      callAPILogOut();
                    },
                    child: Container(
                        margin: EdgeInsets.symmetric(horizontal: 20),
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        width: Get.width,
                        height: 60,
                        decoration: BoxDecoration(
                            color: HexColor('#F6F6F6'),
                            border: Border.all(
                              color: HexColor('#F6F6F6'),
                            ),
                            borderRadius:
                            BorderRadius.all(Radius.circular(15))),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Logout',
                              style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13),
                            ),
                            Icon(
                              Icons.logout,
                              color: Colors.black54,
                            )
                          ],
                        )),
                  ),
                ],
              )
            ],
          ),
        )
        /*Center(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                      onPressed: () => {
                      AppConstant.SCAN_ID = 'Pk8LX7Zo84E',
                      Get.toNamed(Routes.orderScreenRoute)
                      },
                      child: Text('Start barcode scan stream',style: TextStyle(fontSize: 16),)),
                ),
                SizedBox(height: 10,),
                Text('Scan result : $_scanBarcode\n',
                    style: TextStyle(fontSize: 20))
              ],
            ),
          )),*/
        );
  }

  updateData(pageName) async {
    var response = await Get.toNamed(pageName);
    if (response)
      setState(() {
        scanQR();
      });
    return response;
  }

  Future<void> scanQR() async {
    String barcodeScanRes;
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      barcodeScanRes = await FlutterBarcodeScanner.scanBarcode(
          '#ff6666', 'Cancel', true, _switchValueNotification?ScanMode.DEFAULT:ScanMode.BARCODE);
      print(barcodeScanRes);
    } on PlatformException {
      barcodeScanRes = 'Failed to get platform version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    if (barcodeScanRes == "-1") {
      //Get.back();
      setState(() {

      });
    } else {
      AppConstant.SCAN_ID = barcodeScanRes.toString();
      updateData(Routes.orderScreenRoute);
    }
  }

  callAPILogOut() async {
    showProgress();
    try {
      FormData formData = FormData.fromMap(<String, dynamic>{
        "app_id": AppConstant.APP_ID,
        "api_key": AppConstant.APP_KEY,
        "token": loginVo!.data!.token.toString(),
      });
      var _response = await apiCall()
          .post(AppConstant.WS_EXIST_USER_LOGOUT, data: formData);
      if (_response.statusCode == AppConstant.STATUS_CODE) {
        hideProgressBar();
        logoutVO = LogoutVO.fromJson(jsonDecode(_response.toString()));
        /*if (logoutVO != null && logoutVO!.status == AppConstant.APP_SUCCESS) {
          storage.write(AppConstant.IS_LOGIN, false);
          Get.toNamed(Routes.loginRoute);
        } else {
          storage.write(AppConstant.IS_LOGIN, false);
          Get.toNamed(Routes.loginRoute);
          //toastError(logoutVO!.message!);
        }*/
        storage.write(AppConstant.IS_LOGIN, false);
        Get.toNamed(Routes.loginRoute);
      } else {
        hideProgressBar();
        storage.write(AppConstant.IS_LOGIN, false);
        Get.toNamed(Routes.loginRoute);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Oops! Something went wrong...'),
          ),
        );
      }
    } catch (e) {
      storage.write(AppConstant.IS_LOGIN, false);
      Get.toNamed(Routes.loginRoute);
      print('Error: $e');
    }
  }

  Future<bool> willPop() async {
    int now = DateTime.now().millisecondsSinceEpoch;
    if (back && time >= now) {
      back = false;
      exit(0);
    } else {
      time = DateTime.now().millisecondsSinceEpoch + duration;
      print("again tap");
      back = true;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Press again the button to exit")));
    }
    return false;
  }
  dialogSetting() {
    Size size = MediaQuery.of(context).size;
    Get.bottomSheet(
      StatefulBuilder(builder: (context, setState) {
        return SafeArea(
          child: Container(
              height: size.height*0.3 ,
              color: Colors.white,
              child: Column(
                children: [
                  Container(
                    height: size.height * 0.20,
                    child: ListView(
                        children:[
                          Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 10, top: 10),
                                child: Text(
                                  "SETTING",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.red,
                                      fontFamily: 'anekgujarati',
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                              Spacer(),
                              Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: IconButton(
                                  alignment: Alignment.topRight,
                                  onPressed: () async {
                                    if (Get.isBottomSheetOpen ?? false) {
                                      Get.back();
                                    }
                                  },
                                  icon: Icon(
                                    Icons.close_rounded,
                                    size: 30,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          new Divider(
                            color: Colors.grey[300],
                          ),
                          SizedBox(
                            height: 10,
                          ),
                          Container(
                            margin: EdgeInsets.symmetric(horizontal: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text('Switch to QR Scan',style: TextStyle(fontSize: 14,color: Colors.black,fontWeight: FontWeight.w500),),
                                ),
                                SizedBox(width: 5,),
                                Transform.scale(
                                  transformHitTests: true,
                                  scale: 0.8,
                                  child: CupertinoSwitch(
                                    value: _switchValueNotification,
                                    activeColor: Color(0xFFBD8B5A), // Set the active color
                                    trackColor: Colors.grey, // Set the inactive color
                                    onChanged: (value) {
                                      setState(() {
                                        _switchValueNotification = value;
                                        //toastFeedback(_switchValueNotification.toString());
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ]
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: screenHeight(context),
                      child: Align(
                        alignment: FractionalOffset.bottomCenter,
                        child: Container(
                          //width: double.infinity,
                          //height: screenHeight(context)*0.5,
                          //color: Colors.blueGrey,
                          child: Stack(
                            children: [
                              Padding(
                                padding:
                                const EdgeInsets.only(left: 5, right: 5),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        //height: 70,
                                        child: ElevatedButton(
                                          onPressed: () {
                                            if (Get.isBottomSheetOpen ??
                                                false) {
                                              Get.back();
                                            }
                                          },
                                          child: Text(
                                            "CLOSE",
                                            style: TextStyle(
                                                color: Colors.white),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            primary: Colors.blueGrey,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Container(
                                        padding: EdgeInsets.only(left: 8.0),
                                        //height: 70,
                                        child: ElevatedButton(
                                          onPressed: () {
                                            saveSetting();
                                            Get.back();
                                          },
                                          child: Text(
                                            "SAVE",
                                            style: TextStyle(
                                                color: Colors.white),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            primary: Colors.cyan,
                                          ),
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
              )),
        );
      }),
      isScrollControlled: true,
      //barrierColor: Colors.red[50],
      //isDismissible: false,
    );
  }
  void saveSetting(){
    setState(() {
      storage.write(AppConstant.PREF_SETTTING_QR, _switchValueNotification);
    });
  }
}
