import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:deodap/pages/auth/LogoutVO.dart';
import 'package:deodap/pages/home/ScanAWBVO.dart';
import 'package:deodap/widgets/extensions.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart' hide Response, FormData;
import 'package:get_storage/get_storage.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';

import '../../commonmodule/appConstant.dart';
import '../../commonmodule/appString.dart';
import '../../utils/routes.dart';
import '../../widgets/all_widget.dart';
import '../splash/DeviceConfigVO.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  var storage = GetStorage();
  DeviceConfigVO? deviceConfigVO;
  LogoutVO? logoutVO;
  String _scanBarcode = 'Unknown';
  bool isOutwardScanType = true;

  /*Back*/
  bool back = false;
  int time = 0;
  int duration = 1000;

  bool _isFirstTappedBottom = false;
  bool _isSecondTappedBottom = false;
  bool _isThirdTappedBottom = false;
  bool _isFourthTappedBottom = false;
  bool _isSixthTappedBottom = false;
  bool _isFifthTappedBottom = false;

  bool _isFirstTapped = false;
  bool _isSecondTapped = false;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    check().then((intenet) {
      if (intenet) {
        getSetting();
        setState(() {});
      } else {
        // No-Internet Case
        toastError(AppString.no_internet);
      }
    });
  }

  getSetting() {
    if (storage.read(AppConstant.PREF_SETTTING_QR) != null) {
      AppConstant.switchValueNotification =
          storage.read(AppConstant.PREF_SETTTING_QR);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _handleTap(String containerType) {
    setState(() {
      if (containerType == "0") {
        _isFirstTapped = true;
      } else if (containerType == "1") {
        _isSecondTapped = true;
      }
    });

    Timer(Duration(milliseconds: 100), () {
      setState(() {
        if (containerType == "0") {
          _isFirstTapped = false;
        } else if (containerType == "1") {
          _isSecondTapped = false;
        }
      });
      scanQRAndCapturePhoto();
      /*if (containerType == '0') {
        scanQR();// Adjust this according to your navigation
      }
      else {
        scanQR();
      }*/
    });
  }

  void _handleTapBottom(String containerType) {
    setState(() {
      if (containerType == "0") {
        _isFirstTappedBottom = true;
      } else if (containerType == "1") {
        _isSecondTappedBottom = true;
      } else if (containerType == "2") {
        _isThirdTappedBottom = true;
      } else if (containerType == "3") {
        _isFifthTappedBottom = true;
      } else if (containerType == "6") {
        _isSixthTappedBottom = true;
      } else {
        _isFourthTappedBottom = true;
      }
    });

    Timer(Duration(milliseconds: 100), () {
      setState(() {
        _isFirstTappedBottom = false;
        _isSecondTappedBottom = false;
        _isThirdTappedBottom = false;
        _isFourthTappedBottom = false;
        _isFifthTappedBottom = false;
        _isSixthTappedBottom = false;
      });
      //scanQR();
      if (containerType == '0') {
        Get.toNamed(Routes.orderScreenRoute);
      } else if (containerType == "1") {
        Get.toNamed(Routes.profileRoute);
      } else if (containerType == "2") {
        dialogSetting();
      } else if (containerType == "3") {
        Get.toNamed(Routes.pendingOrderScreenRoute);
      } else if (containerType == "6") {
        Get.toNamed(Routes.rtoRoute);
      } else {
        Get.toNamed(Routes.courierScreenRoute);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: willPop,
      child: Scaffold(
        backgroundColor: Colors.grey[100], // Lighter background for contrast
        appBar: appBar(
          AppString.appName,
          actions: <Widget>[
            Visibility(
              visible: false,
              child: IconButton(
                icon: Icon(
                  Icons.supervised_user_circle,
                  color: Colors.black54,
                ),
                onPressed: () {
                  Get.toNamed(Routes.profileRoute);
                },
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.logout,
                color: Colors.black54,
              ),
              onPressed: () {
                _showLogout(context);
              },
            ),
          ],
          automaticallyImplyLeading: false,
          centerTitle: true,
          elevation: 2.0,
          // Slightly higher elevation for a subtle shadow
          backgroundColor: Colors.white,
        ),
        body: Stack(
          children: <Widget>[
            Positioned.fill(
              child: Image.asset(
                "assets/images/bg.png",
                fit: BoxFit.cover,
                alignment: Alignment.bottomLeft,
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Visibility(
                    visible: false,
                    child: GestureDetector(
                      onTap: () {
                        isOutwardScanType = true;
                        scanQRAndCapturePhoto();
                        //_handleTap('0');
                      },
                      child: Container(
                        margin: EdgeInsets.only(bottom: 24),
                        height: 180,
                        decoration: BoxDecoration(
                          color: _isFirstTapped
                              ? Colors.green.shade50
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                AppConstant.switchValueNotification
                                    ? "assets/images/qr.png"
                                    : "assets/images/barcode.png",
                                width: 80,
                                height: 80,
                                color: Colors.black87,
                              ),
                              SizedBox(height: 10),
                              Text(
                                'Outward Scan',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  sizedBoxHWidget(20),
                  _buildMenuItem(
                    title: 'Outward Scan',
                    icon: Icons.navigate_next_sharp,
                    isActive: _isFourthTappedBottom,
                    onTap: () => _handleTapBottom('4'),
                  ),
                  SizedBox(height: 16),
                  _buildMenuItem(
                    title: 'RTO Shipments',
                    icon: Icons.navigate_next_sharp,
                    isActive: _isSixthTappedBottom,
                    onTap: () => _handleTapBottom('6'),
                  ),
                  SizedBox(height: 16),
                  _buildMenuItem(
                    title: 'Order List',
                    icon: Icons.navigate_next_sharp,
                    isActive: _isFirstTappedBottom,
                    onTap: () => _handleTapBottom('0'),
                  ),
                  SizedBox(height: 16),
                  _buildMenuItem(
                    title: 'Pending Order',
                    icon: Icons.navigate_next_sharp,
                    isActive: _isFifthTappedBottom,
                    onTap: () => _handleTapBottom('3'),
                  ),
                  SizedBox(height: 16),
                  Visibility(
                    visible: true,
                    child: _buildMenuItem(
                      title: 'Profile',
                      icon: Icons.navigate_next_sharp,
                      isActive: _isSecondTappedBottom,
                      onTap: () => _handleTapBottom('1'),
                    ),
                  ),
                  SizedBox(height: 16),
                  Visibility(
                    visible: true,
                    child: _buildMenuItem(
                      title: 'Setting',
                      icon: Icons.navigate_next_sharp,
                      isActive: _isThirdTappedBottom,
                      onTap: () => _handleTapBottom('2'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required String title,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 16),
        padding: EdgeInsets.symmetric(horizontal: 10),
        height: 80,
        decoration: BoxDecoration(
          color: isActive ? Colors.green.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? Colors.green.shade200 : Colors.transparent,
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

  updateData(pageName) async {
    var response = await Get.toNamed(pageName);
    if (response)
      setState(() {
        scanQRAndCapturePhoto();
      });
    return response;
  }

  // Call this from your widget's State (same name as before)
  Future<void> scanQRAndCapturePhoto() async {
    String barcodeScanRes = "-1";

    try {
      final result = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (context) => const _ParcelScannerScreen()),
      );

      if (result != null && result.isNotEmpty) {
        barcodeScanRes = result;
      }
    } catch (e) {
      // Keep old behavior on error
      barcodeScanRes = "-1";
      debugPrint('scan error: $e');
    }

    if (!mounted) return;

    if (barcodeScanRes == "-1") {
      // user cancelled (same as old plugin)
      setState(() {}); // optional — keep if you relied on it previously
    } else {
      // preserve old behaviour
      AppConstant.SCAN_ID = barcodeScanRes.toString();
      // capturePhoto(_cameraController); // call if you still need photo capture
      sendData();
    }
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
          playSoundSuccess();
          Future.delayed(Duration(seconds: 1), () {
            scanQRAndCapturePhoto();
          });
        } else {
          hideProgressBar();
          playSoundError();
          showDialogCommon(
              context, "Error 1 -> " + scanAWBVO.data!.errors.toString(),
              onOkTap: () {
            scanQRAndCapturePhoto();
          }, barrierDismissible: false);
        }
      } else {
        hideProgressBar();
        playSoundError();
        showDialogCommon(context, "Error 2 -> " + scanAWBVO.toString(),
            onOkTap: () {
          scanQRAndCapturePhoto();
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

  callAPILogOut() async {
    showProgress();
    try {
      var _response =
          await apiCall().get(AppConstant.WS_LOGOUT, options: option());
      hideProgressBar();
      if (_response.statusCode == AppConstant.STATUS_CODE) {
        logoutVO = LogoutVO.fromJson(jsonDecode(_response.toString()));
        if (logoutVO!.success!) {
          storage.erase();
          storage.write(AppConstant.IS_LOGIN, false);
          Get.toNamed(Routes.loginRoute);
        } else {
          toastError(logoutVO!.message.toString());
        }
      } else {
        hideProgressBar();
        storage.write(AppConstant.IS_LOGIN, false);
        Get.toNamed(Routes.loginRoute);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Oops! Something went wrong...'),
          ),
        );
      }
    } catch (e) {
      storage.write(AppConstant.IS_LOGIN, false);
      Get.toNamed(Routes.loginRoute);
      print('Error: $e');
    }
  }

  Future<bool> willPop() async {
    int now = DateTime.now().millisecondsSinceEpoch;
    if (back && time >= now) {
      back = false;
      exit(0);
    } else {
      time = DateTime.now().millisecondsSinceEpoch + duration;
      print("again tap");
      back = true;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Press again the button to exit")));
    }
    return false;
  }

  void dialogSetting() {
    Get.bottomSheet(
      StatefulBuilder(builder: (context, setState) {
        return SafeArea(
          child: Container(
            color: Colors.white,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                // Use min to adjust height to content
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.only(left: 10, top: 10, right: 10),
                    child: Row(
                      children: [
                        Text(
                          "SETTING",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: appColor(),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Spacer(),
                        IconButton(
                          alignment: Alignment.topRight,
                          onPressed: () {
                            if (Get.isBottomSheetOpen ?? false) {
                              Get.back();
                            }
                          },
                          icon: Icon(
                            Icons.close_rounded,
                            size: 30,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    color: Colors.grey[300],
                  ),
                  sizedBoxHWidget(10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Barcode Scan Enable',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        SizedBox(width: 5),
                        Transform.scale(
                          transformHitTests: true,
                          scale: 0.8,
                          child: CupertinoSwitch(
                            value: AppConstant.switchValueNotification,
                            activeColor: Color(0xFFBD8B5A),
                            trackColor: Colors.grey,
                            onChanged: (value) {
                              setState(() {
                                AppConstant.switchValueNotification = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  sizedBoxHWidget(40),
                  Center(
                    child: Container(
                      width: Get.width / 2,
                      child: ElevatedButton(
                        onPressed: () {
                          saveSetting();
                          Get.back();
                        },
                        child: Text(
                          "SAVE",
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: appColor(),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 10), // Adjust spacing as needed
                ],
              ),
            ),
          ),
        );
      }),
      isScrollControlled: true,
    );
  }

  void _showLogout(BuildContext context) {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            title: Container(),
            content: Text(
              'Are you sure you want to Logout?',
              style: TextStyle(
                  color: Colors.black,
                  fontFamily: fontName(),
                  fontSize: 13,
                  fontWeight: FontWeight.w400),
              textAlign: TextAlign.center,
            ),
            actions: [
              Container(
                margin: EdgeInsets.only(bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        height: 35,
                        width: 100,
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
                            'No',
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
                        callAPILogOut();
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
                            'Yes',
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
              ),
            ],
          );
        });
  }

  void saveSetting() {
    setState(() {
      storage.write(
          AppConstant.PREF_SETTTING_QR, AppConstant.switchValueNotification);
    });
  }
}

// ---------- Scanner screen (no big changes to your app flow) ----------
class _ParcelScannerScreen extends StatefulWidget {
  const _ParcelScannerScreen({Key? key}) : super(key: key);

  @override
  State<_ParcelScannerScreen> createState() => _ParcelScannerScreenState();
}

class _ParcelScannerScreenState extends State<_ParcelScannerScreen> {
  // Use the controller instead of allowDuplicates param
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    // prevents rapid duplicate callbacks
    detectionTimeoutMs: 250,
    // tune if needed
    facing: CameraFacing.back,
  );

  bool _scanned = false;
  bool _torchOn = false;

  @override
  void dispose() {
    // stop + dispose controller to free camera
    unawaited(_controller.stop());
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Parcel'),
        actions: [
          IconButton(
            icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
            onPressed: () async {
              try {
                await _controller.toggleTorch();
                setState(() {
                  _torchOn = !_torchOn;
                });
              } catch (e) {
                debugPrint('toggleTorch failed: $e');
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () =>
                Navigator.pop(context, "-1"), // keep previous cancel behaviour
          ),
        ],
      ),
      body: MobileScanner(
        controller: _controller,
        // onDetect now receives a BarcodeCapture (list of barcodes + optional image)
        onDetect: (BarcodeCapture capture) async {
          if (_scanned) return; // guard to prevent multiple pops
          final List<Barcode> barcodes = capture.barcodes;
          if (barcodes.isEmpty) return;

          final String code = barcodes.first.rawValue ?? "-1";
          _scanned = true;

          // stop camera immediately to avoid further detections in the background
          try {
            await _controller.stop();
          } catch (_) {}

          // return code to the caller (like old plugin)
          if (mounted) Navigator.pop(context, code);
        },
      ),
    );
  }
}
