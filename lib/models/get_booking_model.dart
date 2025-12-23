class GetBookingDetail {
  // 1. IDs
  final String bookingId;
  final String userId;
  final String riderId;
  final String vehSubTypeId;
  final String userName;
  final String userMobileNo;
  final String riderName;
  final String riderMobileNo;
  final String riderLatLong;
  final String riderStatus;
  final String vehNo;
  final String tripStatus;
  final String bookDate;
  final String pickupLocation;
  final String dropLocation;
  final double distance;
  final int fareAmount;
  final String bookStatus;
  final String pickupLatLong;
  final String dropUpLatLong;
  final String? finalAmt;
  final String otp;


  GetBookingDetail({
    required this.bookingId,
    required this.userId,
    required this.riderId,
    required this.vehSubTypeId,
    required this.userName,
    required this.userMobileNo,
    required this.riderName,
    required this.riderMobileNo,
    required this.riderLatLong,
    required this.riderStatus,
    required this.vehNo,
    required this.tripStatus,
    required this.bookDate,
    required this.pickupLocation,
    required this.dropLocation,
    required this.distance,
    required this.fareAmount,
    required this.bookStatus,
    required this.pickupLatLong,
    required this.dropUpLatLong,
    this.finalAmt,
    required this.otp,
  });

  factory GetBookingDetail.fromJson(Map<String, dynamic> json) {
    // 💡 '.toString()' use pannuradhu safe. API la BigInt or int irundhaalum handle pannidum.
    return GetBookingDetail(
      // IDs
      bookingId: json['bookingid']?.toString() ?? '',
      userId: json['userid']?.toString() ?? '',
      riderId: json['riderid']?.toString() ?? '',
      vehSubTypeId: json['vehsubtypeid']?.toString() ?? '',

      // User/Rider Details (Exact Keys)
      userName: json['username']?.toString() ?? '',
    userMobileNo: json['usermobileno']?.toString() ?? '',
      riderName: json['ridername']?.toString() ?? '',
      riderMobileNo: json['ridermobileno']?.toString() ?? '',
    riderLatLong: json['riderlatlong']?.toString() ?? '',
      riderStatus: json['riderstatus']?.toString() ?? '',

      // Vehicle Details
      vehNo: json['vehno']?.toString() ?? '',
      tripStatus: json['tripstatus']?.toString() ?? '',

      // Booking/Trip Details
      bookDate: json['bookdate']?.toString() ?? '',
      pickupLocation: json['pickuplocation']?.toString() ?? '',
      dropLocation: json['droplocation']?.toString() ?? '',

      // Data type handling: JSON la number-a irundha, adha Double/Int-a kondu varom
      distance: (json['distance'] is num) ? json['distance'].toDouble() : 0.0,
      fareAmount: (json['fareamount'] is num) ? json['fareamount'].toInt() : 0,

      bookStatus: json['bookstatus']?.toString() ?? '',
      pickupLatLong: json['pickuplatlong']?.toString() ?? '',
      dropUpLatLong: json['dropuplatlong']?.toString() ?? '',

      finalAmt: json['finalamt']?.toString(),

      otp: json['otp']?.toString() ?? '',
    );
  }
}