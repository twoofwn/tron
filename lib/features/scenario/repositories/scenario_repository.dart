import '../models/scenario_model.dart';

abstract final class ScenarioRepository {
  static const scenarios = [
    ScenarioModel(
      'boss',
      'Sếp cần file gấp',
      'Sếp Hùng',
      'Alo, em đang ở đâu đấy? Anh đang ngồi với khách, họ muốn xem lại cái file báo giá em làm hôm qua. Trên máy anh mở không được. Em về máy gửi lại cho anh bản mới nhất nhé? Ừ, khoảng mười lăm phút nữa là được đúng không? Anh đợi. Gửi xong nhắn anh một tiếng nhé. Thế nhé.',
      '45 giây',
    ),
    ScenarioModel(
      'mother',
      'Mẹ gọi về ăn cơm',
      'Mẹ',
      'Alo, con à? Con đang ở đâu đấy? Ông bà nội vừa lên chơi, đang ngồi ở nhà mình đây này. Ông bà cứ hỏi con mãi. Con về ăn cơm với cả nhà luôn nhé. Ừ, mẹ nấu cơm rồi đấy, về sớm nhé. À, tiện đường mua giúp mẹ chai nước mắm ở đầu ngõ nhé con.',
      '45 giây',
    ),
    ScenarioModel(
      'friend',
      'Lan nhờ ra đón',
      'Lan',
      'Ê, cậu đang ở đâu thế? Xe tớ bị thủng săm rồi, đang ngồi ở quán cà phê gần nhà cậu nè. Điện thoại tớ cũng sắp hết pin. Cậu ra đây với tớ một lát được không? Ừ, cậu ra nhanh nhé, tớ ngồi bàn ngay ngoài cửa. Đến nơi thì gọi tớ nha.',
      '40 giây',
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
