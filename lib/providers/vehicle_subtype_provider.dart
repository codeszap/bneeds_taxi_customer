import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/vehicle_subtype_model.dart';
import 'vehicle_repository_provider.dart';

final vehicleSubTypeProvider =
    FutureProvider.family<List<VehicleSubType>, String>((ref, vehTypeId) async {
  return ref.read(vehicleRepositoryProvider).fetchVehicleSubTypes(vehTypeId);
});
