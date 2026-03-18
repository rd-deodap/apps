import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:get/get_navigation/src/snackbar/snackbar.dart';
import 'package:intl/intl.dart';

import '../commonmodule/appColor.dart';
import '../commonmodule/appConstant.dart';
import '../utils/routes.dart';

appBar(var string) {
  return AppBar(
    iconTheme: IconThemeData(color: Colors.black),
    automaticallyImplyLeading: false,
    title: Text(string, style: TextStyle(fontSize: 14, color: Colors.white)),
    elevation: 0,
    flexibleSpace: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [
              const Color(0xFFBD8B5A),
              const Color(0xFFBD8B5A),
            ],
            begin: const FractionalOffset(0.0, 0.0),
            end: const FractionalOffset(1.0, 0.0),
            stops: [0.0, 1.0],
            tileMode: TileMode.clamp),
      ),
    ),
    //backgroundColor: Colors.white,
    centerTitle: false,
  );
}




// Bold Text
Widget normalText(String text, double fs, Color color) {
  return Text(
    text,
    style: TextStyle(color: color, fontSize: fs, fontFamily: fontName(),fontWeight: FontWeight.w200),
  );
}

Widget normalTextDrawer(String text, double fs, Color color) {
  return Text(
    text,
    style: TextStyle(color: color, fontSize: fs, fontFamily: fontName(),fontWeight: FontWeight.w500),
  );
}

Widget normalTextFont(String text, double fs, Color color,var val) {
  return Text(
    text,
    style: TextStyle(color: color, fontSize: fs, fontFamily: fontName(),fontWeight: val),
  );
}

// Bold Text
Widget boldText(String text, double fs, Color color) {
  return Text(
    text,
    style: TextStyle(
        color: color,
        fontSize: fs,
        fontFamily: fontName(),
        fontWeight: FontWeight.w600),
  );
}

String fontName() {
  var i = "anekgujarati";
  return i;
}

screenHeight(BuildContext context) {
  var screenHeight = MediaQuery.of(context).size.height;
  return screenHeight;
}

mainHeight(BuildContext context) {
  var height = screenHeight(context) -
      appBarHeight(context) -
      statusBarHeight(context) -
      20;
  return height;
}

screenWidth(BuildContext context) {
  var screenWidth = MediaQuery.of(context).size.width;
  return screenWidth;
}

statusBarHeight(BuildContext context) {
  var statusBarHeight = MediaQuery.of(context).padding.top;
  return statusBarHeight;
}

appBarHeight(BuildContext context) {
  var statusBarHeight = 50;
  return statusBarHeight;
}

Future<bool>? toastError(var i) {
  Fluttertoast.showToast(
      msg: i,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.red,
      textColor: Colors.white,
      fontSize: 14.0);
}

Future<bool?> toastSuccess(var i) {
  return Fluttertoast.showToast(
      msg: i,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.cyan,
      textColor: Colors.white,
      fontSize: 14.0);
}
Future<bool?> toastFeedback(var i) {
  return Fluttertoast.showToast(
      msg: i,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 5,
      backgroundColor: Colors.cyan,
      textColor: Colors.white,
      fontSize: 14.0);
}
// purple button

closeKeyboard() {
  FocusManager.instance.primaryFocus?.unfocus();
}



showLoading(BuildContext context) {
  return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Center(
          child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColor.blue)),
        );
      });
}

apiCall() {
  final options = BaseOptions(
    baseUrl: AppConstant.WS_BASE_URL,
    connectTimeout: const Duration(seconds: 60),
    receiveTimeout: const Duration(seconds: 60),
    headers: {
      'content-type': 'application/json; charset=UTF-8',
    },
  );

  return Dio(options);
}


date(var date) {
  DateTime parseDate =
  new DateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'").parse(date);
  var inputDate = DateTime.parse(parseDate.toString());
  var outputFormat = DateFormat('dd/MM/yyyy hh:mm a');
  var outputDate = outputFormat.format(inputDate);
  return outputDate;
}
Future<bool> check() async {
  var connectivityResult = await (Connectivity().checkConnectivity());
  if (connectivityResult == ConnectivityResult.mobile) {
    return true;
  } else if (connectivityResult == ConnectivityResult.wifi) {
    return true;
  }
  return false;
}

Widget purpleButton(String text, Function fun) {
  return GestureDetector(
    onTap: () {
      fun();
    },
    child: Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: Colors.deepPurpleAccent,
      child: SizedBox(
          height: 50,
          child: Center(
              child: Text(
            text,
            style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ))),
    ),
  );
}

gradientColor() {
  return BoxDecoration(
      gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.yellow]));
}

List<TextSpan> highlightOccurrences(String source, String query) {
  if (query == null ||
      query.isEmpty ||
      !source.toLowerCase().contains(query.toLowerCase())) {
    return [TextSpan(text: source)];
  }
  final matches = query.toLowerCase().allMatches(source.toLowerCase());

  int lastMatchEnd = 0;

  final List<TextSpan> children = [];
  for (var i = 0; i < matches.length; i++) {
    final match = matches.elementAt(i);

    if (match.start != lastMatchEnd) {
      children.add(TextSpan(
        text: source.substring(lastMatchEnd, match.start),
      ));
    }

    children.add(TextSpan(
      text: source.substring(match.start, match.end),
      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.yellow),
    ));

    if (i == matches.length - 1 && match.end != source.length) {
      children.add(TextSpan(
        text: source.substring(match.end, source.length),
      ));
    }

    lastMatchEnd = match.end;
  }
  return children;
}
