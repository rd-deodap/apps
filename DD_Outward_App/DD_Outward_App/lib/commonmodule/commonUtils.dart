import 'package:get/get.dart';
import 'package:get/get_utils/get_utils.dart';

import '../widgets/all_widget.dart';
import 'appString.dart';

class CommonUtils {
  static validatesEmail(var i) {
    if (i.text.isEmpty) {
      toastError(AppString.emailRequired);
      return false;
    } else if (!GetUtils.isEmail(i.text)) {
      toastError(AppString.emailNotValid);
      return false;
    } else {
      return true;
    }
  }

  static validatesPassword(var i) {
    if (i.text.isEmpty) {
      toastError(AppString.passwordRequired);
      return false;
    } else if (i.text.length < 6) {
      toastError(AppString.passwordLength);
      return false;
    } else {
      return true;
    }
  }

  static validateName(var i) {
    if (i.text.isEmpty) {
      return 'Name is required';
    }
    return null;
  }

  static validateMessage(var i) {
    if (i.text.isEmpty) {
      return 'Message is required';
    }
    return null;
  }
}
