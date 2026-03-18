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
import 'RTOScanVO.dart';

class RTOPage extends StatefulWidget {
  const RTOPage({Key? key}) : super(key: key);

  @override
  _RTOPageState createState() => _RTOPageState();
}

class _RTOPageState extends State<RTOPage> {
  var storage = GetStorage();
  final ScrollController _controller = ScrollController();

  bool isScannerOpen = false;
  MobileScannerController _scannerController = MobileScannerController();

  List<Orders> listScanData = <Orders>[];
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    checkAndRemoveOldDate();
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
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.grey[100],
      appBar: appBar(
        'RTO Shipments',
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
                      'RTO Accepted Consignment:',
                      style: TextStyle(
                        fontWeight: FontWeight.w400,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      AppConstant.itemCountRTO.toString(),
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
                  itemCount: AppConstant.itemCountRTO,
                  itemBuilder: (context, index) => listDesign(index),
                ),
              ),
            ],
          )
              : noRecordFound(),
        ),);
  }
  listDesign(var index) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: GestureDetector(
        onTap: () {
         /* AppConstant.ORDER_ID =
              listScanData[index].orderId.toString();
          AppConstant.ORDER_TRACKING_ID =
              listScanData[index].awb.toString();
          AppConstant.ORDER_TRACKING_POSITION = index;
          _showDialogAsk();*/
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
                        height: 60,
                        // Set width to 10
                        decoration: BoxDecoration(
                          color: listScanData[index].isPortalOrder
                                      .toString() ==
                                  '1'
                              ? Colors.green
                              : Colors.green,
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
                                    ],
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.start,
                                  ),
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


  @override
  void dispose() {
    super.dispose();
  }
  sendData() {
    callAPISendQRCode();
  }

  callAPISendQRCode() async {
    showProgress();
    try {
      FormData formData = FormData.fromMap(<String, dynamic>{
        "awb": AppConstant.SCAN_ID,
      });
      var _response = await apiCall()
          .post(AppConstant.WS_RTO_SHIPMENT, data: formData, options: option());
      hideProgressBar();
      RTOScanVO scanAWBVO =
      RTOScanVO.fromJson(jsonDecode(_response.toString()));
      if (_response.statusCode == AppConstant.STATUS_CODE) {
        if (scanAWBVO != null && scanAWBVO.success!) {
          //showDialogDB(context, scanAWBVO.message.toString());
          if (scanAWBVO.data!.id != null) {
            showInstantToast('AWB No.' + AppConstant.SCAN_ID);
            playSoundSuccess();
            var order = scanAWBVO.data!;

            // Create new order instance
            Orders newOrder = Orders(
              id: order.id,
              orderId: order.orderId,
              isPortalOrder: false,
              awb: order.awb,
              courierSlug: "",
              scanDate: order.scanAt,
              scanByUserId: order.scanByUserId,
            );

            // 👉 First, check and clear old data if date changed
            checkAndRemoveOldDate();

            // 👉 Insert today's record into both lists
            AppConstant.listDataRTOScan.insert(0, newOrder);
            listScanData.insert(0, newOrder);
            AppConstant.itemCountRTO = AppConstant.itemCountRTO + 1;

            setState(() {});

            // 👉 Persist in storage
            if (storage.read(AppConstant.PREF_STORE_SCAN_RTO) != null) {
              storage.remove(AppConstant.PREF_STORE_SCAN_RTO);
            }
            if (storage.read(AppConstant.PREF_STORE_SCAN_COUNT_RTO) != null) {
              storage.remove(AppConstant.PREF_STORE_SCAN_COUNT_RTO);
            }

            // Store today’s date + orders in storage
            storeCurrentDate();
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
          }, barrierDismissible: false);}

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
        AppConstant.listDataRTOScan.map((order) => order.toJson()).toList();

    // Store the JSON list in GetStorage
    storage.write(AppConstant.PREF_STORE_SCAN_RTO, ordersJson);
    storage.write(AppConstant.PREF_STORE_SCAN_COUNT_RTO, AppConstant.itemCountRTO);
    storeCurrentDate();
    print("Orders stored successfully.");
  }

  void retrieveOrdersFromStorage() {
    // Retrieve the JSON list from GetStorage
    List<dynamic>? ordersJson = storage.read(AppConstant.PREF_STORE_SCAN_RTO);

    if (ordersJson != null) {
      // Convert JSON to Orders objects
      List<Orders> allOrders = ordersJson.map((json) => Orders.fromJson(json)).toList();

      // Filter orders based on matching courierSlug
      listScanData = allOrders.toList();
         /* .where((order) => order.courierSlug.toString().toLowerCase() == AppConstant.SHIPPING_COMPANY_TITLE.toString().toLowerCase())
          .toList();*/

      // Update itemCountRTO to match only the filtered records
      AppConstant.itemCountRTO = listScanData.length;

      print("Filtered orders retrieved successfully. Count: ${AppConstant.itemCountRTO}");
      setState(() {});
    } else {
      print("No orders found in storage.");
    }
  }
  void checkAndClearOldData() {
    String? storedDate = storage.read(AppConstant.PREF_STORE_DATE_RTO);
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    if (storedDate == null || storedDate != today) {
      // New day -> Clear all old scan data
      AppConstant.listDataRTOScan.clear();
      listScanData.clear();
      AppConstant.itemCountRTO = 0;

      // Also clear from storage
      storage.remove(AppConstant.PREF_STORE_SCAN_RTO);
      storage.remove(AppConstant.PREF_STORE_SCAN_COUNT_RTO);

      // Store fresh date
      storeCurrentDate();

      print("✅ Old data cleared, new day started");
    } else {
      retrieveOrdersFromStorage();
      print("📅 Same day, keeping existing scan data");
    }
  }
  void storeCurrentDate() {
    String currentDate =
        DateFormat('yyyy-MM-dd').format(DateTime.now()); // Format the date
    storage.write(AppConstant.PREF_STORE_DATE_RTO, currentDate);
    print("Current date stored: $currentDate");
  }

  void checkAndRemoveOldDate() {
    String? storedDate = storage.read(AppConstant.PREF_STORE_DATE_RTO);
    String currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

    if (storedDate == null || storedDate != currentDate) {
      // If the stored date is null or not equal to today's date
      storage.remove(AppConstant.PREF_STORE_DATE_RTO); // Remove old data
      storage.remove(AppConstant.PREF_STORE_SCAN_RTO); // Remove old data
      storage.remove(AppConstant.PREF_STORE_SCAN_COUNT_RTO); // Remove old data
      storeCurrentDate(); // Store the new date
      print("Old date removed and new date stored.");
    } else {
      print("Data is up to date. Current date: $storedDate");
      retrieveOrdersFromStorage();
    }
    setState(() {});
  }
}
