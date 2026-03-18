import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';

import '../../commonmodule/appConstant.dart';
import '../enum.dart';
import 'dio_error.dart';
import 'error_entity.dart';

const _apiTypeCollection = {
  ApiTypeEnum.get: 'get',
  ApiTypeEnum.post: 'post',
  ApiTypeEnum.delete: 'delete',
  ApiTypeEnum.put: 'put'
};

typedef HttpSuccessCallback<T> = void Function(T data);
typedef HttpFailureCallback = void Function(ErrorEntity? data);

CancelToken cancelToken = CancelToken();

_parseAndDecode(String response) => jsonDecode(response);
parseJson(String text) => compute(_parseAndDecode, text);

class DioHelper {
  DioHelper(this._dio);

  Dio _dio;

  Future<void> request<T>(
      String baseUrl, {
        ApiTypeEnum apiTypeEnum = ApiTypeEnum.get,
        String path = '',
        dynamic data,
        Map<String, dynamic>? queryParameters,
        Options? options,
        Map<String, dynamic>? headers,
        HttpSuccessCallback<T>? success,
        required HttpFailureCallback error,
      }) async {
    try {
      final baseOptions = BaseOptions(
        baseUrl: AppConstant.WS_BASE_URL + baseUrl,
        receiveDataWhenStatusError: false,
        responseType: ResponseType.json,
        connectTimeout: const Duration(seconds: 60), // ✅ Duration
        receiveTimeout: const Duration(seconds: 60), // ✅ Duration
        headers: headers,
      );

      // Create a fresh Dio instance per request (your original style)
      _dio = Dio(baseOptions)..interceptors.addAll(logInterceptor());

      // ✅ Dio v5 adapter (Android/iOS/Desktop)
      _dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.badCertificateCallback =
              (X509Certificate cert, String host, int port) => true;
          return client;
        },
      );

      // OPTIONAL: Background JSON parse (if your dio version exports BackgroundTransformer)
      // If this gives an error, comment these 2 lines.
      if (_dio.transformer is BackgroundTransformer) {
        (_dio.transformer as BackgroundTransformer).jsonDecodeCallback = parseJson;
      }

      final response = await _dio.request(
        path,
        data: data,
        queryParameters: queryParameters,
        options: (options ?? Options()).copyWith(
          method: _apiTypeCollection[apiTypeEnum],
        ),
        // cancelToken: cancelToken, // if you want
      );

      if (success != null) success(response.data as T);
    } on DioException catch (e) {
      // ✅ DioError renamed to DioException in Dio v5
      error(createErrorEntity(e));
    } catch (e) {
      // fallback (optional)
      error(ErrorEntity(code: -1, message: e.toString()));
    }
  }

  List<Interceptor> logInterceptor() {
    if (kReleaseMode) return [];
    return [LogInterceptor(requestBody: true, responseBody: true)];
  }

  void cancelRequests(CancelToken token) {
    token.cancel('cancelled');
  }
}
