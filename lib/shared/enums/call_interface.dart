enum CallInterface {
  phone('Điện thoại'),
  zalo('Zalo'),
  messenger('Messenger');

  const CallInterface(this.label);
  final String label;
}

/// Loại cuộc gọi của combo. Gọi video phát video người gọi tự quay và bật
/// camera trước của người dùng như một cuộc gọi video thật.
enum CallType {
  voice('Gọi thoại'),
  video('Gọi video');

  const CallType(this.label);
  final String label;
}

enum RingtoneType { interfaceDefault, classic, custom }

enum BackgroundSound {
  office('Văn phòng'),
  traffic('Còi xe'),
  television('Tiếng TV'),
  cafe('Nhạc cà phê'),
  rain('Trời mưa');

  const BackgroundSound(this.label);
  final String label;
}

enum CallStatus { idle, scheduled, ringing, inProgress }
