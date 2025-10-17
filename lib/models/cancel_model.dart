class CancelModel {
  final String lastBookingId;
  final String decline_reason;

  CancelModel({
    required this.lastBookingId,
    required this.decline_reason,
  });

  Map<String, dynamic> toMap() {
    return {
      "lastBookingId": lastBookingId,
      "decline_reason": decline_reason,
    };
  }
}
