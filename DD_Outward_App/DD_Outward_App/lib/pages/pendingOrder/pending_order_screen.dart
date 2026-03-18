import 'dart:convert';

import 'package:deodap/pages/order/OrderInfoVO.dart';
import 'package:deodap/widgets/extensions.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart' hide Response, FormData, MultipartFile;
import 'package:get_storage/get_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../commonmodule/CommonDropDownVO.dart';
import '../../commonmodule/CustomDropdown.dart';
import '../../commonmodule/CustomDropdownCourier.dart';
import '../../commonmodule/appConstant.dart';
import '../../commonmodule/appString.dart';
import '../../utils/routes.dart';
import '../../widgets/all_widget.dart';
import '../order/CourierVO.dart';
import '../order/UpdatePhotoVO.dart';
import 'PendingOrderVO.dart';

class PendingOrderScreen extends StatefulWidget {
  const PendingOrderScreen({Key? key}) : super(key: key);

  @override
  _PendingOrderScreenState createState() => _PendingOrderScreenState();
}

class _PendingOrderScreenState extends State<PendingOrderScreen> {
  var storage = GetStorage();

  PendingOrderVO? orderInfoVO;
  final ScrollController _controller = ScrollController();
  int page = 1;
  bool isLoadMoreApiCall = false;
  List<PendingOrders> listData = <PendingOrders>[];
  var idProofFront = '';
  bool isTextSearch = false;
  var search = '';
  String? totalRecords = '';
  final TextEditingController searchController = TextEditingController();

  final List<Courier> _listStateData = <Courier>[];
  CourierVO? courierVO;
  String? selectedStateValue;
  String? selectedStateId = "";
  String? selectedCourierName = "";

  var warehouseController;

  List<Commons> _listWarhouseData = <Commons>[];
  String? selectedWarehouseId = "";
  String? selectedWarehouseName = "";

  /*Filter*/
  final DateTime pastDate = DateTime(2000); // Example: Start from year 2000
  DateTime pastDateToDate = DateTime(2000); // Example: Start from year 2000
  final TextEditingController fromDateController = TextEditingController();
  final TextEditingController toDateController = TextEditingController();
  DateTime? startDate, endData;
  String? formDate = '';
  String? endDateFill = '';
  String? selectOrderId = '';

  String _displayText(String begin, DateTime? date) {
    if (date != null) {
      String formattedDate = DateFormat('dd-MM-yyyy').format(date);
      return '${formattedDate}';
    } else {
      return 'Choose The Date';
    }
  }

  Future<DateTime?> pickDate() async {
    return await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: pastDate,
      lastDate: DateTime.now(),
    );
  }

  Future<DateTime?> pickToDate() async {
    return await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: pastDate,
      lastDate: DateTime.now(),
    );
  }

  String? startDateValidator(value) {
    if (startDate == null) return "select the date";

    /// play with logic
  }

  String? endDateValidator(value) {
    if (startDate != null && endData == null) {
      return "select Both data";
    }
    if (endData == null) return "select the date";
    if (endData!.isBefore(startDate!)) {
      return "End date must be after startDate";
    }

    return null; // optional while already return type is null
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    check().then((intenet) {
      if (intenet) {
        AppConstant.isScanScreen = false;
        fromDateController.clear();
        toDateController.clear();
        AppConstant.clearFilter();
        callAPI();
        _requestCourier();
        apiWarehouse();
        _controller.addListener(() {
          double _pixels = _controller.position.pixels;
          double _maxScroll = _controller.position.maxScrollExtent;
          if (_pixels == _maxScroll) getOrderInfo();
        });
      } else {
        // No-Internet Case
        toastError(AppString.no_internet);
      }
    });
  }

  void navigateToFilterScreen() async {
    var result = await Get.toNamed(Routes.filterOrderScreenRoute);

    if (result == true) {
      print("Filter applied successfully!");
      callAPI();
      // Perform any action after returning true
    }
  }

  void callAPI() {
    page = 1;
    isLoadMoreApiCall = true;
    listData.clear();
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
        appBar: appBar(
          'Pending Order List',
          actions: <Widget>[
            Visibility(
              visible: true,
              child: IconButton(
                icon: Icon(
                  isTextSearch ? Icons.close : Icons.search,
                  color: Colors.black54,
                ),
                onPressed: () {
                  if (isTextSearch) {
                    isTextSearch = false;
                    search = '';
                    callAPI();
                  } else {
                    isTextSearch = true;
                  }
                  searchController.text = "";
                  setState(() {});
                },
              ),
            ),
            IconButton(
              icon: Image.asset(
                'assets/images/filter.png',
                color: Colors.black,
                height: 25,
                width: 25,
              ),
              onPressed: () {
                navigateToFilterScreen();
              },
            ),
            sizedBoxWWidget(5)
          ],
        ),
        body: orderInfoVO != null &&
                orderInfoVO!.data != null &&
                listData.isNotEmpty
            ? RefreshIndicator(
                color: appColor(),
                onRefresh: _refresh,
                child: Column(
                  children: [
                    // Total Records Container
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      color: Colors.grey.shade300,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Records:',
                            style: TextStyle(
                                fontWeight: FontWeight.w400, fontSize: 14),
                          ),
                          Text(
                            totalRecords.toString(),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: appColor(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Search Bar
                    if (isTextSearch)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10.0, vertical: 10),
                        child: TextField(
                          style: TextStyle(fontSize: 14.0),
                          controller: searchController,
                          onSubmitted: (value) {
                            searchData(value);
                          },
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.all(15),
                            fillColor: Colors.grey.shade100,
                            suffixIcon: IconButton(
                              iconSize: 30,
                              icon: Icon(Icons.search),
                              onPressed: () async {
                                searchData(searchController.text);
                              },
                            ),
                            filled: true,
                            labelText: "Search",
                            hintText: 'Search By AWB No.',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ),
                      ),
                    // ListView with scrollable records
                    Expanded(
                      child: ListView.builder(
                        controller: _controller,
                        itemCount: listData.length + 1,
                        // Add 1 for load more
                        itemBuilder: (BuildContext context, int index) {
                          if (index == listData.length) {
                            return loadMore(isLoadMoreApiCall);
                          } else {
                            return listDesign(index);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              )
            : noRecordFound());
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
                      Get.toNamed(Routes.orderDetailScreenRoute);
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
          /*AppConstant.ORDER_ID =
              listData[index].id.toString();
          AppConstant.ORDER_TRACKING_ID =
              listData[index].awb.toString();
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
            color: Colors.white,
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
                      /*Container(
                        width: 15,
                        height: 75,
                        // Set width to 10
                        decoration: BoxDecoration(
                          color: '1'==
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
                      ),*/
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
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Text(
                                          "AWB: " +
                                              listData[index].awb.toString(),
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontFamily: fontName(),
                                              fontWeight: FontWeight.w600),
                                          textAlign: TextAlign.start,
                                        ),
                                        Text(
                                          "Order No.: " +
                                              listData[index]
                                                  .orderNo
                                                  .toString(),
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontFamily: fontName(),
                                              color: Colors.black45,
                                              fontWeight: FontWeight.w500),
                                          textAlign: TextAlign.start,
                                        ),
                                        Text(
                                          "Warehouse: " +
                                              listData[index]
                                                  .warehouses!
                                                  .label
                                                  .toString(),
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontFamily: fontName(),
                                              color: Colors.black45,
                                              fontWeight: FontWeight.w500),
                                          textAlign: TextAlign.start,
                                        ),
                                        listData[index].courierSlug != null
                                            ? Text(
                                                listData[index]
                                                    .courierSlug
                                                    .toString(),
                                                style: TextStyle(
                                                    fontSize: 13,
                                                    fontFamily: fontName(),
                                                    color: Colors.black87,
                                                    fontWeight:
                                                        FontWeight.w400),
                                                textAlign: TextAlign.start,
                                              )
                                            : Container(),
                                      ],
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                    ),
                                  ),
                                  listData[index]
                                          .warehouseId
                                          .toString()
                                          .isNotEmpty
                                      ? Text(
                                          listData[index]
                                              .orderStatus
                                              .toString(),
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontFamily: fontName(),
                                              color: Colors.green,
                                              fontWeight: FontWeight.w500),
                                          textAlign: TextAlign.start,
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
                                    listData[index].orderDate.toString(),
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


  Future<void> _refresh() async {
    // Simulate a delay for refreshing data
    //await Future.delayed(Duration(seconds: 1));
    // Update the list of items
    setState(() {
      callAPI();
    });
  }

  getOrderInfo() async {
    if (page == 1) {
      showProgress();
    }
    try {
      FormData formData = FormData.fromMap(<String, dynamic>{
        "page": page,
        if (search.trim().isNotEmpty) "awb": search.trim(),
        if (search.trim().isNotEmpty) "order_no": search.trim(),
        if (AppConstant.formDateOrderFilter.toString().trim().isNotEmpty)
          "date": AppConstant.formDateOrderFilter.toString().trim(),
        if (AppConstant.selectedCourierIdOrderFilter
            .toString()
            .trim()
            .isNotEmpty)
          "shipping_company_id":
              AppConstant.selectedCourierIdOrderFilter.toString().trim(),
        if (AppConstant.selectedWarehouseIdOrderFilter
            .toString()
            .trim()
            .isNotEmpty)
          "warehouse_id":
              AppConstant.selectedWarehouseIdOrderFilter.toString().trim(),
      });
      var _response = await apiCall().post(AppConstant.WS_PENDING_ORDER_INFO,
          data: formData, options: option());
      print("FormData Values:");
      formData.fields.forEach((element) {
        print("${element.key}: ${element.value}");
      });
      if (_response.statusCode == AppConstant.STATUS_CODE) {
        if (page == 1) {
          hideProgressBar();
        }
        orderInfoVO = PendingOrderVO.fromJson(jsonDecode(_response.toString()));
        if (orderInfoVO != null && orderInfoVO!.success!) {
          if (orderInfoVO != null && orderInfoVO!.data!.orders!.length > 0) {
            if (orderInfoVO!.data!.pagination!.lastPage! >= page) {
              totalRecords =
                  orderInfoVO!.data!.pagination!.totalRecords.toString();
              if (orderInfoVO!.data!.pagination!.lastPage! == 1) {
                isLoadMoreApiCall = false;
              }
              page++;
              listData.addAll(orderInfoVO!.data!.orders!);
              print("leng --> " + listData.length.toString());
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
        if (page == 1) {
          hideProgressBar();
        }
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

  dialog() {
    Size size = MediaQuery.of(context).size;
    Get.bottomSheet(
      StatefulBuilder(builder: (context, setState) {
        return SingleChildScrollView(
          child: SafeArea(
            bottom: true,
            child: Container(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom),
                color: Colors.white,
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Set this to dynamic height
                  children: [
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                              left: 10, right: 10, bottom: 15, top: 15),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      if (Get.isBottomSheetOpen ?? false) {
                                        Get.back();
                                      }
                                    },
                                    child: Icon(
                                      Icons.arrow_back_ios_sharp,
                                      color: Colors.black,
                                      size: 18,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 15,
                                  ),
                                  Text(
                                    "Filter",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: appColor(),
                                        fontFamily: fontName(),
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              GestureDetector(
                                onTap: () {
                                  formDate = '';
                                  endDateFill = '';
                                  selectedStateId = '';
                                  selectedWarehouseId = '';
                                  selectedWarehouseName = '';
                                  selectedCourierName = '';
                                  fromDateController.clear();
                                  toDateController.clear();
                                  Navigator.of(context).pop();
                                  callAPI();
                                },
                                child: Text(
                                  "Reset",
                                  style: TextStyle(
                                      color: Colors.black,
                                      fontFamily: fontName(),
                                      fontWeight: FontWeight.w300,
                                      fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                        new Divider(
                          color: appColor(),
                        ),
                        Container(
                          margin:
                              EdgeInsets.symmetric(horizontal: 0, vertical: 10),
                          child: Column(
                            children: [
                              Container(
                                margin: EdgeInsets.symmetric(
                                    horizontal: 0, vertical: 10),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: Get.width - 20,
                                      height: 45,
                                      child: TextFormField(
                                        controller: fromDateController,
                                        readOnly: true,
                                        onTap: () async {
                                          startDate = await pickDate();
                                          formDate = DateFormat('dd-MM-yyyy')
                                              .format(startDate!);
                                          pastDateToDate = startDate!;
                                          fromDateController.text =
                                              _displayText("", startDate);
                                          setState(() {});
                                        },
                                        validator: startDateValidator,
                                        style: TextStyle(
                                            height: 1,
                                            color: Colors.black,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w400),
                                        decoration: InputDecoration(
                                            fillColor: Colors.white,
                                            hintStyle: TextStyle(
                                                height: 1,
                                                color: Colors.black,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w400),
                                            labelStyle: TextStyle(
                                                height: 1,
                                                color: Colors.black,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w400),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(5.0),
                                              borderSide: BorderSide(
                                                color: appColor(),
                                                width: 2,
                                              ),
                                            ),
                                            labelText: 'Select From Date',
                                            hintText: 'Select From Date'),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 0,
                                    ),
                                    Visibility(
                                      visible: false,
                                      child: Container(
                                        width: Get.width / 2.25,
                                        height: 45,
                                        child: TextFormField(
                                          controller: toDateController,
                                          readOnly: true,
                                          onTap: () async {
                                            endData = await pickToDate();
                                            endDateFill =
                                                DateFormat('yyyy-MM-dd')
                                                    .format(endData!);
                                            toDateController.text =
                                                _displayText("", endData);
                                            setState(() {});
                                          },
                                          validator: endDateValidator,
                                          style: TextStyle(
                                              color: Colors.black,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w400),
                                          decoration: InputDecoration(
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(5.0),
                                                borderSide: BorderSide(
                                                  color: appColor(),
                                                  width: 2,
                                                ),
                                              ),
                                              labelText: 'Select To Date',
                                              hintText: 'Select To Date'),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                margin: EdgeInsets.symmetric(horizontal: 10),
                                child: CustomDropdownCourier(
                                  items: _listStateData,
                                  defaultValue: selectedCourierName!.isNotEmpty
                                      ? selectedCourierName
                                      : null,
                                  hint: 'Select Courier',
                                  onSelected: (selectedId) {
                                    selectedStateId = selectedId;
                                    warehouseController = selectedStateId;
                                    setState(() {
                                      // Update the selectedCourierName with the selected item
                                      selectedCourierName = _listStateData
                                          .firstWhere((courier) =>
                                              courier.id.toString() ==
                                              selectedId)
                                          .name;
                                    });
                                  },
                                  textEditingController:
                                      TextEditingController(),
                                ),
                              ),
                              Container(
                                margin: EdgeInsets.symmetric(horizontal: 10),
                                child: CustomDropdown(
                                  items: _listWarhouseData,
                                  hint: 'Select Warehouse',
                                  selectedCityId:
                                      selectedWarehouseId!.isNotEmpty
                                          ? selectedWarehouseId
                                          : null,
                                  onSelected: (selectedItem) {
                                    selectedWarehouseId =
                                        selectedItem.id.toString();
                                    selectedWarehouseName =
                                        selectedItem.label.toString();
                                  },
                                  textEditingController:
                                      TextEditingController(),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select a warehouse';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    sizedBoxHWidget(10),
                    Container(
                      width: Get.width / 3,
                      height: 50,
                      margin: EdgeInsets.only(bottom: 5),
                      child: ElevatedButton(
                          onPressed: () {
                            Get.back();
                            callAPI();
                          },
                          child: Text(
                            'APPLY',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                                fontFamily: fontName(),
                                fontWeight: FontWeight.w700),
                          ),
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                            backgroundColor: appColor(),
                          )),
                    ),
                  ],
                )),
          ),
        );
      }),
      isScrollControlled: true,
    );
  }

  Future<void> _requestCourier() async {
    try {
      var _response =
          await apiCall().get(AppConstant.WS_GET_COURIER, options: option());
      if (_response.statusCode == AppConstant.STATUS_CODE) {
        courierVO = CourierVO.fromJson(jsonDecode(_response.toString()));
        if (courierVO != null && courierVO!.data!.length > 0) {
          _listStateData.addAll(courierVO!.data!);
          setState(() {});
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Oops! Something went wrong...'),
          ),
        );
      }
    } catch (e) {
      return null;
    }
  }

  apiWarehouse() async {
    await apiCallCommon(
      apiEndpoint: AppConstant.WS_WAREHOUSE,
      dataList: _listWarhouseData,
      fromJson: (json) => CommonDropDownVO.fromJson(json),
    );
    /*setState(() {
      dialog();
    });*/
  }

  Future<void> apiCallCommon({
    required String apiEndpoint,
    required List<dynamic> dataList,
    required Function(Map<String, dynamic>) fromJson,
  }) async {
    showProgress();
    try {
      var response = await apiCall().get(
        apiEndpoint,
        options: option(),
      );

      hideProgressBar();
      if (response.statusCode == AppConstant.STATUS_CODE) {
        var jsonResponse = jsonDecode(response.toString());
        var commonDropDownVO = fromJson(jsonResponse);

        if (commonDropDownVO != null && commonDropDownVO.success!) {
          dataList.addAll(commonDropDownVO.data!);
        } else {
          showSuccessSnackbar('Oops! Something went wrong...');
        }
      } else {
        showSuccessSnackbar('Oops! Something went wrong...');
      }
    } catch (e) {
      print('Error: $e');
      hideProgressBar();
    }
  }
}
