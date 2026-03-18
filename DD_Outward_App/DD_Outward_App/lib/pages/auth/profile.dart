import 'dart:convert';

import 'package:deodap/commonmodule/appString.dart';
import 'package:deodap/pages/auth/ProfileVO.dart';
import 'package:deodap/widgets/extensions.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../commonmodule/appConstant.dart';
import '../../widgets/all_widget.dart';

class Profile extends StatefulWidget {
  const Profile({Key? key}) : super(key: key);

  @override
  _ProfileState createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  var storage = GetStorage();
  ProfileVO? profileVO;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    check().then((intenet) {
      if (intenet) {
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
                        ),
                      ),
                      SizedBox(
                        height: 20,
                      ),
                      Container(
                        margin: EdgeInsets.only(
                            left: 1, right: 1, top: 10, bottom: 10),
                        width: Get.width,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 1, // Border width
                          ),
                          borderRadius: BorderRadius.circular(
                              10), // Adjust the radius as needed
                        ),
                        child: Column(
                          children: [
                            profileVO!.data!.user!.warehouseId != null &&
                                    profileVO!.data!.user!.warehouseId
                                        .toString()
                                        .isNotEmpty
                                ? Column(
                                    children: [
                                      Container(
                                        margin:
                                            EdgeInsets.only(top: 10, bottom: 5),
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 10),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            keyStyle('Warehouse'),
                                            SizedBox(
                                              height: 3,
                                            ),
                                            Text(
                                              profileVO!.data!.user!.warehouseId
                                                  .toString(),
                                              style: keyValue(),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(
                                        width: Get.width,
                                        child: Divider(
                                          thickness: 1,
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                    ],
                                  )
                                : Container(),
                            profileVO!.data!.user!.name != null &&
                                    profileVO!.data!.user!.name
                                        .toString()
                                        .isNotEmpty
                                ? Column(
                                    children: [
                                      Container(
                                        margin:
                                            EdgeInsets.only(top: 5, bottom: 5),
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 10),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            keyStyle('Name'),
                                            SizedBox(
                                              height: 3,
                                            ),
                                            Text(
                                              profileVO!.data!.user!.name,
                                              style: keyValue(),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(
                                        width: Get.width,
                                        child: Divider(
                                          thickness: 1,
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                    ],
                                  )
                                : Container(),
                            profileVO!.data!.user!.email != null &&
                                    profileVO!.data!.user!.email
                                        .toString()
                                        .isNotEmpty
                                ? Column(
                                    children: [
                                      Container(
                                        margin:
                                            EdgeInsets.only(top: 5, bottom: 10),
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 10),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            keyStyle('Email'),
                                            SizedBox(
                                              height: 3,
                                            ),
                                            Text(
                                              profileVO!.data!.user!.email,
                                              style: keyValue(),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(
                                        width: Get.width,
                                        child: Divider(
                                          thickness: 1,
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                    ],
                                  )
                                : Container(),
                            Column(
                              children: [
                                Container(
                                  margin:
                                  EdgeInsets.only(top: 5, bottom: 10),
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 10),
                                  child: Column(
                                    mainAxisAlignment:
                                    MainAxisAlignment.start,
                                    crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                    children: [
                                      keyStyle('App Version'),
                                      SizedBox(
                                        height: 3,
                                      ),
                                      Text(
                                       AppConstant.versionCodeName.toString(),
                                        style: keyValue(),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : noRecordFound()
      ),
    );
  }

  callAPI() async {
    showProgress();
    try {
      var response =
          await apiCall().get(AppConstant.WS_GET_PROFILE, options: option());
      AppConstant.isLogin
          ? print("Authorization" +
              'Bearer ' +
              AppConstant.loginVo!.data!.token.toString())
          : print('nnot login');
      hideProgressBar();
      if (response.statusCode == AppConstant.STATUS_CODE) {
        profileVO = ProfileVO.fromJson(jsonDecode(response.toString()));
        if (profileVO != null && profileVO!.success!) {}
        setState(() {});
      } else {
        showSuccessSnackbar('Oops! Something went wrong...');
      }
    } catch (e) {
      print('Error: $e');
      hideProgressBar();
    }
  }

  keyValue() {
    return TextStyle(
        color: Colors.black, fontSize: 14, fontWeight: FontWeight.w500);
  }

  keyStyle(var title) {
    return Text(title,
        style: TextStyle(
            color: Colors.black54, fontSize: 15, fontWeight: FontWeight.w500));
  }
}
