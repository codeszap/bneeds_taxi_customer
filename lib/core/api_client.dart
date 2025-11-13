import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'; // for kDebugMode

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  late Dio dio;

  ApiClient._internal() {
    dio = Dio(
      BaseOptions(
        //baseUrl: "https://www.bneedsbill.com/Ramauto/Api/",
        baseUrl: "http://184.168.125.10:3000/api",
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        responseType: ResponseType.json,
      ),
    );

    // Custom interceptor with emoji & debug-only logs
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (kDebugMode) {
            print("➡️ [${options.method}] ${options.baseUrl}${options.path}");
            if (options.data != null) print("📦 Body: ${options.data}");
            if (options.queryParameters.isNotEmpty) {
              print("🔍 Query: ${options.queryParameters}");
            }
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          if (kDebugMode) {
            print("✅ Success: ${response.requestOptions.path}");
            print("📥 Result: ${response.data}");
            print("🔚 ------------------------------\n");
          }
          return handler.next(response);
        },
        onError: (DioError e, handler) {
          if (kDebugMode) {
            print("❌ Error: ${e.requestOptions.path}");
            print("⚠️ Message: ${e.message}");
            if (e.response != null) {
              print("📥 Error Response: ${e.response?.data}");
            }
            print("🔚 ------------------------------\n");
          }
          return handler.next(e);
        },
      ),
    );
  }
}
