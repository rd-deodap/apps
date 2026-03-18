import 'dart:convert';
import 'dart:io';

import 'package:deodap/commonmodule/appString.dart';
import 'package:deodap/pages/auth/warehouseVo.dart';
import 'package:deodap/widgets/extensions.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response, FormData, MultipartFile;
import 'package:get_storage/get_storage.dart';

import '../../commonmodule/CustomDropdown.dart';
import '../../commonmodule/appConstant.dart';
import '../../widgets/all_widget.dart';
import '../splash/DeviceConfigVO.dart';
import 'login_controller.dart';

class Login extends StatefulWidget {
  const Login({Key? key}) : super(key: key);

  @override
  _LoginState createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final controller = Get.put(LoginController());
  var storage = GetStorage();
  final TextEditingController textEditingController = TextEditingController();
  String? selectedStateValue;
  String? selectedStateId = "8";
  DeviceConfigVO? deviceConfigVO;

  /*State*/
  final List<Logins> _listStateData = <Logins>[];
  WarehouseVo? warehouseVo;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    check().then((intenet) {
      if (intenet) {
        selectedStateValue = 'L008';
        controller.warehouseController = selectedStateId;
        //_requestWarehouse();
      } else {
        toastError(AppString.no_internet);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: willPop,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: appBar('Login', automaticallyImplyLeading: false),
        body: SafeArea(
          top: true,
          bottom: false,
          child: Form(
            key: controller.validationKey,
            child: SingleChildScrollView(
              /*padding:
            EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.3),*/
              //bottom: MediaQuery.of(context).size.height * 0.15),
              child: Column(
                children: [
                  Container(
                    margin: EdgeInsets.only(top: 10, left: 10, right: 10),
                    child: Column(
                      children: [
                        inputField(
                          controller: controller.mobileController,
                          validation: controller.isEmailValid,
                          labelText: "Email",
                          hintText: '',
                          keyboardType: TextInputType.emailAddress,
                          //maxLength: 10,
                        ),
                        inputField(
                          controller: controller.passwordController,
                          keyboardType: TextInputType.visiblePassword,
                          validation: controller.isPasswordValid,
                          obscuringCharacter: "*",
                          labelText: "Password",
                          hintText: "Enter Password",
                          obscureText: true,
                          // Set initial obscure to true
                          isPasswordField:
                              true, // Enable password visibility toggle
                        ),
                        /*Visibility(
                          visible: false,
                          child: CustomDropdown(
                            items: _listStateData,
                            hint: 'Select Warehouse',
                            onSelected: (selectedId) {
                              selectedStateId = selectedId;
                              controller.warehouseController = selectedStateId;
                            },
                            textEditingController: TextEditingController(),
                            defaultValue: "L008",
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select a Warehouse';
                              }
                              return null;
                            },
                          ),
                        ),*/
                        SizedBox(
                          height: AppConstant.sizeBox,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 20,
                  ),
                  Obx(
                    () => Container(
                      width: Get.width / 2,
                      height: 50,
                      child: ElevatedButton(
                          onPressed: () {
                            //setState(() => controller.flag = !controller.flag);
                            controller.validate();
                          },
                          child: Text(
                            controller.flag.value ? 'SIGN IN' : 'Loading...',
                            style: TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                fontFamily: fontName(),
                                fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                            backgroundColor: controller.flag.value
                                ? appColor()
                                : Colors.teal,
                          )),
                    ),
                  ),
                  SizedBox(
                    height: 10,
                  ),
                ],
                //crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> willPop() async {
    return exit(0);
  }

  Future<void> _requestWarehouse() async {
    showProgress();
    try {
      FormData formData = FormData.fromMap(<String, dynamic>{
        "action": "list",
      });
      var _response =
          await apiCall().post(AppConstant.WS_WAREHOUSE_LIST, data: formData);
      if (_response.statusCode == AppConstant.STATUS_CODE) {
        warehouseVo = WarehouseVo.fromJson(jsonDecode(_response.toString()));
        if (warehouseVo != null && warehouseVo!.data!.length > 0) {
          _listStateData.addAll(warehouseVo!.data!);
          setState(() {});
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Oops! Something went wrong...'),
          ),
        );
      }
    } catch (e) {
      return null;
    }
    hideProgressBar();
  }
}
