import '../models/booking_model.dart';
import 'package:slotbooking/core/api/api_services.dart';

class BookingRemoteDatasource {
  final BookingApi _api = BookingApi();

  Future<List<BookingModel>> getMine() async {
    final rows = await _api.mine();
    return rows.map(BookingModel.fromMap).toList();
  }

  Future<List<BookingModel>> getForDateRange(DateTime from, DateTime to) async {
    final all = await getMine();
    return all.where((b) => !b.date.isBefore(from) && !b.date.isAfter(to)).toList();
  }

  Future<List<BookingModel>> getTodayBookings() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return getForDateRange(start, end);
  }
}
