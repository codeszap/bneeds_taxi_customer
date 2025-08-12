class VehicleSubType {
  final String vehSubTypeId;
  final String vehSubTypeName;
  final String vehTypeId;
  final String price;

  VehicleSubType({
    required this.vehSubTypeId,
    required this.vehSubTypeName,
    required this.vehTypeId,
    required this.price,
  });

  factory VehicleSubType.fromJson(Map<String, dynamic> json) {
    return VehicleSubType(
      vehSubTypeId: json['VehsubTypeid'] ?? '',
      vehSubTypeName: json['VehsubTypeName'] ?? '',
      vehTypeId: json['VehTypeid'] ?? '',
      price: json['Price'] ?? '',
    );
  }
}
