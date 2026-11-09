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
      'debt-collector',
      'Chủ nợ gọi',
      'Thắng Cá Chép',
      'Alo, sợ cái gì mà không bắt máy? Mày tưởng mày cầm 50 triệu của tao mà mày chạy được à? Giờ tao biết mày ở đâu rồi đấy, mày thấy mày chạy được thì chạy nhanh vào. Mày cứ chạy đi, đừng để tao bắt được.',
      '30 giây',
    ),
    ScenarioModel(
      'stranger-at-home',
      'Có người lạ vào trọ',
      'Roommate',
      'Ê, trọ mình có cái ông già già nào vào ý. Mày ơi, tao sợ vãi, mày về đi.',
      '20 giây',
    ),
    ScenarioModel(
      'friend-pickup',
      'Bạn đến đón',
      'Cốt',
      'Alo, tới chưa má, lâu vậy? Ok, được rồi, giờ mày chụp cái biển số xe gửi qua đây đi, rồi tao xuống dưới nhà tao canh, tao đón mày nè.',
      '25 giây',
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
