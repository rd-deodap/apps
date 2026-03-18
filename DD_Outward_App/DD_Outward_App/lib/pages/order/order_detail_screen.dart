import 'dart:convert';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:deodap/pages/order/OrderDetailInfoVO.dart';
import 'package:deodap/widgets/extensions.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response, FormData;
import 'package:get_storage/get_storage.dart';

import '../../commonmodule/FullScreenPage.dart';
import '../../commonmodule/appConstant.dart';
import '../../commonmodule/appString.dart';
import '../../widgets/all_widget.dart';
import 'OrderInfoVO.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({Key? key}) : super(key: key);

  @override
  _OrderDetailScreenState createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  var storage = GetStorage();
  OrderDetailInfoVO? orderInfoVO;
  int currentPos = 0;
  List<Orders> listDataOrder = <Orders>[];
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    check().then((intenet) {
      if (intenet) {
        //callAPI();
        listDataOrder = AppConstant.listDataOrders;
        if(AppConstant.isScanScreen){
          final Map<String, dynamic> arguments = Get.arguments ?? {};
          final List<Orders> listScanData = arguments['listScanData'] ?? [];
          final int position = arguments['position'] ?? 0;

          listDataOrder = listScanData;
        }
        print("object"+listDataOrder.length.toString());
        setState(() {

        });
      } else {
        // No-Internet Case
        toastError(AppString.no_internet);
      }
    });
  }

  void callAPI() {
    getOrderInfo();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.white,
        //resizeToAvoidBottomInset: false,
        appBar: appBar('Order Detail'),
        body: listDataOrder.isNotEmpty
            ? SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    listDesign(),
                  ],
                ))
            : noRecordFound());
  }

  listDesign() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: GestureDetector(
        onTap: () {
          //Get.toNamed(Routes.lowStockDetailsRoute);
        },
        child: Container(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      title('DETAILS'),
                      Visibility(
                        visible: true,
                        child: Container(
                          margin: EdgeInsets.symmetric(horizontal: 15),
                          width: 25,
                          height: 25,
                          // Set width to 10
                          decoration: BoxDecoration(
                            color: listDataOrder[
                                            AppConstant.ORDER_TRACKING_POSITION]
                                        .isPortalOrder
                                        .toString() ==
                                    '1'
                                ? Colors.green
                                : Colors.red,
                            borderRadius: BorderRadius.all(
                              Radius.circular(5),
                            ),
                          ),
                          padding: EdgeInsets.all(0),
                        ),
                      ),
                    ],
                  ),
                  sizedBoxHWidget(10),
                  Container(
                    margin: EdgeInsets.only(
                        left: 10, right: 10, top: 10, bottom: 30),
                    width: Get.width,
                    padding: EdgeInsets.only(top: 10),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 1, // Border width
                      ),
                      borderRadius: BorderRadius.circular(
                          10), // Adjust the radius as needed
                    ),
                    child: Column(
                      children: [
                        Column(
                          children: [
                            Container(
                              margin: EdgeInsets.only(top: 2, bottom: 2),
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  keyStyle('AWB'),
                                  SizedBox(
                                    height: 3,
                                  ),
                                  Text(
                                    listDataOrder[
                                            AppConstant.ORDER_TRACKING_POSITION]
                                        .awb
                                        .toString(),
                                    style: keyValue(),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: Get.width,
                              child: Divider(
                                thickness: 1,
                                color: Colors.grey.shade300,
                              ),
                            ),
                          ],
                        ),
                        listDataOrder[
                                        AppConstant.ORDER_TRACKING_POSITION]
                                    .order !=
                                null
                            ? Column(
                                children: [
                                  Container(
                                    margin: EdgeInsets.only(top: 2, bottom: 2),
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 10),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        keyStyle('Order No.'),
                                        SizedBox(
                                          height: 3,
                                        ),
                                        Text(
                                          listDataOrder[AppConstant
                                                  .ORDER_TRACKING_POSITION]
                                              .order!
                                              .orderNo
                                              .toString(),
                                          style: keyValue(),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    width: Get.width,
                                    child: Divider(
                                      thickness: 1,
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                ],
                              )
                            : Container(),
                        listDataOrder[
                                        AppConstant.ORDER_TRACKING_POSITION]
                                    .scanByUser !=
                                null
                            ? Column(
                                children: [
                                  Container(
                                    margin: EdgeInsets.only(top: 2, bottom: 2),
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 10),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        keyStyle('Scan By UserName'),
                                        SizedBox(
                                          height: 3,
                                        ),
                                        Text(
                                          listDataOrder[AppConstant
                                                  .ORDER_TRACKING_POSITION]
                                              .scanByUser!
                                              .name
                                              .toString(),
                                          style: keyValue(),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    width: Get.width,
                                    child: Divider(
                                      thickness: 1,
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                ],
                              )
                            : Container(),
                        listDataOrder[
                                        AppConstant.ORDER_TRACKING_POSITION]
                                    .courierSlug !=
                                null
                            ? Column(
                                children: [
                                  Container(
                                    margin: EdgeInsets.only(top: 2, bottom: 2),
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 10),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        keyStyle('Courier'),
                                        SizedBox(
                                          height: 3,
                                        ),
                                        Text(
                                          listDataOrder[AppConstant
                                                  .ORDER_TRACKING_POSITION]
                                              .courierSlug
                                              .toString(),
                                          style: keyValue(),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    width: Get.width,
                                    child: Divider(
                                      thickness: 1,
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                ],
                              )
                            : Container(),
                        listDataOrder[
                                        AppConstant.ORDER_TRACKING_POSITION]
                                    .scanDate !=
                                null
                            ? Column(
                                children: [
                                  Container(
                                    margin: EdgeInsets.only(top: 2, bottom: 10),
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 10),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        keyStyle('Scan Date'),
                                        SizedBox(
                                          height: 3,
                                        ),
                                        Text(
                                          listDataOrder[AppConstant
                                                  .ORDER_TRACKING_POSITION]
                                              .scanDate
                                              .toString(),
                                          style: keyValue(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : Container(),
                      ],
                    ),
                  ),
                ],
              ),
              listDataOrder[AppConstant.ORDER_TRACKING_POSITION]
                              .outwardMedias !=
                          null &&
                  listDataOrder[AppConstant.ORDER_TRACKING_POSITION]
                          .outwardMedias!
                          .isNotEmpty
                  ? Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            title('PHOTOS'),
                            Container(
                              margin: EdgeInsets.symmetric(horizontal: 15),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: appColor(),
                              ),
                              padding: EdgeInsets.all(5),
                              child: Container(
                                padding: EdgeInsets.all(7),
                                child: Text(
                                  listDataOrder[
                                          AppConstant.ORDER_TRACKING_POSITION]
                                      .outwardMedias!
                                      .length
                                      .toString(),
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white,
                                      fontFamily: fontName(),
                                      fontWeight: FontWeight.w400),
                                  textAlign: TextAlign.start,
                                ),
                              ),
                            )
                          ],
                        ),
                        sizedBoxHWidget(10),
                        CarouselSlider.builder(
                          itemCount: listDataOrder[
                                  AppConstant.ORDER_TRACKING_POSITION]
                              .outwardMedias!
                              .length,
                          options: CarouselOptions(
                              height: 400,
                              viewportFraction: 1,
                              autoPlay: false,
                              onPageChanged: (index, reason) {
                                setState(() {
                                  currentPos = index;
                                });
                              }),
                          itemBuilder: (context, index, _) {
                            return GestureDetector(
                              onTap: () async {
                                AppConstant.photo.clear();
                                //photo.add(detailVo!.data!.primaryImage!);
                                for (var i = 0;
                                    i <
                                        listDataOrder[AppConstant
                                                .ORDER_TRACKING_POSITION]
                                            .outwardMedias!
                                            .length;
                                    i++) {
                                  AppConstant.photo.add(listDataOrder[
                                          AppConstant.ORDER_TRACKING_POSITION]
                                      .outwardMedias![i]
                                      .imagePath
                                      .toString());
                                }
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => FullScreenPage(
                                      imageUrls: AppConstant.photo,
                                      // Replace with your image URLs
                                      initialIndex:
                                          currentPos, // Specify the initial index
                                    ),
                                  ),
                                );
                              },
                              child: MyImageView(listDataOrder[
                                      AppConstant.ORDER_TRACKING_POSITION]
                                  .outwardMedias![index]
                                  .imagePath
                                  .toString()),
                            );
                          },
                        )
                      ],
                    )
                  : Container()
            ],
          ),
        ),
      ),
    );
  }

  title(var title) {
    return Container(
      padding: EdgeInsets.only(top: 10, bottom: 10, left: 20, right: 20),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Text(
        title,
        style: TextStyle(
            fontSize: 14, color: Colors.black, fontWeight: FontWeight.bold),
      ),
    );
  }

  keyValue() {
    return TextStyle(
        color: Colors.black54, fontSize: 14, fontWeight: FontWeight.w500);
  }

  keyStyle(var title) {
    return Text(title,
        style: TextStyle(
            color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w500));
  }

  Future<void> _refresh() async {
    // Simulate a delay for refreshing data
    //await Future.delayed(Duration(seconds: 1));
    // Update the list of items
    setState(() {
      //callAPI();
    });
  }

  getOrderInfo() async {
    showProgress();
    try {
      FormData formData = FormData.fromMap(<String, dynamic>{
        "action": 'get_record_detail',
        "order_id": AppConstant.ORDER_ID,
        "tracking_id": AppConstant.ORDER_TRACKING_ID,
      });
      var _response =
          await apiCall().post(AppConstant.WS_ORDER_INFO, data: formData);
      if (_response.statusCode == AppConstant.STATUS_CODE) {
        hideProgressBar();
        orderInfoVO =
            OrderDetailInfoVO.fromJson(jsonDecode(_response.toString()));
        if (orderInfoVO != null &&
            orderInfoVO!.status == AppConstant.APP_SUCCESS) {
          setState(() {});
        } else {
          toastError(orderInfoVO!.errors.toString());
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
}

class MyImageView extends StatelessWidget {
  String imgPath;

  MyImageView(this.imgPath);

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 5),
      child: ClipRRect(
        borderRadius: BorderRadius.all(Radius.circular(5)),
        child: FadeInImage(
          fit: BoxFit.fill,
          placeholder: AssetImage(AppConstant.placeHolderImagePath),
          image: NetworkImage(imgPath),
          height: 100,
          width: screenWidth(context) * 1,
        ),
      ),
    );
  }
}
