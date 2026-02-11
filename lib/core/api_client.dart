import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  late Dio dio;

  // Default IP - update this when needed
  //static String dynamicBaseUrl = "http://10.236.44.64:3000/api";
  static String dynamicBaseUrl = "http://184.168.125.10:3000/api";

  /// This should be called in main() before runApp()
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final customIp = prefs.getString('custom_api_ip');
    if (customIp != null && customIp.isNotEmpty) {
      dynamicBaseUrl = "http://$customIp:3000/api";
      if (kDebugMode) print("🌐 Using Custom API Base URL: $dynamicBaseUrl");
    } else {
      if (kDebugMode) print("🌐 Using Default API Base URL: $dynamicBaseUrl");
    }
    _instance._setupDio();
  }

  ApiClient._internal();

  void _setupDio() {
    dio = Dio(
      BaseOptions(
        baseUrl: dynamicBaseUrl,
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
        responseType: ResponseType.json,
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (kDebugMode) {
            print("➡️ [${options.method}] ${options.baseUrl}${options.path}");
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          if (kDebugMode) {
            print("✅ Success: ${response.requestOptions.path}");
          }
          return handler.next(response);
        },
        onError: (DioError e, handler) {
          if (kDebugMode) {
            print("❌ Error: ${e.requestOptions.path} | ${e.message}");
          }
          return handler.next(e);
        },
      ),
    );
  }
}
