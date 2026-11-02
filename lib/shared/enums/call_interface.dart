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

/// Khi video người gọi phát hết: tắt máy như người gọi gác máy, hoặc phát lại
/// từ đầu để cuộc gọi kéo dài đến khi người dùng tự kết thúc.
enum VideoEndAction {
  hangUp('Tắt máy'),
  loop('Lặp lại video');

  const VideoEndAction(this.label);
  final String label;

  static VideoEndAction parse(Object? raw) => VideoEndAction.values.firstWhere(
    (value) => value.name.toLowerCase() == '$raw'.toLowerCase().trim(),
    orElse: () => VideoEndAction.hangUp,
  );
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
