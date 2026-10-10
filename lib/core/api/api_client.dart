import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
// ignore: unused_import — used in global_error_interceptor.dart (part file)
import 'package:flutter/material.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../../core/storage/local_storage_service.dart';
import '../../di/locator.dart';
import '../constants/app_constants.dart';
import '../navigation/app_navigator.dart';
import '../navigation/app_routes.dart';
import 'api_endpoints.dart';
import 'api_error_handler.dart';
import 'app_exception.dart';

part 'interceptors/api_interceptor.dart';
part 'interceptors/global_error_interceptor.dart';

class ApiClient {
  static String baseUrl = AppConstants.baseUrl;
  static final String baseUrlApi = "$baseUrl/api";

  static final Dio _dio =
      Dio(
          BaseOptions(
            baseUrl: baseUrlApi,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
            responseType: ResponseType.json,
          ),
        )
        ..interceptors.addAll([
          _AuthInterceptor(),
          GlobalErrorInterceptor(),
          PrettyDioLogger(
            requestHeader: true,
            requestBody: true,
            responseBody: false,
            responseHeader: false,
            error: true,
            compact: true,
            maxWidth: 90,
            enabled: kDebugMode,
            filter: (options, args) {
              // don't print requests with uris containing '/posts'
              if (options.path.contains('/posts')) {
                return false;
              }
              // don't print responses with unit8 list data
              return !args.isResponse || !args.hasUint8ListData;
            },
          ),
          // LogInterceptor(request: true /*, requestBody: true, responseBody: true, error: true*/),
        ]);

  // ---------- GET ----------
  Future<dynamic> get(String path, {Map<String, dynamic>? query, Options? options}) async {
    try {
      var response = await _dio.get(
        path,
        queryParameters: query,
        options: options ?? Options(
          followRedirects: false, // Prevents 302 redirect, forces it to show the error
          // Keep this to see validation errors (422) instead of throwing exceptions
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 422 && path.contains(ApiEndpoints.getProviderServiceRequestDetails)) {
        kPrint('⚠️ 422 error on request details (GET). Retrying once...');
        await Future.delayed(const Duration(milliseconds: 200));
        response = await _dio.get(
          path,
          queryParameters: query,
          options: options ?? Options(
            followRedirects: false,
            validateStatus: (status) => status != null && status < 500,
          ),
        );
      }

      final statusCode = response.statusCode;
      if (statusCode != null && statusCode >= 400) {
        if (statusCode != 422 || response.data is! Map) {
          throw DioException(
            requestOptions: response.requestOptions,
            response: response,
            type: DioExceptionType.badResponse,
            error: response.statusMessage,
          );
        }
      }

      return response.data;
    } on DioException catch (e) {
      throw AppException(ApiErrorHandler.getErrorMessage(e));
    } catch (e) {
      throw AppException(ApiErrorHandler.getErrorMessage(e));
    }
  }

  // ---------- POST ----------
  Future<dynamic> post(String path, Map<String, dynamic> data) async {
    kPrint(data);
    try {
      var response = await _dio.post(
        path,
        data: data,
        options: Options(
          followRedirects: false, // Prevents 302 redirect, forces it to show the error
          // Keep this to see validation errors (422) instead of throwing exceptions
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 422 && path.contains(ApiEndpoints.getProviderServiceRequestDetails)) {
        kPrint('⚠️ 422 error on request details (POST). Retrying once...');
        await Future.delayed(const Duration(milliseconds: 200));
        response = await _dio.post(
          path,
          data: data,
          options: Options(
            followRedirects: false,
            validateStatus: (status) => status != null && status < 500,
          ),
        );
      }

      final statusCode = response.statusCode;
      if (statusCode != null && statusCode >= 400) {
        if (statusCode != 422 || response.data is! Map) {
          throw DioException(
            requestOptions: response.requestOptions,
            response: response,
            type: DioExceptionType.badResponse,
            error: response.statusMessage,
          );
        }
      }

      return response.data;
    } on DioException catch (e) {
      throw AppException(ApiErrorHandler.getErrorMessage(e));
    } catch (e) {
      throw AppException(ApiErrorHandler.getErrorMessage(e));
    }
  }

  // ---------- PUT ----------
  static Future<dynamic> put(String path, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put(path, data: data);
      return response.data;
    } on DioException catch (e) {
      throw AppException(ApiErrorHandler.getErrorMessage(e));
    } catch (e) {
      throw AppException(ApiErrorHandler.getErrorMessage(e));
    }
  }

  // ---------- DELETE ----------
  static Future<dynamic> delete(String path) async {
    try {
      final response = await _dio.delete(path);
      return response.data;
    } on DioException catch (e) {
      throw AppException(ApiErrorHandler.getErrorMessage(e));
    } catch (e) {
      throw AppException(ApiErrorHandler.getErrorMessage(e));
    }
  }

  // ---------- POST MULTIPART (FORM DATA) ----------
  Future<dynamic> postMultipart(String path, Map<String, dynamic> data, {FormData? formData, Options? options}) async {
    final formDataMap = formData ?? FormData.fromMap(data);
    try {
      final response = await _dio.post(
        path,
        data: formDataMap,
        options: options ?? Options(
          followRedirects: false, // Prevents 302 redirect, forces it to show the error
          // Keep this to see validation errors (422) instead of throwing exceptions
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final statusCode = response.statusCode;
      if (statusCode != null && statusCode >= 400) {
        if (statusCode != 422 || response.data is! Map) {
          throw DioException(
            requestOptions: response.requestOptions,
            response: response,
            type: DioExceptionType.badResponse,
            error: response.statusMessage,
          );
        }
      }

      return response.data;
    } on DioException catch (e) {
      throw AppException(ApiErrorHandler.getErrorMessage(e));
    } catch (e) {
      throw AppException(ApiErrorHandler.getErrorMessage(e));
    }
  }
}

void kPrint(dynamic m) {
  if (kDebugMode) {
    log(m.toString(), name: "re==");
  }
}

void kPrintError(dynamic m, {Object? error, StackTrace? stack}) {
  if (kDebugMode) {
    log(m.toString(), name: "Error: ", error: error, stackTrace: stack);
  } else if (error != null) {
    FirebaseCrashlytics.instance.recordError(
      error,
      stack,
      reason: m.toString(),
      fatal: false,
    );
  }
}
