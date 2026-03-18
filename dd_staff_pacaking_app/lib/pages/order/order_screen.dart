import 'dart:convert';
import 'dart:io';

import 'package:deodap/commonmodule/HexColor.dart';
import 'package:deodap/pages/order/OrderInfoVO.dart';
import 'package:deodap/pages/order/SendOrderVO.dart';
import 'package:deodap/widgets/extensions.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response, FormData, MultipartFile;
import 'package:get_storage/get_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../commonmodule/appConstant.dart';
import '../../commonmodule/appString.dart';
import '../../widgets/all_widget.dart';
import '../auth/LoginVo.dart';
import '../splash/DeviceConfigVO.dart';

class OrderScreen extends StatefulWidget {
  const OrderScreen({Key? key}) : super(key: key);

  @override
  _OrderScreenState createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  var storage = GetStorage();
  DeviceConfigVO? deviceConfigVO;
  LoginVo? loginVo;
  OrderInfoVO? orderInfoVO;
  SendOrderVO? sendOrderVO;

  bool isShowMoreDetails = false;
  int selectedCard = -1;
  final TextEditingController boxController = TextEditingController();
  bool flag = true;
  var imageFile = '';
  var imageFile2 = '';
  bool isUpdateValue = true;

  // -----------------------------
  // UI theme (blue premium)
  // -----------------------------
  Color get _bluePrimary => const Color(0xFF1E5EFF);
  Color get _blueSoft => const Color(0xFFE9F0FF);
  Color get _bg => const Color(0xFFF6F8FF);
  Color get _cardBg => Colors.white;
  Color get _textDark => const Color(0xFF101828);

  TextStyle get _hTitle => const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.2,
  );

  TextStyle get _hSub => TextStyle(
    fontSize: 12.5,
    color: Colors.grey.shade700,
    fontWeight: FontWeight.w600,
  );

  @override
  void initState() {
    super.initState();
    loginVo = LoginVo.fromJson(storage.read(AppConstant.PREF_APP_INFO_LOGIN));
    deviceConfigVO = DeviceConfigVO.fromJson(storage.read(AppConstant.PREF_APP_INFO));

    check().then((intenet) {
      if (intenet != null && intenet) {
        getOrderInfo();
      } else {
        toastError(AppString.no_internet);
      }
    });
  }

  @override
  void dispose() {
    boxController.dispose();
    super.dispose();
  }

  // -----------------------------
  // Small helpers
  // -----------------------------
  Widget _pill(String text, {IconData? icon, Color? bg, Color? fg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg ?? _blueSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg ?? _bluePrimary),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: fg ?? _textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t, {String? rightText, VoidCallback? onRightTap}) {
    return Row(
      children: [
        Text(t, style: _hTitle.copyWith(color: _textDark)),
        const Spacer(),
        if (rightText != null)
          InkWell(
            onTap: onRightTap,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(
                rightText,
                style: TextStyle(
                  color: _bluePrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 12.5,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _card({required Widget child, EdgeInsets? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _orderHeaderCard() {
    final info = orderInfoVO!.data!.orderInfo!;
    final pack = orderInfoVO!.data!.packagingInfo!;
    final staffName = (pack.packagingStaffName ?? '').trim();
    final staffCode = (pack.packagingStaffCode ?? '').trim();
    final statusColor = HexColor(info.statusColorCode!);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Order No + status pill
          Row(
            children: [
              Expanded(
                child: Text(
                  info.orderNo ?? "-",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _textDark,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  info.status ?? "-",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Staff line
          if (staffName.isNotEmpty || staffCode.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (staffName.isNotEmpty)
                  _pill(
                    staffName,
                    icon: Icons.person_rounded,
                    bg: const Color(0xFFFFF2E8),
                    fg: HexColor('#FFBD8B5A'),
                  ),
                if (staffCode.isNotEmpty)
                  _pill(
                    "($staffCode)",
                    icon: Icons.badge_rounded,
                    bg: const Color(0xFFFFF2E8),
                    fg: HexColor('#FFBD8B5A'),
                  ),
              ],
            ),

          const SizedBox(height: 12),

          // Amount
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.currency_rupee_rounded, color: _bluePrimary, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "Total Amount",
                    style: _hSub,
                  ),
                ),
                Text(
                  "Rs. ${info.total ?? "0"}",
                  style: TextStyle(
                    color: _textDark,
                    fontWeight: FontWeight.w900,
                    fontSize: 14.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Toggle details
          InkWell(
            onTap: () {
              setState(() => isShowMoreDetails = !isShowMoreDetails);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    isShowMoreDetails ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: Colors.grey.shade700,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isShowMoreDetails ? "Show less details" : "Show more details",
                    style: TextStyle(
                      color: Colors.grey.shade800,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (isShowMoreDetails) ...[
            const SizedBox(height: 12),
            _moreDetailsBlock(),
          ],
        ],
      ),
    );
  }

  Widget _moreDetailsBlock() {
    final info = orderInfoVO!.data!.orderInfo!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.calendar_month_outlined, color: Colors.grey.shade800, size: 16),
              const SizedBox(width: 6),
              Text(
                info.createdAt ?? "-",
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontSize: 12.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            info.buyerName ?? "-",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textDark,
              fontSize: 15.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            info.buyerCity ?? "-",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade800,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            info.buyerPhone ?? "-",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade800,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _attachmentsCard() {
    final pack = orderInfoVO!.data!.packagingInfo!;
    final base = deviceConfigVO?.data?.assetsBaseUrl ?? "";

    Widget imageBox({
      required String title,
      required String localPath,
      required String serverPath,
      required VoidCallback onTap,
    }) {
      final hasLocal = localPath.isNotEmpty;
      final hasServer = serverPath.isNotEmpty;

      Widget img;
      if (hasLocal) {
        img = Image.file(
          File(localPath),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      } else if (hasServer) {
        img = FadeInImage(
          fit: BoxFit.cover,
          placeholder:  AssetImage(AppConstant.placeHolderImagePath),
          image: NetworkImage(base + serverPath),
        );
      } else {
        img = Image(
          fit: BoxFit.cover,
          image: AssetImage(AppConstant.placeHolderImagePath),
        );
      }

      return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: _textDark,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 130,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                  color: _bg,
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    Positioned.fill(child: img),
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.45),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          "Tap",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 11.5,
                          ),
                        ),
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

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("Attachments"),
          const SizedBox(height: 10),
          Row(
            children: [
              imageBox(
                title: "Attachment 1",
                localPath: imageFile,
                serverPath: pack.attachment1 ?? "",
                onTap: () => dialogPhoto('1'),
              ),
              const SizedBox(width: 12),
              imageBox(
                title: "Attachment 2",
                localPath: imageFile2,
                serverPath: pack.attachment2 ?? "",
                onTap: () => dialogPhoto('2'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "Choose from Camera or Gallery",
            style: _hSub,
          ),
        ],
      ),
    );
  }

  Widget _boxCountCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("Total Box Count"),
          const SizedBox(height: 10),

          // Grid (1..8 and 9+)
          GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.25,
            ),
            itemCount: 9,
            itemBuilder: (context, index) {
              final isSelected = selectedCard == index;
              final label = (index + 1) == 9 ? "9+" : (index + 1).toString();

              return InkWell(
                onTap: () {
                  setState(() {
                    selectedCard = index;
                    boxController.text = (index + 1).toString();
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: isSelected
                        ? LinearGradient(
                      colors: [_bluePrimary, const Color(0xFF2A7BFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                        : null,
                    color: isSelected ? null : const Color(0xFFF1F3F7),
                    border: Border.all(
                      color: isSelected ? Colors.transparent : Colors.grey.shade200,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: isSelected ? Colors.white : _textDark,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          if (selectedCard == 8) ...[
            const SizedBox(height: 12),
            Text(
              "Enter custom box count",
              style: _hSub.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: boxController,
              keyboardType: TextInputType.number,
              maxLength: 3,
              decoration: InputDecoration(
                counterText: "",
                filled: true,
                fillColor: _bg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                hintText: 'Enter no. of box',
                hintStyle: const TextStyle(fontSize: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: _bluePrimary, width: 1.4),
                ),
              ),
            ),
          ] else ...[
            // Keep boxController in sync even if user doesn't tap after API load
            const SizedBox(height: 2),
          ],
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          children: [
            InkWell(
              onTap: () {
                isUpdateValue ? Get.back(result: true) : Get.back(result: false);
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 54,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F3F7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: const Center(
                  child: Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    // ✅ Functional behavior unchanged: you were calling _sendData() directly
                    _sendData();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: flag ? HexColor('#FFBD8B5A') : Colors.teal,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    flag ? 'SUBMIT' : 'SEND DATA...',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _noRecord() {
    return Container(
      width: screenWidth(context),
      height: mainHeight(context) + 100,
      alignment: Alignment.center,
      child: Image.asset(
        AppConstant.noRecordImagePath,
        height: AppConstant.noRecordImageHeightWidth,
        width: AppConstant.noRecordImageHeightWidth,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        isUpdateValue ? Get.back(result: true) : Get.back(result: false);
        return false;
      },
      child: Scaffold(
        backgroundColor: _bg,
        body: orderInfoVO != null && orderInfoVO!.data != null
            ? Stack(
          children: [
            // Background soft gradient
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _blueSoft.withOpacity(0.60),
                      _bg,
                      _bg,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  // Top app header (iOS-like)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () {
                            isUpdateValue ? Get.back(result: true) : Get.back(result: false);
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Icon(Icons.arrow_back_ios_new_rounded, color: _textDark, size: 18),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Order Details", style: _hTitle.copyWith(color: _textDark)),
                              const SizedBox(height: 3),
                              Text("Scan ID: ${AppConstant.SCAN_ID}", style: _hSub, maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [_bluePrimary, const Color(0xFF2A7BFF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 18),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 100),
                      child: Column(
                        children: [
                          _orderHeaderCard(),
                          const SizedBox(height: 12),

                          if (!isShowMoreDetails) ...[
                            _attachmentsCard(),
                            const SizedBox(height: 12),
                          ],

                          _boxCountCard(),
                          const SizedBox(height: 12),

                          // Small note for user friendliness
                          _card(
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: _blueSoft,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(Icons.info_outline_rounded, color: _bluePrimary),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    "Select box count and upload at least one attachment if required, then submit.",
                                    style: TextStyle(
                                      color: Colors.grey.shade800,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      height: 1.25,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom bar (sticky)
            Positioned(left: 0, right: 0, bottom: 0, child: _bottomBar()),
          ],
        )
            : _noRecord(),
      ),
    );
  }

  // =========================================================
  // ✅ ALL YOUR EXISTING FUNCTIONALITY BELOW (UNCHANGED)
  // =========================================================

  getOrderInfo() async {
    showProgress();
    try {
      var _response = await apiCall().get(AppConstant.WS_ORDER_INFO, queryParameters: {
        "app_id": AppConstant.APP_ID,
        "api_key": AppConstant.APP_KEY,
        "token": loginVo!.data!.token.toString(),
        "order_hash": AppConstant.SCAN_ID,
      });
      if (_response.statusCode == AppConstant.STATUS_CODE) {
        hideProgressBar();
        orderInfoVO = OrderInfoVO.fromJson(jsonDecode(_response.toString()));
        if (orderInfoVO != null && orderInfoVO!.status == AppConstant.APP_SUCCESS) {
          if (orderInfoVO!.data!.packagingInfo!.shipmentPackagesCount != null) {
            if (orderInfoVO!.data!.packagingInfo!.shipmentPackagesCount! > 8) {
              selectedCard = 8;
            } else {
              selectedCard = orderInfoVO!.data!.packagingInfo!.shipmentPackagesCount! - 1;
            }
            boxController.text = orderInfoVO!.data!.packagingInfo!.shipmentPackagesCount!.toString();
          }
          setState(() {});
        } else {
          toastError(orderInfoVO!.message!);
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
      // ignore: avoid_print
      print('Error: $e');
    }
  }

  dialogPhoto(var files) {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(AppString.appName),
          content: const Text('Choose Photo Option'),
          actions: [
            TextButton(
              child: const Text('Camera'),
              onPressed: () {
                Get.back();
                getFromCamera(files);
              },
            ),
            TextButton(
              child: const Text('Gallery'),
              onPressed: () {
                Get.back();
                getFromGallery(files);
              },
            ),
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
    if (pickedFile != null) {
      setState(() {
        if (files == '1') {
          imageFile = pickedFile.path;
        } else {
          imageFile2 = pickedFile.path;
        }
      });
    }
  }

  getFromCamera(var files) async {
    XFile? pickedFile = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1800,
      maxHeight: 1800,
    );
    if (pickedFile != null) {
      setState(() {
        if (files == '1') {
          imageFile = pickedFile.path;
        } else {
          imageFile2 = pickedFile.path;
        }
      });
    }
  }

  void validation() {
    if (imageFile.isNotEmpty ||
        imageFile2.isNotEmpty ||
        orderInfoVO!.data!.packagingInfo!.attachment1!.isNotEmpty ||
        orderInfoVO!.data!.packagingInfo!.attachment2!.isNotEmpty) {
      if (boxController.text.isNotEmpty) {
        setState(() {
          flag = !flag;
        });
        _sendData();
      } else {
        toastFeedback('Select packages count');
      }
    } else {
      snackBar('Validation', 'Choose at least one attachment', 3);
    }
  }

  Future<void> _sendData() async {
    showProgress();
    try {
      String fileName = "";
      if (imageFile.isNotEmpty) {
        fileName = imageFile.split('/').last;
      }
      String fileName2 = "";
      if (imageFile2.isNotEmpty) {
        fileName2 = imageFile2.split('/').last;
      }
      FormData formData = FormData.fromMap(<String, dynamic>{
        "app_id": AppConstant.APP_ID,
        "api_key": AppConstant.APP_KEY,
        "token": loginVo!.data!.token.toString(),
        "order_hash": AppConstant.SCAN_ID,
        "shipment_packages_count": boxController.text,
        if (fileName.isNotEmpty) "attachment1": await MultipartFile.fromFile(imageFile, filename: fileName),
        if (fileName2.isNotEmpty) "attachment2": await MultipartFile.fromFile(imageFile2, filename: fileName2),
      });

      var _response = await apiCall().post(AppConstant.WS_SEND_ORDER, data: formData);
      if (_response.statusCode == AppConstant.STATUS_CODE) {
        hideProgressBar();
        sendOrderVO = SendOrderVO.fromJson(jsonDecode(_response.toString()));
        if (sendOrderVO != null && sendOrderVO!.status == AppConstant.APP_SUCCESS) {
          toastSuccess(sendOrderVO!.message);
          isUpdateValue ? Get.back(result: true) : Get.back(result: false);
          setState(() {
            flag = !flag;
          });
        } else {
          snackBar("Error", sendOrderVO!.message.toString(), 5);
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
      setState(() {
        flag = !flag;
      });
      return;
    }
  }
}
