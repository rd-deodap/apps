// dio_error.dart
import 'package:dio/dio.dart';
import 'error_entity.dart';
import 'dio_error_message.dart';

ErrorEntity createErrorEntity(DioException error) {
  switch (error.type) {
    case DioExceptionType.cancel:
      return const ErrorEntity(code: -1, message: requestCancelError);

    case DioExceptionType.connectionTimeout:
      return const ErrorEntity(code: -1, message: connectionTimeOutError);

    case DioExceptionType.sendTimeout:
      return const ErrorEntity(code: -1, message: requestTimeOutError);

    case DioExceptionType.receiveTimeout:
      return const ErrorEntity(code: -1, message: responseTimeOutError);

    case DioExceptionType.badCertificate:
      return const ErrorEntity(code: -1, message: invalidRequestError);

    case DioExceptionType.connectionError:
    // typically no internet / DNS / socket error
      return const ErrorEntity(code: 0, message: checkInternetConnectionError);

    case DioExceptionType.badResponse:
      try {
        final errCode = error.response?.statusCode ?? -1;
        switch (errCode) {
          case 400:
            return const ErrorEntity(code: 400, message: requestSyntaxError);
          case 403:
            return const ErrorEntity(code: 403, message: serverRefusedError);
          case 404:
            return const ErrorEntity(code: 404, message: dataNotAvailableError);
          case 405:
            return const ErrorEntity(code: 405, message: requestForbiddenError);
          case 500:
            return const ErrorEntity(code: 500, message: serverInternalError);
          case 502:
            return const ErrorEntity(code: 502, message: invalidRequestError);
          case 503:
            return const ErrorEntity(code: 503, message: serverDownError);
          case 505:
            return const ErrorEntity(code: 505, message: notSupportHTTPError);
          default:
            return ErrorEntity(code: errCode, message: unknownMistakeError);
        }
      } catch (_) {
        return const ErrorEntity(code: -1, message: unknownError);
      }

    case DioExceptionType.unknown:
    default:
    // error.message can be null in Dio v5
      return ErrorEntity(code: -1, message: error.message ?? unknownError);
  }
}
