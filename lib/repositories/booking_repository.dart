import 'dart:convert';

import 'package:bneeds_taxi_customer/core/api_client.dart';
import 'package:bneeds_taxi_customer/core/api_endpoints.dart';
import 'package:bneeds_taxi_customer/models/booking_model.dart';
import 'package:dio/dio.dart';

import '../models/cancel_model.dart';

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


  Future<bool> cancelBooking(CancelModel cancel) async {
    try {
      final payload = {
        "vehbookingdecline": [cancel.toMap()]
      };

      final response = await _dio.post(
        "${ApiEndpoints.bookingRide}?action=D",
        data: payload,
        options: Options(headers: {"Content-Type": "application/json"}),
      );

      print("Status code: ${response.statusCode}");

      dynamic data;

      if (response.data is String) {
        try {
          String raw = response.data.toString();
          print("Raw Response: $raw");
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

      print("API Status: $status");
      print("API Message: $message");

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          status == "success") {
        print("Booking cancelled successfully ✅");
        return true;
      } else {
        print("Failed to cancel booking ❌");
        return false;
      }
    } catch (e) {
      print("Error cancelling booking: $e");
      return false;
    }
  }

}
