import 'dart:convert';
import 'package:bneeds_taxi_customer/core/api_client.dart';
import 'package:bneeds_taxi_customer/core/api_endpoints.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/user_profile_model.dart';
import '../utils/sharedPrefrencesHelper.dart';

class ProfileRepository {
  final Dio _dio = ApiClient().dio;

  Future<List<UserProfile>> fetchUserProfile({required String mobileno}) async {
    final String url =
        "${ApiEndpoints.userProfile}?action=L&mobileno=$mobileno";

    if (kDebugMode) {
      print("📡 Fetch Profile API URL: ${_dio.options.baseUrl}$url");
    }

    try {
      final response = await _dio.get(url);

      print("✅ Status: ${response.statusCode}");
      print("📦 Data type: ${response.data.runtimeType}");
      print("📦 Data: ${response.data}");

      final data = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      if (response.statusCode == 200 && data is Map) {
        final status = data['status']?.toString().toLowerCase();

        if (status == 'error') {
          print("⚠ No user found: ${data['message']}");
          return []; // or throw Exception(data['message']);
        }

        if (status == 'success' && data['data'] is List) {
          return (data['data'] as List)
              .map((json) => UserProfile.fromJson(json))
              .toList();
        }

        throw Exception("Unexpected success response format");
      } else {
        throw Exception("Unexpected response format");
      }
    } catch (e) {
      print("❌ Error fetching profile: $e");
      throw Exception("Error fetching profile: $e");
    }
  }



  Future<String> insertUserProfile(UserProfile profile) async {
    final String url = "${ApiEndpoints.userProfile}?action=I";

    // Note: The structure of the body needs to match the C# API's expected RootObject
    final body = {
      "userprofileDet": [profile.toJson()],
    };

    print("📡 Insert API URL: ${_dio.options.baseUrl}$url");
    print("📦 Insert Payload: ${jsonEncode(body)}");

    try {
      final response = await _dio.post(
        url,
        data: jsonEncode(body),
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (kDebugMode) {
        print("✅ Insert Response: ${response.data}");
      }

      if (response.statusCode == 200) {
        final data = response.data is String
            ? jsonDecode(response.data)
            : response.data;

        if (data["status"] == "success") {
          // --- THIS IS THE CRITICAL CHANGE ---
          final String userId = data["userid"].toString(); // Get the userid from the response
          await SharedPrefsHelper.setUserId(userId); // Save it to shared preferences
          // ------------------------------------

          return data["message"] ?? "Insert Successfully";
        } else {
          return data["message"] ?? "Insert Failed";
        }
      } else {
        throw Exception("Insert failed: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Error inserting profile: $e");
      throw Exception("Error inserting profile: $e");
    }
  }


  Future<String> updateUserProfile(UserProfile profile) async {
    final String url = "${ApiEndpoints.userProfile}?action=U";

    final body = {
      "userprofileupdate": [profile.toJson()],
    };

    print("📡 Update API URL: ${_dio.options.baseUrl}$url");
    print("📦 Update Payload: ${jsonEncode(body)}");

    try {
      final response = await _dio.post(
        url,
        data: jsonEncode(body),
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      print("✅ Update Response: ${response.data}");

      if (response.statusCode == 200) {
        final data = response.data is String
            ? jsonDecode(response.data)
            : response.data;

        if (data["status"] == "success") {
          // Confirm the userid from the response (Optional: can be used for logging/verification)
          final String userId = data["userid"].toString();
          await SharedPrefsHelper.setUserId(userId);
          print("UserID $userId updated successfully.");

          return data["message"] ?? "Updated Successfully";
        } else {
          // Handles C# API errors like {"status":"error", "message":"..."}
          return data["message"] ?? "Update Failed";
        }
      } else {
        throw Exception("Update failed: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Error updating profile: $e");
      // Ensure the thrown exception is formatted for a clear stack trace/error handling
      throw Exception("Error updating profile: $e");
    }
  }


  Future<List<DriverProfile>> getDriverDetail({required String mobileno}) async {
    final url = "${ApiEndpoints.driverProfile}?action=L&mobileno=$mobileno";

    try {
      final response = await _dio.get(url);

      // முழு response data print பண்ண
      print("Raw response: ${response.data}");

      final data = response.data is String ? jsonDecode(response.data) : response.data;

      // decode ஆனது print பண்ண
      print("Decoded data: $data");

      if (data['status'] == 'success' && data['data'] != null) {
        final riders = List<Map<String, dynamic>>.from(data['data']);
        return riders.map((r) => DriverProfile.fromJson(r)).toList();
      } else {
        return [];
      }
    } on DioException catch (e) {
      print("Error fetching rider login: ${e.response?.data ?? e.message}");
      return [];
    }

  }

  Future<List<DriverProfile>> getDriverNearby({
    required String vehSubTypeId,
    required String riderStatus,
  }) async {
    final String url =
        "${ApiEndpoints.driverProfile}?action=G&VehsubTypeid=$vehSubTypeId&riderstatus=$riderStatus";

    print("📡 Fetch Nearby Drivers API URL: ${_dio.options.baseUrl}$url");

    try {
      final response = await _dio.get(url);

      // Raw response
      print("Raw response: ${response.data}");

      // Decode JSON if response is string
      final data = response.data is String ? jsonDecode(response.data) : response.data;
      print("Decoded data: $data");

      if (data['status']?.toString().toLowerCase() == 'success' &&
          data['data'] is List) {
        final driversList = List<Map<String, dynamic>>.from(data['data']);
        return driversList.map((json) => DriverProfile.fromJson(json)).toList();
      } else if (data['status']?.toString().toLowerCase() == 'error') {
        print("⚠ No drivers found: ${data['message']}");
        return [];
      } else {
        throw Exception("Unexpected response format");
      }
    } catch (e) {
      print("❌ Error fetching nearby drivers: $e");
      return [];
    }
  }

  Future<int?> updateFcmToken({
    required String mobileNo,
    required String tokenKey,
  }) async {
    final String url = "${ApiEndpoints.userProfile}?action=T";

    final body = jsonEncode({
      "updateridertokenkey": [
        {
          "mobileno": mobileNo,
          "tokenkey": tokenKey,
        }
      ]
    });

    try {
      print("🚀 Calling API: $url");
      print("📦 Body: $body");

      final response = await _dio.post(
        url,
        data: body,
        options: Options(headers: {"Content-Type": "application/json"}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        var data = response.data;

        // 🚀 check if data is string, then decode
        if (data is String) {
          data = jsonDecode(data);
        }

        final bookingId = data['bookingId'] as int?;

        if (bookingId != null) {
          print("Booking saved successfully with ID: $bookingId");
          return bookingId;
        } else {
          print("Error: 'bookingId' not found in the response.");
          return null;
        }
      } else {
        print("Error saving booking with status code: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Error saving booking: $e");
      rethrow;
    }
  }
}
