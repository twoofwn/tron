import '../models/scenario_model.dart';

abstract final class ScenarioRepository {
  static const scenarios = [
    ScenarioModel(
      'friend',
      'Người yêu gọi',
      'Bà chã húi <3',
      'Alo, anh đang đâu đấy? Anh về lai em ra viện với, em đau bụng quá.',
      '20 giây',
    ),
    ScenarioModel(
      'mother',
      'Bố gọi',
      'Bố',
      'Alo, mày đang đâu đấy? Nhà đang bao việc mà không lo, tao cho mày 5 phút về ngay cho tao.',
      '25 giây',
    ),
    ScenarioModel(
      'boss',
      'Anh trai gọi (Tình huống đường vắng)',
      'Khọm già',
      'Alo, đi đến đâu rồi? Đợi tí, tao sắp đến nơi rồi.',
      '20 giây',
    ),
    ScenarioModel(
      'delivery',
      'Shipper đang chờ',
      'Giao hàng',
      'A lô, em có đơn hàng giao cho anh chị. Em đang đứng trước cửa nhà rồi ạ. Anh chị về nhận giúp em nhé, đơn này cần ký nhận trực tiếp ạ.',
      '18 giây',
    ),
  ];
  static ScenarioModel find(String id) => scenarios.firstWhere(
    (scenario) => scenario.id == id,
    orElse: () => scenarios.first,
  );
}
