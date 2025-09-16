import 'dart:convert';

import 'package:bneeds_taxi_customer/core/api_client.dart';
import 'package:bneeds_taxi_customer/core/api_endpoints.dart';
import 'package:bneeds_taxi_customer/models/booking_model.dart';
import 'package:dio/dio.dart';

class BookingRepository {
  final Dio _dio = ApiClient().dio;

  Future<int?> addBooking(BookingModel booking) async {
    try {
      final payload = {
        "vehbookingDet": [booking.toMap()]
      };

      final response = await _dio.post(
        "${ApiEndpoints.bookingRide}?action=I",
        data: payload,
        options: Options(headers: {"Content-Type": "application/json"}),
      );

      print("Status code: ${response.statusCode}");

      dynamic data;

      if (response.data is String) {
        try {
          String raw = response.data.toString();
          print("Raw Response: $raw");

          // 🔧 Fix malformed JSON => "bookingId":19"Insert Successfully"
          raw = raw.replaceAllMapped(
            RegExp(r'"bookingId":(\d+)"([^"]+)"'),
            (match) =>
                '"bookingId":${match.group(1)},"message":"${match.group(2)}"',
          );

          data = jsonDecode(raw);
        } catch (e) {
          print("Response is not valid JSON: ${response.data}");
          data = {"status": "error", "message": response.data};
        }
      } else {
        data = response.data;
      }

      print("Response data: $data");

      final status = data['status'] ?? 'unknown';
      final message = data['message'] ?? 'No message';
      final bookingId = data['bookingId'];

      print("API Status: $status");
      print("API Message: $message");
      print("Booking ID: $bookingId");

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("Booking saved successfully");
        return bookingId; // ✅ return bookingId
      } else {
        print("Error saving booking");
        return null;
      }
    } catch (e) {
      print("Error saving booking: $e");
      rethrow;
    }
  }
}
