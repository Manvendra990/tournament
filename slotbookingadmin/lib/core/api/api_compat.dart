import 'dart:async';
import 'api_services.dart';
import 'api_parsers.dart';

class ApiTimestamp implements Comparable<ApiTimestamp> {
  final DateTime value;
  const ApiTimestamp(this.value);
  DateTime toDate() => value;
  @override int compareTo(ApiTimestamp other) => value.compareTo(other.value);
}

class ApiDocument {
  final String id;
  final Map<String, dynamic> _data;
  ApiDocument(Map<String, dynamic> raw) : id = apiId(raw), _data = _normalize(raw);
  Map<String, dynamic> data() => _data;
}

class ApiQuerySnapshot {
  final List<ApiDocument> docs;
  const ApiQuerySnapshot(this.docs);
}

Map<String,dynamic> _normalize(Map<String,dynamic> raw) {
  final d=Map<String,dynamic>.from(raw);
  if (d['id']==null && d['_id']!=null) d['id']=d['_id'];
  if (d['slotDate']==null && d['date']!=null) d['slotDate']=d['date'];
  if (d['bookingStatus']==null && d['status']!=null) d['bookingStatus']=d['status'];
  for (final k in ['createdAt','updatedAt','paidAt','slotDate','startTime','endTime']) {
    final v=d[k];
    if (v!=null && v is! ApiTimestamp) {
      final parsed = DateTime.tryParse(v.toString());
      if (parsed!=null) d[k]=ApiTimestamp(parsed.toLocal());
    }
  }
  return d;
}

class AdminApiCompat {
  static final _booking=BookingApi();
  static final _ground=GroundApi();

  static Stream<ApiQuerySnapshot> bookings() async* {
    while (true) {
      final rows=await _booking.admin();
      yield ApiQuerySnapshot(rows.map(ApiDocument.new).toList());
      await Future.delayed(const Duration(seconds:5));
    }
  }

  static Stream<ApiQuerySnapshot> grounds() async* {
    while (true) {
      final rows=await _ground.mine();
      yield ApiQuerySnapshot(rows.map(ApiDocument.new).toList());
      await Future.delayed(const Duration(seconds:5));
    }
  }

  static Stream<ApiQuerySnapshot> revenue({DateTime? date,String? groundId}) async* {
    while (true) {
      final rows=await _booking.admin(from:date,to:date);
      final filtered=rows.where((r)=>groundId==null||groundId.isEmpty||(r['groundId']??'').toString()==groundId).map((r){
        final d=Map<String,dynamic>.from(r);
        d['paidAt'] ??= d['createdAt'];
        final dt=apiDate(d['date']??d['slotDate']);
        d['date'] ??= '${dt.year.toString().padLeft(4,'0')}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}';
        return ApiDocument(d);
      }).toList();
      yield ApiQuerySnapshot(filtered);
      await Future.delayed(const Duration(seconds:5));
    }
  }

  static Future<ApiDocument?> ground(String id) async {
    if(id.isEmpty)return null;
    try{return ApiDocument(await _ground.getOne(id));}catch(_){return null;}
  }
}

class ApiBookingService {
  static final _booking=BookingApi();
  static final _slot=SlotApi();
  static Future<void> cancelBooking({required String bookingId,Map<String,dynamic>? bookingData})=>_booking.cancel(bookingId,reason:'Cancelled by admin');
  static Future<void> updateBookingStatus({required String bookingId,required String newStatus,Map<String,dynamic>? bookingData}) async {
    if(newStatus=='cancelled'){await _booking.cancel(bookingId,reason:'Cancelled by admin');return;}
    await _slot.update(bookingId,status:newStatus);
  }
  static Future<void> deleteSlot({required String bookingId,Map<String,dynamic>? bookingData})=>_slot.delete(bookingId);
}
