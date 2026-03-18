import 'dart:convert';
import 'dart:io';

import 'package:deodap/widgets/extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart' hide Response, FormData;
import 'package:get_storage/get_storage.dart';

import '../../commonmodule/appConstant.dart';
import '../../commonmodule/appString.dart';
import '../../utils/routes.dart';
import '../../widgets/all_widget.dart';
import '../auth/warehouseVo.dart';
import '../order/CourierVO.dart';

class CourierList extends StatefulWidget {
  const CourierList({Key? key}) : super(key: key);

  @override
  _CourierListState createState() => _CourierListState();
}

class _CourierListState extends State<CourierList> {
  var storage = GetStorage();
  final ScrollController _controller = ScrollController();

  final List<Courier> listData = <Courier>[];
  CourierVO? warehouseVo;


  /*Back*/
  bool? isInternet = false;
  bool? isSearchOpen = false;
  String title = '';
  final TextEditingController searchController = TextEditingController();


  @override
  void initState() {
    super.initState();

    check().then((intenet) {
      if (intenet != null && intenet) {
        // Internet Present Case
        callAPI();
      } else {
        // No-Internet Case
        toastError(AppString.no_internet);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar(
        'Select Courier',
        actions: <Widget>[
          Visibility(
            visible: false,
            child: IconButton(
              icon: Icon(
                isSearchOpen! ? Icons.close : Icons.search,
                color: Colors.white,
              ),
              onPressed: () {
                isSearchOpen == true ? isSearchOpen = false : isSearchOpen = true;
                title = 'Search Courier';
                searchController.text = "";
                setState(() {});
                // do something
                //Get.toNamed(page);
              },
            ),
          ),

        ],
      ),
      body: RefreshIndicator(
          color: appColor(),
          onRefresh: _refresh,
          child: SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            controller: _controller,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                isSearchOpen!
                    ? Column(
                        children: [
                          Container(
                            margin: EdgeInsets.only(top: 10, right: 5, left: 5),
                            child: TextField(
                              style: TextStyle(fontSize: 14.0),
                              controller: searchController,
                              onSubmitted: (value) {
                                //if (value.toString().trim().isNotEmpty) {
                                //value is entered text after ENTER press
                                //you can also call any function here or make setState() to assign value to other variable
                                searchData(value);
                                //}
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
                                    }),
                                filled: true,
                                labelText: "Search By Warehouse",
                                hintText: 'Search By Warehouse',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 10,
                          ),
                        ],
                      )
                    : Container(),
                listData.isNotEmpty
                    ? ListView.builder(
                        physics: NeverScrollableScrollPhysics(),
                        scrollDirection: Axis.vertical,
                        shrinkWrap: true,
                        itemBuilder: (BuildContext context, int index) {
                          return listDesign(index);
                        },
                        itemCount: listData.length)
                    : Container(
                        width: screenWidth(context),
                        height: mainHeight(context) / 1.5,
                        child: Stack(alignment: Alignment.center, children: [
                          Image.asset(
                            AppConstant.noRecordImagePath,
                            height: AppConstant.noRecordImageHeightWidth,
                            width: AppConstant.noRecordImageHeightWidth,
                            color: Colors.white,
                          ),
                          //hideProgressBar()
                        ]),
                      ),
              ],
            ),
          ),
        ),

    );
  }

  updateData(pageName) async {
    var response = await Get.toNamed(pageName);
    if (response)
      setState(() {
        callAPI();
      });
    return response;
  }

  listDesign(var index) {
    return index!=0?Container(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: GestureDetector(
        onTap: () {
          detailScreen(index);
        },
        child: Container(
          margin: EdgeInsets.only(bottom: 0, right: 5, left: 5),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5.0),
            ),
            elevation: 0.5, // Change this
            color: Colors.grey.shade50,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  sizedBoxHWidget(5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Text(
                              listData[index].name.toString(),
                              style: TextStyle(
                                  fontSize: 18,
                                  fontFamily: fontName(),
                                  fontWeight: FontWeight.w500),
                              textAlign: TextAlign.start,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  sizedBoxHWidget(5),
                ],
              ),
            ),
          ),
        ),
      ),
    ):Container();
  }

  Future<void> _refresh() async {
    // Simulate a delay for refreshing data
    //await Future.delayed(Duration(seconds: 1));
    // Update the list of items
    setState(() {
      callAPI();
    });
  }

  void searchData(String value) {
    searchController.text = value;
    //isSearchOpen = false;
    closeKeyboard();
    title = searchController.text;
    callAPI();
  }

  void callAPI() {
    listData.clear();
    _requestWarehouse();
  }

  Future<void> _requestWarehouse() async {
    showProgress();
    try {
      var _response =
      await apiCall().get(AppConstant.WS_GET_COURIER,options: option());
      if (_response.statusCode == AppConstant.STATUS_CODE) {
        warehouseVo = CourierVO.fromJson(jsonDecode(_response.toString()));
        if (warehouseVo != null && warehouseVo!.data!.length > 0) {
          listData.addAll(warehouseVo!.data!);
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
    hideProgressBar();
  }
  detailScreen(var index){
    AppConstant.SHIPPING_COMPANY_ID = listData[index].id.toString();
    AppConstant.SHIPPING_COMPANY_TITLE = listData[index].name.toString();
    Get.toNamed(Routes.scanRoute);
  }

}
