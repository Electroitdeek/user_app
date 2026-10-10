import 'package:dio/dio.dart';
import '../constants/error_constants.dart';
import 'app_exception.dart';

class ApiErrorHandler {
  static String getErrorMessage(dynamic error) {
    if (error is DioException) {
      return _handleDioError(error);
    } else if (error is AppException) {
      return error.message;
    } else if (error is Exception) {
      return error.toString().replaceAll('Exception: ', '');
    } else {
      return ErrorConstants.defaultError;
    }
  }

  static String _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return ErrorConstants.timeoutError;
      
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        if (statusCode != null && statusCode >= 500) {
          return ErrorConstants.serverError;
        }
        
        // Try to extract server-provided error message
        final responseData = error.response?.data;
        if (responseData is Map<String, dynamic>) {
          // Check for Laravel-style validation errors: { "errors": { "field": ["message"] } }
          if (responseData.containsKey('errors') && responseData['errors'] is Map) {
            final errors = responseData['errors'] as Map<String, dynamic>;
            if (errors.isNotEmpty) {
              final firstErrorList = errors.values.first;
              if (firstErrorList is List && firstErrorList.isNotEmpty) {
                return firstErrorList.first.toString();
              }
            }
          }

          if (responseData.containsKey('message') && responseData['message'] != null) {
            return responseData['message'].toString();
          } else if (responseData.containsKey('error') && responseData['error'] != null) {
            return responseData['error'].toString();
          }
        }
        return ErrorConstants.defaultError;

      case DioExceptionType.cancel:
        return "Request was cancelled.";
      
      case DioExceptionType.connectionError:
        return ErrorConstants.networkError;
      
      case DioExceptionType.badCertificate:
        return "Security certificate validation failed.";

      case DioExceptionType.unknown:
        return ErrorConstants.defaultError;
    }
  }
}
