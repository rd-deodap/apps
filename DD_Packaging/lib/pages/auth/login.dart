import 'dart:convert';
import 'dart:io';

import 'package:deodap/commonmodule/HexColor.dart';
import 'package:deodap/commonmodule/appString.dart';
import 'package:deodap/pages/auth/warehouseVo.dart';
import 'package:deodap/widgets/extensions.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response, FormData;
import 'package:get_storage/get_storage.dart';

import '../../commonmodule/appConstant.dart';
import '../../utils/routes.dart';
import '../../widgets/all_widget.dart';
import '../splash/DeviceConfigVO.dart';
import 'login_controller.dart';

class Login extends StatefulWidget {
  const Login({Key? key}) : super(key: key);

  @override
  _LoginState createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final controller = Get.put(LoginController(Get.find(),Get.find()));
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
      if (intenet != null && intenet) {
        selectedStateValue = 'L008';
        controller.warehouseController = selectedStateId;
        _requestWarehouse();
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
        appBar: appBar('Login'),
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
                          validation: controller.isMobileValid,
                          labelText: "Domain Name / Phone Number",
                          hintText: 'Eg: myshop.com / 9999999999',
                          keyboardType: TextInputType.phone,
                          //maxLength: 10,
                        ),
                        inputField(
                          controller: controller.passwordController,
                          keyboardType: TextInputType.visiblePassword,
                          validation: controller.isPasswordValid,
                          obscuringCharacter: "*",
                          labelText: "Password",
                          hintText: "Enter Password",
                        ),
                        SizedBox(
                          height: AppConstant.sizeBox,
                        ),
                        DecoratedBox(
                          decoration: ShapeDecoration(
                            color: Colors.grey.shade100,
                            shape: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 0),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton2(
                                isExpanded: true,
                                hint: Text(
                                  'Select Warehouse',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(context).hintColor,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.arrow_drop_down,
                                  color: Colors.black45,
                                  size: 30,
                                ),
                                items: _listStateData
                                    .map((item) => DropdownMenuItem<String>(
                                          value: item.label.toString(),
                                          child: Text(
                                            item.label.toString(),
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                        ))
                                    .toList(),
                                value: selectedStateValue,

                                onChanged: (value) {
                                  setState(() {
                                    for (var i = 0;
                                        i < _listStateData.length;
                                        i++) {
                                      if (value.toString() ==
                                          _listStateData[i].label) {
                                        selectedStateId =
                                            _listStateData[i].id.toString();
                                        break;
                                      }
                                    }
                                    selectedStateValue = value as String;
                                    //toastSuccess(selectedStateId);
                                    controller.warehouseController =
                                        selectedStateId;
                                  });
                                },
                                buttonHeight: 50,
                                searchController: textEditingController,
                                searchInnerWidget: Padding(
                                  padding: const EdgeInsets.only(
                                    top: 10,
                                    bottom: 4,
                                    right: 10,
                                    left: 10,
                                  ),
                                  child: TextFormField(
                                    controller: textEditingController,
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      hintText: 'Search...',
                                      hintStyle: const TextStyle(fontSize: 12),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                                searchMatchFn: (item, searchValue) {
                                  return (item.value
                                      .toString()
                                      .contains(searchValue));
                                },
                                //This to clear the search value when you close the menu
                                onMenuStateChange: (isOpen) {
                                  if (!isOpen) {
                                    textEditingController.clear();
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: AppConstant.sizeBox,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 20,
                  ),
                  Obx(()=>Container(
                    width: Get.width / 2,
                    height: 40,
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
                        backgroundColor: controller.flag.value ? HexColor('#FFBD8B5A') : Colors.teal,)
                    ),
                  ),),
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
      var _response =
          await apiCall().get(AppConstant.WS_WAREHOUSE_LIST, queryParameters: {
        "app_id": AppConstant.APP_ID,
        "api_key": AppConstant.APP_KEY,
      });
      if (_response.statusCode == AppConstant.STATUS_CODE) {
        warehouseVo = WarehouseVo.fromJson(jsonDecode(_response.toString()));
        if (warehouseVo != null && warehouseVo!.data!.length > 0) {
          _listStateData.addAll(warehouseVo!.data);
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
