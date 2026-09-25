import '../models/ground_model.dart';
import 'package:slotbooking/core/api/api_services.dart';

class GroundRemoteDatasource {
  final GroundApi _api = GroundApi();

  Future<List<GroundModel>> getPublicGrounds({String? sportType}) async {
    final rows = await _api.publicList(sportType: sportType);
    return rows.map(GroundModel.fromMap).toList();
  }

  Future<GroundModel?> getGround(String groundId) async {
    final row = await _api.getOne(groundId);
    return GroundModel.fromMap(row);
  }
}
