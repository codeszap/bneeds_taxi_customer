import 'dart:convert';

import 'package:bneeds_taxi_customer/models/vehicle_subtype_model.dart';
import '../core/api_client.dart';
import '../core/api_endpoints.dart';
import '../models/vehicle_type_model.dart';

class VehicleTypeRepository {
  final _client = ApiClient().dio;

  Future<List<VehicleTypeModel>> fetchVehicleTypes() async {
    final response = await _client.get(ApiEndpoints.vehicleType);

    dynamic data = response.data;

    // API sometimes returns JSON string instead of actual List
    if (data is String) {
      data = jsonDecode(data);
    }

    if (data is List) {
      return data.map((e) => VehicleTypeModel.fromJson(e)).toList();
    } else {
      throw Exception("Invalid response format");
    }
  }

Future<List<VehicleSubType>> fetchVehicleSubTypes(String vehTypeId) async {
  final res = await _client.get(
    ApiEndpoints.vehicleSubType,
    queryParameters: {'action': 'D', 'VehTypeid': vehTypeId},
  );

  dynamic data = res.data;
  if (data is String) {
    data = jsonDecode(data);
  }

  if (data is List) {
    return data.map((e) => VehicleSubType.fromJson(e)).toList();
  } else {
    throw Exception("Invalid response format");
  }
}

}
