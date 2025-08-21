class LocationData {
  final String address;
  final double lat;
  final double lng;

  LocationData({
    required this.address,
    required this.lat,
    required this.lng,
  });

  bool get isEmpty => address.isEmpty && lat == 0 && lng == 0;
}
