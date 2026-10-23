import '../models/scenario_model.dart';

abstract final class ScenarioRepository {
  static const scenarios = [
    ScenarioModel(
      'boss',
      'Sếp báo server sập',
      'Anh Minh · Công việc',
      'Em đang ở đâu đấy? Hệ thống bên mình đang gặp sự cố, khách hàng không truy cập được. Em về kiểm tra giúp anh ngay nhé. Anh đang đợi ở văn phòng. Ừ, em cứ về sớm nhất có thể nhé.',
      '25 giây',
    ),
    ScenarioModel(
      'mother',
      'Mẹ nhắc về nhà',
      'Mẹ yêu',
      'Con ơi, con đang ở đâu? Về nhà giúp mẹ một chút nhé, nhà mình đang có việc gấp. Mẹ chờ con ở nhà. Đi đường cẩn thận nhé con.',
      '20 giây',
    ),
    ScenarioModel(
      'friend',
      'Bạn có chuyện cần tâm sự',
      'Lan',
      'A lô, cậu có rảnh không? Tớ đang có chuyện cần nói với cậu. Cậu ra quán cà phê quen của mình nhé, tớ đang ở đây rồi. Gặp cậu một chút thôi, cảm ơn cậu nha.',
      '22 giây',
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
