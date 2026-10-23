enum CallInterface {
  phone('Điện thoại'),
  zalo('Zalo'),
  messenger('Messenger');

  const CallInterface(this.label);
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
