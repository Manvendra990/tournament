import 'package:slotbooking/core/api/api_services.dart';
import '../models/slot_model.dart';

class SlotRepository {
  final GroundApi _groundApi = GroundApi();
  final SlotApi _slotApi = SlotApi();

  Future<Map<String, dynamic>> getGround(String groundId) =>
      _groundApi.getOne(groundId);

  Future<List<SlotModel>> getSlots(String groundId, DateTime date) async {
    final rows = await _slotApi.list(groundId, date);
    return rows.map(SlotModel.fromApi).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }
}
