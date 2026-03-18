import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';

import '../commonmodule/HexColor.dart';
import '../commonmodule/appConstant.dart';

AppBar appBar(
  String title, {
  List<Widget>? actions, // All actions will be passed as a dynamic list
  bool automaticallyImplyLeading = true,
  bool centerTitle = false,
  double elevation = 0.0,
  Color backgroundColor = Colors.white,
  Color textColor = Colors.black,
  double fontSize = 16,
}) {
  return AppBar(
    iconTheme: IconThemeData(color: Colors.black),
    title: Text(
      title,
      style: TextStyle(
        fontSize: fontSize,
        color: textColor,
        fontWeight: FontWeight.bold,
      ),
    ),
    elevation: elevation,
    backgroundColor: backgroundColor,
    centerTitle: centerTitle,
    automaticallyImplyLeading: automaticallyImplyLeading,
    actions: actions, // Use the dynamic actions list
  );
}

HexColor appColor() {
  return HexColor('#0E3A61');
}

sizedBoxHWidget(double size) {
  return SizedBox(height: size);
}

sizedBoxWWidget(double size) {
  return SizedBox(width: size);
}

dividerWidget({double? thickness, Color? color}) {
  return Divider(
    color: color ?? Colors.grey,
    thickness: thickness ?? 1,
  );
}

// Bold Text
Widget normalText(String text, double fs, Color color) {
  return Text(
    text,
    style: TextStyle(
        color: color,
        fontSize: fs,
        fontFamily: fontName(),
        fontWeight: FontWeight.w200),
  );
}

Widget normalTextDrawer(String text, double fs, Color color) {
  return Text(
    text,
    style: TextStyle(
        color: color,
        fontSize: fs,
        fontFamily: fontName(),
        fontWeight: FontWeight.w500),
  );
}

Widget normalTextFont(String text, double fs, Color color, var val) {
  return Text(
    text,
    style: TextStyle(
        color: color, fontSize: fs, fontFamily: fontName(), fontWeight: val),
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
  return null;
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

Future<bool?> toastScan(var i) {
  return Fluttertoast.showToast(
      msg: i,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.TOP,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.cyan,
      textColor: Colors.white,
      fontSize: 14.0);
}

void showInstantToast(String message) {
  // Show toast
  Fluttertoast.showToast(
    msg: message,
    toastLength: Toast.LENGTH_SHORT,
    gravity: ToastGravity.TOP,
    timeInSecForIosWeb: 1,
    backgroundColor: Colors.cyan,
    textColor: Colors.white,
    fontSize: 14.0,
  );

  // Cancel the toast instantly
  Future.delayed(Duration(milliseconds: 500), () {
    Fluttertoast.cancel();
  });
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

typedef DialogCallback = void Function();

void showDialogCommon(BuildContext context, String msg,
    {DialogCallback? onOkTap, bool barrierDismissible = true}) {
  showDialog(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
        title: Container(),
        content: Text(
          msg,
          style: TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
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
                    if (onOkTap != null) {
                      onOkTap();
                    }
                  },
                  child: Container(
                    height: 35,
                    width: 100,
                    decoration: BoxDecoration(
                      color: appColor(), // Replace with your appColor function
                      borderRadius: BorderRadius.circular(5.0),
                      border: Border.all(
                        color: appColor(),
                        // Replace with your appColor function
                        width: 1.0,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Ok',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
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
    },
  );
}

// purple button
void playSoundError() async {
  final player = AudioPlayer();
  try {
    await player.play(AssetSource('sound.mp3'));
    // 🔥 Put your mp3 file under assets/sound.mp3
    // and add it in pubspec.yaml
  } catch (e) {
    print('Error playing sound: $e');
  }
}

void playSoundSuccess() async {
  final player = AudioPlayer();
  try {
    await player.play(AssetSource('success.mp3'));
    // 🔥 Put your mp3 file under assets/sound.mp3
    // and add it in pubspec.yaml
  } catch (e) {
    print('Error playing sound: $e');
  }
}

void showDialogDB(BuildContext context, var msg) async {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      Future.delayed(Duration(seconds: 2), () {
        Navigator.of(context).pop(true);
      });
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15.0),
        ),
        elevation: 16,
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            Container(
              padding: EdgeInsets.all(20.0),
              margin: EdgeInsets.only(top: 45),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    offset: Offset(0, 5),
                    blurRadius: 10.0,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Flower Animation
                  Text(
                    msg,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: appColor(),
                    ),
                  ),
                  Lottie.asset('assets/ani.json', height: 250, width: 250),
                ],
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.red,
                child: IconButton(
                  icon: Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

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
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue)),
        );
      });
}

apiCall() {
  BaseOptions options = new BaseOptions(
    baseUrl: AppConstant.WS_BASE_URL,
    //connectTimeout: 60 * 2000, // 60 seconds
    //receiveTimeout: 60 * 2000, // 60 seconds
    headers: {
      'Content-Type': 'application/json; charset=UTF-8',
      'Accept': 'application/json',
    },
  );
  final dioClient = Dio(options);
  return dioClient;
}

noRecordFound() {
  return Center(
    child: Image.asset(
      AppConstant.noRecordImagePath,
      height: AppConstant.noRecordImageHeightWidth,
      width: AppConstant.noRecordImageHeightWidth,
    ),
  );
}

option() {
  return Options(
    validateStatus: (_) => true,
    headers: {
      "Accept": "application/json",
      "Authorization": AppConstant.isLogin
          ? 'Bearer ' + AppConstant.loginVo!.data!.token.toString()
          : '',
    },
  );
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
  final connectivityResult = await Connectivity().checkConnectivity();
  if (connectivityResult == ConnectivityResult.none) return false;

  try {
    final result = await InternetAddress.lookup('example.com');
    return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
  } catch (_) {
    return false;
  }
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
  if (query.isEmpty || !source.toLowerCase().contains(query.toLowerCase())) {
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
