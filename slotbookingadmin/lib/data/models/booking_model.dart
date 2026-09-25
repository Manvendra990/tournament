import 'package:slotbookingadmin/core/api/api_parsers.dart';

class BookingModel {
  final String id,
      userId,
      adminId,
      groundId,
      groundName,
      slotId,
      startTime,
      endTime,
      paymentStatus,
      bookingStatus,
      razorpayPaymentId;
  final DateTime date, createdAt;
  final double amount;
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
  factory BookingModel.fromMap(Map<String, dynamic> d) => BookingModel(
    id: apiId(d),
    userId: (d['userId'] ?? '').toString(),
    adminId: (d['adminId'] ?? '').toString(),
    groundId: (d['groundId'] ?? '').toString(),
    groundName: (d['groundName'] ?? '').toString(),
    slotId: (d['slotId'] ?? '').toString(),
    date: apiDate(d['date'] ?? d['slotDate']),
    startTime: (d['startTime'] ?? '').toString(),
    endTime: (d['endTime'] ?? '').toString(),
    amount: ((d['amount'] ?? 0) as num).toDouble(),
    paymentStatus: (d['paymentStatus'] ?? 'pending').toString(),
    bookingStatus: (d['bookingStatus'] ?? d['status'] ?? 'upcoming').toString(),
    razorpayPaymentId: (d['razorpayPaymentId'] ?? '').toString(),
    createdAt: apiDate(d['createdAt']),
  );
  Map<String, dynamic> toMap() => {
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
