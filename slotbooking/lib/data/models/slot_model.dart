import 'package:intl/intl.dart';

const _unavailableStatuses = {
  'booked',
  'confirmed',
  'blocked',
  'pending',
  'cancelled',
};

class SlotModel {
  final String slotId;
  final String label;
  final DateTime start;
  final DateTime end;
  final String durationLabel;
  final int amount;
  final String bookingStatus;
  final String paymentStatus;
  final String adminId;
  final String docId;

  const SlotModel({
    required this.slotId,
    required this.label,
    required this.start,
    required this.end,
    required this.durationLabel,
    required this.amount,
    required this.bookingStatus,
    required this.paymentStatus,
    required this.adminId,
    this.docId = '',
  });

  bool get isAvailable =>
      !_unavailableStatuses.contains(bookingStatus.toLowerCase());
  bool get isPast => end.isBefore(DateTime.now());
  bool get isDisabled => !isAvailable || isPast;

  factory SlotModel.fromApi(Map<String, dynamic> data) {
    final date = DateTime.tryParse(data['date']?.toString() ?? '') ?? DateTime.now();
    DateTime parseTime(dynamic raw, DateTime fallback) {
      final p = raw?.toString().split(':') ?? const <String>[];
      if (p.length < 2) return fallback;
      return DateTime(
        date.year,
        date.month,
        date.day,
        int.tryParse(p[0]) ?? fallback.hour,
        int.tryParse(p[1]) ?? fallback.minute,
      );
    }

    final start = parseTime(data['startTime'], date);
    var end = parseTime(data['endTime'], start.add(const Duration(hours: 1)));
    if (!end.isAfter(start)) end = start.add(const Duration(hours: 1));
    final status = data['status']?.toString().toLowerCase() ?? 'available';
    final diff = end.difference(start);
    final durationLabel = diff.inMinutes % 60 == 0
        ? '${diff.inHours}h'
        : '${diff.inHours}h ${diff.inMinutes % 60}m';

    return SlotModel(
      docId: data['id']?.toString() ?? '',
      slotId: data['id']?.toString() ?? '',
      label: '${DateFormat('h:mm a').format(start)} – ${DateFormat('h:mm a').format(end)}',
      start: start,
      end: end,
      durationLabel: durationLabel,
      amount: (data['price'] as num?)?.toInt() ?? 0,
      bookingStatus: status,
      paymentStatus: status == 'booked' ? 'paid' : '',
      adminId: data['adminId']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toPaymentPayload({
    required String groundId,
    required String groundName,
    required String userId,
    required String userPhone,
    required String date,
  }) => {
        'groundId': groundId,
        'groundName': groundName,
        'userId': userId,
        'userPhone': userPhone,
        'date': date,
        'slotId': docId.isNotEmpty ? docId : slotId,
        'slotLabel': label,
        'startTime': start,
        'endTime': end,
        'durationLabel': durationLabel,
        'timeDuretion': {
          'hour': end.difference(start).inHours.abs(),
          'minute': end.difference(start).inMinutes.remainder(60).abs(),
        },
        'amount': amount,
        'bookingStatus': bookingStatus,
        'paymentStatus': paymentStatus.isEmpty ? 'unpaid' : paymentStatus,
        'adminId': adminId,
        'adminBookingId': docId,
      };
}
