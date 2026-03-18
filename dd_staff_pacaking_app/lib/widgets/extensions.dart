import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../commonmodule/appConstant.dart';
import '../utils/routes.dart';

extension ValiationExtensions on String {
  validateEmail() {
    var regExp = RegExp(emailPattern);
    if (isEmpty) {
      return 'Email is required';
    } else if (!regExp.hasMatch(this)) {
      return 'Invalid email';
    } else {
      return null;
    }
  }

  validateName() {
    if (isEmpty) {
      return 'Name is required';
    }
    return null;
  }

  validateMessage() {
    if (isEmpty) {
      return 'Message is required';
    }
    return null;
  }

  validateBulkQTY() {
    if (isEmpty) {
    return 'QTY is required';
    }
    return null;
  }

  validateBulkPrice() {
    if (isEmpty) {
      return 'Price is required';
    }
    return null;
  }

  validateBoard() {
    if (isEmpty) {
      return 'Name is required';
    }
    return null;
  }

  validateCity() {
    if (isEmpty) {
      return 'City is required';
    }
    return null;
  }

  validateState() {
    if (isEmpty) {
      return 'State is required';
    }
    return null;
  }

  validateAddress() {
    if (isEmpty) {
      return 'Address is required';
    }
    return null;
  }

  validateProductName() {
    if (isEmpty) {
      return 'Product Name is required';
    }
    return null;
  }

  validateProductQTY() {
    if (isEmpty) {
      return 'QTY is required';
    }
    return null;
  }

  validatePrice() {
    if (isEmpty) {
      return 'Price is required';
    }
    return null;
  }

  validatePassword() {
    if (isEmpty) {
      return 'Password is required';
    } else if (length < 3) {
      return 'Password must be 3 characters';
    }
    return null;
  }

  validateMobile() {
    var regExp = RegExp(mobilePattern);
    if (replaceAll(" ", "").isEmpty) {
      return 'Mobile is required';
    } else if (!regExp.hasMatch(this)) {
      return 'Invalid mobile number';
    }else if (length < 10) {
      return 'Mobile no. must be 10 digit';
    } else {
      return null;
    }
  }

  String? aadharValidation() {
    if (isEmpty) {
      return 'Please enter Aadhar Number';
    }
    return null;
  }

  String? accountValidation() {
    if (isEmpty) {
      return 'Please enter Account Number';
    }
    return null;
  }

  String? amountValidation() {
    if (isEmpty) {
      return 'Please enter Amount';
    }
    return null;
  }

  String? panValidation() {
    if (isEmpty) {
      return 'Please enter Pan Number';
    }
    return null;
  }

  String? ifscValidation() {
    if (isEmpty) {
      return 'Please enter IFSC Code';
    }
    return null;
  }

  String? nameValidation() {
    if (isEmpty) {
      return 'Please enter Name';
    }
    return null;
  }

  String? lastNameValidation() {
    if (isEmpty) {
      return 'Please enter Last Name';
    }
    return null;
  }

  String? validatePinCode() {
    if (isEmpty) {
      return 'Pin code is required';
    } else if (length < 6) {
      return 'Pin code must be 6 characters';
    }
    return null;
  }

  String? emergencyName1Validation() {
    if (isEmpty) {
      return 'Please enter  Name';
    }
    return null;
  }

  String? emergencyNumber1Validation() {
    if (isEmpty) {
      return 'Please enter  Number';
    }
    return null;
  }
}

extension VoidExtensions on void {
  inputField({
    ValueChanged<String>? onChanged,
    TextEditingController? controller,
    int? maxLength,
    TextInputType? keyboardType,
    String? hintText,
    String? labelText,
    int maxLines = 1,
    bool obscureText = false,
    InkWell? inkWell,
    InkWell? inkWellPrefixIcon,
    FormFieldValidator<String>? validation,
    bool? editable,
    String? obscuringCharacter,
    IconButton? suffixIcon,
    TextInputAction? textInputAction,
    InputDecoration? decoration,
    bool? filled,
    Color? fillColor,
  }) =>
      Padding(
        padding: const EdgeInsets.only(top: 15, bottom: 2),
        child: TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: TextInputAction.next,
          maxLength: maxLength,
          style:
              const TextStyle(height: 1.5, color: Colors.black, fontSize: 14),
          maxLines: maxLines,
          onChanged: onChanged,
          enabled: editable,
          decoration: InputDecoration(
            contentPadding: EdgeInsets.all(15),
            fillColor: Colors.grey.shade100,
            filled: true,
            labelText: labelText,
            hintText: hintText,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          validator: validation,
        ),
      );

  showProgress() {
    Get.dialog(
        Container(
            alignment: FractionalOffset.center,
            child:
            CircularProgressIndicator(color: Colors.red, strokeWidth: 3)),
        barrierDismissible: true);
  }

  loadMore(bool isLoadMoreApiCall) {
    return isLoadMoreApiCall
        ? Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16.0),
      child: CircularProgressIndicator(color: Colors.red, strokeWidth: 3),
    )
        : Visibility(visible: false, child: Container());
  }

  hideProgressBar() {
    if (Get.isDialogOpen!) {
      Get.back();
    }
  }

  showErrorSnackbar(String? message) {
    Get.snackbar("There was a problem", message!,
        colorText: Colors.black, backgroundColor: Colors.cyan);
  }

  showSuccessSnackbar(String? message) {
    Get.snackbar("Success", message!, colorText: Colors.black);
  }
  snackBar(var msg, var msg2,int sec) {
    Get.snackbar(msg, msg2, snackPosition: SnackPosition.BOTTOM, duration: Duration(seconds: sec),colorText: Colors.white, backgroundColor: Colors.red);
  }
  showSnackbar(String? title, String? message) {
    Get.snackbar(title!, message!,
        snackPosition: SnackPosition.BOTTOM,
        colorText: Colors.black, backgroundColor: Colors.cyan);
  }
}


extension ListUtils<T> on List<T> {
  num sumBy(num f(T element)) {
    num sum = 0;
    for(var item in this) {
      sum += f(item);
    }
    return sum;
  }
}
extension WidgetExtensions on Widget {
  circleProgressIndicator() => Container(
      alignment: FractionalOffset.center,
      child: const CircularProgressIndicator(strokeWidth: 1));

  myText(
          {required String title,
          Color textColor = Colors.white,
          FontWeight fontWeight = FontWeight.normal,
          double titleSize = 18}) =>
      Text(
        title,
        style: TextStyle(
            color: textColor, fontSize: titleSize, fontWeight: fontWeight),
      );
}

extension WidgetExtensions2 on Widget {
  circleProgressIndicator() => Container(
      alignment: FractionalOffset.center,
      child: const CircularProgressIndicator(strokeWidth: 1));

  myText(
          {required String title,
          Color textColor = Colors.white,
          FontWeight fontWeight = FontWeight.normal,
          double titleSize = 18}) =>
      Text(
        title,
        style: TextStyle(
            color: textColor, fontSize: titleSize, fontWeight: fontWeight),
      );

  inputField2({
    ValueChanged<String>? onChanged,
    TextEditingController? controller,
    int? maxLength,
    TextInputType? keyboardType,
    String? hintText,
    String? labelText,
    int maxLines = 1,
    bool obscureText = false,
    InkWell? inkWell,
    InkWell? inkWellPrefixIcon,
    FormFieldValidator<String>? validation,
    bool? editable,
  }) =>
      Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 2),
        child: TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          maxLength: maxLength,
          style:
              const TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
          maxLines: maxLines,
          onChanged: onChanged,
          enabled: editable,
          decoration: InputDecoration(
            counterText: "",
            border: InputBorder.none,
            hintStyle: const TextStyle(
                color: Colors.grey, fontWeight: FontWeight.w500),
            filled: true,
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.grey),
              borderRadius: BorderRadius.circular(10.0),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.grey),
              borderRadius: BorderRadius.circular(10.0),
            ),
            disabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.grey),
              borderRadius: BorderRadius.circular(10.0),
            ),
            errorBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.grey),
              borderRadius: BorderRadius.circular(10.0),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.red),
              borderRadius: BorderRadius.circular(10.0),
            ),
            fillColor: Colors.white,
            hintText: hintText,
            suffixIcon: Padding(
              padding: const EdgeInsets.all(7.0),
              child: inkWell,
            ),
            prefixIcon: inkWellPrefixIcon,
          ),
          validator: validation,
        ),
      );
}

var emailPattern =
    r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$';
var mobilePattern = r'(^[0-9]*$)';
