import 'dart:convert';

import 'package:deodap/pages/auth/LoginVo.dart';
import 'package:deodap/shared/api_repository.dart';
import 'package:deodap/utils/routes.dart';
import 'package:deodap/widgets/extensions.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response, FormData, MultipartFile;
import 'package:get_storage/get_storage.dart';

import '../../commonmodule/appConstant.dart';
import '../../shared/get_storage_repository.dart';
import '../../widgets/all_widget.dart';

class LoginController extends GetxController {
  final GetStorageRepository _getStorageRepository;
  final ApiRepository _apiRepository;

  LoginController(this._getStorageRepository, this._apiRepository);

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
  }

  callAPI() async {
    Map<String, dynamic> requestBody = {
      "app_id": AppConstant.APP_ID,
      "api_key": AppConstant.APP_KEY,
      "phone": mobileController.text,
      "password": passwordController.text,
      "warehouse": warehouseController,
    };
    String jsonBody = json.encode(requestBody);
    showProgress();
    _apiRepository.postApi(AppConstant.WS_EXIST_USER_LOGIN, data: jsonBody,
        success: (response) async {
      hideProgressBar();
      LoginVo loginVo = LoginVo.fromJson(response);
      if (loginVo.status == AppConstant.APP_SUCCESS) {
        _getStorageRepository.write(
            AppConstant.PREF_APP_INFO_LOGIN, loginVo.toJson());
        toastSuccess(loginVo.message.toString());
        _getStorageRepository.write(AppConstant.IS_LOGIN, true);
        mobileController.clear();
        passwordController.clear();
        Get.toNamed(Routes.homeRoute);
      } else {
        flag.value = !flag.value;
        showErrorSnackbar(loginVo.message.toString());
      }
    }, error: (error) {
      flag.value = !flag.value;
      hideProgressBar();
      showErrorSnackbar(error!.message);
    });
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
  String? isMobileValid(String? value) => value!.validateMobile();

  String? isPasswordValid(String? value) => value!.trim().validatePassword();
}
