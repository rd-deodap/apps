import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:deodap/commonmodule/appConstant.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'AppException.dart';

class ApiBaseHelper {
  // static String _baseUrl = "http://demo.ewinfotech.com/healthgate/public/";
  // static String _baseUrl = "https://aaizoon.in/";
  //  final  const String _baseUrl = "https://aaizoon.com/";
  // static String _baseUrl = "https://ec2-15-206-146-93.ap-south-1.compute.amazonaws.com/";

  // String get baseUrl => _baseUrl;

  final String _baseUrl = AppConstant.WS_BASE_URL;

  Future<dynamic> get(String url) async {
    debugPrint('Api Get, url $url');
    var responseJson;
    try {
      final response = await http.get(Uri.parse(_baseUrl + url));
      responseJson = _returnResponse(response);
    } on SocketException {
      debugPrint('No net');
      throw FetchDataException('No Internet connection');
    }
    debugPrint('api get recieved!');
    debugPrint(responseJson.toString());
    return responseJson;
  }

  Future<dynamic> getWithHeader(String url, String token) async {
    //debugPrint('Api Post, url $_baseUrl+url');
    debugPrint(_baseUrl + url);
    debugPrint('Api token, token $token');
    var responseJson;
    try {
      final response = await http
          .get(Uri.parse(_baseUrl + url), headers: {"Authorization": token});
      responseJson = _returnResponse(response);
    } on SocketException {
      debugPrint('No net1');
      throw FetchDataException('No Internet connection');
    }
    debugPrint('api post.');
    debugPrint(responseJson.toString());
    return responseJson;
  }

  Future<dynamic> post(String url, Map body) async {
    debugPrint('Api Post, url $url');
    debugPrint(jsonEncode(body));
    var responseJson;
    try {
      final response = await http.post(Uri.parse(_baseUrl + url), body: body);
      responseJson = _returnResponse(response);
    } on SocketException {
      debugPrint('No net');
      throw FetchDataException('No Internet connection');
    }
    debugPrint('api post.');
    debugPrint(responseJson.toString());
    return responseJson;
  }

  Future<dynamic> postWithHeader(String url, Map body, String token) async {
    //debugPrint('Api Post, url $_baseUrl+url');
    debugPrint(_baseUrl + url);
    debugPrint(jsonEncode(body));
    debugPrint(token);
    var responseJson;
    try {
      final response = await http.post(Uri.parse(_baseUrl + url),
          body: jsonEncode(body),
          headers: {
            "Authorization": token,
            "Content-Type": "application/json"
          });
      responseJson = _returnResponse(response);
    }
    /*on SocketException {debugPrint('No net');
      throw FetchDataException('No Internet connection');
    } */
    catch (ex) {
      debugPrint("error $ex");
    }
    debugPrint('api post.->$responseJson');

    debugPrint('api post.');
    return responseJson;
  }

  Future<dynamic> postWithFileAndHeader(
      String url, Map body, String token, String filePath) async {
    debugPrint(_baseUrl + url);
    debugPrint(jsonEncode(body));
    debugPrint("token is :::: ");
    debugPrint(token);

    Map<String, String> headers = {"Authorization": token};
    var request =
        http.MultipartRequest("POST", Uri.parse("https://aaizoon.com/" + url));
    //add text fields
    request.headers.addAll(headers);

    request.fields["name"] = body["name"];
    request.fields["contact"] = body["contact"];
    request.fields["email"] = body["email"];
    request.fields["gender"] = body["gender"];
    request.fields["language_pref"] = body["language_pref"];
    request.fields["date_of_birth"] = body["date_of_birth"];
    request.fields["bachelor"] = body["bachelor"];
    request.fields["byear"] = body["byear"];
    request.fields["masters"] = body["masters"];
    request.fields["mdate"] = body["mdate"];
    request.fields["postgraduation"] = body["postgraduation"];
    request.fields["pdate"] = body["pdate"];
    request.fields["diploma"] = body["diploma"];
    request.fields["ddate"] = body["ddate"];
    request.fields["total_experiance"] = body["total_experiance"];
    request.fields["awards"] = body["awards"];
    request.fields["type_of_practice"] = body["type_of_practice"];
    request.fields["experience"] = body["experience"];
    request.fields["medical_license"] = body["medical_license"];
    request.fields["specialist_in"] = body["specialist_in"];
    request.fields["video_consultant"] = body["video_consultant"].toString();
    request.fields["address"] = body["address"];
    request.fields["tweeter_link"] = body["tweeter_link"].toString();
    request.fields["instagram_link"] = body["instagram_link"].toString();
    request.fields["facebook_link"] = body["facebook_link"];
    request.fields["youtube_link"] = body["youtube_link"].toString();
    request.fields["bio"] = body["bio"].toString();
    request.fields["extra_details"] = body["extra_details"].toString();
    request.fields["doc_specialist_id"] = body["doc_specialist_id"].toString();
    debugPrint("request--->");
    debugPrint("path--");
    debugPrint(filePath);
    var pic = await http.MultipartFile.fromPath("profile_pic", filePath,
        contentType: MediaType('image', 'jpeg'));
    //add multipart to request
    request.files.add(pic);

    Map<String, dynamic> respJson = {};
    try {
      final response = await request.send();
      respJson.putIfAbsent("status", () => response.statusCode);
      respJson.putIfAbsent(
          "message",
          () => response.statusCode == 200
              ? "Your Profile has been updated successfully"
              : "Something went wrong!");
      respJson.putIfAbsent(
          "success", () => response.statusCode == 200 ? true : false);
      //print(responseData);
      //var responseString = String.fromCharCodes(responseData);
      //responseJson = json.decode(responseString);
      //responseJson = _returnResponse(response);
    }
    /*on SocketException {debugPrint('No net');
      throw FetchDataException('No Internet connection');
    } */
    catch (ex) {
      debugPrint("$ex");
    }
    return respJson;
  }

  Future<dynamic> put(String url, dynamic body) async {
    debugPrint('Api Put, url $url');
    var responseJson;
    try {
      final response = await http.put(Uri.parse(_baseUrl + url), body: body);
      responseJson = _returnResponse(response);
    } on SocketException {
      debugPrint('No net');
      throw FetchDataException('No Internet connection');
    }
    debugPrint('api put.');
    debugPrint(responseJson.toString());
    return responseJson;
  }

  Future<dynamic> delete(String url) async {
    debugPrint('Api delete, url $url');
    var apiResponse;
    try {
      final response = await http.delete(Uri.parse(_baseUrl + url));
      apiResponse = _returnResponse(response);
    } on SocketException {
      debugPrint('No net');
      throw FetchDataException('No Internet connection');
    }
    debugPrint('api delete.');
    debugPrint(apiResponse.toString());
    return apiResponse;
  }
}

dynamic _returnResponse(http.Response response) {
  switch (response.statusCode) {
    case 200:
      debugPrint(response.body.toString());
      var responseJson = json.decode(response.body.toString());
      return responseJson;
    case 400:
      throw BadRequestException(response.body.toString());
    case 401:
    case 403:
      throw UnauthorisedException(response.body.toString());
    case 500:
    default:
      throw FetchDataException(
          'Error occurred while Communication with Server with StatusCode : ${response.statusCode}');
  }
}
