import 'dart:convert';

import 'package:deodap/commonmodule/appString.dart';
import 'package:deodap/pages/auth/login_controller.dart';
import 'package:deodap/widgets/extensions.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response, FormData;
import 'package:get_storage/get_storage.dart';

import '../../commonmodule/appConstant.dart';
import '../../widgets/all_widget.dart';
import 'LoginVo.dart';
import 'ProfileVO.dart';

class Profile extends StatefulWidget {
  const Profile({Key? key}) : super(key: key);

  @override
  _ProfileState createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  final controller = Get.put(LoginController(Get.find(),Get.find()));
  var storage = GetStorage();
  LoginVo? loginVo;
  ProfileVO? profileVO;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    check().then((intenet) {
      loginVo = LoginVo.fromJson(storage.read(AppConstant.PREF_APP_INFO_LOGIN));
      if (intenet != null && intenet) {
        callAPI();
      } else {
        toastError(AppString.no_internet);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: appBar('Profile'),
      body: SafeArea(
        top: true,
        bottom: false,
        child: profileVO != null
            ? SingleChildScrollView(
                child: Container(
                  margin: EdgeInsets.all(10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      ClipRect(
                        child: Image.asset(
                          'assets/images/header_logo.png',
                          height: 100,
                          width: 100,
                        ),
                      ),
                      SizedBox(
                        height: 30,
                      ),
                      profileVO!.data!.name != null &&
                              profileVO!.data!.name.toString().isNotEmpty
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Text(
                                  'First Name',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                      fontFamily: fontName(),
                                      fontWeight: FontWeight.w400),
                                ),
                                SizedBox(
                                  height: 1,
                                ),
                                Text(
                                  profileVO!.data!.name.toString(),
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.black,
                                      fontFamily: fontName(),
                                      fontWeight: FontWeight.w500),
                                ),
                              ],
                            )
                          : Container(),
                      profileVO!.data!.phone != null &&
                              profileVO!.data!.phone.toString().isNotEmpty
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                SizedBox(
                                  height: 15,
                                ),
                                Text(
                                  'Phone',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                      fontFamily: fontName(),
                                      fontWeight: FontWeight.w400),
                                ),
                                SizedBox(
                                  height: 1,
                                ),
                                Text(
                                  profileVO!.data!.phone.toString(),
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.black,
                                      fontFamily: fontName(),
                                      fontWeight: FontWeight.w500),
                                ),
                              ],
                            )
                          : Container(),
                      profileVO!.data!.code != null &&
                              profileVO!.data!.code.toString().isNotEmpty
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                SizedBox(
                                  height: 15,
                                ),
                                Text(
                                  'Code',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                      fontFamily: fontName(),
                                      fontWeight: FontWeight.w400),
                                ),
                                SizedBox(
                                  height: 1,
                                ),
                                Text(
                                  profileVO!.data!.code.toString(),
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.black,
                                      fontFamily: fontName(),
                                      fontWeight: FontWeight.w500),
                                ),
                              ],
                            )
                          : Container(),
                      profileVO!.data!.warehouseId != null &&
                              profileVO!.data!.warehouseId
                                  .toString()
                                  .isNotEmpty
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                SizedBox(
                                  height: 15,
                                ),
                                Text(
                                  'WarehouseId',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                      fontFamily: fontName(),
                                      fontWeight: FontWeight.w400),
                                ),
                                SizedBox(
                                  height: 1,
                                ),
                                Text(
                                  profileVO!.data!.warehouseId
                                      .toString(),
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.black,
                                      fontFamily: fontName(),
                                      fontWeight: FontWeight.w500),
                                ),
                              ],
                            )
                          : Container(),
                    ],
                  ),
                ),
              )
            : Container(
                width: screenWidth(context),
                height: mainHeight(context) - 100,
                child: Stack(alignment: Alignment.center, children: [
                  Image.asset(
                    AppConstant.noRecordImagePath,
                    height: AppConstant.noRecordImageHeightWidth,
                    width: AppConstant.noRecordImageHeightWidth,
                  ),
                  //hideProgressBar()
                ]),
              ),
      ),
    );
  }

  callAPI() async {
    showProgress();
    try {
      var _response =
          await apiCall().get(AppConstant.WS_GET_PROFILE, queryParameters: {
        "app_id": AppConstant.APP_ID,
        "api_key": AppConstant.APP_KEY,
        "token": loginVo!.data!.token.toString(),
      });
      if (_response.statusCode == AppConstant.STATUS_CODE) {
        hideProgressBar();
        profileVO = ProfileVO.fromJson(jsonDecode(_response.toString()));
        if (profileVO != null && profileVO!.status == AppConstant.APP_SUCCESS) {
          setState(() {});
        } else {
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
    } catch (e) {
      print('Error: $e');
    }
  }
}
