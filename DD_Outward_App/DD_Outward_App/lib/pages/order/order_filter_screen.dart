import 'dart:convert';

import 'package:deodap/pages/order/OrderInfoVO.dart';
import 'package:deodap/widgets/extensions.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
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
import 'CourierVO.dart';
import 'UpdatePhotoVO.dart';
import 'UserVO.dart';

class OrderFilterScreen extends StatefulWidget {
  const OrderFilterScreen({Key? key}) : super(key: key);

  @override
  _OrderFilterScreenState createState() => _OrderFilterScreenState();
}

class _OrderFilterScreenState extends State<OrderFilterScreen> {
  var storage = GetStorage();

  final List<Courier> _listStateCourier = <Courier>[];
  List<Courier> _listUser = <Courier>[];
  CourierVO? courierVO;
  UserVO? userVO;
  String? selectedStateValue;
  var warehouseController;

  /*Filter*/
  final DateTime pastDate = DateTime(2000); // Example: Start from year 2000
  DateTime pastDateToDate = DateTime(2000); // Example: Start from year 2000
  final TextEditingController fromDateController = TextEditingController();
  final TextEditingController toDateController = TextEditingController();
  DateTime? startDate, endData;

  //String? formDate = '';
  String? endDateFill = '';
  Set<int> selectedItemIds = {}; // Store multiple selected IDs
  final box = GetStorage();
  List<Commons> _listWarhouseData = <Commons>[];

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
        _requestCourier();
        apiRequestUser();
        apiWarehouse();
        fromDateController.text = AppConstant.formDateOrderFilter.toString();
        _loadSelectedItems();
      } else {
        // No-Internet Case
        toastError(AppString.no_internet);
      }
    });
  }

  void _loadSelectedItems() {
    List<dynamic>? storedIds = box.read<List<dynamic>>("selectedItemIds");
    if (storedIds != null) {
      setState(() {
        selectedItemIds = storedIds.map((id) => id as int).toSet();
      });
    }
  }

  // Save selected IDs to GetStorage
  void _saveSelectedItems() {
    box.write("selectedItemIds", selectedItemIds.toList());
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
          'Filter Screen',
        ),
        bottomSheet: Container(
          color: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 20),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 50,
                  child: ElevatedButton(
                      onPressed: () {
                        AppConstant.formDateOrderFilter = '';
                        endDateFill = '';
                        selectedItemIds.clear(); // Clear selection
                        fromDateController.clear();
                        toDateController.clear();
                        AppConstant.clearFilter();
                        Get.back(result: true);
                      },
                      child: Text(
                        'CLEAR',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.black,
                            fontFamily: fontName(),
                            fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                        backgroundColor: Colors.white38,
                      )),
                ),
              ),
              sizedBoxWWidget(10),
              Expanded(
                child: Container(
                  height: 50,
                  child: ElevatedButton(
                      onPressed: () {
                        AppConstant.selectedWarehouseIdOrderFilter =
                            getSelectedIdsAsString();
                        /*toastSuccess(AppConstant
                            .selectedWarehouseIdOrderFilter);*/
                        Get.back(result: true);
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
              ),
            ],
          ),
        ),
        body: courierVO != null && courierVO!.data != null
            ? SingleChildScrollView(
                child: Column(
                  children: [
                    SingleChildScrollView(
                      child: SafeArea(
                        bottom: true,
                        child: Container(
                            padding: EdgeInsets.only(
                                bottom:
                                    MediaQuery.of(context).viewInsets.bottom),
                            color: Colors.white,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              // Set this to dynamic height
                              children: [
                                Column(
                                  children: [
                                    Container(
                                      margin: EdgeInsets.symmetric(
                                          horizontal: 0, vertical: 10),
                                      child: Column(
                                        children: [
                                          Container(
                                            margin: EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 10),
                                            child: TextFormField(
                                              controller: fromDateController,
                                              readOnly: true,
                                              onTap: () async {
                                                startDate = await pickDate();
                                                AppConstant
                                                        .formDateOrderFilter =
                                                    DateFormat('dd-MM-yyyy')
                                                        .format(startDate!);
                                                pastDateToDate = startDate!;
                                                fromDateController.text =
                                                    _displayText("", startDate);
                                                setState(() {});
                                              },
                                              validator: startDateValidator,
                                              style: TextStyle(
                                                  height: 0.7,
                                                  color: Colors.black,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w400),
                                              decoration: InputDecoration(
                                                  fillColor: Colors.white,
                                                  hintStyle: TextStyle(
                                                      height: 0.7,
                                                      color: Colors.black,
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w400),
                                                  labelStyle: TextStyle(
                                                      height: 0.7,
                                                      color: Colors.black,
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w400),
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            5.0),
                                                    borderSide: BorderSide(
                                                      color: appColor(),
                                                      width: 2,
                                                    ),
                                                  ),
                                                  labelText: 'Select From Date',
                                                  hintText: 'Select From Date'),
                                            ),
                                          ),
                                          Container(
                                            margin: EdgeInsets.symmetric(
                                                horizontal: 10),
                                            child: CustomDropdownCourier(
                                              items: _listStateCourier,
                                              defaultValue: AppConstant
                                                      .selectedCourierNameOrderFilter!
                                                      .isNotEmpty
                                                  ? AppConstant
                                                      .selectedCourierNameOrderFilter
                                                  : null,
                                              hint: 'Select Courier',
                                              onSelected: (selectedId) {
                                                AppConstant
                                                        .selectedCourierIdOrderFilter =
                                                    selectedId;
                                                warehouseController = AppConstant
                                                    .selectedCourierIdOrderFilter;
                                                setState(() {
                                                  // Update the selectedCourierName with the selected item
                                                  AppConstant
                                                          .selectedCourierNameOrderFilter =
                                                      _listStateCourier
                                                          .firstWhere((courier) =>
                                                              courier.id
                                                                  .toString() ==
                                                              selectedId)
                                                          .name;
                                                });
                                              },
                                              textEditingController:
                                                  TextEditingController(),
                                            ),
                                          ),
                                          Container(
                                            margin: EdgeInsets.symmetric(
                                                horizontal: 10),
                                            child: CustomDropdownCourier(
                                              items: _listUser,
                                              defaultValue: AppConstant
                                                      .selectedScanUserFilter!
                                                      .isNotEmpty
                                                  ? AppConstant
                                                      .selectedScanUserFilter
                                                  : null,
                                              hint: 'Select Scan User',
                                              onSelected: (selectedId) {
                                                AppConstant
                                                        .selectedScanUserIdOrderFilter =
                                                    selectedId.toString();
                                                setState(() {
                                                  // Update the selectedCourierName with the selected item
                                                  AppConstant
                                                          .selectedScanUserFilter =
                                                      _listUser
                                                          .firstWhere((courier) =>
                                                              courier.id
                                                                  .toString() ==
                                                              selectedId)
                                                          .name;
                                                });
                                              },
                                              textEditingController:
                                                  TextEditingController(),
                                            ),
                                          ),
                                          /*Container(
                                    margin: EdgeInsets.symmetric(horizontal: 10),
                                    child: CustomDropdown(
                                      items: _listWarhouseData,
                                      hint: 'Select Warehouse',
                                      selectedCityId: AppConstant.selectedWarehouseIdOrderFilter!.isNotEmpty
                                          ? AppConstant.selectedWarehouseIdOrderFilter
                                          : null,
                                      onSelected: (selectedItem) {
                                        AppConstant.selectedWarehouseIdOrderFilter = selectedItem.id.toString();
                                        AppConstant.selectedWarehouseNameOrderFilter =
                                            selectedItem.label.toString();
                                      },
                                      textEditingController: TextEditingController(),


                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please select a warehouse';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),*/
                                          Container(
                                            width: Get.width,
                                            child: Padding(
                                              padding: EdgeInsets.all(10),
                                              child: Text(
                                                "Select Warehouse",
                                                style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight:
                                                        FontWeight.bold),
                                                textAlign: TextAlign.start,
                                              ),
                                            ),
                                          ),
                                          _listWarhouseData.isNotEmpty
                                              ? GridView.builder(
                                                  physics:
                                                      NeverScrollableScrollPhysics(),
                                                  shrinkWrap: true,
                                                  gridDelegate:
                                                      SliverGridDelegateWithFixedCrossAxisCount(
                                                    crossAxisCount: 3,
                                                    // Number of columns
                                                    crossAxisSpacing: 8,
                                                    // Space between columns
                                                    mainAxisSpacing: 8,
                                                    // Space between rows
                                                    childAspectRatio:
                                                        2, // Adjust item size for better layout
                                                  ),
                                                  itemCount:
                                                      _listWarhouseData.length,
                                                  itemBuilder:
                                                      (BuildContext context,
                                                          int index) {
                                                    return listDesign(index);
                                                  },
                                                )
                                              : Container(),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                sizedBoxHWidget(10),
                              ],
                            )),
                      ),
                    )
                  ],
                ),
              )
            : noRecordFound());
  }

  String getSelectedIdsAsString() {
    return selectedItemIds.join(",");
  }

  listDesign(var index) {
    int itemId =
        int.parse(_listWarhouseData[index].id.toString()); // Get item ID

    return InkWell(
      onTap: () {
        setState(() {
          if (selectedItemIds.contains(itemId)) {
            selectedItemIds.remove(itemId); // Unselect if already selected
          } else {
            selectedItemIds.add(itemId); // Select if not selected
          }
          _saveSelectedItems(); // Save selection
        });
      },
      child: Container(
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5.0),
          ),
          elevation: 0.5,
          color: selectedItemIds.contains(itemId)
              ? Colors.blue.shade100 // Highlight selected item
              : Colors.grey.shade50,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 5, vertical: 5),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                sizedBoxHWidget(2),
                Text(
                  _listWarhouseData[index].label.toString(),
                  style: TextStyle(
                    fontSize: 16,
                    fontFamily: fontName(),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                sizedBoxHWidget(2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _requestCourier() async {
    try {
      var _response =
          await apiCall().get(AppConstant.WS_GET_COURIER, options: option());
      if (_response.statusCode == AppConstant.STATUS_CODE) {
        courierVO = CourierVO.fromJson(jsonDecode(_response.toString()));
        if (courierVO != null && courierVO!.data!.length > 0) {
          _listStateCourier.addAll(courierVO!.data!);
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
  Future<void> apiRequestUser() async {
    try {
      var _response =
      await apiCall().get(AppConstant.WS_GET_USER, options: option());
      if (_response.statusCode == AppConstant.STATUS_CODE) {
        CourierVO courierVO = CourierVO.fromJson(jsonDecode(_response.toString()));
        if (courierVO != null && courierVO.data!.length > 0) {
          _listUser.addAll(courierVO.data!);
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
    setState(() {});
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
