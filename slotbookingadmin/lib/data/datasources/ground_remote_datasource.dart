import 'dart:async'; import 'dart:io'; import 'package:slotbookingadmin/core/api/api_services.dart'; import '../models/ground_model.dart';
class GroundRemoteDatasource { final GroundApi _api=GroundApi(); GroundRemoteDatasource();
 Stream<List<GroundModel>> watchAdminGrounds(String adminId) async* { while(true){ yield (await _api.mine()).map(GroundModel.fromMap).toList(); await Future.delayed(const Duration(seconds:5)); } }
 Future<GroundModel?> getGround(String id) async=>GroundModel.fromMap(await _api.getOne(id));
 Future<String> addGround(GroundModel g) async => (await _api.create(data:g.toMap()))['id']?.toString()??'';
 Future<void> updateGround(String id,Map<String,dynamic>d)=>_api.update(id,d); Future<void> toggleGroundStatus(String id,bool active)=>_api.toggle(id,active);
 Future<List<String>> uploadGroundImages(String id,List<File> files)=>_api.uploadImages(id,files); Future<void> deleteGroundImage(String id,String imageId)=>_api.deleteImage(id,imageId); }
