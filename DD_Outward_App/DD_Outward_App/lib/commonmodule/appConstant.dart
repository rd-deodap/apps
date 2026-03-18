import 'package:get_storage/get_storage.dart';

import '../pages/auth/LoginVo.dart';
import '../pages/order/OrderInfoVO.dart';

class AppConstant {
  static final WS_BASE_URL = "https://ship.deodap.in/api/";

  //static final WS_BASE_URL = "https://trackship.in/deve/dispatch/";  //DEV
  static final WS_DEVICE_CONFIG = "app_info";
  static final String WS_WAREHOUSE_LIST = "warehouse.php";
  static final String WS_GET_PROFILE = "get-user";
  static final String WS_GET_COURIER = "order-outward/get-couriers";
  static final String WS_GET_USER = "order-outward/get-scan-users";
  static final String WS_EXIST_USER_LOGIN = "login";
  static final String WS_LOGOUT = "logout";
  static final String WS_ORDER_INFO = "order-outward/get-orders";
  static final String WS_PENDING_ORDER_INFO =
      "order-outward/get-pending-orders";
  static final String WS_SEND_ORDER = "order-outward/dispatch-awb";
  static final String WS_RTO_SHIPMENT = "order-outward/store-rto-shiment";
  static final String WS_WAREHOUSE = "order-outward/get-warehouses";
  static final String WS_PHOTO_UPDATE = "order-outward/upload-awb-image";
  static String IS_LOGIN = "IsLoggedIn";
  static bool isLogin = false;
  static bool isScanScreen = false;
  static LoginVo? loginVo;

  /*End */
  static List<String> photo = [];
  static String SCAN_ID = "";
  static String SHIPPING_COMPANY_ID = "";
  static String SHIPPING_COMPANY_TITLE = "";
  static String ORDER_ID = "";
  static String ORDER_TRACKING_ID = "1";
  static int ORDER_TRACKING_POSITION = -1;
  static String APP_ID = "1";
  static String APP_KEY = "c77b74df-59f6-4257-b0ee-9b81e30026b1";
  static final STATUS_CODE = 200;
  static final double sizeBox = 15;
  static final double noRecordImageHeightWidth = 250;
  static String noRecordImagePath = "assets/images/no_record_found.png";
  static String placeHolderImagePath = "assets/images/image_placeholder.png";
  static String APP_SUCCESS = "ok";

  /*Device Config Data*/
  static String PREF_APP_INFO_LOGIN = "app_info_login";
  static String APP_ITEMS_PER_PAGE = "10";
  static String PREF_SETTTING_QR = "pref_s_qo";
  static String PREF_STORE_SCAN = "app_store_scan";
  static String PREF_STORE_DATE = "app_store_date";
  static String PREF_STORE_SCAN_COUNT = "app_store_scan_count";

  static String PREF_STORE_SCAN_RTO = "app_store_scan_rto";
  static String PREF_STORE_DATE_RTO = "app_store_date_rto";
  static String PREF_STORE_SCAN_COUNT_RTO = "app_store_scan_count_rto";

  static List<Orders> listDataOrders = <Orders>[];
  static List<Orders> listDataOrdersScan = <Orders>[];
  static List<Orders> listDataRTOScan = <Orders>[];
  static int itemCount = 0;
  static int itemCountRTO = 0;
  static String? versionCode = '';
  static String? versionCodeName = '';
  static bool switchValueNotification = false;

  /*Order Filter*/
  static String? formDateOrderFilter = '';
  static String? selectedWarehouseIdOrderFilter = "";
  static String? selectedWarehouseNameOrderFilter = "";
  static String? selectedCourierIdOrderFilter = "";
  static String? selectedCourierNameOrderFilter = "";
  static String? selectedScanUserIdOrderFilter = "";
  static String? selectedScanUserFilter = "";

  static clearFilter() {
    final box = GetStorage();
    box.remove("selectedItemIds");
    AppConstant.formDateOrderFilter = '';
    AppConstant.selectedWarehouseIdOrderFilter = "";
    AppConstant.selectedWarehouseNameOrderFilter = "";
    AppConstant.selectedCourierIdOrderFilter = "";
    AppConstant.selectedCourierNameOrderFilter = "";
    AppConstant.selectedScanUserIdOrderFilter = "";
    AppConstant.selectedScanUserFilter = "";
  }
}
