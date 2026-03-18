import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:deodap/widgets/all_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class ScreenshotUtils {
  // Singleton pattern to ensure only one instance
  static final ScreenshotUtils _instance = ScreenshotUtils._internal();

  factory ScreenshotUtils() => _instance;

  ScreenshotUtils._internal();

  Future<void> captureAndUploadScreenshot(GlobalKey repaintBoundaryKey) async {
    final status = await Permission.storage.request();
    try {
      final image = await _captureScreenshot(repaintBoundaryKey);
      if (image != null) {
        final filePath = await _saveScreenshot(image);
        await _uploadScreenshot(filePath);
      } else {
        print("Screenshot capture returned null.");
      }
    } catch (e) {
      print("Error capturing screenshot: $e");
    }
  }

  Future<Uint8List?> _captureScreenshot(GlobalKey repaintBoundaryKey) async {
    try {
      RenderRepaintBoundary boundary =
          repaintBoundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage();
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      print("Error capturing screenshot: $e");
      return null;
    }
  }

  Future<String> _saveScreenshot(Uint8List image) async {
    final directory = await _getDownloadDirectory();
    final ssDirectory = Directory('${directory.path}/SS');

    if (!await ssDirectory.exists()) {
      await ssDirectory.create(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = '${ssDirectory.path}/screenshot_$timestamp.png';
    final file = File(filePath);
    await file.writeAsBytes(image);
    print("Screenshot saved at $filePath");
    toastSuccess("Screenshot saved at $filePath");
    return filePath;
  }

  Future<Directory> _getDownloadDirectory() async {
    if (Platform.isAndroid) {
      return Directory('/storage/emulated/0/Download');
    } else {
      return await getApplicationDocumentsDirectory();
    }
  }

  Future<void> _uploadScreenshot(String filePath) async {
    final uri = Uri.parse("https://yourserver.com/upload");
    final request = http.MultipartRequest('POST', uri);
    final file = await http.MultipartFile.fromPath('file', filePath);
    request.files.add(file);

    final response = await request.send();
    if (response.statusCode == 200) {
      print("Upload successful");
    } else {
      print("Upload failed");
    }
  }
}