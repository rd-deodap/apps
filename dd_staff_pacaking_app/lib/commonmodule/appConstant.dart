class AppConstant {
  // ✅ Base API (your normal app APIs)
  static final String WS_BASE_URL =
      "https://support.vacalvers.com/api-packaging-app/";

  // ✅ App APIs (relative to WS_BASE_URL)
  static final String WS_DEVICE_CONFIG = "app_info";
  static final String WS_WAREHOUSE_LIST = "app_info/warehouse_list";
  static final String WS_GET_PROFILE = "auth/user";
  static final String WS_EXIST_USER_LOGIN = "auth/login";
  static final String WS_EXIST_USER_LOGOUT = "auth/logout";
  static final String WS_ORDER_INFO = "order/get";
  static final String WS_SEND_ORDER = "order/set";
  static final String WS_EXIST_USER_OTP_VERIFY = "auth/verify-otp";
  static final String WS_RESEND_OTP = "auth/resend-otp";

  // ✅ Version update API (FULL URL - different domain, DO NOT join with baseUrl)
  static const String WS_VERSION_CHECK =
      "https://customprint.deodap.com/common-page/sp_vupdate.php";

  // ✅ Keys / Common
  static String APP_ID = "1";
  static String APP_KEY = "c77b74df-59f6-4257-b0ee-9b81e30026b1";

  static const int STATUS_CODE = 200;
  static const String APP_SUCCESS = "success";

  // ✅ Storage Keys
  static String IS_LOGIN = "IsLoggedIn";
  static String PREF_APP_INFO_LOGIN = "app_info_login";
  static String PREF_APP_INFO = "app_info";
  static String PREF_APP_INFO_LOGIN_SPLASH = "app_info_login_splash";

  // ✅ App Runtime
  static bool isLogin = false;
  static String SCAN_ID = "";
  static String TEMP_TOKEN = "";
  static String TEMP_PHONE = "";

  // ✅ UI Constants
  static const double sizeBox = 15;
  static const double noRecordImageHeightWidth = 150;
  static String noRecordImagePath = "assets/images/no_record_found.png";
  static String placeHolderImagePath = "assets/images/image_placeholder.png";

  // ✅ Others
  static String APP_ITEMS_PER_PAGE = "10";
  static String BUYER_PINCODE = "";
  static String PREF_SETTTING_QR = "";
}
