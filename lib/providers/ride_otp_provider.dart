import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/location_data.dart';


final rideOtpProvider = StateProvider<String>((ref) => '');
final driverLatLongProvider = StateProvider<String>((ref) => '');

