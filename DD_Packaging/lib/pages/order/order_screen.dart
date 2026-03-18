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

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    loginVo = LoginVo.fromJson(storage.read(AppConstant.PREF_APP_INFO_LOGIN));
    deviceConfigVO =
        DeviceConfigVO.fromJson(storage.read(AppConstant.PREF_APP_INFO));
    check().then((intenet) {
      if (intenet != null && intenet) {
        getOrderInfo();
      } else {
        // No-Internet Case
        toastError(AppString.no_internet);
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height -
        (MediaQuery.of(context).padding.top +
            MediaQuery.of(context).padding.bottom);
    return WillPopScope(
      onWillPop: () async {
        isUpdateValue ? Get.back(result: true) : Get.back(result: false);
        return false;
      },
      child: Scaffold(
          backgroundColor: Colors.white,
          //resizeToAvoidBottomInset: false,
          body: orderInfoVO != null && orderInfoVO!.data != null
              ? SingleChildScrollView(
                child: SafeArea(
                  child: Stack(
                    children: [
                      Container(
                        height: height,
                        margin: EdgeInsets.symmetric(
                            horizontal: 10, vertical: 0),
                        padding: EdgeInsets.only(top: 15),
                        child: Column(
                          children: [
                            Column(
                              children: [
                                Text(
                                  orderInfoVO!.data!.orderInfo!.orderNo!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 20,
                                      color: Colors.black,
                                      fontWeight: FontWeight.w600),
                                ),
                                SizedBox(
                                  height: 5,
                                ),
                                Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.center,
                                  children: [
                                    orderInfoVO!
                                        .data!.packagingInfo!.packagingStaffName!=null&&orderInfoVO!
                                        .data!.packagingInfo!.packagingStaffName!.isNotEmpty?Text(
                                      orderInfoVO!
                                          .data!.packagingInfo!.packagingStaffName!,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 16,
                                          color:  HexColor('#FFBD8B5A'),
                                          fontWeight: FontWeight.w400),
                                    ):Container(),
                                    SizedBox(width: 3,),
                                    orderInfoVO!
                                        .data!.packagingInfo!.packagingStaffCode!=null&&orderInfoVO!
                                        .data!.packagingInfo!.packagingStaffCode!.isNotEmpty?Text(
                                      '( ' +
                                          orderInfoVO!
                                              .data!.packagingInfo!.packagingStaffCode!+' )',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: HexColor('#FFBD8B5A'),
                                          fontWeight: FontWeight.w400),
                                    ):Container(),
                                  ],
                                ),
                                SizedBox(
                                  height: 15,
                                ),
                                Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                          color: HexColor(orderInfoVO!
                                              .data!.orderInfo!.statusColorCode!),
                                          borderRadius: BorderRadius.all(
                                              Radius.circular(5))),
                                      child: Text(
                                        orderInfoVO!
                                            .data!.orderInfo!.status!,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w400),
                                      ),
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 15, vertical: 5),
                                    ),
                                    Container(
                                      decoration: BoxDecoration(
                                          border: Border.all(
                                            color: HexColor(orderInfoVO!
                                                .data!.orderInfo!.statusColorCode!),
                                          ),
                                          borderRadius: BorderRadius.all(
                                              Radius.circular(5))),
                                      child: Text(
                                        'Rs. ' +
                                            orderInfoVO!
                                                .data!.orderInfo!.total!,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.black,
                                            fontWeight: FontWeight.w400),
                                      ),
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 15, vertical: 5),
                                    ),
                                  ],
                                ),
                                SizedBox(
                                  height: 20,
                                ),
                                !isShowMoreDetails
                                    ? Row(
                                  children: [
                                    Expanded(
                                        child: new Divider(
                                          color: Colors.blueGrey.shade100,
                                          thickness: 1,
                                        )),
                                    SizedBox(
                                      width: 10,
                                    ),
                                    Container(
                                      child: GestureDetector(
                                        onTap: () {
                                          isShowMoreDetails =
                                          !isShowMoreDetails;
                                          setState(() {});
                                        },
                                        child: Row(
                                          children: [
                                            Text(
                                              !isShowMoreDetails
                                                  ? "Show more details"
                                                  : 'Show less details',
                                              style: TextStyle(
                                                  color:
                                                  Colors.black54,
                                                  fontSize: 14,
                                                  fontWeight:
                                                  FontWeight
                                                      .w400),
                                            ),
                                            SizedBox(
                                              width: 5,
                                            ),
                                            Icon(
                                              !isShowMoreDetails
                                                  ? Icons
                                                  .arrow_circle_down_outlined
                                                  : Icons
                                                  .arrow_circle_up_outlined,
                                              color: Colors.black54,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 10,
                                    ),
                                    Expanded(
                                        child: new Divider(
                                          color: Colors.blueGrey.shade100,
                                          thickness: 1,
                                        )),
                                  ],
                                )
                                    : Column(
                                  mainAxisAlignment:
                                  MainAxisAlignment.center,
                                  crossAxisAlignment:
                                  CrossAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      height: 10,
                                    ),
                                    Row(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.center,
                                      mainAxisAlignment:
                                      MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons
                                              .calendar_month_outlined,
                                          color: Colors.black87,
                                          size: 15,
                                        ),
                                        SizedBox(
                                          width: 5,
                                        ),
                                        Text(
                                          orderInfoVO!.data!
                                              .orderInfo!.createdAt!,
                                          style: TextStyle(
                                              color: Colors.black87,
                                              fontSize: 13,
                                              fontWeight:
                                              FontWeight.w300),
                                        ),
                                      ],
                                    ),
                                    SizedBox(
                                      height: 10,
                                    ),
                                    Text(
                                      orderInfoVO!.data!.orderInfo!
                                          .buyerName!,
                                      style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 16,
                                          fontWeight:
                                          FontWeight.w500),
                                    ),
                                    SizedBox(
                                      height: 5,
                                    ),
                                    Text(
                                      orderInfoVO!.data!.orderInfo!
                                          .buyerCity!,
                                      style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 14,
                                          fontWeight:
                                          FontWeight.w400),
                                    ),
                                    SizedBox(
                                      height: 5,
                                    ),
                                    Text(
                                      orderInfoVO!.data!.orderInfo!
                                          .buyerPhone!,
                                      style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 14,
                                          fontWeight:
                                          FontWeight.w400),
                                    ),
                                    SizedBox(
                                      height: 10,
                                    ),
                                    Row(
                                      children: [
                                        Expanded(
                                            child: new Divider(
                                              color: Colors
                                                  .blueGrey.shade100,
                                              thickness: 1,
                                            )),
                                        SizedBox(
                                          width: 10,
                                        ),
                                        Container(
                                          child: GestureDetector(
                                            onTap: () {
                                              isShowMoreDetails =
                                              !isShowMoreDetails;
                                              setState(() {});
                                            },
                                            child: Row(
                                              children: [
                                                Text(
                                                  !isShowMoreDetails
                                                      ? "Show more details"
                                                      : 'Show less details',
                                                  style: TextStyle(
                                                      color: Colors
                                                          .black54,
                                                      fontSize: 14,
                                                      fontWeight:
                                                      FontWeight
                                                          .w400),
                                                ),
                                                SizedBox(
                                                  width: 5,
                                                ),
                                                Icon(
                                                  !isShowMoreDetails
                                                      ? Icons
                                                      .arrow_circle_down_outlined
                                                      : Icons
                                                      .arrow_circle_up_outlined,
                                                  color:
                                                  Colors.black54,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 10,
                                        ),
                                        Expanded(
                                            child: new Divider(
                                              color: Colors
                                                  .blueGrey.shade100,
                                              thickness: 1,
                                            )),
                                      ],
                                    )
                                  ],
                                ),
                                SizedBox(
                                  height: 20,
                                ),
                              ],
                            ),
                            !isShowMoreDetails
                                ? Container(
                              margin: EdgeInsets.symmetric(
                                  horizontal: 20),
                              child: Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      dialogPhoto('1');
                                    },
                                    child: Column(
                                      children: [
                                        Text(
                                          'Attachment 1',
                                          textAlign: TextAlign.start,
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.black87,
                                              fontWeight:
                                              FontWeight.w400),
                                        ),
                                        SizedBox(
                                          height: 5,
                                        ),
                                        ClipRRect(
                                          borderRadius:
                                          BorderRadius.all(
                                            Radius.circular(5),
                                          ),
                                          child: imageFile.isEmpty
                                              ? orderInfoVO!
                                              .data!
                                              .packagingInfo!
                                              .attachment1!
                                              .isEmpty
                                              ? FadeInImage(
                                            fit: BoxFit
                                                .cover,
                                            placeholder:
                                            AssetImage(
                                                AppConstant
                                                    .placeHolderImagePath),
                                            //image: NetworkImage(orderInfoVO!.data!.packagingInfo!.attachment1!),
                                            image: AssetImage(
                                                AppConstant
                                                    .placeHolderImagePath),
                                            height: 120,
                                            width: 120,
                                          )
                                              : FadeInImage(
                                            fit: BoxFit
                                                .cover,
                                            placeholder:
                                            AssetImage(
                                                AppConstant
                                                    .placeHolderImagePath),
                                            image: NetworkImage(deviceConfigVO!
                                                .data!
                                                .assetsBaseUrl! +
                                                orderInfoVO!
                                                    .data!
                                                    .packagingInfo!
                                                    .attachment1!),
                                            height: 120,
                                            width: 120,
                                          )
                                              : Image.file(
                                            File(imageFile),
                                            fit: BoxFit.cover,
                                            //image: NetworkImage(orderInfoVO!.data!.packagingInfo!.attachment1!),
                                            height: 120,
                                            width: 120,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      dialogPhoto('2');
                                    },
                                    child: Column(
                                      children: [
                                        Text(
                                          'Attachment 2',
                                          textAlign: TextAlign.start,
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.black87,
                                              fontWeight:
                                              FontWeight.w400),
                                        ),
                                        SizedBox(
                                          height: 5,
                                        ),
                                        ClipRRect(
                                          borderRadius:
                                          BorderRadius.all(
                                            Radius.circular(5),
                                          ),
                                          child: imageFile2.isEmpty
                                              ? orderInfoVO!
                                              .data!
                                              .packagingInfo!
                                              .attachment2!
                                              .isEmpty
                                              ? FadeInImage(
                                            fit: BoxFit
                                                .cover,
                                            placeholder:
                                            AssetImage(
                                                AppConstant
                                                    .placeHolderImagePath),
                                            //image: NetworkImage(orderInfoVO!.data!.packagingInfo!.attachment1!),
                                            image: AssetImage(
                                                AppConstant
                                                    .placeHolderImagePath),
                                            height: 120,
                                            width: 120,
                                          )
                                              : FadeInImage(
                                            fit: BoxFit
                                                .cover,
                                            placeholder:
                                            AssetImage(
                                                AppConstant
                                                    .placeHolderImagePath),
                                            image: NetworkImage(deviceConfigVO!
                                                .data!
                                                .assetsBaseUrl! +
                                                orderInfoVO!
                                                    .data!
                                                    .packagingInfo!
                                                    .attachment2!),
                                            height: 120,
                                            width: 120,
                                          )
                                              : Image.file(
                                            File(imageFile2),
                                            fit: BoxFit.cover,
                                            //image: NetworkImage(orderInfoVO!.data!.packagingInfo!.attachment1!),
                                            height: 120,
                                            width: 120,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )
                                : Container(),
                            Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.stretch,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                SizedBox(
                                  height: 25,
                                ),
                                Center(
                                  child: Text(
                                    'Total Box Count',
                                    textAlign: TextAlign.start,
                                    style: TextStyle(
                                        fontSize: 15,
                                        color: Colors.black87,
                                        fontWeight: FontWeight.w400),
                                  ),
                                ),
                                SizedBox(
                                  height: 5,
                                ),
                                GridView.builder(
                                  physics: ScrollPhysics(),
                                  scrollDirection: Axis.vertical,
                                  shrinkWrap: true,
                                  gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                      childAspectRatio:
                                      Get.width / Get.width * 1.3,
                                      crossAxisCount: 3,
                                      crossAxisSpacing: 0),
                                  itemBuilder:
                                      (BuildContext context, int index) {
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          // Ontap of each card, set the defined int to the grid view index
                                          selectedCard = index;
                                          boxController.text =
                                              (index + 1).toString();
                                        });
                                      },
                                      child: Column(
                                        children: [
                                          Container(
                                            child: Card(
                                              color: selectedCard == index
                                                  ? HexColor('#BD8B5A')
                                                  : HexColor('#E1E1E1'),
                                              child: Center(
                                                child: Text(
                                                  (index + 1) == 9
                                                      ? '9+'
                                                      : (index + 1)
                                                      .toString(),
                                                  textAlign:
                                                  TextAlign.center,
                                                  style: TextStyle(
                                                      fontSize: 19,
                                                      color: selectedCard ==
                                                          index
                                                          ? Colors.white
                                                          : Colors.black,
                                                      fontWeight:
                                                      FontWeight.w400),
                                                ),
                                              ),
                                            ),
                                            width: 80,
                                            height: 70,
                                          ),
                                          SizedBox(
                                            height: 10,
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  itemCount: 9,
                                ),
                                selectedCard == 8
                                    ? Column(
                                  mainAxisAlignment:
                                  MainAxisAlignment.end,
                                  crossAxisAlignment:
                                  CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      width: 80,
                                      margin:
                                      EdgeInsets.only(right: 15),
                                      child: TextFormField(
                                        controller: boxController,
                                        keyboardType:
                                        TextInputType.number,
                                        maxLength: 3,
                                        decoration: InputDecoration(
                                          isDense: true,
                                          contentPadding:
                                          const EdgeInsets
                                              .symmetric(
                                            horizontal: 10,
                                            vertical: 12,
                                          ),
                                          hintText:
                                          'Enter no. of box',
                                          hintStyle: const TextStyle(
                                              fontSize: 14),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                            BorderRadius.circular(
                                                4),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                                    : Container(),
                              ],
                            ),
                            Spacer(),
                            Container(
                              width: Get.width,
                              height: 50,
                              margin:
                              EdgeInsets.symmetric(vertical: 5, horizontal: 5),
                              child: Row(
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      isUpdateValue
                                          ? Get.back(result: true)
                                          : Get.back(result: false);
                                    },
                                    child: Container(
                                      width: 70,
                                      height: 50,
                                      decoration: BoxDecoration(
                                          color: Colors.grey.shade300,
                                          border: Border.all(
                                            color: HexColor('#F6F6F6'),
                                          ),
                                          borderRadius:
                                          BorderRadius.all(Radius.circular(5))),
                                      child: Center(
                                          child: Icon(Icons.arrow_back_ios_new)),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 10,
                                  ),
                                  Container(
                                    width: (Get.width) - 110,
                                    height: 50,
                                    child: ElevatedButton(
                                        onPressed: () {
                                          //setState(() => flag = !flag);
                                          //validation();
                                          _sendData();
                                        },
                                        child: Text(
                                          flag ? 'SUBMIT' : 'Send Data...'.toUpperCase(),
                                          style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: flag
                                              ? HexColor('#FFBD8B5A')
                                              : Colors.teal,
                                        )),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
              : Container(
                  width: screenWidth(context),
                  height: mainHeight(context) + 100,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.asset(
                        AppConstant.noRecordImagePath,
                        height: AppConstant.noRecordImageHeightWidth,
                        width: AppConstant.noRecordImageHeightWidth,
                      ),
                    ],
                  ))),
    );
  }

  getOrderInfo() async {
    showProgress();
    try {
      var _response =
          await apiCall().get(AppConstant.WS_ORDER_INFO, queryParameters: {
        "app_id": AppConstant.APP_ID,
        "api_key": AppConstant.APP_KEY,
        "token": loginVo!.data!.token.toString(),
        "order_hash": AppConstant.SCAN_ID,
      });
      if (_response.statusCode == AppConstant.STATUS_CODE) {
        hideProgressBar();
        orderInfoVO = OrderInfoVO.fromJson(jsonDecode(_response.toString()));
        if (orderInfoVO != null &&
            orderInfoVO!.status == AppConstant.APP_SUCCESS) {
          if (orderInfoVO!.data!.packagingInfo!.shipmentPackagesCount != null) {
            if (orderInfoVO!.data!.packagingInfo!.shipmentPackagesCount! > 8) {
              selectedCard = 8;
            } else {
              selectedCard =
                  orderInfoVO!.data!.packagingInfo!.shipmentPackagesCount! - 1;
            }
            boxController.text = orderInfoVO!
                .data!.packagingInfo!.shipmentPackagesCount!
                .toString();
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
              child: Text('Gallery'),
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
    if (pickedFile != null) {
      //Get.back();
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
        if (fileName.isNotEmpty)
          "attachment1":
              await MultipartFile.fromFile(imageFile, filename: fileName),
        if (fileName2.isNotEmpty)
          "attachment2":
              await MultipartFile.fromFile(imageFile2, filename: fileName2),
      });
      //print(formData.toString());
      var _response =
          await apiCall().post(AppConstant.WS_SEND_ORDER, data: formData);
      if (_response.statusCode == AppConstant.STATUS_CODE) {
        hideProgressBar();
        sendOrderVO = SendOrderVO.fromJson(jsonDecode(_response.toString()));
        if (sendOrderVO != null &&
            sendOrderVO!.status == AppConstant.APP_SUCCESS) {
          toastSuccess(sendOrderVO!.message);
          isUpdateValue ? Get.back(result: true) : Get.back(result: false);
          setState(() {
            flag = !flag;
          });
        } else {
          snackBar("Error", sendOrderVO!.message.toString(),5);
          //toastError(sendOrderVO!.message.toString());
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
      //hideProgressBar();
      return null;
    }
    //hideProgressBar();
  }
}
