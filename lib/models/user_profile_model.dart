class UserProfile {
    final String userid;
  final String userName;
  final String mobileNo;
  final String password;
  final String gender;
  final String dob;
  final String address1;
  final String address2;
  final String address3;
  final String city;
  final String tokenkey;

  UserProfile({
    required this.userid,
    required this.userName,
    required this.mobileNo,
    required this.password,
    required this.gender,
    required this.dob,
    required this.address1,
    required this.address2,
    required this.address3,
    required this.city,
    required this.tokenkey,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userid: json['userid'] ?? '',
      userName: json['userName'] ?? '',
      mobileNo: json['mobileno'] ?? '',
      password: json['Password'] ?? '',
      gender: json['Gender'] ?? '',
      dob: json['dob'] ?? '',
      address1: json['Address1'] ?? '',
      address2: json['Address2'] ?? '',
      address3: json['Address3'] ?? '',
      city: json['City'] ?? '',
       tokenkey: json['tokenkey'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "userid": userid,
      "userName": userName,
      "mobileno": mobileNo,
      "password": password,
      "gender": gender,
      "dob": dob,
      "address1": address1,
      "address2": address2,
      "address3": address3,
      "city": city,
      "tokenkey": tokenkey,
    };
  }
}


class DriverProfile {
  final String riderName;
  final String mobileNo;
  final String vehSubTypeId;
  final String riderStatus;
  final String fromLatLong;
  final String toLatLong;
  final String tokenKey;

  DriverProfile({
    required this.riderName,
    required this.mobileNo,
    required this.vehSubTypeId,
    required this.riderStatus,
    required this.fromLatLong,
    required this.toLatLong,
    required this.tokenKey,
  });

  // Factory constructor to create DriverProfile from JSON
  factory DriverProfile.fromJson(Map<String, dynamic> json) {
    return DriverProfile(
      riderName: json['RiderName'] ?? '',
      mobileNo: json['MobileNo'] ?? '',
      vehSubTypeId: json['VehsubTypeid'] ?? '',
      riderStatus: json['riderstatus'] ?? '',
      fromLatLong: json['FromLatLong'] ?? '',
      toLatLong: json['ToLatLong'] ?? '',
      tokenKey: json['tokenkey'] ?? '',
    );
  }

  // Convert DriverProfile to JSON
  Map<String, dynamic> toJson() {
    return {
      'RiderName': riderName,
      'MobileNo': mobileNo,
      'VehsubTypeid': vehSubTypeId,
      'riderstatus': riderStatus,
      'FromLatLong': fromLatLong,
      'ToLatLong': toLatLong,
      'tokenkey': tokenKey,
    };
  }
}
