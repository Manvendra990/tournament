class BookingModel {
  final String id;
  final String userId;
  final String adminId;
  final String groundId;
  final String groundName;
  final String slotId;
  final DateTime date;
  final String startTime;
  final String endTime;
  final double amount;
  final String paymentStatus;
  final String bookingStatus;
  final String razorpayPaymentId;
  final DateTime createdAt;

  const BookingModel({
    required this.id,
    required this.userId,
    required this.adminId,
    required this.groundId,
    required this.groundName,
    required this.slotId,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.amount,
    required this.paymentStatus,
    required this.bookingStatus,
    required this.razorpayPaymentId,
    required this.createdAt,
  });

  factory BookingModel.fromMap(Map<String, dynamic> data) => BookingModel(
        id: data['id']?.toString() ?? '',
        userId: data['userId']?.toString() ?? '',
        adminId: data['adminId']?.toString() ?? '',
        groundId: data['groundId']?.toString() ?? '',
        groundName: data['groundName']?.toString() ?? '',
        slotId: data['slotId']?.toString() ?? '',
        date: DateTime.tryParse(data['date']?.toString() ?? '') ?? DateTime.now(),
        startTime: data['startTime']?.toString() ?? '',
        endTime: data['endTime']?.toString() ?? '',
        amount: (data['amount'] as num?)?.toDouble() ?? 0,
        paymentStatus: data['paymentStatus']?.toString() ?? 'pending',
        bookingStatus: data['bookingStatus']?.toString() ?? 'upcoming',
        razorpayPaymentId: data['razorpayPaymentId']?.toString() ?? '',
        createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? '') ??
            DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'adminId': adminId,
        'groundId': groundId,
        'groundName': groundName,
        'slotId': slotId,
        'date': date.toIso8601String(),
        'startTime': startTime,
        'endTime': endTime,
        'amount': amount,
        'paymentStatus': paymentStatus,
        'bookingStatus': bookingStatus,
        'razorpayPaymentId': razorpayPaymentId,
        'createdAt': createdAt.toIso8601String(),
      };
}
