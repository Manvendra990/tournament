import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/session_manager.dart';
import '../data/datasources/booking_remote_datasource.dart';
import '../data/datasources/ground_remote_datasource.dart';
import '../data/datasources/slot_remote_datasource.dart';
import '../data/models/booking_model.dart';
import '../data/models/ground_model.dart';
import '../data/models/slot_model.dart';

final currentAdminIdProvider = Provider<String>(
  (_) => SessionManager.currentUserId,
);
final groundDatasourceProvider = Provider<GroundRemoteDatasource>(
  (_) => GroundRemoteDatasource(),
);
final bookingDatasourceProvider = Provider<BookingRemoteDatasource>(
  (_) => BookingRemoteDatasource(),
);
final slotDatasourceProvider = Provider<SlotRemoteDatasource>(
  (_) => SlotRemoteDatasource(),
);
final adminGroundsProvider = StreamProvider<List<GroundModel>>(
  (ref) => ref
      .watch(groundDatasourceProvider)
      .watchAdminGrounds(ref.watch(currentAdminIdProvider)),
);
final selectedGroundProvider = StateProvider<GroundModel?>((ref) => null);
final adminBookingsProvider = StreamProvider<List<BookingModel>>(
  (ref) => ref
      .watch(bookingDatasourceProvider)
      .watchAdminBookings(ref.watch(currentAdminIdProvider)),
);
final bookingFilterProvider = StateProvider<String>((ref) => 'all');
final filteredBookingsProvider = Provider<AsyncValue<List<BookingModel>>>((
  ref,
) {
  final a = ref.watch(adminBookingsProvider),
      f = ref.watch(bookingFilterProvider);
  return a.whenData(
    (l) => f == 'all' ? l : l.where((b) => b.bookingStatus == f).toList(),
  );
});
final slotDateProvider = StateProvider<DateTime>((ref) => DateTime.now());
final selectedGroundForSlotsProvider = StateProvider<String?>((ref) => null);
final slotsProvider = StreamProvider<List<SlotModel>>((ref) {
  final id = ref.watch(selectedGroundForSlotsProvider);
  if (id == null) return const Stream.empty();
  return ref
      .watch(slotDatasourceProvider)
      .watchSlotsForGround(id, ref.watch(slotDateProvider));
});
final todayBookingsProvider = FutureProvider<List<BookingModel>>(
  (ref) => ref
      .watch(bookingDatasourceProvider)
      .getTodayBookings(ref.watch(currentAdminIdProvider)),
);
final revenueFilterProvider = StateProvider<String>((ref) => 'monthly');
final revenueDataProvider = FutureProvider.family<List<BookingModel>, String>((
  ref,
  filter,
) {
  final n = DateTime.now();
  final from = filter == 'daily'
      ? DateTime(n.year, n.month, n.day)
      : filter == 'weekly'
      ? n.subtract(const Duration(days: 7))
      : DateTime(n.year, n.month, 1);
  return ref
      .watch(bookingDatasourceProvider)
      .getAdminBookingsForDateRange(ref.watch(currentAdminIdProvider), from, n);
});
