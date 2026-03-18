import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:deodap/pages/home/ScanAWBVO.dart' hide ScanByUser;
import 'package:deodap/pages/order/OrderInfoVO.dart';
import 'package:deodap/widgets/extensions.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart' hide Response, FormData, MultipartFile;
import 'package:get_storage/get_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';

import '../../commonmodule/appConstant.dart';
import '../../commonmodule/appString.dart';
import '../../utils/routes.dart';
import '../../widgets/all_widget.dart';
import '../order/UpdatePhotoVO.dart';
import '../splash/DeviceConfigVO.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({Key? key}) : super(key: key);

  @override
  _ScanPageState createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  var storage = GetStorage();
  DeviceConfigVO? deviceConfigVO;
  OrderInfoVO? orderInfoVO;
  final ScrollController _controller = ScrollController();
  int page = 1;

  bool isScannerOpen = false;
  MobileScannerController _scannerController = MobileScannerController();

  bool isLoadMoreApiCall = false;
  var idProofFront = '';
  bool isTextSearch = false;
  var search = '';
  final TextEditingController searchController = TextEditingController();
  //Barcode? result;
  //QRViewController? controller;
  bool hasScanned = false; // Flag to track scan state
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  List<Orders> listScanData = <Orders>[];
  Timer? debounceTimer;
  bool isScanning = false;
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    check().then((intenet) {
      if (intenet) {
        AppConstant.isScanScreen = true;
        if (storage.read(AppConstant.PREF_STORE_DATE) != null &&
            storage.read(AppConstant.PREF_STORE_SCAN) != null) {
          checkAndRemoveOldDate();
        }
        //callAPI();
        //AppConstant.listDataOrdersScan.clear();
        /*_controller.addListener(() {
          double _pixels = _controller.position.pixels;
          double _maxScroll = _controller.position.maxScrollExtent;
          if (_pixels == _maxScroll) getOrderInfo();
        });*/
      } else {
        // No-Internet Case
        toastError(AppString.no_internet);
      }
    });
  }
  void _toggleScanner() {
    setState(() {
      isScannerOpen = !isScannerOpen;
    });
  }

  void _onDetect(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String code = barcodes.first.rawValue ?? "Unknown";
      debugPrint("✅ Scanned code: $code");

      setState(() {
        AppConstant.SCAN_ID = code; // Save directly
        isScannerOpen = false; // Close scanner
      });

      // 👉 Now call your API logic
      sendData();
    }
  }
  void callAPI() {
    page = 1;
    isLoadMoreApiCall = true;
    AppConstant.listDataOrdersScan.clear();
    getOrderInfo();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: appBar(
          'Scan Screen '+'('+AppConstant.SHIPPING_COMPANY_TITLE+')',
          actions: <Widget>[
            IconButton(
                icon: Icon(
                  isScannerOpen ? Icons.close : Icons.document_scanner_outlined,
                  color: Colors.black54,
              ),
              onPressed: _toggleScanner,
            ),
          ],
          elevation: 2.0,
          // Slightly higher elevation for a subtle shadow
        ),
        body: SafeArea(
          child: isScannerOpen
              ? MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          )
              : listScanData.isNotEmpty
              ? Column(
            children: [
              // List Items header
              Container(
                margin: const EdgeInsets.only(top: 5),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                color: Colors.grey.shade300,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Accepted Consignment:',
                      style: TextStyle(
                        fontWeight: FontWeight.w400,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      AppConstant.itemCount.toString(),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: appColor(),
                      ),
                    ),
                  ],
                ),
              ),

              // List Data
              Expanded(
                child: ListView.builder(
                  controller: _controller,
                  itemCount: AppConstant.itemCount,
                  itemBuilder: (context, index) => listDesign(index),
                ),
              ),
            ],
          )
              : noRecordFound(),
        ),);
  }

  void _showDialogAsk() {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            title: Container(),
            content: Text(
              'Select Option',
              style: TextStyle(
                  color: Colors.black,
                  fontFamily: fontName(),
                  fontSize: 16,
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                      //updateData(Routes.editEmployeeRoute);
                      dialogPhoto('1');
                    },
                    child: Container(
                      height: 35,
                      //width: 100,
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(5.0),
                        // Adjust the radius as needed
                        border: Border.all(
                          color: appColor(), // Set your desired border color
                          width: 1.0, // Set the border width
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Upload Photo',
                          style: TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.w400),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 10,
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                      //Get.toNamed(Routes.orderDetailScreenRoute);
                      Get.toNamed(
                        Routes.orderDetailScreenRoute,
                        arguments: {
                          'listScanData': listScanData, // Pass the list
                          'position': AppConstant.ORDER_TRACKING_POSITION, // Pass the selected position
                        },
                      );
                      //showDialogCommon(context, 'This feature is under development');
                    },
                    child: Container(
                      height: 35,
                      width: 100,
                      decoration: BoxDecoration(
                        color: appColor(),
                        borderRadius: BorderRadius.circular(5.0),
                        // Adjust the radius as needed
                        border: Border.all(
                          color: appColor(), // Set your desired border color
                          width: 1.0, // Set the border width
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Detail',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w400),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        });
  }

  listDesign(var index) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: GestureDetector(
        onTap: () {
          AppConstant.ORDER_ID =
              listScanData[index].orderId.toString();
          AppConstant.ORDER_TRACKING_ID =
              listScanData[index].awb.toString();
          AppConstant.ORDER_TRACKING_POSITION = index;
          _showDialogAsk();
        },
        child: Container(
          margin: EdgeInsets.only(bottom: 0, right: 5, left: 0),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5.0),
            ),
            elevation: 1, // Change this
            color: Colors.grey.shade50,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 0, vertical: 0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 15,
                        height: 100,
                        // Set width to 10
                        decoration: BoxDecoration(
                          color: listScanData[index].isPortalOrder
                                      .toString() ==
                                  '1'
                              ? Colors.green
                              : Colors.red,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(5),
                            // Round top-left corner
                            bottomLeft:
                                Radius.circular(5), // Round bottom-left corner
                          ),
                        ),
                        padding: EdgeInsets.all(0),
                        child: Container(
                          padding: EdgeInsets.all(5),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          padding:
                              EdgeInsets.symmetric(vertical: 5, horizontal: 5),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Column(
                                    children: [
                                      Text(
                                        "AWB: " +
                                            listScanData[index].awb
                                                .toString(),
                                        style: TextStyle(
                                            fontSize: 15,
                                            fontFamily: fontName(),
                                            fontWeight: FontWeight.w500),
                                        textAlign: TextAlign.start,
                                      ),
                                      listScanData[index]
                                                  .scanByUser !=
                                              null
                                          ? Text(
                                              listScanData[index]
                                                  .scanByUser!
                                                  .name
                                                  .toString(),
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  fontFamily: fontName(),
                                                  color: Colors.black54,
                                                  fontWeight: FontWeight.w400),
                                              textAlign: TextAlign.start,
                                            )
                                          : Container(),
                                      listScanData[index]
                                                  .courierSlug !=
                                              null
                                          ? Text(
                                              listScanData[index]
                                                  .courierSlug
                                                  .toString(),
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  fontFamily: fontName(),
                                                  color: Colors.black54,
                                                  fontWeight: FontWeight.w400),
                                              textAlign: TextAlign.start,
                                            )
                                          : Container(),
                                    ],
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.start,
                                  ),
                                  listScanData[index]
                                                  .outwardMedias !=
                                              null &&
                                          listScanData[index]
                                              .outwardMedias!.isNotEmpty
                                      ? Container(
                                          margin: EdgeInsets.symmetric(
                                              horizontal: 5),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: appColor(),
                                          ),
                                          padding: EdgeInsets.all(4),
                                          child: Container(
                                            padding: EdgeInsets.all(4),
                                            child: Text(
                                              listScanData[index]
                                                  .outwardMedias!
                                                  .length
                                                  .toString(),
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.white,
                                                  fontFamily: fontName(),
                                                  fontWeight: FontWeight.w400),
                                              textAlign: TextAlign.start,
                                            ),
                                          ),
                                        )
                                      : Container(),
                                ],
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    listScanData[index].scanDate
                                        .toString(),
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontFamily: fontName(),
                                        fontWeight: FontWeight.w300),
                                    textAlign: TextAlign.end,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  searchData(var value) {
    if (value.toString().trim().isNotEmpty) {
      search = value;
    } else {
      search = '';
    }
    closeKeyboard();
    callAPI();
  }

  getOrderInfo() async {
    showProgress();
    try {
      FormData formData = FormData.fromMap(<String, dynamic>{
        "page": page,
        "awb": search,
      });
      var _response = await apiCall()
          .post(AppConstant.WS_ORDER_INFO, data: formData, options: option());
      if (_response.statusCode == AppConstant.STATUS_CODE) {
        hideProgressBar();
        orderInfoVO = OrderInfoVO.fromJson(jsonDecode(_response.toString()));
        if (orderInfoVO != null && orderInfoVO!.success!) {
          if (orderInfoVO != null && orderInfoVO!.data!.orders!.length > 0) {
            if (orderInfoVO!.data!.pagination!.lastPage! >= page) {
              if (orderInfoVO!.data!.pagination!.lastPage! == 1) {
                isLoadMoreApiCall = false;
              }
              page++;
              AppConstant.listDataOrdersScan.addAll(orderInfoVO!.data!.orders!);
              print("leng --> " +
                  AppConstant.listDataOrdersScan.length.toString());
              storeOrdersInStorage();
              setState(() {});
            }
          } else {
            isLoadMoreApiCall = false;
            setState(() {});
          }
          setState(() {});
        } else {
          toastError(orderInfoVO!.message.toString());
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

  dialogPhoto(var files) {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(AppString.appName),
          content: Text('Choose Photo Option'),
          actions: [
            TextButton(
              child: Text('Camera'),
              onPressed: () {
                Get.back();
                getFromCamera(files);
              },
            ),
            TextButton(
              child: Text(' Gallery'),
              onPressed: () {
                Get.back();
                getFromGallery(files);
              },
            ),
            /*TextButton(
              child: Text('SKIP'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),*/
          ],
        );
      },
    );
  }

  getFromGallery(var files) async {
    XFile? pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1800,
      maxHeight: 1800,
    );
    pickPhoto(pickedFile, files);
  }

  pickPhoto(XFile? pickedFile, var files) {
    if (pickedFile != null) {
      //Get.back();
      setState(() {
        idProofFront = pickedFile.path;
        callAPIUpdatePhoto();
      });
    }
  }

  getFromCamera(var files) async {
    XFile? pickedFile = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1800,
      maxHeight: 1800,
    );
    pickPhoto(pickedFile, files);
  }

  callAPIUpdatePhoto() async {
    showProgress();

    String idProofFronts = "";
    if (idProofFront.isNotEmpty) {
      idProofFronts = idProofFront.split('/').last;
    }
    FormData formData = FormData.fromMap(<String, dynamic>{
      "awb": AppConstant.ORDER_TRACKING_ID,
      if (idProofFronts.isNotEmpty)
        "image":
            await MultipartFile.fromFile(idProofFront, filename: idProofFronts),
    });
    try {
      var _response = await apiCall()
          .post(AppConstant.WS_PHOTO_UPDATE, data: formData, options: option());
      print("res -- " + _response.statusCode.toString());
      hideProgressBar();
      UpdatePhotoVO logoutVO =
          UpdatePhotoVO.fromJson(jsonDecode(_response.toString()));
      if (_response.statusCode == AppConstant.STATUS_CODE) {
        if (logoutVO.success!) {
          //Get.back(result: true);
          showDialogCommon(context, logoutVO.message.toString(),
              onOkTap: () async {
            callAPI();
          }, barrierDismissible: false);
        } else {
          playSoundError();
          showDialogCommon(context, logoutVO.data!.errors.toString(),
              onOkTap: () {
            //scanQRAndCapturePhoto();
          }, barrierDismissible: false);
        }
      } else {
        playSoundError();
        showDialogCommon(context, logoutVO.data!.errors.toString(),
            onOkTap: () {
          //scanQRAndCapturePhoto();
        }, barrierDismissible: false);
      }
    } catch (e) {
      print('Error: $e');
      hideProgressBar();
      showDialogCommon(context, e.toString());
    } finally {
      hideProgressBar();
    }
  }

  Widget _buildMenuItem({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 16),
        padding: EdgeInsets.symmetric(horizontal: 10),
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w500,
                fontSize: 18,
              ),
            ),
            Icon(
              icon,
              color: Colors.black54,
              size: 40,
            ),
          ],
        ),
      ),
    );
  }
  @override
  void dispose() {
    //controller?.dispose();
    debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> scanQRAndCapturePhoto() async {
    if (isScanning) return;  // Prevent multiple scans at the same time
    isScanning = true;

    String barcodeScanRes;
    try {
      /*barcodeScanRes = await FlutterBarcodeScanner.scanBarcode(
        '#ff6666',
        'Close',
        true,
        ScanMode.BARCODE,
      );

      await Future.delayed(Duration(milliseconds: 200));  // Debounce delay
      print("Scanned Result: $barcodeScanRes");

      if (barcodeScanRes == "-1") {
        print("Scan canceled");
        return;
      }

      if (isValidBarcode(barcodeScanRes)) {
        AppConstant.SCAN_ID = barcodeScanRes;
        sendData();
        //tempLocalScan();
      } else {
        playSoundError();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Invalid barcode. Please try again.")),
        );
      }*/
    } on PlatformException catch (e) {
      print("Platform exception: ${e.message}");
    } catch (e) {
      print("Unexpected error: $e");
    } finally {
      isScanning = false;
    }
  }
  tempLocalScan(){
    if (1==1) {
      showInstantToast('AWB No.' + AppConstant.SCAN_ID);
      playSoundSuccess();
      //var order = scanAWBVO.data!;

// Create a new order instance
      Orders newOrder = Orders(
        id: 1001, // Static ID
        orderId: "ORDER_12345",
        isPortalOrder: true,
        awb: AppConstant.SCAN_ID,
        courierSlug: AppConstant.SHIPPING_COMPANY_TITLE,
        scanDate: "2025-01-01T12:00:00Z",
        scanByUserId: 9999,
        scanByUser: ScanByUser(
          id: 999,
          name: "Default User",
        )
      );
      AppConstant.listDataOrdersScan.insert(0, newOrder);
      listScanData.insert(0, newOrder);
      AppConstant.itemCount = AppConstant.itemCount + 1;
      setState(() {});
      if (storage.read(AppConstant.PREF_STORE_SCAN) != null) {
        storage.remove(
            AppConstant.PREF_STORE_SCAN); // Removes the stored record
      }
      if (storage.read(AppConstant.PREF_STORE_SCAN_COUNT) != null) {
        storage.remove(AppConstant
            .PREF_STORE_SCAN_COUNT); // Removes the stored record
      }
      storeOrdersInStorage();
    } else {
      toastScan("Getting ID Null From Server Side");
    }
  }

// Barcode validation helper function based on a pattern or length
  bool isValidBarcode(String code) {
    return code.isNotEmpty && code.length >= 5 && code.length <= 18;
  }

  Future<void> capturePhoto(CameraController _cameraController) async {
    try {
      // Start camera preview with the highest resolution preset
      await _cameraController.initialize();

      // Ensure the camera is ready
      if (!_cameraController.value.isInitialized) {
        print('Error: Camera is not initialized.');
        return;
      }

      // Capture a high-resolution photo
      final XFile picture = await _cameraController.takePicture();

      // Get the path to the downloads directory
      final directory = await _getDownloadDirectory();
      final ssDirectory = Directory('${directory.path}/SS');

      // Create the directory if it doesn't exist
      if (!await ssDirectory.exists()) {
        await ssDirectory.create(recursive: true);
      }

      // Generate a timestamped file name for the captured photo
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final imagePath = '${ssDirectory.path}/captured_photo_$timestamp.png';

      // Save the captured photo to the SS folder
      await picture.saveTo(imagePath);

      print('Photo saved to: $imagePath');
      toastSuccess('Photo saved to: $imagePath');
    } catch (e) {
      print('Error capturing photo: $e');
      // Handle any errors that occur during the photo capture process
    } finally {
      // Dispose of the camera controller properly
      _cameraController.dispose();
    }
  }

  sendData() {
    callAPISendQRCode();
  }

  Future<Directory> _getDownloadDirectory() async {
    if (Platform.isAndroid) {
      return Directory('/storage/emulated/0/Download');
    } else {
      // For iOS or other platforms, use the application's document directory
      return await getApplicationDocumentsDirectory();
    }
  }

  callAPISendQRCode() async {
    showProgress();
    try {
      FormData formData = FormData.fromMap(<String, dynamic>{
        "awb": AppConstant.SCAN_ID,
        "shipping_company_id": AppConstant.SHIPPING_COMPANY_ID,
      });
      var _response = await apiCall()
          .post(AppConstant.WS_SEND_ORDER, data: formData, options: option());
      hideProgressBar();
      ScanAWBVO scanAWBVO =
          ScanAWBVO.fromJson(jsonDecode(_response.toString()));
      if (_response.statusCode == AppConstant.STATUS_CODE) {
        if (scanAWBVO != null && scanAWBVO.success!) {
          //showDialogDB(context, scanAWBVO.message.toString());
          if (scanAWBVO.data!.id != null) {
            showInstantToast('AWB No.' + AppConstant.SCAN_ID);
            playSoundSuccess();
            var order = scanAWBVO.data!;

// Create a new order instance
            Orders newOrder = Orders(
              id: order.id,
              orderId: order.orderId,
              isPortalOrder: order.isPortalOrder,
              awb: order.awb,
              courierSlug: order.courierSlug,
              scanDate: order.scanDate,
              scanByUserId: order.scanByUserId,
              // Ensure 'scanByUser' is instantiated correctly
              scanByUser: order.scanByUser != null
                  ? ScanByUser(
                      id: order.scanByUser!.id,
                      name: order.scanByUser!.name,
                    )
                  : null,
            );
            AppConstant.listDataOrdersScan.insert(0, newOrder);
            listScanData.insert(0, newOrder);
            AppConstant.itemCount = AppConstant.itemCount + 1;
            setState(() {});
            if (storage.read(AppConstant.PREF_STORE_SCAN) != null) {
              storage.remove(
                  AppConstant.PREF_STORE_SCAN); // Removes the stored record
            }
            if (storage.read(AppConstant.PREF_STORE_SCAN_COUNT) != null) {
              storage.remove(AppConstant
                  .PREF_STORE_SCAN_COUNT); // Removes the stored record
            }
            storeOrdersInStorage();
          } else {
            toastScan("Getting ID Null From Server Side");
          }
          /*Future.delayed(Duration(seconds: 2), () {
            hasScanned = false; // Reset flag to allow the next scan
          });*/
          Future.delayed(const Duration(milliseconds: 700), () {
            openScanner();
          });
        } else {
          hideProgressBar();
          playSoundError();
          showDialogCommon(
              context, "Error 1 -> " + scanAWBVO.data!.errors.toString(),
              onOkTap: () {
                openScanner();
          }, barrierDismissible: false);
        }
      } else {
        hideProgressBar();
        playSoundError();
        showDialogCommon(context, scanAWBVO.data!.errors.toString(),
            onOkTap: () {
              openScanner();
        }, barrierDismissible: false);
      }
    } catch (e) {
      print('Error: $e');
      hideProgressBar();
      showDialogCommon(context, "Error 3 -> " + e.toString());
    } finally {
      hideProgressBar();
    }
  }
  openScanner(){
    setState(() {
      isScannerOpen = true;
    });
  }
  void storeOrdersInStorage() {
    final storage = GetStorage();

    // Convert the list of Orders objects to a list of Maps (JSON)
    List<Map<String, dynamic>> ordersJson =
        AppConstant.listDataOrdersScan.map((order) => order.toJson()).toList();

    // Store the JSON list in GetStorage
    storage.write(AppConstant.PREF_STORE_SCAN, ordersJson);
    storage.write(AppConstant.PREF_STORE_SCAN_COUNT, AppConstant.itemCount);
    storeCurrentDate();
    print("Orders stored successfully.");
  }

  void retrieveOrdersFromStorage() {
    // Retrieve the JSON list from GetStorage
    List<dynamic>? ordersJson = storage.read(AppConstant.PREF_STORE_SCAN);

    if (ordersJson != null) {
      // Convert JSON to Orders objects
      List<Orders> allOrders = ordersJson.map((json) => Orders.fromJson(json)).toList();

      // Filter orders based on matching courierSlug
      listScanData = allOrders
          .where((order) => order.courierSlug.toString().toLowerCase() == AppConstant.SHIPPING_COMPANY_TITLE.toString().toLowerCase())
          .toList();

      // Update itemCount to match only the filtered records
      AppConstant.itemCount = listScanData.length;

      print("Filtered orders retrieved successfully. Count: ${AppConstant.itemCount}");
      setState(() {});
    } else {
      print("No orders found in storage.");
    }
  }

  void storeCurrentDate() {
    String currentDate =
        DateFormat('yyyy-MM-dd').format(DateTime.now()); // Format the date
    storage.write(AppConstant.PREF_STORE_DATE, currentDate);
    print("Current date stored: $currentDate");
  }

  void checkAndRemoveOldDate() {
    String? storedDate = storage.read(AppConstant.PREF_STORE_DATE);
    String currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

    if (storedDate == null || storedDate != currentDate) {
      // If the stored date is null or not equal to today's date
      storage.remove(AppConstant.PREF_STORE_DATE); // Remove old data
      storage.remove(AppConstant.PREF_STORE_SCAN); // Remove old data
      storage.remove(AppConstant.PREF_STORE_SCAN_COUNT); // Remove old data
      storeCurrentDate(); // Store the new date
      print("Old date removed and new date stored.");
    } else {
      print("Data is up to date. Current date: $storedDate");
      retrieveOrdersFromStorage();
    }
    setState(() {});
  }
}
