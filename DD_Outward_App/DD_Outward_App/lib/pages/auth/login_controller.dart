import 'package:deodap/pages/auth/LoginVo.dart';
import 'package:deodap/utils/routes.dart';
import 'package:deodap/widgets/extensions.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response, FormData, MultipartFile;
import 'package:get_storage/get_storage.dart';

import '../../commonmodule/appConstant.dart';
import '../../widgets/all_widget.dart';

class LoginController extends GetxController {
  var storage = GetStorage();
  final TextEditingController nameController = TextEditingController();
  late var designationController;
  final TextEditingController cityController = TextEditingController();
  var warehouseController;
  final TextEditingController mobileController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final TextEditingController birthdateController = TextEditingController();
  final validationKey = GlobalKey<FormState>();
  RxBool flag = true.obs;
  final _autoValidateRx = Rx<bool>(false);

  checkAutoValidate() {
    _autoValidateRx.value = true;
  }

  @override
  void onInit() async {
    super.onInit();
    if (kDebugMode) {
      mobileController.text = 'developer@gmail.com';
      passwordController.text = 'Iddqd2017@';
    }
  }

  callAPI() async {
    showProgress();
    FormData formData = FormData.fromMap(<String, dynamic>{
      "email": mobileController.text,
      "password": passwordController.text,
    });

    try {
      var _response =
          await apiCall().post(AppConstant.WS_EXIST_USER_LOGIN, data: formData);

      hideProgressBar();

      // If status code is 200, process the response normally
      if (_response.statusCode == 200) {
        LoginVo loginVo = LoginVo.fromJson(_response.data);
        if (loginVo.success!) {
          storage.write(AppConstant.PREF_APP_INFO_LOGIN, loginVo.toJson());
          storage.write(AppConstant.IS_LOGIN, true);
          AppConstant.isLogin = true;
          AppConstant.loginVo =
              LoginVo.fromJson(storage.read(AppConstant.PREF_APP_INFO_LOGIN));
          mobileController.clear();
          passwordController.clear();
          Get.toNamed(Routes.homeRoute);
        } else {
          showErrorSnackbar(loginVo.data.toString());
        }
      }
    } catch (e) {
      if (e is DioError) {
        handleError(e); // Use the common error handling function
      } else {
        hideProgressBar();
        showErrorSnackbar('Oops! Something went wrong: $e');
      }
    } finally {
      flag.value = !flag.value;
    }
  }

  void handleError(DioError e) {
    hideProgressBar();

    final response = e.response;
    if (response != null) {
      switch (response.statusCode) {
        case 401:
          showErrorSnackbar("Invalid credentials. Please try again.");
          break;
        case 500:
          showErrorSnackbar("Internal server error. Please try again later.");
          break;
        default:
          showErrorSnackbar(
              'Error: ${response.statusCode} - ${response.statusMessage}');
      }
    } else {
      showErrorSnackbar('Oops! Something went wrong: ${e.message}');
    }
  }

  validate() {
    switch (validationKey.currentState!.validate()) {
      case true:
        validationKey.currentState!.save();
        flag.value = !flag.value;
        callAPI();
        break;
      case false:
        checkAutoValidate();
        break;
    }
  }

  //CLEAR RESOURCE
  @override
  void onClose() {
    super.onClose();
  }

  //VALIDATION
  String? isEmailValid(String? value) => value!.validateEmail();

  String? isPasswordValid(String? value) => value!.trim().validatePassword();
}
