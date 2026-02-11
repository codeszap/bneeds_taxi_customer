import 'dart:convert';

import 'package:bneeds_taxi_customer/core/api_client.dart';
import 'package:bneeds_taxi_customer/core/api_endpoints.dart';
import 'package:bneeds_taxi_customer/models/booking_model.dart';
import 'package:dio/dio.dart';

import '../models/cancel_model.dart';
import '../models/get_booking_model.dart';
import '../providers/params/booking_params.dart';

class BookingRepository {
  final Dio _dio = ApiClient().dio;

  Future<int?> addBooking(BookingModel booking) async {
    // D:/sulthan/bneeds_taxi_customer/lib/repositories/booking_repository.dartFuture<int?> addBooking(BookingModel booking) async {
    try {
      final payload = {
        "vehbookingDet": [booking.toMap()],
      };

      final response = await _dio.post(
        "${ApiEndpoints.bookingRide}?action=I",
        data: payload,
        options: Options(headers: {"Content-Type": "application/json"}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        var data = response.data;

        if (data is String) {
          data = jsonDecode(data);
        }

        // --- 💡 மாற்றம் இங்கே தொடங்குகிறது ---

        // 'bookingIds' என்ற array-ஐப் பெறுகிறோம்
        final bookingIds = data['bookingIds'] as List<dynamic>?;

        // array null-ஆகவோ அல்லது காலியாகவோ (empty) இல்லை என்பதைச் சரிபார்க்கவும்
        if (bookingIds != null && bookingIds.isNotEmpty) {
          // array-வில் உள்ள முதல் ID-ஐப் பெறுகிறோம்
          final bookingId = bookingIds.first as int?;

          if (bookingId != null) {
            print("Booking saved successfully with ID: $bookingId");
            return bookingId;
          } else {
            print("Error: Could not parse bookingId from the list.");
            return null;
          }
        } else {
          // 'bookingId' அல்லது 'bookingIds' கிடைக்கவில்லை என்றால் பிழையைக் காட்டவும்
          print("Error: 'bookingIds' not found or is empty in the response.");
          return null;
        }
        // --- ✨ மாற்றம் இங்கே முடிகிறது ---
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
        "vehbookingdecline": [cancel.toMap()],
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

  Future<List<GetBookingDetail>> fetchBookingDetail(
    int bookingId,
    int riderId,
  ) async {
    try {
      final response = await _dio.get(
        '${ApiEndpoints.getBookingStatus}&Bookingid=$bookingId&Riderid=$riderId',
      );

      dynamic resData = response.data;
      if (resData is String) resData = jsonDecode(resData);

      if (resData is Map<String, dynamic>) {
        if (resData['status'] == 'success' && resData['data'] is List) {
          final list = resData['data'] as List<dynamic>;
          return list.map((e) => GetBookingDetail.fromJson(e)).toList();
        }
      }

      return [];
    } catch (e) {
      print('❌ Error fetching booking details: $e');
      return [];
    }
  }

  Future<GetBookingDetail?> checkBookingStatus(int bookingId) async {
    try {
      // We use action=G which is getBookingStatus endpoint
      // Using POST as observed in working logs
      final response = await _dio.post(
        '${ApiEndpoints.getBookingStatus}&Bookingid=$bookingId&Riderid=0',
      );

      dynamic resData = response.data;
      if (resData is String) resData = jsonDecode(resData);

      if (resData is Map<String, dynamic> && resData['status'] == 'success') {
        final dataList = resData['data'] as List<dynamic>?;
        if (dataList != null && dataList.isNotEmpty) {
          final detail = GetBookingDetail.fromJson(dataList.first);
          // If riderId is not empty or "0", it means a driver has been assigned
          if (detail.riderId.isNotEmpty && detail.riderId != "0") {
            return detail;
          }
        }
      }
      return null;
    } catch (e) {
      print('❌ Error checking booking status: $e');
      return null;
    }
  }
}
