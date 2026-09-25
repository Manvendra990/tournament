import 'package:slotbookingadmin/core/api/api_parsers.dart';
class SlotModel {
 final String id,groundId,startTime,endTime,status; final DateTime date; final double price;
 const SlotModel({required this.id,required this.groundId,required this.date,required this.startTime,required this.endTime,required this.price,required this.status});
 factory SlotModel.fromMap(Map<String,dynamic> d)=>SlotModel(id:apiId(d),groundId:(d['groundId']??'').toString(),date:apiDate(d['date']??d['slotDate']),startTime:(d['startTime']??'').toString(),endTime:(d['endTime']??'').toString(),price:((d['price']??d['amount']??0) as num).toDouble(),status:(d['status']??d['bookingStatus']??'available').toString());
 Map<String,dynamic> toMap()=>{'groundId':groundId,'date':date.toIso8601String(),'startTime':startTime,'endTime':endTime,'price':price,'status':status};
 SlotModel copyWith({String? status,double? price})=>SlotModel(id:id,groundId:groundId,date:date,startTime:startTime,endTime:endTime,price:price??this.price,status:status??this.status);
 bool get isAvailable=>status=='available'; bool get isBooked=>status=='booked'; bool get isBlocked=>status=='blocked';
}
