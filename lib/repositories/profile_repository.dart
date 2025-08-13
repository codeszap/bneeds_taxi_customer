import 'dart:convert';
import 'package:bneeds_taxi_customer/core/api_client.dart';
import 'package:bneeds_taxi_customer/core/api_endpoints.dart';
import 'package:dio/dio.dart';
import '../models/user_profile_model.dart';

class ProfileRepository {
  final Dio _dio = ApiClient().dio;


Future<List<UserProfile>> fetchUserProfile({
  required String mobileno,
}) async {
  final String url = "${ApiEndpoints.userProfile}?action=L&mobileno=$mobileno";

  print("📡 Fetch Profile API URL: ${_dio.options.baseUrl}$url");

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


  /// 🔹 Insert Profile (Insert Action)
  Future<String> insertUserProfile(UserProfile profile) async {
    final String url =
        "${ApiEndpoints.userProfile}?action=I";

    final body = {
      "userprofileDet": [profile.toJson()]
    };

    print("📡 Insert Profile API URL: ${_dio.options.baseUrl}$url");
    print("📦 Insert Payload: ${jsonEncode(body)}");

    try {
      final response = await _dio.post(
        url,
        data: jsonEncode(body),
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      print("✅ API Response Status: ${response.statusCode}");
      print("📦 API Response Data: ${response.data}");

      if (response.statusCode == 200) {
        return response.data.toString();
      } else {
        throw Exception(
            'Failed to insert profile: ${response.statusCode}');
      }
    } catch (e) {
      print("❌ Error inserting profile: $e");
      throw Exception('Error inserting profile: $e');
    }
  }
}



